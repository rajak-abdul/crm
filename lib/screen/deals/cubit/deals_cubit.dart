// ╔══════════════════════════════════════════════════════════════╗
// ║           lib/screen/deals/cubit/deals_cubit.dart            ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/deals/cubit/deals_sheet_state.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/screen/invoice/modal/invoice_model.dart';
import 'package:dio/dio.dart'
    show Dio, BaseOptions, InterceptorsWrapper, DioException, DioExceptionType, MultipartFile, FormData, Options, Response, ResponseType;
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter/material.dart' show debugPrint, ScaffoldMessenger, SnackBar, Text;
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:crm_app/database/local_db.dart';

// ══════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════
abstract class DealsState extends Equatable {
  const DealsState();
  @override
  List<Object?> get props => [];
}

class DealsInitial extends DealsState {}

class DealsLoading extends DealsState {}

class DealsActionSuccess extends DealsState {
  final String message;
  const DealsActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class DealsError extends DealsState {
  final String message;
  const DealsError(this.message);
  @override
  List<Object?> get props => [message];
}

class DealsLoaded extends DealsState {
  final List<Deal> allDeals;
  final List<Deal> pendingDeals;
  final List<Deal> lostDeals;
  final List<String> salesUsers;
  

  const DealsLoaded({
    required this.allDeals,
    required this.pendingDeals,
    required this.lostDeals,
    required this.salesUsers,

  });

  DealsLoaded copyWithDeals(List<Deal> d) => DealsLoaded(
      allDeals: d,
      pendingDeals: pendingDeals,
      lostDeals: lostDeals,
      salesUsers: salesUsers);

  @override
  List<Object?> get props => [allDeals, pendingDeals, lostDeals, salesUsers];
}
// ================
// Rejected state 
// ================
// ── replace the existing RejectedDealsLoaded class ──────────────
class RejectedDealsLoaded extends DealsState {
  final List<Deal> deals;
  final int currentPage;
  final int totalPages;
  final int totalDeals;

  const RejectedDealsLoaded(
    this.deals, {
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalDeals = 0,
  });

  @override
  List<Object?> get props => [deals, currentPage, totalPages, totalDeals];
}
// ══════════════════════════════════════════════════════════════
// CUBIT
// ══════════════════════════════════════════════════════════════
class DealsCubit extends Cubit<DealsState> {
  static const _base = 'https://crm-backend-api.techzarinfo.cloud/api';

  late final Dio _dio;
  String? _cachedToken;

