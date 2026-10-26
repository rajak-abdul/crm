// ══════════════════════════════════════════════════════════════
// 1️⃣  STATE
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crm_app/database/local_db.dart';
import 'package:crm_app/modals/modals.dart';
import 'package:crm_app/screen/currency/modal/account_currency_modal.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:crm_app/utils/data_sync.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class CallState extends Equatable {
  const CallState();

  @override
  List<Object?> get props => [];
}

class LeadLoaded extends LeadState {
  final List<Lead> leads;
  final List<AppUser> salesUsers;
  final int currentPage;
  final int? totalCount; // null when the API doesn't return a total — see debugPrint below
  const LeadLoaded({
    required this.leads,
    this.salesUsers = const [],
    this.currentPage = 1,
    this.totalCount,
  });
  @override
  List<Object?> get props => [leads, salesUsers, currentPage, totalCount];
}

// ============================================
class LeadActionSuccess extends LeadLoaded {
  final String message;
  const LeadActionSuccess({
    required super.leads,
    super.salesUsers,
    super.currentPage,
    super.totalCount,
    required this.message,
  });
  @override
  List<Object?> get props => [leads, salesUsers, currentPage, totalCount, message];
}
// ============================================
class CallInitial extends CallState {}

class CallLoading extends CallState {}

class CallSuccess extends CallState {}

class CallError extends CallState {
  final String message;

  const CallError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class LeadState extends Equatable {
  const LeadState();
  @override
  List<Object?> get props => [];
}

class LeadInitial extends LeadState {}

class LeadLoading extends LeadState {}

// class LeadLoaded extends LeadState {
//   final List<Lead> leads;
//   final List<AppUser> salesUsers;
//   const LeadLoaded({required this.leads, this.salesUsers = const []});
//   @override
//   List<Object?> get props => [leads, salesUsers];
// }

// class LeadActionSuccess extends LeadLoaded {
//   final String message;
//   const LeadActionSuccess(
//       {required super.leads, super.salesUsers, required this.message});
//   @override
//   List<Object?> get props => [leads, salesUsers, message];
// }

class LeadError extends LeadState {
  final String message;
  const LeadError(this.message);
  @override
  List<Object?> get props => [message];
}

/// One page of GET /leads/missed-followups.
class MissedFollowupPage {
  final List<Lead> leads;
  final int total;
  final int page;
  final int totalPages;

  const MissedFollowupPage({
    required this.leads,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  const MissedFollowupPage.empty()
      : leads = const [],
        total = 0,
        page = 1,
        totalPages = 1;

  bool get hasMore => page < totalPages;
}

// Top-level function required by compute()
List<Map<String, dynamic>> _parseListIsolate(dynamic d) {
  List<dynamic> raw = [];
  if (d is List) {
    raw = d;
  } else if (d is Map) {
    for (final k in [
      'data',
      'leads',
      'users',
      'salesUsers',
      'staff',
      'employees',
      'result',
      'results',
      'records',
      'items'
    ]) {
      if (d[k] is List) {
        raw = d[k] as List;
        break;
      }
    }
    if (raw.isEmpty && (d.containsKey('_id') || d.containsKey('id'))) {
      raw = [d];
    }
  }
  return raw.whereType<Map>().map((e) {
    final m = Map<String, dynamic>.from(e);

    // _id → id
    if (m['id'] == null || m['id'].toString().isEmpty) {
      m['id'] = m['_id']?.toString() ?? '';
    }
    // leadName → name
    if ((m['name'] == null || m['name'].toString().isEmpty) &&
        m['leadName'] != null) {
      m['name'] = m['leadName'];
    }
    // phoneNumber → phone
    if ((m['phone'] == null || m['phone'].toString().isEmpty) &&
        m['phoneNumber'] != null) {
      m['phone'] = m['phoneNumber'];
    }

    // Normalise assignTo
    final assignRaw = m['assignTo'] ?? m['assignedTo'];
    if (assignRaw is Map) {
      final fn = assignRaw['firstName']?.toString() ?? '';
      final ln = assignRaw['lastName']?.toString() ?? '';
      m['assignTo'] = '$fn $ln'.trim();
      m['assignedToId'] = assignRaw['_id']?.toString() ?? '';
    } else if (assignRaw != null) {
      m['assignTo'] = assignRaw.toString().trim();
    }
    for (final key in ['createdBy', 'updatedBy']) {
      final v = m[key];
      if (v is Map) {
        final fn = v['firstName']?.toString() ?? '';
        final ln = v['lastName']?.toString() ?? '';
        m[key] = '$fn $ln'.trim();
      }
    }
    return m;
  }).toList();
}

class LeadImportResult {
  final int successCount;
  final int failedCount;
  final List<String> errors;
  const LeadImportResult({
    required this.successCount,
    required this.failedCount,
    this.errors = const [],
  });
}

// ══════════════════════════════════════════════════════════════
// 2️⃣  CUBIT
// ══════════════════════════════════════════════════════════════
class LeadCubit extends Cubit<LeadState> {
  static const _domain = 'https://crm-backend-api.techzarinfo.cloud';
  static const _base = '$_domain/api';
  String? _currentUserId;
  bool _isSalesman = false;
  late final Dio _dio;
  // ignore: unused_field
  final _db = LocalDb.instance;
  List<AppUser> _salesUsers = [];
  String? _cachedToken;
  String? _cachedTenantSlug;

  LeadCubit() : super(LeadInitial()) {
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opt, handler) {
        if (_cachedToken != null && _cachedToken!.isNotEmpty) {
          opt.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        handler.next(opt);
      },
      onError: (err, handler) {
        if (err.response?.statusCode == 401) _cachedToken = null;
        handler.next(err);
      },
    ));
    _dio.interceptors.add(AuthInterceptor());
    // Saves through here mark Dashboard / Leads (/ Deals on convert) to
    // refresh on their next visit.
    _dio.interceptors.add(DataSyncInterceptor());
    _initToken();
  }

 Future<void> _initToken() async {
  try {
    final prefs =
        await SharedPreferences.getInstance();

    _cachedToken =
        prefs.getString('token');

    _cachedTenantSlug = (
      prefs.getString('tenant_slug') ??
      prefs.getString('tenantSlug') ??
      ''
    ).trim();

    if (_cachedTenantSlug == null ||
        _cachedTenantSlug!.isEmpty) {
      throw Exception(
        'Tenant slug not found',
      );
    }

    // IMPORTANT
    // Set tenant-specific API URL
    _dio.options.baseUrl =
        '$_domain/'
        '$_cachedTenantSlug/api';

    if (_cachedToken != null &&
        _cachedToken!.isNotEmpty) {
      _dio.options.headers['Authorization'] =
          'Bearer $_cachedToken';
    }

    _dio.options.headers['Accept'] =
        'application/json';

    debugPrint(
      '========== DIO INITIALIZED ==========',
    );

    debugPrint(
      'Tenant: $_cachedTenantSlug',
    );

    debugPrint(
      'Base URL: ${_dio.options.baseUrl}',
    );

    debugPrint(
      'Token exists: '
      '${_cachedToken?.isNotEmpty ?? false}',
    );

    debugPrint(
      '=====================================',
    );
  } catch (e) {
    debugPrint(
      'InitToken Error: $e',
    );
    rethrow;
  }
}
  List<AppUser> get salesUsers => List.unmodifiable(_salesUsers);

  // ── 🌐 GET /leads/getAllLead ───────────────────────────────
  // NOTE: This now ALWAYS merges in rejected leads (via getRejectedLeads())
  // on top of the normal lead list, with NO de-duplication — by design,
  // per current requirements: every filter combination (All Assignee,
  // Missed Follow-ups, both together) should show the same combined,
  // un-deduped list of normal + rejected leads.
  /// [silent]: background refresh (bottom-nav tab) — keeps the current
  /// list on screen instead of flashing the "Fetching leads…" spinner.
  Future<void> fetchAllLeads({
  int page = 1,
  int limit = 10,
  String? status,
  bool silent = false,
}) async {
  if (isClosed) return;

  if (!(silent && state is LeadLoaded)) emit(LeadLoading());

  try {
    await _initToken();
    await PermissionHelper.load();

    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null && status != 'All Status')
        'status': status,
    };

    debugPrint('========== FETCH LEADS ==========');
    debugPrint('URL: ${_dio.options.baseUrl}/leads/getAllLead');
    debugPrint('PAGE: $page');
    debugPrint('LIMIT: $limit');
    debugPrint('STATUS: $status');

