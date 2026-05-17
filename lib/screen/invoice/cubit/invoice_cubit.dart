// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/invoice/cubit/invoice_cubit.dart          ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:io';

import 'package:crm_app/database/local_db.dart';
import 'package:crm_app/screen/invoice/modal/invoice_model.dart';
import 'package:crm_app/screen/invoice/ui/dealOption.dart'
    show DealOption, SalesUser;
import 'package:crm_app/screen/invoice/ui/invoice_screen.dart'
    show
        InvoiceState,
        InvoiceInitial,
        InvoiceLoading,
        InvoiceLoaded,
        InvoiceError;
import 'package:dio/dio.dart'
    show
        DioExceptionType,
        DioException,
        Dio,
        BaseOptions,
        InterceptorsWrapper,
        ResponseType,
        Options;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoiceCubit extends Cubit<InvoiceState> {
  static const _base = 'https://sales.stagingzar.com/api';
  static const MethodChannel _downloadsChannel = MethodChannel('crm/downloads');
  final _db = LocalDb.instance;
  late final Dio _dio;
  final Map<String, double> _rateCache = {};

  InvoiceCubit() : super(InvoiceInitial()) {
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opt, handler) async {
        final p = await SharedPreferences.getInstance();
        final t = p.getString('token');
        if (t != null) opt.headers['Authorization'] = 'Bearer $t';
        handler.next(opt);
      },
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // LOAD
  // ─────────────────────────────────────────────────────────────
  Future<void> load() async {
    emit(InvoiceLoading());

    // Permissions + current user (used to scope invoice visibility)
    await PermissionHelper.load();
    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString('user_id') ?? '').trim();
    final userName = (prefs.getString('user_name') ?? '').trim();
    final canViewAll = PermissionHelper.can('admin_access') ||
        PermissionHelper.can('users_roles');

    // ✅ FIX 1: Always read the local SQLite cache first so the UI is
    // never blank while the network call is in flight (or offline).
    final localRows = await _db.getInvoices();
    final localInvs = localRows.map(Invoice.fromMap).toList();

    try {
      final apiInvoices = await _fetchInvoices('/Invoices/getInvoice');
      final recentInvs = await _fetchSafe('/Invoices/recent');
      final pendingInvs = await _fetchSafe('/Invoices/pending');

      // ✅ FIX 2: Persist every API invoice to SQLite so future offline
      // sessions see the full dataset, not just locally-created records.
      for (final inv in apiInvoices) {
        await _db.upsertInvoiceFromApi(inv.toSaveMap()
          ..['_id'] = inv.id
          ..['invoiceNo'] = inv.invoiceNo
          ..['createdAt'] = inv.createdAt.toIso8601String()
          ..['status'] = inv.status
          ..['currency'] = inv.currency
          ..['inrAmount'] = inv.inrAmount
          ..['exchangeRate'] = inv.exchangeRate
          ..['isLocal'] = 0);
      }

      // Merge: local-only records first, then API records (dedup by id)
      final apiIds = apiInvoices.map((i) => i.id).toSet();
      final localOnly = localInvs.where((i) => !apiIds.contains(i.id)).toList();
      final merged = [...localOnly, ...apiInvoices];

      final users = await _fetchUsers();
      final deals = await _fetchDeals();

      final mergedWithRates = await _applyApiRates(merged);
      final dedupedAll = mergedWithRates
          .map((i) => _normalizeInvoiceForUi(i, users: users, deals: deals))
          .toList();
      final recentAll = (await _applyApiRates(recentInvs))
          .map((i) => _normalizeInvoiceForUi(i, users: users, deals: deals))
          .toList();
      final pendingAll = (await _applyApiRates(pendingInvs))
          .map((i) => _normalizeInvoiceForUi(i, users: users, deals: deals))
          .toList();

      bool matchesCurrentUser(Invoice inv) {
        if (canViewAll) return true;
        final a = inv.assignTo.trim();
        if (a.isEmpty) return false;

        // Some APIs return assignedTo as an id, some as a name.
        if (userId.isNotEmpty && a == userId) return true;

        if (userName.isNotEmpty) {
          String norm(String s) =>
              s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
          return norm(a) == norm(userName);
        }
        return false;
      }

      final deduped = dedupedAll.where(matchesCurrentUser).toList();
      final recent = recentAll.where(matchesCurrentUser).toList();
      final pending = pendingAll.where(matchesCurrentUser).toList();

      emit(InvoiceLoaded(
        invoices: deduped,
        recentInvoices: recent,
        pendingInvoices: pending,
        salesUsers: users,
        deals: deals,
      ));
    } on DioException catch (e) {
      // ✅ FIX 3: On any network failure emit the SQLite cache so the app
      // remains fully usable offline — not just an empty list.
      if (_isOfflineError(e)) {
        final localOnlyAll =
            localInvs.map((i) => _normalizeInvoiceForUi(i)).toList();
        final localOnly = canViewAll
            ? localOnlyAll
            : localOnlyAll.where((i) {
                final a = i.assignTo.trim();
                if (a.isEmpty) return false;
                if (userId.isNotEmpty && a == userId) return true;
                if (userName.isEmpty) return false;
                String norm(String s) =>
                    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
                return norm(a) == norm(userName);
              }).toList();
        emit(InvoiceLoaded(
          invoices: localOnly,
          recentInvoices: const [],
          pendingInvoices: const [],
          salesUsers: const [],
          deals: const [],
        ));
      } else {
        emit(InvoiceError(e.response?.statusCode == 404
            ? 'Invoice endpoint not found (404).'
            : _dioMsg(e)));
      }
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Exchange rate helpers
  // ─────────────────────────────────────────────────────────────
  Future<List<Invoice>> _applyApiRates(List<Invoice> invoices) async {
    final out = <Invoice>[];
    for (final inv in invoices) {
      final ccy = inv.currency.toUpperCase().trim();
      if (ccy == 'INR' ||
          (inv.exchangeRate ?? 0) > 0 ||
          (inv.inrAmount ?? 0) > 0) {
        out.add(inv);
        continue;
      }
      final rate = await _fetchInrRate(ccy);
      if (rate != null && rate > 0) {
        out.add(inv.copyWith(exchangeRate: rate));
      } else {
        out.add(inv);
      }
    }
    return out;
  }

  Future<double?> _fetchInrRate(String currency) async {
    final ccy = currency.toUpperCase().trim();
    if (ccy.isEmpty || ccy == 'INR') return 1;
    // if (_rateCache.containsKey(ccy)) return _rateCache[ccy];
    try {
      final res = await _dio.get('/invoices/exchange-rate/$ccy');
      final rate = double.tryParse(res.data?['rate']?.toString() ?? '');
      if (rate != null && rate > 0) {
        _rateCache[ccy] = rate;
        return rate;
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // GET SINGLE
  // ─────────────────────────────────────────────────────────────
  Future<Invoice?> getById(String id) async {
    try {
      final res = await _dio.get('/Invoices/getSingle/$id');
      return _parseOne(res.data);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DOWNLOAD
  // ─────────────────────────────────────────────────────────────
  String downloadUrl(String id) => '$_base/invoices/download/$id';

  Future<String?> downloadInvoicePdf(String id,
      {required String fileName}) async {
    try {
      final safeName =
          fileName.trim().isEmpty ? 'invoice_$id' : fileName.trim();
      final response = await _dio.get<List<int>>(
        '/invoices/download/$id',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        return 'Empty invoice file received.';
      }
      if (Platform.isAndroid) {
        await _downloadsChannel.invokeMethod<String>(
          'saveToDownloads',
          <String, dynamic>{
            'fileName': '$safeName.pdf',
            'bytes': Uint8List.fromList(data),
            'mimeType': 'application/pdf',
          },
        );
      } else {
        await FileSaver.instance.saveFile(
          name: safeName,
          bytes: Uint8List.fromList(data),
          ext: 'pdf',
          mimeType: MimeType.pdf,
        );
      }
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    } on PlatformException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CREATE
  // ─────────────────────────────────────────────────────────────
  Future<String?> createInvoice(Map<String, dynamic> data) async {
    final normalizedData = _normalizeCreateDataForUi(data);
    print("CREATE INVOICE DATA => $data");
    print("PRICE BEFORE API => ${data['price']}");
    print("CURRENCY BEFORE API => ${data['currency']}");
    // ✅ FIX 4: Optimistic local insert — the record is visible instantly
    // and survives an app restart even if the server call never completes.
    final row = await _db.insertInvoice(normalizedData);
    final localInv = Invoice.fromMap(row);
    final prevState = state;

    if (state is InvoiceLoaded) {
      final s = state as InvoiceLoaded;
      emit(s.copyWithInvoices([localInv, ...s.invoices]));
    }

    try {
      final res = await _dio.post(
        '/Invoices/createinvoice',
        data: _toApiBody(normalizedData),
      );

      final parsed = _normalizeInvoiceForUi(_parseOne(res.data) ?? localInv);
      final serverInv = (await _applyApiRates([parsed])).first;

      // ✅ FIX 5: Persist the server-returned invoice (with its real _id)
      // and delete the optimistic local record so there's no duplicate.
      await _db.upsertInvoiceFromApi(_invoiceToUpsertMap(serverInv));
      if (serverInv.id != localInv.id) {
        await _db.deleteInvoice(localInv.id);
      }

      if (state is InvoiceLoaded) {
        final s = state as InvoiceLoaded;
        final updated = [
          serverInv,
          ...s.invoices.where((i) => i.id != localInv.id),
        ];

        emit(s.copyWithInvoices(updated));
      }
      return null;
    } on DioException catch (e) {
      // ✅ FIX 6: Offline → keep the local record (isLocal=true) and
      // return success so the user knows it will sync later.
      if (_isOfflineError(e)) return null;
      await _db.deleteInvoice(localInv.id);
      emit(prevState);
      return _dioMsg(e);
    } catch (e) {
      await _db.deleteInvoice(localInv.id);
      emit(prevState);
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UPDATE
  // ─────────────────────────────────────────────────────────────
  Future<String?> updateInvoice(String id, Map<String, dynamic> data) async {
    final prevState = state;

    if (state is InvoiceLoaded) {
      final s = state as InvoiceLoaded;

      String? displayName = data['assignTo']?.toString();
      final assignToId = data['assignToId']?.toString() ?? '';
      if (assignToId.isNotEmpty) {
        try {
          displayName = s.salesUsers.firstWhere((u) => u.id == assignToId).name;
        } catch (_) {}
      }

      final uiStatus =
          Invoice.normaliseStatus(data['status']?.toString() ?? 'Unpaid');

      emit(s.copyWithInvoices(s.invoices.map((inv) {
        if (inv.id != id) return inv;
        return inv.copyWith(
          assignTo: displayName,
          issueDate: data['issueDate']?.toString(),
          dueDate: data['dueDate']?.toString(),
          status: uiStatus,
          taxType: data['taxType']?.toString(),
          taxValue: (data['taxValue'] as num?)?.toDouble(),
          discountType: data['discountType']?.toString(),
          discountValue: (data['discountValue'] as num?)?.toDouble(),
          dealId: data['dealId']?.toString(),
          dealName: data['dealName']?.toString(),
          price: (data['price'] as num?)?.toDouble(),
          notes: data['notes']?.toString(),
          currency: data['currency']?.toString(),
        );
      }).toList()));
    }

    // ✅ FIX 7: Always write to SQLite first (optimistic) — works online AND offline.
    await _db.updateInvoice(id, data);

    try {
      await _dio.put('/Invoices/updateInvoice/$id', data: _toApiBody(data));
      return null;
    } on DioException catch (e) {
      // ✅ FIX 8: Offline → SQLite already updated; silently succeed.
      if (_isOfflineError(e)) return null;
      emit(prevState);
      return _dioMsg(e);
    } catch (e) {
      emit(prevState);
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────
  Future<String?> deleteInvoice(String id) async {
    final prevState = state;

    // ✅ FIX 9: Remove from SQLite immediately (optimistic) before the API call.
    await _db.deleteInvoice(id);

    if (state is InvoiceLoaded) {
      final s = state as InvoiceLoaded;
      emit(s.copyWithInvoices(s.invoices.where((i) => i.id != id).toList()));
    }

    try {
      await _dio.delete('/Invoices/delete/$id');
      return null;
    } on DioException catch (e) {
      // ✅ FIX 10: Offline → SQLite already cleaned up; treat as success.
      if (_isOfflineError(e)) return null;
      emit(prevState);
      return _dioMsg(e);
    } catch (e) {
      emit(prevState);
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BULK DELETE
  // ─────────────────────────────────────────────────────────────
  Future<String?> bulkDeleteInvoices(List<String> ids) async {
    if (ids.isEmpty) return null;
    final prevState = state;
    final idSet = ids.toSet();

    // ✅ FIX 11: Delete from SQLite first so offline bulk-delete works.
    for (final id in ids) {
      await _db.deleteInvoice(id);
    }

    if (state is InvoiceLoaded) {
      final s = state as InvoiceLoaded;
      emit(s.copyWithInvoices(
          s.invoices.where((i) => !idSet.contains(i.id)).toList()));
    }

    try {
      await _dio.delete('/Invoices/bulk-delete', data: {'ids': ids});
      return null;
    } on DioException catch (e) {
      if (_isOfflineError(e)) return null;
      emit(prevState);
      return _dioMsg(e);
    } catch (e) {
      emit(prevState);
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SEND EMAIL
  // ─────────────────────────────────────────────────────────────
  Future<String?> sendEmail(String id) async {
    try {
      await _dio.post('/invoices/sendEmail/$id');
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    } catch (e) {
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // REFRESH
  // ─────────────────────────────────────────────────────────────
  Future<void> refresh() async {
    if (state is! InvoiceLoading) load();
  }

  // ═══════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════

  /// Converts an [Invoice] object into the flat map shape expected by
  /// [LocalDb.upsertInvoiceFromApi]. Keeps all nullable fields explicit.
  Map<String, dynamic> _invoiceToUpsertMap(Invoice inv) => {
        '_id': inv.id,
        'invoiceNo': inv.invoiceNo,
        'assignTo': inv.assignTo,
        'issueDate': inv.issueDate,
        'dueDate': inv.dueDate,
        'status': inv.status,
        'taxType': inv.taxType,
        'taxValue': inv.taxValue,
        'discountType': inv.discountType,
        'discountValue': inv.discountValue,
        'dealId': inv.dealId,
        'dealName': inv.dealName,
        'notes': inv.notes,
        'currency': inv.currency,
        'price': inv.price,
        'inrAmount': inv.inrAmount,
        'exchangeRate': inv.exchangeRate,
        'createdAt': inv.createdAt.toIso8601String(),
        'isLocal': inv.isLocal ? 1 : 0,
      };

  Map<String, dynamic> _toApiBody(Map<String, dynamic> data) {
    final price = _num(data['price']);
    final amounts = _computeInvoiceAmounts(data, price);
    final dealId = data['dealId']?.toString() ?? '';
    final dealName = data['dealName']?.toString() ?? '';
    final itemDesc = data['dealRequirement']?.toString() ?? '';

    return {
      'assignTo': data['assignToId'] ?? data['assignTo'],
      'deal': dealId,

      'issueDate': _toApiDate(data['issueDate']?.toString() ?? ''),
      'dueDate': _toApiDate(data['dueDate']?.toString() ?? ''),

      'status': (data['status']?.toString() ?? 'unpaid').toLowerCase(),

      'subtotal': price,
      'discountType': amounts.discountTypeApi,
      'discountValue': amounts.discountValueApi,
      'discount': amounts.discountAmount,
      'taxType': amounts.taxTypeApi,
      'taxValue': amounts.taxValueApi,
      'tax': amounts.taxAmount,
      'total': amounts.total,

      'notes': data['notes']?.toString() ?? '',
      'currency': data['currency'] ?? 'INR',

      'items': [
        {
          'name': dealName.isNotEmpty ? dealName : 'Invoice Item',
          'description': itemDesc,
          'quantity': 1,
          'price': price,
          'amount': price,
          'deal': dealId,
        },
      ],
    };
  }

  /// Matches API: discount on subtotal, tax on (subtotal − discount), total = subtotal − discount + tax.
  ({
    double discountAmount,
    double taxAmount,
    double total,
    double discountValueApi,
    double taxValueApi,
    String discountTypeApi,
    String taxTypeApi,
  }) _computeInvoiceAmounts(Map<String, dynamic> data, double price) {
    final taxType = data['taxType']?.toString() ?? 'Zero Tax';
    final taxValueInput = _num(data['taxValue']);
    final discountType = data['discountType']?.toString() ?? 'No Discount';
    final discountValueInput = _num(data['discountValue']);

    var discountAmount = 0.0;
    if (discountType == 'Percentage') {
      discountAmount = price * discountValueInput / 100;
    } else if (discountType == 'Fixed Amount') {
      discountAmount = discountValueInput;
    }

    final taxableBase =
        (price - discountAmount).clamp(0, double.infinity).toDouble();

    var taxAmount = 0.0;
    if (taxType == 'Percentage') {
      taxAmount = taxableBase * taxValueInput / 100;
    } else if (taxType == 'Fixed Amount') {
      taxAmount = taxValueInput;
    }

    final total = (price - discountAmount + taxAmount)
        .clamp(0, double.infinity)
        .toDouble();

    final discountTypeApi = _toApiType(discountType);
    final taxTypeApi = _toApiType(taxType);

    final discountValueApi =
        discountType == 'No Discount' ? 0.0 : discountValueInput;
    final taxValueApi = taxType == 'Zero Tax' ? 0.0 : taxValueInput;

    return (
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      total: total,
      discountValueApi: discountValueApi,
      taxValueApi: taxValueApi,
      discountTypeApi: discountTypeApi,
      taxTypeApi: taxTypeApi,
    );
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// Backend only accepts "fixed" or "percentage" (not "none").
  String _toApiType(String? v) {
    if (v == null) return 'fixed';
    if (v.toLowerCase().contains('percent')) return 'percentage';
    return 'fixed';
  }

  /// API expects `YYYY-MM-DD` (e.g. `2026-05-14`).
  String _toApiDate(String raw) {
    if (raw.isEmpty) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    }
    final iso = DateTime.tryParse(raw);
    if (iso != null) {
      return DateFormat('yyyy-MM-dd').format(iso.toUtc());
    }
    try {
      final dt = DateFormat('dd MMM yyyy').parse(raw);
      return DateFormat('yyyy-MM-dd').format(dt.toUtc());
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
    }
  }

  Future<List<Invoice>> _fetchInvoices(String path) async {
    final res = await _dio.get(path);
    final list = _rawList(res.data, keys: ['data', 'invoices', 'result']);
    return list.map(_safeFromJson).whereType<Invoice>().toList();
  }

  Future<List<Invoice>> _fetchSafe(String path) async {
    try {
      final res = await _dio.get(path);
      final list = _rawList(res.data, keys: [
        'data',
        'invoices',
        'result',
        'recentInvoices',
        'pendingInvoices',
      ]);
      return list.map(_safeFromJson).whereType<Invoice>().toList();
    } on DioException catch (e) {
      debugPrint('[InvoiceCubit] $path → ${e.response?.statusCode ?? e.type}');
      return [];
    } catch (e) {
      debugPrint('[InvoiceCubit] $path → $e');
      return [];
    }
  }

  Future<List<SalesUser>> _fetchUsers() async {
    try {
      final res = await _dio.get('/users/sales');
      final list = _rawList(res.data,
          keys: ['data', 'users', 'salesUsers', 'result', 'salesTeam']);
      return list
          .map((m) {
            final id = (m['_id'] ?? m['id'] ?? '').toString();
            final fn = m['firstName']?.toString().trim() ?? '';
            final ln = m['lastName']?.toString().trim() ?? '';
            final full = '$fn $ln'.trim();
            final name =
                full.isNotEmpty ? full : (m['name']?.toString().trim() ?? '');
            return SalesUser(id, name);
          })
          .where((u) => u.id.isNotEmpty && u.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[InvoiceCubit] _fetchUsers: $e');
      return [];
    }
  }

  Future<List<DealOption>> _fetchDeals() async {
    try {
      final res = await _dio.get('/deals/getAll');
      final list = _rawList(res.data);

      return list
          .map((m) {
            String safeString(dynamic v, {String fallback = ''}) {
              if (v == null) return fallback;
              final s = v.toString().trim();
              if (s.isEmpty || s.toLowerCase() == 'null') return fallback;
              return s;
            }

            final id = safeString(m['_id'] ?? m['id']);
            final name = safeString(m['dealName'] ?? m['name']);

            // Full raw value example: "1,000 USD"
            final rawValue = safeString(
                m['value'] ??
                    m['dealvalue'] ??
                    m['dealValue'] ??
                    m['price'] ??
                    '0',
                fallback: '0');
            print("RAW DEAL VALUE => ${m['value']}");

            // Extract numeric amount
            final val = double.tryParse(
                  rawValue
                      .replaceAll(',', '')
                      .replaceAll(RegExp(r'[^0-9.]'), ''),
                ) ??
                0;
            print("PARSED VALUE => $val");
            final rawCurrency = safeString(m['currency']);

            String cur = 'INR';

            if (rawCurrency.isNotEmpty) {
              if (rawCurrency.contains('INR'))
                cur = 'INR';
              else if (rawCurrency.contains('USD'))
                cur = 'USD';
              else if (rawCurrency.contains('EUR'))
                cur = 'EUR';
              else if (rawCurrency.contains('GBP'))
                cur = 'GBP';
              else if (rawCurrency.contains('JPY'))
                cur = 'JPY';
              else if (rawCurrency.contains('CNY'))
                cur = 'CNY';
              else if (rawCurrency.contains('AUD'))
                cur = 'AUD';
              else if (rawCurrency.contains('CAD'))
                cur = 'CAD';
              else if (rawCurrency.contains('CHF'))
                cur = 'CHF';
              else if (rawCurrency.contains('MYR'))
                cur = 'MYR';
              else if (rawCurrency.contains('AED'))
                cur = 'AED';
              else if (rawCurrency.contains('SGD'))
                cur = 'SGD';
              else if (rawCurrency.contains('ZAR'))
                cur = 'ZAR';
              else if (rawCurrency.contains('SAR')) cur = 'SAR';
            }

            final req = safeString(m['requirement']);

            return DealOption(
              id,
              name,
              val,
              cur,
              requirement: req,
            );
          })
          .where((d) => d.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Invoice? _safeFromJson(Map<String, dynamic> m) {
    try {
      return Invoice.fromJson(m);
    } catch (e) {
      debugPrint('[InvoiceCubit] fromJson error: $e');
      return null;
    }
  }

  Invoice? _parseOne(dynamic data) {
    try {
      Map<String, dynamic>? map;
      if (data is Map) {
        final d = Map<String, dynamic>.from(data);
        if (d.containsKey('_id') || d.containsKey('id')) {
          map = d;
        } else {
          for (final k in ['data', 'invoice', 'result']) {
            if (d[k] is Map) {
              map = Map<String, dynamic>.from(d[k] as Map);
              break;
            }
          }
        }
      } else if (data is List && data.isNotEmpty) {
        map = Map<String, dynamic>.from(data.first as Map);
      }
      return map != null ? _normalizeInvoiceForUi(Invoice.fromJson(map)) : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _normalizeCreateDataForUi(Map<String, dynamic> data) {
    if (state is! InvoiceLoaded) return data;
    final s = state as InvoiceLoaded;
    final normalized = Map<String, dynamic>.from(data);
    final assignToId = normalized['assignToId']?.toString() ?? '';
    if (assignToId.isNotEmpty) {
      try {
        normalized['assignTo'] =
            s.salesUsers.firstWhere((u) => u.id == assignToId).name;
      } catch (_) {}
    }
    final dealId = normalized['dealId']?.toString() ?? '';
    if (dealId.isNotEmpty) {
      try {
        normalized['dealName'] = s.deals.firstWhere((d) => d.id == dealId).name;
      } catch (_) {}
    }
    return normalized;
  }

  Invoice _normalizeInvoiceForUi(
    Invoice inv, {
    List<SalesUser>? users,
    List<DealOption>? deals,
  }) {
    final loaded = state is InvoiceLoaded ? (state as InvoiceLoaded) : null;
    final effectiveUsers = users ?? loaded?.salesUsers ?? const <SalesUser>[];
    final effectiveDeals = deals ?? loaded?.deals ?? const <DealOption>[];

    String assignTo = inv.assignTo;
    if (assignTo.isNotEmpty) {
      try {
        assignTo = effectiveUsers.firstWhere((u) => u.id == assignTo).name;
      } catch (_) {}
    }

    var dealName = inv.dealName;
    if (dealName.trim().isEmpty || dealName.trim().toLowerCase() == 'no deal') {
      final did = inv.dealId.trim();
      if (did.isNotEmpty) {
        try {
          dealName = effectiveDeals.firstWhere((d) => d.id == did).name;
        } catch (_) {}
      }
    }

    return inv.copyWith(assignTo: assignTo, dealName: dealName);
  }

  List<Map<String, dynamic>> _rawList(dynamic d,
      {List<String> keys = const [
        'data',
        'result',
        'invoices',
        'users',
        'salesUsers',
        'deals',
        'records',
        'items',
        'list',
      ]}) {
    List<dynamic> raw = [];
    if (d is List) {
      raw = d;
    } else if (d is Map) {
      for (final k in keys) {
        if (d[k] is List) {
          raw = d[k] as List;
          break;
        }
      }
      if (raw.isEmpty) {
        for (final v in d.values) {
          if (v is List) {
            raw = v;
            break;
          }
        }
      }
    }
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _dioMsg(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    if (e.type == DioExceptionType.badResponse) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'] ?? data['msg'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          return msg.toString();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        return data;
      }
      return 'Server error (${e.response?.statusCode}).';
    }
    return 'Something went wrong.';
  }

  bool _isOfflineError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout;
}