  DealsCubit() : super(DealsInitial()) {
    // ── FIX: Do NOT set Content-Type globally. ─────────────────
    // Dio must set it automatically per-request so that multipart
    // requests get the correct boundary in their Content-Type header.
    // Setting 'application/json' globally breaks FormData uploads.
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opt, handler) {
        final t = _cachedToken;
        if (t != null && t.isNotEmpty) {
          opt.headers['Authorization'] = 'Bearer $t';
        }
        // ── FIX: Only set JSON content-type when NOT multipart ──
        // FormData requests must NOT have Content-Type pre-set;
        // Dio sets it with the correct multipart boundary automatically.
        if (opt.data is! FormData) {
          opt.headers['Content-Type'] = 'application/json';
        }
        handler.next(opt);
      },
      onError: (err, handler) {
  if (err.response?.statusCode == 401) {
    _cachedToken = null;
  }
  handler.next(err);
},
    ));
    _dio.interceptors.add(AuthInterceptor());

    _initToken();
  }

  Future<void> _initToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('token');
    } catch (_) {}
  }

  // ── READ ──────────────────────────────────────────────────────

  Future<void> loadDeals() async {
    if (isClosed) return;
    emit(DealsLoading());
    if (_cachedToken == null || _cachedToken!.isEmpty) await _initToken();
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id') ?? '';
    final userName = prefs.getString('user_name') ?? '';
    final roleName = prefs.getString('role') ?? '';
    final canViewAll =
        PermissionHelper.can('users_roles') && !_isSalesRole(roleName);

    final allDeals = await _safeGet('/deals/getAll');
    final pendingDeals = await _safeGet('/deals/pending');
    final lostDeals = await _safeGet('/lost-deals');
    final userMaps = await _safeGet('/users/sales');

    final scopedAllRows = _scopeDealsForUser(
      allDeals,
      canViewAll: canViewAll,
      userId: currentUserId,
      userName: userName,
    );
    final scopedPendingRows = _scopeDealsForUser(
      pendingDeals,
      canViewAll: canViewAll,
      userId: currentUserId,
      userName: userName,
    );
    final scopedLostRows = _scopeDealsForUser(
      lostDeals,
      canViewAll: canViewAll,
      userId: currentUserId,
      userName: userName,
    );

    final deals = _parseDeals(scopedAllRows);
    final pending = _parseDeals(scopedPendingRows);
    final lost = _parseDeals(scopedLostRows);

    if (deals.isNotEmpty) {
      try {
        await LocalDb.instance.replaceDealsFromApi(scopedAllRows);
      } catch (e) {
        debugPrint('[DealsCubit] local cache write failed: $e');
      }
    }

    if (deals.isEmpty) {
      try {
        final cachedRows = await LocalDb.instance.getLocalDealMaps();
        final cachedDeals = _parseDeals(cachedRows);
        if (cachedDeals.isNotEmpty) {
          final cachedLost = cachedDeals
              .where(
                  (d) => DealConstants.canonicalStage(d.stage) == 'Closed Lost')
              .toList();
          final cachedPending = cachedDeals
              .where((d) =>
                  DealConstants.canonicalStage(d.stage) != 'Closed Won' &&
                  DealConstants.canonicalStage(d.stage) != 'Closed Lost')
              .toList();
          if (!isClosed) {
            emit(DealsLoaded(
              allDeals: cachedDeals,
              pendingDeals: cachedPending,
              lostDeals: cachedLost,
              salesUsers: const [], 
            ));
          }
          return;
        }
      } catch (e) {
        debugPrint('[DealsCubit] local cache read failed: $e');
      }
    }

    List<String> users = userMaps
        .map((e) {
          final fn = e['firstName']?.toString().trim() ?? '';
          final ln = e['lastName']?.toString().trim() ?? '';
          final id = e['_id']?.toString() ?? '';
          final name = [fn, ln].where((s) => s.isNotEmpty).join(' ');
          return name.isNotEmpty && id.isNotEmpty ? '$name||$id' : '';
        })
        .where((s) => s.isNotEmpty)
        .toList();

    if (users.isEmpty) {
      users = deals
          .map((d) => d.assignTo)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    }

    if (isClosed) return;
    emit(DealsLoaded(
      
      allDeals: deals,
      pendingDeals: pending,
      lostDeals: lost,
      salesUsers: users, 
    ));
  }

  Future<void> refresh() async {
    if (state is! DealsLoading) await loadDeals();
  }

  Future<Deal?> getDealById(String id) async {
  try {
    if (_cachedToken == null || _cachedToken!.isEmpty) await _initToken();
    final res = await _dio.get('/deals/getAll/$id');
    final data = res.data;

    Map<String, dynamic>? map;

    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else if (data is List && data.isNotEmpty) {
      map = Map<String, dynamic>.from(data.first as Map);
    }

    if (map == null) {
      return null;
    }

    return Deal.fromJson(map);
  } catch (e) {
    debugPrint('[DealsCubit] getDealById error: $e');
    return null;
  }
}

  // ── 🌐 GET /{tenantSlug}/api/deals/:id/activity ───────────
  // ADD: unlike every other call in this cubit, this endpoint needs
  // the tenant slug in the path (e.g. /kishore/api/...), which _base
  // does not include. We build an absolute URL for just this call —
  // Dio overrides baseUrl automatically when a full URL is passed,
  // and the Authorization interceptor still fires for it.
  Future<List<DealActivityItem>> getDealActivity(String dealId) async {
    if (_cachedToken == null || _cachedToken!.isEmpty) {
      await _initToken();
    }

    final prefs = await SharedPreferences.getInstance();
    final tenantSlug = prefs.getString('tenant_slug') ?? '';
    if (tenantSlug.isEmpty) {
      throw Exception('Missing tenant slug — please log in again');
    }

    final res = await _dio.get(
      'https://crm-backend-api.techzarinfo.cloud/$tenantSlug/api/deals/$dealId/activity',
    );

    final data = res.data;
    final List<dynamic> rawList = (data is Map && data['activity'] is List)
        ? data['activity'] as List
        : (data is List ? data : []);

    return rawList
        .whereType<Map>()
        .map((e) => DealActivityItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /{tenantSlug}/api/users/me
/// Returns the tenant's configured currency, e.g. USD.
Future<String> getTenantCurrency() async {
  try {
    if (_cachedToken == null || _cachedToken!.isEmpty) {
      await _initToken();
    }

    final prefs = await SharedPreferences.getInstance();
    final tenantSlug = prefs.getString('tenant_slug') ?? '';

    if (tenantSlug.isEmpty) {
      throw Exception('Missing tenant slug');
    }

    final response = await _dio.get(
      'https://crm-backend-api.techzarinfo.cloud/'
      '$tenantSlug/api/users/me',
    );

    final data = response.data;

    if (data is Map) {
      final currency = data['currency']?.toString().trim().toUpperCase();

      if (currency != null && currency.isNotEmpty) {
        debugPrint(
          '[DealsCubit] Tenant currency: $currency',
        );

        return currency;
      }
    }
  } catch (e) {
    debugPrint(
      '[DealsCubit] getTenantCurrency error: $e',
    );
  }

  // Safe fallback
  return 'USD';
}

/// Gets exchange rate from [fromCurrency] to [toCurrency].
///
/// Example:
/// latest/INR
/// rates["USD"]
Future<double?> getExchangeRate({
  required String fromCurrency,
  required String toCurrency,
}) async {
  final from = fromCurrency.trim().toUpperCase();
  final to = toCurrency.trim().toUpperCase();

  if (from.isEmpty || to.isEmpty) {
    return null;
  }

  if (from == to) {
    return 1.0;
  }

  try {
    final exchangeDio = Dio();

    final response = await exchangeDio.get(
      'https://open.er-api.com/v6/latest/$from',
    );

    final data = response.data;

    if (data is Map) {
      final rates = data['rates'];

      if (rates is Map) {
        final rawRate = rates[to];

        if (rawRate is num) {
          return rawRate.toDouble();
        }

        return double.tryParse(
          rawRate?.toString() ?? '',
        );
      }
    }
  } catch (e) {
    debugPrint(
      '[DealsCubit] getExchangeRate error: $e',
    );
  }

  return null;
}

  // ── CREATE ────────────────────────────────────────────────────

  /// POST /deals/createManual  (multipart — attachments included at create time)
  ///
  /// API response shape (confirmed from Postman):
  /// { "message": "Manual deal created", "deal": { "_id": "...", "attachments": [...] } }
  ///
  /// FIX 1: FormData is built here — no separate uploadAttachments call needed for create.
  /// FIX 2: Content-Type is NOT pre-set; Dio sets multipart/form-data + boundary automatically.
  /// FIX 3: ID extracted from response['deal']['_id'] matching the actual API shape.
  Future<String?> createDeal(
    Map<String, dynamic> payload,
    List<PlatformFile> files, {
    List<XFile> images = const [],
  }) async {
    if (isClosed) return null;
    final prev = state;

    try {
      final formData = FormData();

      // Add all text fields
      payload.forEach((key, value) {
        if (value != null) {
          formData.fields.add(MapEntry(key, value.toString()));
        }
      });

      // Add attachment files
      for (final f in files) {
        try {
          MultipartFile mf;

          if (f.bytes != null) {
            mf = MultipartFile.fromBytes(f.bytes!, filename: f.name);
          } else if (f.path != null && f.path!.isNotEmpty) {
            mf = await MultipartFile.fromFile(f.path!, filename: f.name);
          } else {
            debugPrint("❌ Skipped file: ${f.name} (no bytes & no path)");
            continue;
          }

          formData.files.add(MapEntry('attachments', mf));
          debugPrint("✅ Added file: ${f.name}");
        } catch (e) {
          debugPrint("❌ Error adding file: ${f.name} → $e");
        }
      }

      // Add image files
      for (final img in images) {
        try {
          final mf = await MultipartFile.fromFile(img.path, filename: img.name);
          formData.files.add(MapEntry('images', mf));
        } catch (e) {
          debugPrint("❌ Error adding image: ${img.name} → $e");
        }
      }
      debugPrint(
          '[DealsCubit] createDeal → fields=${formData.fields.length} files=${formData.files.length}');

      final res = await _dio.post('/deals/createManual', data: formData);
      final body = res.data;

      // ── FIX: Extract ID from confirmed API shape ────────────
      // Response: { "message": "...", "deal": { "_id": "69e07c...", ... } }
      String? newId;
      Map<String, dynamic>? dealMap;

      if (body is Map) {
        // Primary path: body['deal'] is the deal object
        if (body['deal'] is Map) {
          dealMap = Map<String, dynamic>.from(body['deal'] as Map);
          newId = dealMap['_id']?.toString();
        }
        // Fallback: body itself is the deal
        if (newId == null && body['_id'] != null) {
          dealMap = Map<String, dynamic>.from(body);
          newId = dealMap['_id']?.toString();
        }
        // Fallback: body['data'] wraps the deal
        if (newId == null && body['data'] is Map) {
          dealMap = Map<String, dynamic>.from(body['data'] as Map);
          newId = dealMap['_id']?.toString();
        }
      }

      debugPrint('[DealsCubit] createDeal → newId=$newId');

      // Optimistic insert if we have the deal map
      if (prev is DealsLoaded && !isClosed) {
        if (dealMap != null) {
  try {
    final newDeal = Deal.fromJson(dealMap);
    emit(prev.copyWithDeals([newDeal, ...prev.allDeals]));
  } catch (_) {}

  try {
    await LocalDb.instance.upsertDealFromApi(dealMap);
  } catch (e) {
    debugPrint('[DealsCubit] create local cache write failed: $e');
  }
}
      }

      // Always reload to get consistent server state
      await loadDeals();
      if (!isClosed) {
        emit(const DealsActionSuccess('Deal created successfully'));
      }

      return newId;
    } on DioException catch (e) {
      debugPrint(
          '[DealsCubit] createDeal DioException: ${e.response?.statusCode} ${e.response?.data}');
      if (_isOfflineDio(e)) {
        final localId = 'local_deal_${DateTime.now().millisecondsSinceEpoch}';
        final offlinePayload = <String, dynamic>{
          ...payload,
          '_id': localId,
          'attachments': files
              .map((f) => {
                    'name': f.name,
                    'path': f.path ?? '',
                    'type': f.extension ?? '',
                    'size': f.size,
                  })
              .toList(),
        };
        try {
          await LocalDb.instance.insertDeal(offlinePayload);
          await loadDeals();
          if (!isClosed) {
            emit(const DealsActionSuccess('Deal saved offline'));
          }
          return localId;
        } catch (dbErr) {
          debugPrint('[DealsCubit] createDeal offline save error: $dbErr');
        }
      }
      if (!isClosed) {
        if (prev is DealsLoaded) emit(prev);
        emit(DealsError(_dioMsg(e, 'Failed to create deal')));
      }
      return null;
    } catch (e) {
      debugPrint('[DealsCubit] createDeal error: $e');
      if (!isClosed) {
        if (prev is DealsLoaded) emit(prev);
        emit(const DealsError('Failed to create deal'));
      }
      return null;
    }
  }

  /// POST /deals/fromLead/:leadId
  Future<void> createDealFromLead(String leadId) async {
    if (isClosed) return;
    try {
      await _dio.post('/leads/$leadId/convert');
      await loadDeals();
      if (!isClosed) emit(const DealsActionSuccess('Deal created from lead'));
    } on DioException catch (e) {
      if (!isClosed) {
        emit(DealsError(_dioMsg(e, 'Failed to create deal from lead')));
      }
    }
  }
  // -=======================
  // Load Rejected Deals
  // ========================

  // ── replace loadRejectedDeals ────────────────────────────────────
Future<void> loadRejectedDeals({
  int page = 1,
  int limit = 10,
}) async {
  if (isClosed) return;

  emit(DealsLoading());

  try {
    final response = await _dio.get(
      '/deals/rejected',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );

    final data = response.data;
    final rows = _toList(data);
    final deals = _parseDeals(rows);

    int totalDeals = deals.length;
    int totalPages = 1;
    int currentPage = page;
    if (data is Map) {
      totalDeals = (data['totalDeals'] as num?)?.toInt() ?? deals.length;
      totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      currentPage = (data['currentPage'] as num?)?.toInt() ?? page;
    }

    if (!isClosed) {
      emit(RejectedDealsLoaded(
        deals,
        currentPage: currentPage,
        totalPages: totalPages,
        totalDeals: totalDeals,
      ));
    }
  } on DioException catch (e) {
    if (!isClosed) {
      emit(DealsError(_dioMsg(e, 'Failed to load rejected deals')));
    }
  }
}

// ── add: dedicated delete for the rejected list ──────────────────
// deleteDeal() only updates state when it's DealsLoaded, so it can't
// be reused here — this reloads the current rejected page instead.
Future<bool> deleteRejectedDeal(
  String id, {
  required int page,
  int limit = 10,
}) async {
  if (isClosed) return false;
  try {
    await _dio.delete('/deals/delete-deal/$id');
    await loadRejectedDeals(page: page, limit: limit);
    return true;
  } on DioException catch (e) {
    if (!isClosed) {
      emit(DealsError(_dioMsg(e, 'Failed to delete rejected deal')));
    }
    return false;
  }
}

  // ── UPDATE ────────────────────────────────────────────────────

  /// PATCH /deals/update-deal/:id  (JSON — no files)
  /// NOTE: Does NOT emit DealsActionSuccess so deal_screen._save()
  /// can run follow-up + attachments before closing the modal.
  Future<void> updateDeal(String id, Map<String, dynamic> payload,{
  List<PlatformFile> attachments = const [],
  List<XFile> images = const [],
}) async {
    if (isClosed) return;
    final prev = state;
    try {
      final formData = FormData();

// Add all normal fields
payload.forEach((key, value) {
  if (value == null) return;

  if (value is List) {
    for (final item in value) {
      formData.fields.add(
        MapEntry(key, item.toString()),
      );
    }
  } else {
    formData.fields.add(
      MapEntry(key, value.toString()),
    );
  }
});

// Add attachments
for (final file in attachments) {
  MultipartFile? mf;
  if (file.bytes != null) {
    mf = MultipartFile.fromBytes(
      file.bytes!,
      filename: file.name,
    );
  } else if (file.path != null && file.path!.isNotEmpty) {
    mf = await MultipartFile.fromFile(
      file.path!,
      filename: file.name,
    );
  }

  if (mf != null) {
    formData.files.add(
      MapEntry('attachments', mf),
    );
  }
}

// Add images
for (final img in images) {
  try {
    final mf = await MultipartFile.fromFile(img.path, filename: img.name);
    formData.files.add(MapEntry('images', mf));
  } catch (e) {
    debugPrint("❌ Error adding image: ${img.name} → $e");
  }
}

final res = await _dio.patch(
  '/deals/update-deal/$id',
  data: formData,
);
debugPrint('[updateDeal] sent: ${formData.fields}');
debugPrint('[updateDeal] ${res.statusCode} → ${res.data}');


      await LocalDb.instance.updateLocalDeal(id, payload);
      final body = res.data;

      Map<String, dynamic>? dealMap;
      if (body is Map) {
        final m = Map<String, dynamic>.from(body);
        for (final k in ['deal', 'data', 'result']) {
          if (m[k] is Map) {
            dealMap = Map<String, dynamic>.from(m[k] as Map);
            break;
          }
        }
        dealMap ??= (m.containsKey('_id') ? m : null);
      }

      if (dealMap != null && prev is DealsLoaded && !isClosed) {
        final updated = Deal.fromJson(dealMap);
        emit(prev.copyWithDeals(
            prev.allDeals.map((d) => d.id == id ? updated : d).toList()));
        try {
          await LocalDb.instance.upsertDealFromApi(dealMap);
        } catch (e) {
          debugPrint('[DealsCubit] update local cache write failed: $e');
        }
      } else {
        await loadDeals();
      }
      // Intentionally no DealsActionSuccess — caller owns modal close.
    } on DioException catch (e) {
      if (_isOfflineDio(e)) {
        try {
          await LocalDb.instance.updateLocalDeal(id, payload);
          await loadDeals();
          if (!isClosed) {
            emit(const DealsActionSuccess('Deal updated offline'));
          }
          return;
        } catch (dbErr) {
          debugPrint('[DealsCubit] updateDeal offline save error: $dbErr');
        }
      }
      if (!isClosed) {
        if (prev is DealsLoaded) emit(prev);
        emit(DealsError(_dioMsg(e, 'Failed to update deal')));
      }
    }
  }

  /// PATCH /deals/:id/stage
  Future<void> updateDealStage(String id, String newStage) async {
    if (isClosed || state is! DealsLoaded) return;
    final prev = state as DealsLoaded;
    emit(prev.copyWithDeals(prev.allDeals
        .map((d) => d.id == id ? d.copyWith(stage: newStage) : d)
        .toList()));
    try {
      await _dio.patch('/deals/$id/stage', data: {'stage': newStage});
      if (!isClosed) emit(const DealsActionSuccess('Stage updated'));
    } on DioException catch (e) {
      if (_isOfflineDio(e)) {
        try {
          await LocalDb.instance.updateLocalDeal(id, {'stage': newStage});
          if (!isClosed) {
            emit(const DealsActionSuccess('Stage updated offline'));
          }
          return;
        } catch (dbErr) {
          debugPrint('[DealsCubit] updateDealStage offline save error: $dbErr');
        }
      }
      if (!isClosed) {
        emit(prev);
        emit(DealsError(_dioMsg(e, 'Failed to update stage')));
      }
    }
  }

  // ── FOLLOW-UP ─────────────────────────────────────────────────

  /// POST /deals/schedule-followup/:id
  Future<bool> scheduleFollowUp(
  String dealId, {
  required DateTime followUpDate,
  required String comment,
  DateTime? previousFollowUpDate,
  String previousNotes = '',
  String previousOutcome = '',
}) async {
  try {
    if (_cachedToken == null || _cachedToken!.isEmpty) {
      await _initToken();
    }

    debugPrint('Token being sent: $_cachedToken');
    await _dio.post(
      '/deals/schedule-followup/$dealId',
      data: {
        'dealId': dealId,
        'followUpDate': followUpDate.toUtc().toIso8601String(),
        'followUpComment': comment.trim(),
        'previousFollowUpDate': previousFollowUpDate?.toUtc().toIso8601String(),
        'previousNotes': previousNotes,
        'previousOutcome': previousOutcome,
      },
    );
    debugPrint('[DealsCubit] follow-up scheduled for $dealId');
    return true;
  } catch (e) {
  if (e is DioException) {
    debugPrint('[DealsCubit] scheduleFollowUp error: ${e.response?.statusCode} ${e.response?.data}');
    debugPrint('[DealsCubit] request payload: ${e.requestOptions.data}');
  } else {
    debugPrint('[DealsCubit] scheduleFollowUp error: $e');
  }
  return false;
}
}
  /// POST /deals/:id/complete-followup
  Future<bool> completeFollowUp(
  String dealId, {
  required String outcome,
  required String notes,
}) async {
  try {
    await _initToken();
    debugPrint('complete Headers: ${_dio.options.headers}');
    await _dio.post(
      '/deals/$dealId/complete-followup',
      data: {'outcome': outcome, 'notes': notes},
    );
    debugPrint('[DealsCubit] follow-up completed for $dealId');
    return true;
  } catch (e) {
    debugPrint('[DealsCubit] completeFollowUp error: $e');
    return false;
  }
}
  // ── ATTACHMENTS ───────────────────────────────────────────────

  /// POST /deals/:id/attachments  (multipart)
  /// Used ONLY for edit flow — create flow sends files in createDeal().
  ///
  /// FIX: Content-Type NOT pre-set; interceptor skips it for FormData.
  Future<bool> uploadAttachments(
      String dealId, List<PlatformFile> files) async {
    if (files.isEmpty) return true;

    try {
      final formData = FormData();

      for (final f in files) {
        MultipartFile? mf;
        if (f.bytes != null) {
          mf = MultipartFile.fromBytes(f.bytes!, filename: f.name);
        } else if (f.path != null && f.path!.isNotEmpty) {
          mf = await MultipartFile.fromFile(f.path!, filename: f.name);
        }
        if (mf != null) formData.files.add(MapEntry('attachments', mf));
      }

      if (formData.files.isEmpty) {
        debugPrint('[DealsCubit] uploadAttachments: no valid files to upload');
        return false;
      }

      debugPrint(
          '[DealsCubit] uploadAttachments → dealId=$dealId files=${formData.files.length}');

      final res = await _dio.post('/deals/$dealId/attachments', data: formData);
      debugPrint('[DealsCubit] uploadAttachments response: ${res.statusCode}');
      return true;
    } on DioException catch (e) {
      debugPrint(
          '[DealsCubit] uploadAttachments error: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('[DealsCubit] uploadAttachments error: $e');
      return false;
    }
  }

  // ── add inside DealsCubit, near createDeal/uploadAttachments ────

/// POST /deals/bulk-import  (multipart — single Excel/CSV file)
///
/// Response shape (confirmed): { "success": true, "created": N,
/// "failed": N, "errors": [...] }
///
/// Assumption: multipart field name is 'file' — verify against
/// Postman/backend and adjust the MapEntry key below if different.
Future<BulkImportResult?> bulkImportDeals(PlatformFile file) async {
  if (isClosed) return null;

  try {
    MultipartFile mf;
    if (file.bytes != null) {
      mf = MultipartFile.fromBytes(file.bytes!, filename: file.name);
    } else if (file.path != null && file.path!.isNotEmpty) {
      mf = await MultipartFile.fromFile(file.path!, filename: file.name);
    } else {
      debugPrint('[DealsCubit] bulkImportDeals: file has no bytes or path');
      return null;
    }

    final formData = FormData();
    formData.files.add(MapEntry('file', mf));

    debugPrint('[DealsCubit] bulkImportDeals → uploading ${file.name}');

    final res = await _dio.post('/deals/bulk-import', data: formData);
    final body = res.data;
    debugPrint('[DealsCubit] bulkImportDeals ← ${res.statusCode} $body');

    if (body is! Map) {
      debugPrint('[DealsCubit] bulkImportDeals: unexpected response shape');
      return null;
    }

    final result = BulkImportResult.fromJson(Map<String, dynamic>.from(body));

    debugPrint(
        '[DealsCubit] bulkImportDeals → created=${result.created} failed=${result.failed}');

    // Refresh deal lists so newly-imported deals show up immediately.
    await loadDeals();

    if (!isClosed) {
      final msg = result.failed > 0
          ? 'Imported ${result.created} deal(s), ${result.failed} failed'
          : 'Imported ${result.created} deal(s) successfully';
      emit(DealsActionSuccess(msg));
    }

    return result;
  } on DioException catch (e) {
    debugPrint(
        '[DealsCubit] bulkImportDeals DioException: ${e.response?.statusCode} ${e.response?.data}');
    if (!isClosed) {
      emit(DealsError(_dioMsg(e, 'Failed to import deals')));
    }
    return null;
  } catch (e) {
    debugPrint('[DealsCubit] bulkImportDeals error: $e');
    if (!isClosed) {
      emit(const DealsError('Failed to import deals'));
    }
    return null;
  }
}
  // ── DELETE ────────────────────────────────────────────────────

  Future<void> deleteDeal(String id) async {
    if (isClosed || state is! DealsLoaded) return;
    final prev = state as DealsLoaded;
    emit(prev.copyWithDeals(prev.allDeals.where((d) => d.id != id).toList()));
    try {
      await _dio.delete('/deals/delete-deal/$id');
      try {
        await LocalDb.instance.deleteDealHard(id);
      } catch (e) {
        debugPrint('[DealsCubit] delete local cache failed: $e');
      }
      if (!isClosed) emit(const DealsActionSuccess('Deal deleted'));
    } on DioException catch (e) {
      if (_isOfflineDio(e)) {
        try {
          await LocalDb.instance.deleteDealHard(id);
          if (!isClosed) emit(const DealsActionSuccess('Deal deleted offline'));
          return;
        } catch (dbErr) {
          debugPrint('[DealsCubit] deleteDeal offline delete failed: $dbErr');
        }
      }
      if (!isClosed) {
        emit(prev);
        emit(DealsError(_dioMsg(e, 'Failed to delete deal')));
      }
    }
  }

  Future<void> bulkDeleteDeals(List<String> ids) async {
    if (isClosed || state is! DealsLoaded) return;
    final prev = state as DealsLoaded;
    final idSet = ids.toSet();
    emit(prev.copyWithDeals(
        prev.allDeals.where((d) => !idSet.contains(d.id)).toList()));
    try {
      await _dio.delete('/deals/bulk-delete', data: {'ids': ids});
      if (!isClosed) emit(DealsActionSuccess('${ids.length} deals deleted'));
    } on DioException catch (e) {
      if (!isClosed) {
        emit(prev);
        emit(DealsError(_dioMsg(e, 'Failed to bulk delete deals')));
      }
    }
  }
  //=============================
  // Add Deal Note
  //=============================
  Future<bool> addDealNote(
  String dealId,
  String text,
) async {
  try {
    await _dio.post(
      '/deals/$dealId/notes',
      data: {
        'text': text,
      },
    );

    return true;
  } on DioException catch (e) {
    debugPrint(e.toString());
    return false;
  }
}

  // ================
  //  Deals cubit
  // ================
Future<List<Map<String, dynamic>>> exportDeals({
  DateTime? startDate,
  DateTime? endDate,
}) async {
  if (_cachedToken == null || _cachedToken!.isEmpty) {
    await _initToken();
  }

  final query = <String, dynamic>{};

  if (startDate != null) {
    query['startDate'] =
        startDate.toIso8601String().split('T').first;
  }

  if (endDate != null) {
    query['endDate'] =
        endDate.toIso8601String().split('T').first;
  }

  try {
    final response = await _dio.get(
      '/deals/export',
      queryParameters: query,
    );

    final body = response.data;

    if (body is! Map) {
      throw Exception("Invalid response received.");
    }

    if (body['success'] != true) {
      throw Exception(body['message'] ?? "Export failed.");
    }

    final List<dynamic> rows = body['data'] ?? [];

    return rows
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  } on DioException catch (e) {
    throw Exception(_dioMsg(e, "Failed to export deals"));
  }
}  
// ===================
// Invoice Tab
// ===================
Future<List<Invoice>> getDealInvoices(String dealId) async {
  try {
    final res = await _dio.get('/deals/$dealId/invoices');

    if (res.data is! List) return [];

    return (res.data as List)
        .map(
          (e) => Invoice.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  } on DioException catch (e) {
    debugPrint(
      '[DealsCubit] getDealInvoices: ${e.response?.statusCode} ${e.response?.data}',
    );
    return [];
  } catch (e) {
    debugPrint(
      '[DealsCubit] getDealInvoices: $e',
    );
    return [];
  }
}

// ── Helpers ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _safeGet(String path) async {
    try {
      final res = await _dio.get(path);
      return _toList(res.data);
    } catch (e) {
      debugPrint('[DealsCubit] $path → $e');
      return [];
    }
  }

  List<Deal> _parseDeals(List<Map<String, dynamic>> items) {
    final out = <Deal>[];
    for (final item in items) {
      try {
        out.add(Deal.fromJson(item));
      } catch (e) {
        debugPrint('[DealsCubit] skipping bad deal: $e');
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _toList(dynamic d) {
    try {
      List<dynamic> raw = [];
      if (d is List) {
        raw = d;
      } else if (d is Map) {
        for (final k in [
          'data',
          'deals',
          'result',
          'results',
          'items',
          'users',
          'lostDeals',
          'pendingDeals'
        ]) {
          if (d[k] is List) {
            raw = d[k] as List;
            break;
          }
        }
      }
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _dioMsg(DioException e, String fallback) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return data['message']?.toString() ??
            data['error']?.toString() ??
            fallback;
      }
    } catch (_) {}
    return e.message?.isNotEmpty == true ? e.message! : fallback;
  }

  bool _isOfflineDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      case DioExceptionType.unknown:
        final msg = e.message?.toLowerCase() ?? '';
        return msg.contains('socket') ||
            msg.contains('network') ||
            msg.contains('timed out') ||
            msg.contains('connection');
      default:
        return false;
    }
  }

  List<Map<String, dynamic>> _scopeDealsForUser(
    List<Map<String, dynamic>> rows, {
    required bool canViewAll,
    required String userId,
    required String userName,
  }) {
    if (canViewAll) return List<Map<String, dynamic>>.from(rows);
    return rows.where((m) => _dealAssignedToUser(m, userId, userName)).toList();
  }

  bool _dealAssignedToUser(
    Map<String, dynamic> m,
    String userId,
    String userName,
  ) {
    final uid = userId.trim();
    final uname = userName.trim().toLowerCase();

    final assignRaw = m['assignTo'] ?? m['assignedTo'];
    if (assignRaw is Map) {
      final id =
          assignRaw['_id']?.toString() ?? assignRaw['id']?.toString() ?? '';
      if (id.isNotEmpty && uid.isNotEmpty && id == uid) return true;
      final fn = assignRaw['firstName']?.toString().trim() ?? '';
      final ln = assignRaw['lastName']?.toString().trim() ?? '';
      final combined = '$fn $ln'.trim().toLowerCase();
      if (uname.isNotEmpty && combined.isNotEmpty && combined == uname) {
        return true;
      }
    } else if (assignRaw != null && uname.isNotEmpty) {
      if (assignRaw.toString().trim().toLowerCase() == uname) return true;
    }

    final topId =
        m['assignToId']?.toString() ?? m['assignedToId']?.toString() ?? '';
    if (topId.isNotEmpty && uid.isNotEmpty && topId == uid) return true;

    return false;
  }

  bool _isSalesRole(String roleName) {
    final role = roleName.trim().toLowerCase();
    return role == 'sales' ||
        role == 'salesperson' ||
        role == 'sales person' ||
        role == 'sales executive';
  }
}