    // ----------------------------------------------------------
    // ONLY SERVER REQUEST
    // ----------------------------------------------------------

    final results = await Future.wait<dynamic>([
      _dio.get(
        '/leads/getAllLead',
        queryParameters: queryParams,
      ),
      // Shared with Deals / Dashboard for 2 min (SessionCache).
      SessionCache.salesUsers().catchError((_) => <dynamic>[]),
    ]);

    final leadsRaw = (results[0] as Response).data;
    final usersRaw = results[1];

    debugPrint(
      'LEADS RESPONSE: $leadsRaw',
    );

    // ----------------------------------------------------------
    // TOTAL COUNT
    // ----------------------------------------------------------

    final totalCount =
        _extractTotalCount(leadsRaw);

    debugPrint(
      '=== LEADS META === '
      'totalCount=$totalCount '
      'rawKeys=${leadsRaw is Map ? leadsRaw.keys.toList() : "not map"}',
    );

    // ----------------------------------------------------------
    // PARSE SERVER LEADS
    // ----------------------------------------------------------

    final parsedLeadMaps =
        await compute(
      _parseListIsolate,
      leadsRaw,
    );

    final apiLeads = parsedLeadMaps
        .map(
          (e) => Lead.fromJson(e),
        )
        .toList();

    debugPrint(
      'SERVER LEADS RECEIVED: ${apiLeads.length}',
    );

    for (final lead in apiLeads) {
      debugPrint(
        '${lead.name} | '
        'ID=${lead.id} | '
        'assignedToId=${lead.assignedToId} | '
        'assignTo=${lead.assignTo}',
      );
    }

    // ----------------------------------------------------------
    // SALES USERS
    // ----------------------------------------------------------

    final parsedUsers =
        _parseListIsolate(usersRaw);

    _salesUsers = parsedUsers
        .map((e) {
          final m =
              Map<String, dynamic>.from(e);

          if (!m.containsKey('id') ||
              m['id'] == null ||
              m['id'].toString().isEmpty) {
            m['id'] =
                m['_id']?.toString() ?? '';
          }

          if (!m.containsKey('fullName') ||
              m['fullName'] == null ||
              m['fullName']
                  .toString()
                  .isEmpty) {
            final fn =
                m['firstName']?.toString() ?? '';

            final ln =
                m['lastName']?.toString() ?? '';

            final combined =
                '$fn $ln'.trim();

            m['fullName'] =
                combined.isNotEmpty
                    ? combined
                    : (m['name']?.toString() ?? '');
          }

          return AppUser.fromJson(m);
        })
        .where(
          (u) => u.id.isNotEmpty,
        )
        .toList();

    // ----------------------------------------------------------
    // USER PERMISSION FILTER
    // ----------------------------------------------------------

    final prefs =
    await SharedPreferences.getInstance();

_currentUserId =
    prefs.getString('user_id')?.trim();

final hasUsersRoles =
    PermissionHelper.can('users_roles');

_isSalesman = !hasUsersRoles;

debugPrint('========== ASSIGNEE CHECK ==========');
debugPrint('CURRENT USER ID: $_currentUserId');
debugPrint('HAS USERS ROLES: $hasUsersRoles');
debugPrint('IS SALESMAN: $_isSalesman');
debugPrint('====================================');

List<Lead> finalLeads;

if (_isSalesman &&
    _currentUserId != null &&
    _currentUserId!.isNotEmpty) {
  finalLeads = apiLeads.where((lead) {
    final assignedId =
        lead.assignedToId?.trim();

    final match =
        assignedId == _currentUserId;

    debugPrint(
      '${lead.name} | '
      'assigned=$assignedId | '
      'current=$_currentUserId | '
      'MATCH=$match',
    );

    return match;
  }).toList();
} else {
  // Admin / manager
  finalLeads = apiLeads;
}

    // ----------------------------------------------------------
    // EMIT SERVER DATA ONLY
    // ----------------------------------------------------------

    if (isClosed) return;

