// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/invoice/cubit/invoice_cubit.dart          ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:io';

import 'package:crm_app/database/local_db.dart';
import 'package:crm_app/screen/invoice/modal/invoice_model.dart';
import 'package:crm_app/screen/invoice/ui/dealOption.dart' show DealOption, SalesUser;
import 'package:crm_app/screen/invoice/ui/invoice_screen.dart'
    show
        InvoiceState,
        InvoiceInitial,
        InvoiceLoading,
        InvoiceLoaded,
        InvoiceError;
import 'package:dio/dio.dart'
    show DioExceptionType, DioException, Dio, BaseOptions, InterceptorsWrapper, ResponseType, Options;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
    try {
      final apiInvoices = await _fetchInvoices('/Invoices/getInvoice');
      final recentInvs  = await _fetchSafe('/Invoices/recent');
      final pendingInvs = await _fetchSafe('/Invoices/pending');

      final localRows = await _db.getInvoices();
      final localInvs = localRows.map(Invoice.fromMap).toList();

      final localIds = localInvs.map((i) => i.id).toSet();
      final dedupedRaw  = <Invoice>[
        ...localInvs,
        ...apiInvoices.where((i) => !localIds.contains(i.id)),
      ];

      final users = await _fetchUsers();
      final deals = await _fetchDeals();
      final dedupedWithRates = await _applyApiRates(dedupedRaw);
      final deduped = dedupedWithRates
          .map((i) => _normalizeInvoiceForUi(i, users: users, deals: deals))
          .toList();
      final recent = (await _applyApiRates(recentInvs))
          .map((i) => _normalizeInvoiceForUi(i, users: users, deals: deals))
          .toList();
      final pending = (await _applyApiRates(pendingInvs))
          .map((i) => _normalizeInvoiceForUi(i, users: users, deals: deals))
          .toList();

      emit(InvoiceLoaded(
        invoices:        deduped,
        recentInvoices:  recent,
        pendingInvoices: pending,
        salesUsers:      users,
        deals:           deals,
      ));
    } on DioException catch (e) {
      emit(InvoiceError(e.response?.statusCode == 404
          ? 'Invoice endpoint not found (404).'
          : _dioMsg(e)));
    } catch (e) {
      emit(InvoiceError(e.toString()));
    }
  }

  Future<List<Invoice>> _applyApiRates(List<Invoice> invoices) async {
    final out = <Invoice>[];
    for (final inv in invoices) {
      final ccy = inv.currency.toUpperCase().trim();
      if (ccy == 'INR' || (inv.exchangeRate ?? 0) > 0 || (inv.inrAmount ?? 0) > 0) {
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
    if (_rateCache.containsKey(ccy)) return _rateCache[ccy];
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
  // DOWNLOAD URL
  // ─────────────────────────────────────────────────────────────
  String downloadUrl(String id) => '$_base/invoices/download/$id';

  Future<String?> downloadInvoicePdf(String id, {required String fileName}) async {
    try {
      final safeName = fileName.trim().isEmpty ? 'invoice_$id' : fileName.trim();
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
  // CREATE  POST /Invoices/createinvoice
  // Returns null on success, error string on failure.
  // ─────────────────────────────────────────────────────────────
  Future<String?> createInvoice(Map<String, dynamic> data) async {
    final normalizedData = _normalizeCreateDataForUi(data);

    // Optimistic local insert
    final row      = await _db.insertInvoice(normalizedData);
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

      if (state is InvoiceLoaded) {
        final s       = state as InvoiceLoaded;
        final updated = s.invoices
            .map((i) => i.id == localInv.id ? serverInv : i)
            .toList();
        emit(s.copyWithInvoices(updated));
        if (serverInv.id != localInv.id) await _db.deleteInvoice(localInv.id);
      }
      return null;
    } on DioException catch (e) {
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
  // UPDATE  PUT /Invoices/updateInvoice/:id
  // Returns null on success, error string on failure.
  // ─────────────────────────────────────────────────────────────
  Future<String?> updateInvoice(String id, Map<String, dynamic> data) async {
    final prevState = state;

    if (state is InvoiceLoaded) {
      final s = state as InvoiceLoaded;

      // Resolve display name so the card never shows a raw _id string
      String? displayName = data['assignTo']?.toString();
      final assignToId = data['assignToId']?.toString() ?? '';
      if (assignToId.isNotEmpty) {
        try {
          displayName = s.salesUsers
              .firstWhere((u) => u.id == assignToId)
              .name;
        } catch (_) {}
      }

      // Normalise status to Title case for optimistic UI update
      final uiStatus = Invoice.normaliseStatus(
          data['status']?.toString() ?? 'Unpaid');

      emit(s.copyWithInvoices(s.invoices.map((inv) {
        if (inv.id != id) return inv;
        return inv.copyWith(
          assignTo:      displayName,
          issueDate:     data['issueDate']?.toString(),
          dueDate:       data['dueDate']?.toString(),
          status:        uiStatus,
          taxType:       data['taxType']?.toString(),
          taxValue:      (data['taxValue']      as num?)?.toDouble(),
          discountType:  data['discountType']?.toString(),
          discountValue: (data['discountValue'] as num?)?.toDouble(),
          dealId:        data['dealId']?.toString(),
          dealName:      data['dealName']?.toString(),
          price:         (data['price']         as num?)?.toDouble(),
          notes:         data['notes']?.toString(),
          currency:      data['currency']?.toString(),
        );
      }).toList()));
    }

    try {
      await _dio.put('/Invoices/updateInvoice/$id', data: _toApiBody(data));
      await _db.updateInvoice(id, data);
      return null;
    } on DioException catch (e) {
      emit(prevState);
      return _dioMsg(e);
    } catch (e) {
      emit(prevState);
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE  DELETE /Invoices/delete/:id
  // Returns null on success, error string on failure.
  // ─────────────────────────────────────────────────────────────
  Future<String?> deleteInvoice(String id) async {
    final prevState = state;
    if (state is InvoiceLoaded) {
      final s = state as InvoiceLoaded;
      emit(s.copyWithInvoices(s.invoices.where((i) => i.id != id).toList()));
    }
    try {
      await _dio.delete('/Invoices/delete/$id');
      await _db.deleteInvoice(id);
      return null;
    } on DioException catch (e) {
      emit(prevState);
      return _dioMsg(e);
    } catch (e) {
      emit(prevState);
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BULK DELETE  DELETE /Invoices/bulk-delete  { ids: [...] }
  // Returns null on success, error string on failure.
  // ─────────────────────────────────────────────────────────────
  Future<String?> bulkDeleteInvoices(List<String> ids) async {
    if (ids.isEmpty) return null;
    final prevState = state;
    if (state is InvoiceLoaded) {
      final s     = state as InvoiceLoaded;
      final idSet = ids.toSet();
      emit(s.copyWithInvoices(
          s.invoices.where((i) => !idSet.contains(i.id)).toList()));
    }
    try {
      await _dio.delete('/Invoices/bulk-delete', data: {'ids': ids});
      for (final id in ids) {
        await _db.deleteInvoice(id);
      }
      return null;
    } on DioException catch (e) {
      emit(prevState);
      return _dioMsg(e);
    } catch (e) {
      emit(prevState);
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SEND EMAIL  POST /invoices/sendEmail/:id
  // Returns null on success, error string on failure.
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

  // ─────────────────────────────────────────────────────────────
  // Build the request body the API expects.
  // ─────────────────────────────────────────────────────────────
  Map<String, dynamic> _toApiBody(Map<String, dynamic> data) {
    return {
      // assignTo expects the user _id string, not the display name
      'assignTo':    data['assignToId'] ?? data['assignTo'],

      // ISO 8601 UTC dates
      'issueDate':   _toIso(data['issueDate']?.toString() ?? ''),
      'dueDate':     _toIso(data['dueDate']?.toString()   ?? ''),

      // API stores lowercase status: "paid" / "unpaid" / "send"
      'status':      (data['status']?.toString() ?? 'unpaid').toLowerCase(),

      // items array — backend requires this exact shape
      'items': [
        {
          'deal':   data['dealId'],
          'price':  data['price'],
          'amount': data['price'],
        }
      ],

      // API field is "note" (not "notes")
      'note':         data['notes'] ?? '',

      // numeric values + lowercase type strings
      'discount':     data['discountValue'] ?? 0,
      'discountType': _toApiType(data['discountType']?.toString()),
      'tax':          data['taxValue'] ?? 0,
      'taxType':      _toApiType(data['taxType']?.toString()),

      'currency':     data['currency'] ?? 'INR',
    };
  }

  // ─────────────────────────────────────────────────────────────
  // UI label → API type string
  // "Percentage"              → "percentage"
  // "Fixed Amount" / anything → "fixed"
  // ─────────────────────────────────────────────────────────────
  String _toApiType(String? v) {
    if (v == null) return 'fixed';
    if (v.toLowerCase().contains('percent')) return 'percentage';
    return 'fixed';
  }

  // ─────────────────────────────────────────────────────────────
  // "06 Apr 2026" or ISO → ISO 8601 UTC string
  // ─────────────────────────────────────────────────────────────
  String _toIso(String raw) {
    if (raw.isEmpty) return DateTime.now().toUtc().toIso8601String();
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso.toUtc().toIso8601String();
    try {
      final dt = DateFormat('dd MMM yyyy').parse(raw);
      return dt.toUtc().toIso8601String();
    } catch (_) {
      return DateTime.now().toUtc().toIso8601String();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch all invoices from the main endpoint
  // ─────────────────────────────────────────────────────────────
  Future<List<Invoice>> _fetchInvoices(String path) async {
    final res  = await _dio.get(path);
    final list = _rawList(res.data, keys: ['data', 'invoices', 'result']);
    return list.map(_safeFromJson).whereType<Invoice>().toList();
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch recent / pending — silently returns [] on any error
  // ─────────────────────────────────────────────────────────────
  Future<List<Invoice>> _fetchSafe(String path) async {
    try {
      final res  = await _dio.get(path);
      final list = _rawList(res.data, keys: [
        'data', 'invoices', 'result', 'recentInvoices', 'pendingInvoices',
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

  // ─────────────────────────────────────────────────────────────
  // Fetch sales users — returns List<SalesUser> with id + name
  // ─────────────────────────────────────────────────────────────
  Future<List<SalesUser>> _fetchUsers() async {
    try {
      final res  = await _dio.get('/users/sales');
      final list = _rawList(res.data,
          keys: ['data', 'users', 'salesUsers', 'result', 'salesTeam']);
      return list.map((m) {
        final id = (m['_id'] ?? m['id'] ?? '').toString();
        final fn = m['firstName']?.toString().trim() ?? '';
        final ln = m['lastName']?.toString().trim()  ?? '';
        final full = '$fn $ln'.trim();
        final name = full.isNotEmpty ? full : (m['name']?.toString().trim() ?? '');
        return SalesUser(id, name);
      }).where((u) => u.id.isNotEmpty && u.name.isNotEmpty).toList();
    } catch (e) {
      debugPrint('[InvoiceCubit] _fetchUsers: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Fetch deals
  // ─────────────────────────────────────────────────────────────
  Future<List<DealOption>> _fetchDeals() async {
    try {
      final res  = await _dio.get('/deals/getAll');
      final list = _rawList(res.data);
      return list.map((m) {
        String safeString(dynamic v, {String fallback = ''}) {
          if (v == null) return fallback;
          final s = v.toString().trim();
          if (s.isEmpty || s.toLowerCase() == 'null') return fallback;
          return s;
        }

        final id   = safeString(m['_id'] ?? m['id']);
        final name = safeString(m['dealName'] ?? m['name']);
        final valRaw = safeString(m['value'] ?? m['dealValue'] ?? '0', fallback: '0')
            .replaceAll(RegExp(r'[^\d.\-]'), '');
        final val  = double.tryParse(valRaw) ?? 0;
        final cur  = safeString(m['currency'], fallback: 'INR');
        final req  = safeString(m['requirement']);
        return DealOption(id, name, val, cur, requirement: req);
      }).where((d) => d.id.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Safely parse one invoice from a JSON map — logs and returns
  // null on any error so a single bad record doesn't crash the list
  // ─────────────────────────────────────────────────────────────
  Invoice? _safeFromJson(Map<String, dynamic> m) {
    try {
      return Invoice.fromJson(m);
    } catch (e) {
      debugPrint('[InvoiceCubit] fromJson error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Parse a single invoice from any API wrapper shape:
  //   { invoice: {...} }  /  { data: {...} }  /  raw object  /  array
  // ─────────────────────────────────────────────────────────────
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
        normalized['dealName'] =
            s.deals.firstWhere((d) => d.id == dealId).name;
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

    return inv.copyWith(
      assignTo: assignTo,
      dealName: dealName,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Extract a List<Map> from any API wrapper shape
  // ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _rawList(dynamic d,
      {List<String> keys = const [
        'data', 'result', 'invoices', 'users', 'salesUsers',
        'deals', 'records', 'items', 'list',
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
      // Last resort: grab the first List value found
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

  // ─────────────────────────────────────────────────────────────
  // Human-readable Dio error messages
  // ─────────────────────────────────────────────────────────────
  String _dioMsg(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout  => 'Connection timed out.',
    DioExceptionType.connectionError => 'No internet connection.',
    DioExceptionType.badResponse     =>
        'Server error (${e.response?.statusCode}).',
    _                                => 'Something went wrong.',
  };
}