    emit(
      LeadLoaded(
        leads: finalLeads,
        salesUsers: _salesUsers,
        currentPage: page,
        totalCount: totalCount,
      ),
    );
  } on DioException catch (e) {
    debugPrint(
      '========== FETCH LEADS ERROR ==========',
    );

    debugPrint(
      'STATUS: ${e.response?.statusCode}',
    );

    debugPrint(
      'URL: ${e.requestOptions.uri}',
    );

    debugPrint(
      'RESPONSE: ${e.response?.data}',
    );

    debugPrint(
      'MESSAGE: ${e.message}',
    );

    debugPrint(
      '=======================================',
    );

    if (isClosed) return;

    // NO OFFLINE FALLBACK
    emit(
      LeadError(
        _dioMsg(e),
      ),
    );
  } catch (e) {
    debugPrint(
      'FETCH LEADS ERROR: $e',
    );

    if (isClosed) return;

    emit(
      LeadError(
        e.toString(),
      ),
    );
  }
}
  // ── 🌐 GET /leads/getLead/:id ─────────────────────────────
  Future<Lead?> fetchLeadById(String id) async {
    try {
      final res = await _dio.get('/leads/getLead/$id');
      final data = res.data;
      Map<String, dynamic> raw;
      if (data is Map<String, dynamic>) {
        raw = data.containsKey('data') && data['data'] is Map
            ? Map<String, dynamic>.from(data['data'] as Map)
            : Map<String, dynamic>.from(data);
      } else {
        return null;
      }
      final normalised = _parseListIsolate([raw]);
      return normalised.isEmpty ? null : Lead.fromJson(normalised.first);
    } catch (_) {
      return null;
    }
  }

  /// Leads by id via GET /leads/getLead/:id, six requests at a time —
  /// used by the Leads "Tasks" filter, which needs specific leads from
  /// across every page. Ids that fail to load are skipped.
  Future<List<Lead>> fetchLeadsByIds(Iterable<String> ids) async {
    await _initToken();
    final list = ids.where((id) => id.isNotEmpty).toSet().toList();
    const batch = 6;
    final out = <Lead>[];
    for (var i = 0; i < list.length; i += batch) {
      final chunk = list.sublist(i, (i + batch).clamp(0, list.length));
      final results = await Future.wait(chunk.map(fetchLeadById));
      out.addAll(results.whereType<Lead>());
    }
    return out;
  }

  // ── 🌐 GET /leads/check-duplicate ─────────────────────────
  /// Names of leads already using [email] / [phoneNumber], keyed 'email' /
  /// 'phoneNumber' (only the ones that exist). Null when the check fails —
  /// it's a warning only, so callers just show nothing.
  Future<Map<String, String>?> checkDuplicate({
    String? email,
    String? phoneNumber,
  }) async {
    final params = <String, String>{
      if (email != null && email.isNotEmpty) 'email': email,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phoneNumber': phoneNumber,
    };
    if (params.isEmpty) return const {};
    try {
      await _initToken();
      final res =
          await _dio.get('/leads/check-duplicate', queryParameters: params);
      var data = res.data;
      if (data is Map && data['data'] is Map) data = data['data'];
      if (data is! Map) return null;
      final out = <String, String>{};
      for (final key in params.keys) {
        final hit = data[key];
        if (hit is Map && hit['exists'] == true) {
          out[key] = (hit['leadName'] ?? '').toString().trim();
        }
      }
      return out;
    } catch (e) {
      debugPrint('checkDuplicate error: $e');
      return null;
    }
  }

  // ── 🌐 POST /leads/create ─────────────────────────────────
  // The API accepts multipart/form-data.
  // Attachments are sent as repeated 'attachments' entries:
  //   attachments: <file1>
  //   attachments: <file2>
  //   ...other fields as plain string values...
  Future<String?> createLead(
  Lead lead, {
  List<MultipartFile> attachments = const [],
  List<MultipartFile> images = const [],
}) async {
  try {
    await _initToken();

    // ==========================================================
    // CURRENT USER
    // ==========================================================

    final prefs = await SharedPreferences.getInstance();

    final currentUserId =
        prefs.getString('user_id')?.trim();

    final isSalesman =
        !PermissionHelper.can('users_roles');

    debugPrint(
      '========== CREATE LEAD USER =========='
    );
    debugPrint('Current User ID: $currentUserId');
    debugPrint('Is Salesman: $isSalesman');
    debugPrint('UI Assigned ID: ${lead.assignedToId}');
    debugPrint(
      '======================================',
    );

    // ==========================================================
    // CUSTOM FIELDS
    // ==========================================================

    final customFieldsJson =
        lead.customFields.map(
      (field) {
        return {
          if (field.id.isNotEmpty)
            '_id': field.id,
          'cardTitle': field.cardTitle,
          'name': field.name,
          'type': field.type,
          'options': field.options,
          'value': field.value,
        };
      },
    ).toList();

    final formData = FormData();

    formData.fields.add(
      MapEntry('leadName', lead.name),
    );

    formData.fields.add(
      MapEntry('phoneNumber', lead.phone),
    );

    formData.fields.add(
      MapEntry(
        'alternatePhoneNumber',
        lead.alternatePhoneNumber,
      ),
    );

    formData.fields.add(
      MapEntry('email', lead.email),
    );

    formData.fields.add(
      MapEntry(
        'alternateEmail',
        lead.alternateEmail,
      ),
    );

    formData.fields.add(
      MapEntry('source', lead.source),
    );

    if (lead.sourceId != null) {
      formData.fields.add(
        MapEntry(
          'sourceId',
          lead.sourceId!,
        ),
      );
    }

    formData.fields.add(
      MapEntry(
        'companyName',
        lead.companyName,
      ),
    );

    formData.fields.add(
      MapEntry(
        'industry',
        lead.industry,
      ),
    );

    formData.fields.add(
      MapEntry(
        'requirement',
        lead.requirement,
      ),
    );

    if (lead.clientType.isNotEmpty) {
      formData.fields.add(
        MapEntry(
          'clientType',
          lead.clientType,
        ),
      );
    }

    if (lead.numberOfEmployees != null) {
      formData.fields.add(
        MapEntry(
          'NumberOfEmployees',
          lead.numberOfEmployees.toString(),
        ),
      );
    }

    formData.fields.add(
      MapEntry(
        'status',
        lead.status,
      ),
    );

    formData.fields.add(
      MapEntry(
        'notes',
        lead.notes,
      ),
    );

    // ==========================================================
    // ASSIGN TO
    // ==========================================================

    String? assignToId;

    // SALESMAN
    // Always assign the newly created lead to himself.
    if (isSalesman &&
        currentUserId != null &&
        currentUserId.isNotEmpty) {
      assignToId = currentUserId;
    }

    // ADMIN / MANAGER
    // Use the assignee selected in the UI.
    else if (lead.assignedToId != null &&
        lead.assignedToId!.trim().isNotEmpty) {
      assignToId =
          lead.assignedToId!.trim();
    }

    if (assignToId != null &&
        assignToId.isNotEmpty) {
      formData.fields.add(
        MapEntry(
          'assignTo',
          assignToId,
        ),
      );
    }

    debugPrint(
      'FINAL assignTo SENT TO API: $assignToId',
    );

    // ==========================================================
    // FOLLOW UP
    // ==========================================================

    if (lead.followUpDate != null) {
      formData.fields.add(
        MapEntry(
          'followUpDate',
          DateFormat('yyyy-MM-dd').format(
            lead.followUpDate!,
          ),
        ),
      );
    }

    // ==========================================================
    // ADDRESS
    // ==========================================================

    formData.fields.add(
      MapEntry(
        'address',
        lead.address,
      ),
    );

    formData.fields.add(
      MapEntry(
        'city',
        lead.city,
      ),
    );

    formData.fields.add(
      MapEntry(
        'state',
        lead.state,
      ),
    );

    formData.fields.add(
      MapEntry(
        'pincode',
        lead.pincode,
      ),
    );

    formData.fields.add(
      MapEntry(
        'country',
        lead.country,
      ),
    );

    if (lead.latitude != null) {
      formData.fields.add(
        MapEntry(
          'latitude',
          lead.latitude.toString(),
        ),
      );
    }

    if (lead.longitude != null) {
      formData.fields.add(
        MapEntry(
          'longitude',
          lead.longitude.toString(),
        ),
      );
    }

    // ==========================================================
    // ATTACHMENTS
    // ==========================================================

    formData.fields.add(
      MapEntry(
        'existingAttachments',
        jsonEncode([]),
      ),
    );

    formData.fields.add(
      MapEntry(
        'customFields',
        jsonEncode(customFieldsJson),
      ),
    );

    for (final file in attachments) {
      formData.files.add(
        MapEntry(
          'attachments',
          file,
        ),
      );
    }

    for (final file in images) {
      formData.files.add(
        MapEntry(
          'images',
          file,
        ),
      );
    }

    // ==========================================================
    // DEBUG
    // ==========================================================

    debugPrint(
      '========== CREATE FORMDATA =========='
    );

    debugPrint(
      'assignTo: $assignToId',
    );

    debugPrint(
      'customFields: '
      '${jsonEncode(customFieldsJson)}',
    );

    debugPrint(
      'attachments: ${attachments.length}',
    );

    debugPrint(
      'images: ${images.length}',
    );

    debugPrint(
      '===================================='
    );

    // ==========================================================
    // API
    // ==========================================================

    final res = await _dio.post(
      '/leads/create',
      data: formData,
    );

    debugPrint(
      '========== CREATE RESPONSE =========='
    );

    debugPrint(
      res.data.toString(),
    );

    debugPrint(
      '===================================='
    );

    final saved =
        _extractLead(res.data) ?? lead;

    try {
      await LocalDb.instance
          .upsertLeadFromApi(saved);
    } catch (e) {
      debugPrint(
        '=== LEAD CACHE CREATE WRITE ERROR ===: $e',
      );
    }

    if (!isClosed) {
      final current =
          state is LeadLoaded
              ? (state as LeadLoaded).leads
              : <Lead>[];

      emit(
        LeadActionSuccess(
          leads: [
            saved,
            ...current,
          ],
          salesUsers: _salesUsers,
          message: 'Lead created ✓',
        ),
      );
    }

    return null;
  } on DioException catch (e) {
    if (_isOfflineDio(e)) {
      try {
        final saved =
            await LocalDb.instance
                .insertLead(lead);

        if (!isClosed) {
          final current =
              state is LeadLoaded
                  ? (state as LeadLoaded).leads
                  : <Lead>[];

          emit(
            LeadActionSuccess(
              leads: [
                saved,
                ...current,
              ],
              salesUsers: _salesUsers,
              message: 'Lead saved offline',
            ),
          );
        }

        return null;
      } catch (dbErr) {
        return 'Failed to save lead offline: $dbErr';
      }
    }

    return _dioMsg(e);
  } catch (e) {
    return 'Failed to create lead: $e';
  }
}
  // ── 🌐 PUT /leads/updateLead/:id ──────────────────────────
  // Edit does NOT re-upload attachments — server keeps existing files.
  // Payload sent as JSON (no FormData needed when no files).
  Future<String?> updateLead(
  String id,
  Lead lead, {
  List<MultipartFile> attachments = const [],
  List<MultipartFile> images = const [],
  List<String>? retainedAttachmentPaths,
  List<String>? retainedImagePaths,
}) async {
  try {
    final payload = _buildPayload(
      lead,
      attachments: attachments,
      retainedAttachmentPaths: retainedAttachmentPaths,
      images: images,
      retainedImagePaths: retainedImagePaths,
    );

    // DEBUG BEFORE API REQUEST
    debugPrint('========== MOBILE UPDATE ==========');
    debugPrint('Lead ID: $id');
    debugPrint('Custom fields count: ${lead.customFields.length}');

    for (final field in lead.customFields) {
      debugPrint(
        'CustomField => '
        'id=${field.id}, '
        'name=${field.name}, '
        'type=${field.type}, '
        'value=${field.value}',
      );
    }

    debugPrint('Payload customFields: ${lead.customFields.map((e) => e.toJson()).toList()}');
    debugPrint('===================================');

    final res = await _dio.put(
      '/leads/updateLead/$id',
      data: payload,
    );

    debugPrint('========== UPDATE RESPONSE ==========');
    debugPrint(res.data.toString());
    debugPrint('=====================================');

    final updated = _extractLead(res.data) ?? lead.copyWith(id: id);

    try {
      await LocalDb.instance.upsertLeadFromApi(updated);
    } catch (e) {
      debugPrint('=== LEAD CACHE UPDATE WRITE ERROR ===: $e');
    }

    if (!isClosed && state is LeadLoaded) {
      final newList = (state as LeadLoaded)
          .leads
          .map((l) => l.id == id ? updated : l)
          .toList();

      emit(
        LeadActionSuccess(
          leads: newList,
          salesUsers: _salesUsers,
          message: 'Lead updated ✓',
        ),
      );
    }

    return null;
  } on DioException catch (e) {
    debugPrint('=== UPDATE API ERROR ===');
    debugPrint(e.response?.data.toString());
    debugPrint('========================');

    if (_isOfflineDio(e)) {
      try {
        final updated = await LocalDb.instance.updateLead(id, lead);

        if (!isClosed && state is LeadLoaded) {
          final newList = (state as LeadLoaded)
              .leads
              .map((l) => l.id == id ? updated : l)
              .toList();

          emit(
            LeadActionSuccess(
              leads: newList,
              salesUsers: _salesUsers,
              message: 'Lead updated offline',
            ),
          );
        }

        return null;
      } catch (dbErr) {
        return 'Failed to update lead offline: $dbErr';
      }
    }

    return _dioMsg(e);
  } catch (e) {
    return 'Failed to update lead: $e';
  }
}

  // ── 🌐 DELETE /leads/deleteLead/:id ──────────────────────
  Future<String?> deleteLead(String id) async {
    try {
      await _dio.delete('/leads/deleteLead/$id');
      try {
        await LocalDb.instance.deleteLead(id);
      } catch (e) {
        debugPrint('=== LEAD CACHE DELETE ERROR ===: $e');
      }
      if (!isClosed && state is LeadLoaded) {
        final newList =
            (state as LeadLoaded).leads.where((l) => l.id != id).toList();
        emit(LeadActionSuccess(
            leads: newList, salesUsers: _salesUsers, message: 'Lead deleted'));
      }
      return null;
    } on DioException catch (e) {
      if (_isOfflineDio(e)) {
        try {
          await LocalDb.instance.deleteLead(id);
          if (!isClosed && state is LeadLoaded) {
            final newList =
                (state as LeadLoaded).leads.where((l) => l.id != id).toList();
            emit(LeadActionSuccess(
                leads: newList,
                salesUsers: _salesUsers,
                message: 'Lead deleted offline'));
          }
          return null;
        } catch (dbErr) {
          return 'Failed to delete lead offline: $dbErr';
        }
      }
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to delete lead: $e';
    }
  }

  // ── 🌐 PATCH /leads/:id/status ────────────────────────────
  Future<String?> updateStatus(String id, String status) async {
    try {
      await _dio.patch('/leads/$id/status', data: {'status': status});
      if (!isClosed && state is LeadLoaded) {
        final newList = (state as LeadLoaded)
            .leads
            .map((l) => l.id == id ? l.copyWith(status: status) : l)
            .toList();
        final updatedLead = newList.firstWhere((l) => l.id == id);
        try {
          await LocalDb.instance.upsertLeadFromApi(updatedLead);
        } catch (e) {
          debugPrint('=== LEAD CACHE STATUS WRITE ERROR ===: $e');
        }
        emit(LeadActionSuccess(
            leads: newList,
            salesUsers: _salesUsers,
            message: 'Status updated to $status'));
      }
      return null;
    } on DioException catch (e) {
      if (_isOfflineDio(e) && !isClosed && state is LeadLoaded) {
        final current = state as LeadLoaded;
        final existing = current.leads.where((l) => l.id == id).firstOrNull;
        if (existing != null) {
          final updated = existing.copyWith(status: status);
          try {
            await LocalDb.instance.updateLead(id, updated);
            final newList =
                current.leads.map((l) => l.id == id ? updated : l).toList();
            emit(LeadActionSuccess(
                leads: newList,
                salesUsers: _salesUsers,
                message: 'Status updated offline'));
            return null;
          } catch (dbErr) {
            return 'Failed to update status offline: $dbErr';
          }
        }
      }
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to update status: $e';
    }
  }

  // ── 🌐 PUT /leads/updateLead/:id ──────────────────────────
  // Status change that needs a reason (e.g. moving to Cold).
  // Request body: { "status": "Cold", "rejectionReason": "No budget" }
  Future<String?> updateStatusWithReason(
      String id, String status, String reason) async {
    try {
      final res = await _dio.put('/leads/updateLead/$id', data: {
        'status': status,
        'rejectionReason': reason,
      });
      if (!isClosed && state is LeadLoaded) {
        final current = state as LeadLoaded;
        final existing = current.leads.where((l) => l.id == id).firstOrNull;
        final updated = _extractLead(res.data) ??
            existing?.copyWith(status: status, rejectionReason: reason);
        if (updated != null) {
          try {
            await LocalDb.instance.upsertLeadFromApi(updated);
          } catch (e) {
            debugPrint('=== LEAD CACHE STATUS WRITE ERROR ===: $e');
          }
          emit(LeadActionSuccess(
              leads: current.leads
                  .map((l) => l.id == id ? updated : l)
                  .toList(),
              salesUsers: _salesUsers,
              message: 'Status updated to $status'));
        }
      }
      return null;
    } on DioException catch (e) {
      if (_isOfflineDio(e) && !isClosed && state is LeadLoaded) {
        final current = state as LeadLoaded;
        final existing = current.leads.where((l) => l.id == id).firstOrNull;
        if (existing != null) {
          final updated =
              existing.copyWith(status: status, rejectionReason: reason);
          try {
            await LocalDb.instance.updateLead(id, updated);
            emit(LeadActionSuccess(
                leads: current.leads
                    .map((l) => l.id == id ? updated : l)
                    .toList(),
                salesUsers: _salesUsers,
                message: 'Status updated offline'));
            return null;
          } catch (dbErr) {
            return 'Failed to update status offline: $dbErr';
          }
        }
      }
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to update status: $e';
    }
  }

  // ── 🌐 PATCH /leads/:id/followup ─────────────────────────
  Future<String?> updateFollowUp(String id, DateTime date) async {
    try {
      await _dio.patch('/leads/$id/followup',
          data: {'followUpDate': DateFormat('yyyy-MM-dd').format(date)});
      if (!isClosed && state is LeadLoaded) {
        final newList = (state as LeadLoaded)
            .leads
            .map((l) => l.id == id ? l.copyWith(followUpDate: date) : l)
            .toList();
        final updatedLead = newList.firstWhere((l) => l.id == id);
        try {
          await LocalDb.instance.upsertLeadFromApi(updatedLead);
        } catch (e) {
          debugPrint('=== LEAD CACHE FOLLOWUP WRITE ERROR ===: $e');
        }
        emit(LeadActionSuccess(
            leads: newList,
            salesUsers: _salesUsers,
            message: 'Follow-up date updated'));
      }
      return null;
    } on DioException catch (e) {
      if (_isOfflineDio(e) && !isClosed && state is LeadLoaded) {
        final current = state as LeadLoaded;
        final existing = current.leads.where((l) => l.id == id).firstOrNull;
        if (existing != null) {
          final updated = existing.copyWith(followUpDate: date);
          try {
            await LocalDb.instance.updateLead(id, updated);
            final newList =
                current.leads.map((l) => l.id == id ? updated : l).toList();
            emit(LeadActionSuccess(
                leads: newList,
                salesUsers: _salesUsers,
                message: 'Follow-up updated offline'));
            return null;
          } catch (dbErr) {
            return 'Failed to update follow-up offline: $dbErr';
          }
        }
      }
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to update follow-up: $e';
    }
  }

  // ── 🌐 POST /{tenantSlug}/api/leads/:id/followup-notes ────
  // NOTE: this endpoint lives under the tenant-scoped path
  // (…techzarinfo.cloud/<tenantSlug>/api/…) rather than the plain
  // /api base used by every other call in this cubit, so we build
  // an absolute URL for this one request instead of a relative path.
  // Response shape: { "message": "...", "lead": { ...full lead... } }
  Future<String?> addFollowUpNote(
  String id,
  String note, {
  PlatformFile? audioFile,
}) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return 'Note cannot be empty';

    try {
      await _initToken();
      final tenantSlug = _cachedTenantSlug;
      if (tenantSlug == null || tenantSlug.isEmpty) {
        return 'Missing tenant slug — please log in again';
      }

      dynamic payload;

if (audioFile != null && audioFile.path != null) {
  payload = FormData.fromMap({
    'note': trimmed,
    'audio': await MultipartFile.fromFile(
      audioFile.path!,
      filename: audioFile.name,
    ),
  });
} else {
  payload = {
    'note': trimmed,
  };
}

final res = await _dio.post(
  '$_domain/$tenantSlug/api/leads/$id/followup-notes',
  data: payload,
);

      final updated = _extractLead(res.data);
      if (updated == null) {
        return 'Follow-up note saved, but response could not be parsed';
      }

      try {
        await LocalDb.instance.upsertLeadFromApi(updated);
      } catch (e) {
        debugPrint('=== LEAD CACHE FOLLOWUP NOTE WRITE ERROR ===: $e');
      }

      if (!isClosed && state is LeadLoaded) {
        final newList = (state as LeadLoaded)
            .leads
            .map((l) => l.id == id ? updated : l)
            .toList();
        final message = (res.data is Map<String, dynamic>)
            ? (res.data['message'] as String? ?? 'Follow-up note added')
            : 'Follow-up note added';
        emit(LeadActionSuccess(
            leads: newList, salesUsers: _salesUsers, message: message));
      }
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to add follow-up note: $e';
    }
  }

  // ── 🌐 PATCH /{tenantSlug}/api/leads/:id/reject ───────────
// Request body:  { "rejectionReason": "..." }
// Response shape: { "message": "Lead rejected", "lead": { ...full lead... } }
Future<String?> rejectLead(String id, String reason) async {
  final trimmed = reason.trim();
  debugPrint("========== REJECT LEAD ==========");
  debugPrint("ID: $id");
  debugPrint("Reason: '$trimmed'");

  if (trimmed.isEmpty) {
    return 'Rejection reason cannot be empty';
  }

  try {
    await _initToken();
    final tenantSlug = _cachedTenantSlug;

    if (tenantSlug == null || tenantSlug.isEmpty) {
      return 'Missing tenant slug — please log in again';
    }
     final payload = {
      "rejectionReason": trimmed,
    };

    final res = await _dio.patch(
  '$_domain/$tenantSlug/api/leads/$id/reject',
  options: Options(
    headers: {
      "Authorization": "Bearer $_cachedToken",
      "Content-Type": "application/json",
    },
  ),
  data: {
    "reason": trimmed,
  },
);

    final updated = _extractLead(res.data);
    if (updated == null) {
      return 'Lead rejected, but response could not be parsed';
    }

    try {
      await LocalDb.instance.upsertLeadFromApi(updated);
    } catch (e) {
      debugPrint('=== LEAD CACHE REJECT WRITE ERROR ===: $e');
    }

    if (!isClosed && state is LeadLoaded) {
      final newList = (state as LeadLoaded)
          .leads
          .map((l) => l.id == id ? updated : l)
          .toList();
      final message = (res.data is Map<String, dynamic>)
          ? (res.data['message'] as String? ?? 'Lead rejected')
          : 'Lead rejected';
      emit(LeadActionSuccess(
          leads: newList, salesUsers: _salesUsers, message: message));
    }
    return null;
  } on DioException catch (e) {
    return _dioMsg(e);
  } catch (e) {
    return 'Failed to reject lead: $e';
  }
}

  // ── 🌐 GET /users/me → account default currency ("USD") ──
  // Falls back to the value cached in prefs, then 'INR'.
  Future<String> getAccountCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('currency')?.trim().toUpperCase() ?? '';
    try {
      await _initToken();
      final res = await _dio
          .get('/users/me')
          .timeout(const Duration(seconds: 8));
      final data = res.data;
      if (data is Map) {
        // "currency" is top-level; also tolerate { user: {...} } / { data: {...} }
        final source = data['currency'] != null
            ? data
            : (data['user'] is Map
                ? data['user']
                : (data['data'] is Map ? data['data'] : data));
        final live = AccountCurrency.fromJson(
                Map<String, dynamic>.from(source as Map))
            .currency;
        debugPrint('[LeadCubit] /users/me currency: $live');
        if (live.isNotEmpty) {
          await prefs.setString('currency', live);
          return live;
        }
      }
    } catch (e) {
      debugPrint('=== ACCOUNT CURRENCY ERROR ===: $e');
    }
    return cached.isNotEmpty ? cached : 'INR';
  }

  // ── 🌐 PATCH /leads/:id/convert ──────────────────────────
  Future<String?> convertToDeal(
    String id,
    double dealValue,
    String currencyCode, {
    DateTime? expectedCloseDate,
    String? stage,
    String? notes,
  }) async {
    try {
      await _dio.patch('/leads/$id/convert', data: {
        'value': dealValue,
        'currency': currencyCode,
        if (expectedCloseDate != null)
          'expectedCloseDate':
              DateFormat('yyyy-MM-dd').format(expectedCloseDate),
        if (stage != null && stage.isNotEmpty) 'stage': stage,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
      if (!isClosed && state is LeadLoaded) {
        final newList = (state as LeadLoaded)
            .leads
            .map((l) => l.id == id ? l.copyWith(status: 'converted') : l)
            .toList();
        final updatedLead = newList.firstWhere((l) => l.id == id);
        try {
          await LocalDb.instance.upsertLeadFromApi(updatedLead);
        } catch (e) {
          debugPrint('=== LEAD CACHE CONVERT WRITE ERROR ===: $e');
        }
        emit(LeadActionSuccess(
            leads: newList,
            salesUsers: _salesUsers,
            message: 'Lead converted to deal ✓'));
      }
      return null;
    } on DioException catch (e) {
      if (_isOfflineDio(e) && !isClosed && state is LeadLoaded) {
        final current = state as LeadLoaded;
        final existing = current.leads.where((l) => l.id == id).firstOrNull;
        if (existing != null) {
          final updated = existing.copyWith(status: 'converted');
          try {
            await LocalDb.instance.updateLead(id, updated);
            final newList =
                current.leads.map((l) => l.id == id ? updated : l).toList();
            emit(LeadActionSuccess(
                leads: newList,
                salesUsers: _salesUsers,
                message: 'Lead converted offline'));
            return null;
          } catch (dbErr) {
            return 'Failed to convert lead offline: $dbErr';
          }
        }
      }
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to convert lead: $e';
    }
  }

//============================
// leads for notes
//=============================
Future<String?> addNote(
  String id,
  String note,
) async {
  final trimmed = note.trim();

  if (trimmed.isEmpty) {
    return 'Note cannot be empty';
  }

  try {
    await _initToken();

    final tenantSlug = _cachedTenantSlug;

    if (tenantSlug == null || tenantSlug.isEmpty) {
      return 'Missing tenant slug — please log in again';
    }

    final payload = {
  'text': trimmed,
};
    final res = await _dio.post(
      '$_domain/$tenantSlug/api/leads/$id/notes',
      data: payload,
    );

    debugPrint('========== NORMAL NOTE REQUEST ==========');
debugPrint('URL: $_domain/$tenantSlug/api/leads/$id/notes');
debugPrint('PAYLOAD: $payload');
debugPrint('TEXT LENGTH: ${trimmed.length}');
debugPrint('=========================================');


    final updated = _extractLead(res.data);

    if (updated == null) {
      return 'Note added, but response could not be parsed';
    }

    // Update Cubit state only.
    // No LocalDb integration for now.
    if (!isClosed && state is LeadLoaded) {
      final newList = (state as LeadLoaded)
          .leads
          .map(
            (l) => l.id == id ? updated : l,
          )
          .toList();

      final message =
          res.data is Map<String, dynamic>
              ? (res.data['message'] as String? ?? 'Note added')
              : 'Note added';

      emit(
        LeadActionSuccess(
          leads: newList,
          salesUsers: _salesUsers,
          message: message,
        ),
      );
    }

    return null;
  } on DioException catch (e) {
    debugPrint('=== ADD NOTE API ERROR ===');
    debugPrint(e.response?.data.toString());
    debugPrint('==========================');

    return _dioMsg(e);
  } catch (e) {
    return 'Failed to add note: $e';
  }
}

// ===================
// delete note
// ===================
Future<String?> deleteNote(
  String leadId,
  String noteId,
) async {
  try {
    await _initToken();

    final tenantSlug = _cachedTenantSlug;

    if (tenantSlug == null || tenantSlug.isEmpty) {
      return 'Missing tenant slug — please log in again';
    }

    debugPrint('========== DELETE NOTE ==========');
    debugPrint('Lead ID: $leadId');
    debugPrint('Note ID: $noteId');

    final res = await _dio.delete(
      '$_domain/$tenantSlug/api/leads/$leadId/notes/$noteId',
    );

    debugPrint('DELETE NOTE RESPONSE: ${res.data}');
    debugPrint('================================');

    final updated = _extractLead(res.data);

    if (updated != null && !isClosed && state is LeadLoaded) {
      final newList = (state as LeadLoaded)
          .leads
          .map(
            (l) => l.id == leadId ? updated : l,
          )
          .toList();

      emit(
        LeadActionSuccess(
          leads: newList,
          salesUsers: _salesUsers,
          message: 'Note deleted successfully',
        ),
      );
    }

    return null;
  } on DioException catch (e) {
    debugPrint('=== DELETE NOTE API ERROR ===');
    debugPrint(e.response?.data.toString());
    debugPrint('=============================');

    return _dioMsg(e);
  } catch (e) {
    return 'Failed to delete note: $e';
  }
}

// ===============
// update note
// ================
Future<String?> updateNote(
  String leadId,
  String noteId,
  String text,
) async {
  final trimmed = text.trim();

  if (trimmed.isEmpty) {
    return 'Note cannot be empty';
  }

  try {
    await _initToken();

    final tenantSlug = _cachedTenantSlug;

    if (tenantSlug == null || tenantSlug.isEmpty) {
      return 'Missing tenant slug — please log in again';
    }

    debugPrint('========== UPDATE NOTE ==========');
    debugPrint('Lead ID: $leadId');
    debugPrint('Note ID: $noteId');
    debugPrint('Text: $trimmed');

    final res = await _dio.patch(
      '$_domain/$tenantSlug/api/leads/$leadId/notes/$noteId',
      data: {
        'text': trimmed,
      },
    );

    debugPrint('UPDATE NOTE RESPONSE: ${res.data}');
    debugPrint('================================');

    final updated = _extractLead(res.data);

    if (updated == null) {
      return 'Note updated, but response could not be parsed';
    }

    // No LocalDb integration.
    if (!isClosed && state is LeadLoaded) {
      final newList = (state as LeadLoaded)
          .leads
          .map(
            (l) => l.id == leadId ? updated : l,
          )
          .toList();

      emit(
        LeadActionSuccess(
          leads: newList,
          salesUsers: _salesUsers,
          message: 'Note updated successfully',
        ),
      );
    }

    return null;
  } on DioException catch (e) {
    debugPrint('=== UPDATE NOTE API ERROR ===');
    debugPrint(e.response?.data.toString());
    debugPrint('=============================');

    return _dioMsg(e);
  } catch (e) {
    return 'Failed to update note: $e';
  }
}
// ================
// fetch Activity
// ================

Future<List<LeadActivity>> fetchLeadActivity(
  String leadId,
) async {
  try {
    await _initToken();

    final tenantSlug = _cachedTenantSlug;

    if (tenantSlug == null || tenantSlug.isEmpty) {
      debugPrint('Missing tenant slug');
      return [];
    }

    final res = await _dio.get(
      '$_domain/$tenantSlug/api/leads/$leadId/activity',
    );

    debugPrint('========== LEAD ACTIVITY ==========');
    debugPrint(res.data.toString());
    debugPrint('===================================');

    final data = res.data;

    if (data is! Map) {
      return [];
    }

    final activityData = data['activity'];

    if (activityData is! List) {
      return [];
    }

    return activityData
        .whereType<Map>()
        .map(
          (item) => LeadActivity.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  } on DioException catch (e) {
    debugPrint('=== FETCH ACTIVITY ERROR ===');
    debugPrint(e.response?.data.toString());
    debugPrint('============================');
    return [];
  } catch (e) {
    debugPrint('Failed to fetch lead activity: $e');
    return [];
  }
}


//============================
//get All Leads for pop-up
//=============================

  Future<List<Lead>> getAllLeads() async {
  await _initToken();

  final res = await _dio.get('/leads/getAllLead');

  final parsed = await compute(_parseListIsolate, res.data);

  return parsed.map((e) => Lead.fromJson(e)).toList();
}

//===================================
// fetch Reject lead
//===================================
Future<void> fetchRejectedLeads({
  int page = 1,
  int limit = 10,
}) async {
  if (isClosed) return;

  emit(LeadLoading());

  try {
    await _initToken();

    final tenantSlug = _cachedTenantSlug;
    if (tenantSlug == null || tenantSlug.isEmpty) {
      emit(const LeadError('Missing tenant slug'));
      return;
    }

    final res = await _dio.get(
      '$_domain/$tenantSlug/api/leads/rejected',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );

    final leads = await compute(_parseListIsolate, res.data)
        .then((list) => list.map((e) => Lead.fromJson(e)).toList());

    emit(
      LeadLoaded(
        leads: leads,
        salesUsers: _salesUsers,
      ),
    );
  } on DioException catch (e) {
    emit(LeadError(_dioMsg(e)));
  } catch (e) {
    emit(LeadError(e.toString()));
  }
}
// ==================
// get Rejected leads
//===================
Future<List<Lead>> getRejectedLeads() async {
  await _initToken();

  final tenantSlug = _cachedTenantSlug;
  if (tenantSlug == null || tenantSlug.isEmpty) {
    return [];
  }

  final res = await _dio.get(
    '$_domain/$tenantSlug/api/leads/rejected',
  );

  final parsed = await compute(_parseListIsolate, res.data);

  return parsed.map((e) => Lead.fromJson(e)).toList();
}

// =======================
// fetch the missed leads
//========================
// NOTE: fetchAllLeads() now already merges in rejected leads on every
// call, so this method is functionally equivalent to fetchAllLeads()
// for the "Missed Follow-ups" filter path. Left in place in case any
// other call site still references it directly.
// =========================
// Fetch missed follow-ups (one page)
// =========================
// GET /leads/missed-followups?page=&limit= →
// { leads: [...], total, page, totalPages, limit }
Future<MissedFollowupPage> getMissedFollowups({
  int page = 1,
  int limit = 10,
}) async {
  await _initToken();

  final tenantSlug = _cachedTenantSlug;

  if (tenantSlug == null || tenantSlug.isEmpty) {
    return const MissedFollowupPage.empty();
  }

  final res = await _dio.get(
    '$_domain/$tenantSlug/api/leads/missed-followups',
    queryParameters: {
      'page': page,
      'limit': limit,
    },
  );

  final parsed = await compute(
    _parseListIsolate,
    res.data,
  );

  final leads = parsed.map((e) => Lead.fromJson(e)).toList();
  final body = res.data is Map ? res.data as Map : const {};

  int readInt(dynamic v, int fallback) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

  return MissedFollowupPage(
    leads: leads,
    total: readInt(body['total'], leads.length),
    page: readInt(body['page'], page),
    totalPages: readInt(body['totalPages'], page),
  );
}// ===============
// Export the leads
// ================
// Two modes (the dialog guarantees both dates or neither):
//  • no dates   → every lead
//  • start+end  → leads CREATED between start and end (both days included)
Future<String?> exportLeads({
  DateTime? startDate,
  DateTime? endDate,
}) async {
  try {
    final allLeads = await _fetchAllLeadsForExport();
    final leads = allLeads
        .where((l) => _inDateRange(l.createdAt, startDate, endDate))
        .toList();
    debugPrint('[ExportLeads] fetched ${allLeads.length}, exporting '
        '${leads.length} (range: $startDate → $endDate)');

    if (leads.isEmpty) {
      return startDate != null
          ? 'No leads found in the selected date range'
          : 'No leads to export';
    }

    final workbook = xls.Excel.createExcel();
    const sheetName = 'Leads';
    final sheet = workbook[sheetName];
    if (workbook.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      workbook.delete('Sheet1');
    }

    const headers = [
      'Lead Name',
      'Company Name',
      'Phone Number',
      'Email',
      'Address',
      'Country',
      'Client Type',
      'Industry',
      'Source',
      'Requirement',
      'Status',
      'Assigned To',
      'Follow-up Date',
      'Notes',
      'Created Date',
    ];
    sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());

    for (final l in leads) {
      sheet.appendRow([
        xls.TextCellValue(l.name),
        xls.TextCellValue(l.companyName),
        xls.TextCellValue(l.phone),
        xls.TextCellValue(l.email),
        xls.TextCellValue(l.address),
        xls.TextCellValue(l.country),
        xls.TextCellValue(l.clientType),
        xls.TextCellValue(l.industry),
        xls.TextCellValue(l.source),
        xls.TextCellValue(l.requirement),
        xls.TextCellValue(l.status),
        xls.TextCellValue(l.assignTo),
        _xlsDate(l.followUpDate),
        xls.TextCellValue(l.notes),
        _xlsDate(l.createdAt),
      ]);
    }
    sheet.setColumnWidth(0, 20); // Lead Name
    sheet.setColumnWidth(1, 20); // Company Name
    sheet.setColumnWidth(2, 18); // Phone Number
    sheet.setColumnWidth(3, 30); // Email
    sheet.setColumnWidth(4, 30); // Address
    sheet.setColumnWidth(5, 10); // Country
    sheet.setColumnWidth(6, 10); // Client Type
    sheet.setColumnWidth(7, 10); // Industry
    sheet.setColumnWidth(8, 10); // Source
    sheet.setColumnWidth(9, 30); // Requirement
    sheet.setColumnWidth(10, 10); // Status
    sheet.setColumnWidth(11, 18); // Assigned To
    sheet.setColumnWidth(12, 16); // Follow-up Date
    sheet.setColumnWidth(13, 30); // Notes
    sheet.setColumnWidth(14, 16); // Created Date

    final bytes = workbook.save();
    if (bytes == null) return 'Failed to generate export file';

    final savedPath = await _saveXlsxToDownloads('Leads.xlsx', bytes);
    debugPrint("Save Path: $savedPath");
    return null;
  } on DioException catch (e) {
    return _dioMsg(e);
  } catch (e) {
    return 'Failed to export leads: $e';
  }
}

// =========================
// Export Followups
// =========================
// Two modes (the dialog guarantees both dates or neither):
//  • no dates   → every lead
//  • start+end  → leads whose FOLLOW-UP DATE is between start and end
// Each exported lead is written with its full follow-up note history.
Future<String?> exportFollowUps({
  DateTime? startDate,
  DateTime? endDate,
}) async {
  try {
    final allLeads = await _fetchAllLeadsForExport();
    final leads = allLeads
        .where((l) => _inDateRange(l.followUpDate, startDate, endDate))
        .toList();
    debugPrint('[ExportFollowUps] fetched ${allLeads.length}, exporting '
        '${leads.length} (range: $startDate → $endDate)');

    if (leads.isEmpty) {
      return startDate != null
          ? 'No follow-ups found in the selected date range'
          : 'No leads to export';
    }

    await _saveXlsxToDownloads(
      'FollowUps.xlsx',
      _buildFollowUpsWorkbook(leads),
    );
    return null;
  } on DioException catch (e) {
    return _dioMsg(e);
  } catch (e) {
    return 'Failed to export follow-ups: $e';
  }
}

/// Fetches every lead from GET /leads/getAllLead, page by page, so the
/// export is complete even when the server caps the page size. No date
/// params are sent — the range is applied locally on the right field.
Future<List<Lead>> _fetchAllLeadsForExport() async {
  await _initToken();
  const pageSize = 500;
  const maxPages = 200; // safety net
  final byId = <String, Lead>{};
  final noId = <Lead>[];

  for (var page = 1; page <= maxPages; page++) {
    final res = await _dio.get(
      '/leads/getAllLead',
      queryParameters: {'page': page, 'limit': pageSize},
    );
    final raw = await compute(_parseListIsolate, res.data);
    if (raw.isEmpty) break;

    var added = 0;
    for (final e in raw) {
      final lead = Lead.fromJson(e);
      if (lead.id.isEmpty) {
        noId.add(lead);
        added++;
      } else if (!byId.containsKey(lead.id)) {
        byId[lead.id] = lead;
        added++;
      }
    }

    final total = _extractTotalCount(res.data);
    final fetched = byId.length + noId.length;
    // Stop when the page added nothing new (server ignores `page`),
    // or we reached the total the server reported.
    if (added == 0) break;
    if (total != null && fetched >= total) break;
  }
  return [...byId.values, ...noId];
}

/// True when [date] (in local time) is between the start of [start] and
/// the end of [end], both days included. No range → always true.
bool _inDateRange(DateTime? date, DateTime? start, DateTime? end) {
  if (start == null && end == null) return true;
  if (date == null) return false;
  final d = date.toLocal();
  if (start != null &&
      d.isBefore(DateTime(start.year, start.month, start.day))) {
    return false;
  }
  if (end != null &&
      !d.isBefore(DateTime(end.year, end.month, end.day + 1))) {
    return false;
  }
  return true;
}

xls.CellValue _xlsDate(DateTime? d) {
  if (d == null) return xls.TextCellValue('');
  final local = d.toLocal();
  return xls.DateCellValue(
      year: local.year, month: local.month, day: local.day);
}

/// Follow-ups sheet: one row per lead, columns from [columns] below.
/// Header row: blue fill, white bold text, centered; every cell has a thin
/// border. Column widths follow the longest value in each column.
Uint8List _buildFollowUpsWorkbook(List<Lead> leads) {
  final workbook = xls.Excel.createExcel();
  const sheetName = 'Follow-ups';
  final sheet = workbook[sheetName];
  if (workbook.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
    workbook.delete('Sheet1');
  }

  final dateFmt = DateFormat("MMM d, yyyy 'at' hh:mm a");
  // Header → value. Add/remove/reorder columns here only.
  final columns = <(String, String Function(Lead))>[
    ('Lead', (l) => l.name),
    ('Company', (l) => l.companyName),
    ('Assign To', (l) => l.assignTo),
    (
      'Follow-up Date',
      (l) => l.followUpDate == null
          ? ''
          : dateFmt.format(l.followUpDate!.toLocal()),
    ),
    (
      'Follow-up Note',
      // Notes oldest → newest, one per line.
      (l) => ([...l.followUpNotes]
            ..sort((a, b) => (a.createdAt ?? DateTime(0))
                .compareTo(b.createdAt ?? DateTime(0))))
          .map((n) => n.note.trim())
          .where((n) => n.isNotEmpty)
          .join('\n'),
    ),
  ];

  final thin = xls.Border(borderStyle: xls.BorderStyle.Thin);
  final headerStyle = xls.CellStyle(
    bold: true,
    fontColorHex: xls.ExcelColor.white,
    backgroundColorHex: xls.ExcelColor.fromHexString('#2E86C1'),
    horizontalAlign: xls.HorizontalAlign.Center,
    verticalAlign: xls.VerticalAlign.Center,
    leftBorder: thin,
    rightBorder: thin,
    topBorder: thin,
    bottomBorder: thin,
  );
  final bodyStyle = xls.CellStyle(
    verticalAlign: xls.VerticalAlign.Top,
    textWrapping: xls.TextWrapping.WrapText,
    leftBorder: thin,
    rightBorder: thin,
    topBorder: thin,
    bottomBorder: thin,
  );

  final widths = [for (final c in columns) c.$1.length];
  void writeRow(int row, List<String> values, xls.CellStyle style) {
    for (var col = 0; col < values.length; col++) {
      final cell = sheet.cell(
        xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.value = xls.TextCellValue(values[col]);
      cell.cellStyle = style;
      for (final line in values[col].split('\n')) {
        if (line.length > widths[col]) widths[col] = line.length;
      }
    }
  }

  writeRow(0, [for (final c in columns) c.$1], headerStyle);
  for (var i = 0; i < leads.length; i++) {
    writeRow(i + 1, [for (final c in columns) c.$2(leads[i])], bodyStyle);
  }

  // Fit each column to its content (with padding, capped for long notes).
  for (var col = 0; col < columns.length; col++) {
    sheet.setColumnWidth(col, (widths[col] + 4).clamp(12, 60).toDouble());
  }

  final bytes = workbook.save();
  if (bytes == null) throw Exception('Failed to generate workbook');
  return Uint8List.fromList(bytes);
}

// =========================
// Download Import Template
// =========================
Future<String?> downloadLeadTemplate() async {
  try {
    final workbook = xls.Excel.createExcel();
    const sheetName = 'Leads Template';
    final sheet = workbook[sheetName];
    if (workbook.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      workbook.delete('Sheet1');
    }

    const headers = [
      'Lead Name',
      'Company Name',
      'Phone Number',
      'Email',
      'Address',
      'Country',
      'Client Type (B2B/B2C)',
      'Industry',
      'Source',
      'Requirement',
      'Status',
      'Assign To (Email)',
      'Follow-up Date (YYYY-MM-DD)',
      'Notes',
    ];
    sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());

    final bytes = workbook.save();
    if (bytes == null) return 'Failed to generate template';

     final savedPath =
        await _saveXlsxToDownloads('Leads_Import_Template.xlsx', bytes);
    debugPrint('Template Save Path: $savedPath');
    return null;
  } catch (e) {
    return e.toString();
  }
}

// ========================
// Import Leads from Excel
// ========================
Future<LeadImportResult> importLeadsFromFile(PlatformFile file) async {
  await _initToken();

  if (file.bytes == null) {
    throw Exception('Could not read file');
  }

  final workbook = xls.Excel.decodeBytes(file.bytes!);
  if (workbook.tables.isEmpty) {
    throw Exception('No sheet found in the selected file');
  }
  final sheet = workbook.tables[workbook.tables.keys.first]!;
  if (sheet.maxRows <= 1) {
    throw Exception('No data found in the selected file');
  }

  // 👇 NEW: build an email -> id lookup from the sales users you already have
  final assigneeByEmail = <String, String>{
    for (final u in _salesUsers)
      if (u.email.trim().isNotEmpty) u.email.trim().toLowerCase(): u.id
  };

  int success = 0;
  int failed = 0;
  final errors = <String>[];

  for (var i = 1; i < sheet.maxRows; i++) {
    final row = sheet.row(i);

    String cell(int idx) {
      if (idx >= row.length) return '';
      return row[idx]?.value?.toString().trim() ?? '';
    }

    final isBlank = row.every(
        (c) => c?.value == null || c!.value.toString().trim().isEmpty);
    if (isBlank) continue;

    final leadName = cell(0);
    if (leadName.isEmpty) {
      failed++;
      errors.add('Row ${i + 1}: Lead Name is required');
      continue;
    }

    final followUpRaw = cell(12);
    String? followUpDate;
    if (followUpRaw.isNotEmpty) {
      try {
        followUpDate =
            DateFormat('yyyy-MM-dd').format(DateTime.parse(followUpRaw));
      } catch (_) {}
    }

    // 👇 NEW: optional heads-up if the email doesn't match a known user
    if (cell(11).isNotEmpty &&
        !assigneeByEmail.containsKey(cell(11).trim().toLowerCase())) {
      debugPrint(
          'Row ${i + 1} ($leadName): assignee email "${cell(11)}" not found — importing unassigned');
    }

    final payload = <String, dynamic>{
      'leadName': leadName,
      'companyName': cell(1),
      'phoneNumber': cell(2),
      'email': cell(3),
      'address': cell(4),
      'country': cell(5),
      if (cell(6).isNotEmpty) 'clientType': cell(6),
      'industry': cell(7),
      'source': cell(8),
      'requirement': cell(9),
      'status': cell(10).isEmpty ? 'New' : cell(10),
      // 👇 CHANGED: was `cell(11)` (raw email string), now resolved to the user's id
      if (assigneeByEmail[cell(11).trim().toLowerCase()] != null)
        'assignTo': assigneeByEmail[cell(11).trim().toLowerCase()],
      if (followUpDate != null) 'followUpDate': followUpDate,
      'notes': cell(13),
    };

    try {
      await _dio.post('/leads/create', data: payload);
      success++;
    } on DioException catch (e) {
      failed++;
      errors.add('Row ${i + 1} ($leadName): ${_dioMsg(e)}');
    } catch (e) {
      failed++;
      errors.add('Row ${i + 1} ($leadName): $e');
    }
  }

  await fetchAllLeads();

  return LeadImportResult(
      successCount: success, failedCount: failed, errors: errors);
}

// path
 MethodChannel _leadDownloadsChannel = MethodChannel('crm/downloads');

Future<String> _saveXlsxToDownloads(String fileName, List<int> bytes) async {
  if (Platform.isAndroid) {
    final path = await _leadDownloadsChannel.invokeMethod<String>(
      'saveToDownloads',
      <String, dynamic>{
        'fileName': fileName,
        'bytes': Uint8List.fromList(bytes),
        'mimeType':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
    );
    return path ?? '';
  }
  return FileSaver.instance.saveFile(
    name: fileName.replaceAll('.xlsx', ''),
    bytes: Uint8List.fromList(bytes),
    ext: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}


  // ── Helpers ───────────────────────────────────────────────

  /// Builds the request payload.
  ///
  /// • No attachments → returns a plain [Map] (Dio sends as JSON).
  /// • With attachments → returns [FormData] where each file is
  ///   added as a separate 'attachments' entry (key-value pair).
  ///   This matches the POST /leads/create multipart expectation.
  // ===========================================
  // this are payload for create and update lead
  // ===========================================
  dynamic _buildPayload(
  Lead lead, {
  List<MultipartFile> attachments = const [],
  List<MultipartFile> images = const [],
  List<String>? retainedAttachmentPaths,
  List<String>? retainedImagePaths,
}) {
  final map = <String, dynamic>{
    'leadName': lead.name,
    'phoneNumber': lead.phone,
    'alternatePhoneNumber': lead.alternatePhoneNumber,
    'email': lead.email,
    'alternateEmail': lead.alternateEmail,

    'source': lead.source,
    if (lead.sourceId != null) 'sourceId': lead.sourceId,

    'companyName': lead.companyName,
    'industry': lead.industry,
    'requirement': lead.requirement,

    if (lead.clientType.isNotEmpty)
      'clientType': lead.clientType,

    if (lead.numberOfEmployees != null)
      'NumberOfEmployees': lead.numberOfEmployees,

    'status': lead.status,
    'notes': lead.notes,

    if (lead.assignedToId != null &&
        lead.assignedToId!.isNotEmpty)
      'assignTo': lead.assignedToId,

    if (lead.followUpDate != null)
      'followUpDate':
          DateFormat('yyyy-MM-dd').format(lead.followUpDate!),

    'address': lead.address,
    'city': lead.city,
    'state': lead.state,
    'pincode': lead.pincode,
    'country': lead.country,

    if (lead.latitude != null)
      'latitude': lead.latitude,

    if (lead.longitude != null)
      'longitude': lead.longitude,

    'existingAttachments':
        retainedAttachmentPaths ?? [],
  'existingImages':
    retainedImagePaths ?? [],
    // IMPORTANT
    'customFields': jsonEncode(
  lead.customFields.map((field) {
    final data = <String, dynamic>{
      'cardTitle': field.cardTitle,
      'name': field.name,
      'type': field.type,
      'options': field.options,
      'value': field.value,
    };

    if (field.id.isNotEmpty) {
      data['_id'] = field.id;
    }

    return data;
  }).toList(),
),
  };

  final formData = FormData();

  map.forEach((key, value) {
    formData.fields.add(
      MapEntry(
        key,
        value.toString(),
      ),
    );
  });

  for (final file in attachments) {
    formData.files.add(
      MapEntry(
        'attachments',
        file,
      ),
    );
  }

  for (final file in images) {
  formData.files.add(
    MapEntry(
      'images',
      file,
    ),
  );
}

  return formData;
}
// 

  Lead? _extractLead(dynamic d) {
    try {
      Map<String, dynamic>? raw;
      if (d is Map<String, dynamic>) {
        if (d['data'] is Map) {
          raw = Map<String, dynamic>.from(d['data'] as Map);
        } else if (d['lead'] is Map) {
          raw = Map<String, dynamic>.from(d['lead'] as Map);
        } else if (d.containsKey('id') || d.containsKey('_id')) {
          raw = d;
        }
      }
      if (raw == null) return null;
      final n = _parseListIsolate([raw]);
      return n.isEmpty ? null : Lead.fromJson(n.first);
    } catch (_) {
      return null;
    }
  }
  // Leads exracts the count
  int? _extractTotalCount(dynamic raw) {
    if (raw is! Map) return null;
    for (final k in ['totalLeads', 'total', 'totalCount', 'totalRecords', 'count', 'totalItems']) {
      final v = raw[k];
      if (v is num) return v.toInt();
    }
    final nested = raw['pagination'] ?? raw['meta'];
    if (nested is Map) {
      for (final k in ['totalLeads', 'total', 'totalCount', 'totalRecords', 'count', 'totalItems']) {
        final v = nested[k];
        if (v is num) return v.toInt();
      }
    }
    return null;
  }
  //

  String _dioMsg(DioException e) {
    debugPrint(
        '=== DIO ERROR ===: type=${e.type} status=${e.response?.statusCode} body=${e.response?.data}');
    if (e.type == DioExceptionType.badResponse) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = (data['message'] ?? data['error'] ?? data['msg'])?.toString();
      }
      return msg?.isNotEmpty == true
          ? msg!
          : 'Server error (${e.response?.statusCode}).';
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout =>
        'Connection timed out.',
      DioExceptionType.connectionError => 'No internet connection.',
      _ => 'Something went wrong.',
    };
  }

  bool _isOfflineDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        true,
      DioExceptionType.unknown =>
        (e.message?.toLowerCase().contains('socket') ?? false) ||
            (e.message?.toLowerCase().contains('network') ?? false) ||
            (e.message?.toLowerCase().contains('timed out') ?? false) ||
            (e.message?.toLowerCase().contains('connection') ?? false),
      _ => false,
    };
  }
}