// ╔══════════════════════════════════════════════════════════════╗
// ║           lib/screen/deals/cubit/deals_cubit.dart            ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:dio/dio.dart'
    show
        Dio,
        BaseOptions,
        InterceptorsWrapper,
        DioException,
        MultipartFile,
        FormData,
        Options;
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:crm_app/utils/permission_helper.dart';

// ══════════════════════════════════════════════════════════════
// ATTACHMENT MODEL
// ══════════════════════════════════════════════════════════════
class Attachment {
  final String name;
  final String path;
  final String type;
  final int size;

  const Attachment({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        name: j['name']?.toString() ?? '',
        path: j['path']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
      );
}

// ══════════════════════════════════════════════════════════════
// DEAL MODEL
// ══════════════════════════════════════════════════════════════
class Deal {
  final String id;
  final String name;
  final String companyName;
  final String phone;
  final String email;
  final String stage;
  final String industry;
  final String source;
  final String clientType;
  final String country;
  final String address;
  final String assignTo;
  final String notes;
  final String currency;
  final String countryCode;
  final double value;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastReminderAt;
  final String? followUpDate;
  final String? followUpComment;
  final List<FollowUpHistoryItem> followUpHistory;
  final List<Attachment> attachments;

  const Deal({
    required this.id,
    required this.name,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.stage,
    required this.industry,
    required this.source,
    required this.clientType,
    required this.country,
    required this.address,
    required this.assignTo,
    required this.notes,
    required this.currency,
    required this.countryCode,
    required this.value,
    required this.createdAt,
    this.updatedAt,
    this.lastReminderAt,
    this.followUpDate,
    this.followUpComment,
    this.followUpHistory = const [],
    this.attachments = const [],
  });

  static String _s(dynamic v, [String fb = '']) =>
      v == null ? fb : v.toString();

  static String _normalizeClientType(dynamic v) {
    final raw = _s(v).trim().toUpperCase();
    if (raw == 'B2B' || raw == 'B2C') return raw;
    return '';
  }

  factory Deal.fromJson(Map<String, dynamic> j) {
    // assignTo
    String assignTo = '';
    final raw = j['assignTo'] ?? j['assignedTo'];
    if (raw is Map) {
      assignTo = '${_s(raw['firstName'])} ${_s(raw['lastName'])}';
    } else if (raw != null) {
      assignTo = _s(raw);
    }
    assignTo = assignTo.trim();

    // value — strip non-numeric chars before parsing
    double val = 0;
    final rv = j['value'] ?? j['dealValue'] ?? j['amount'];
    if (rv != null) {
      val = double.tryParse(
              rv.toString().replaceAll(RegExp(r'[^\d.\-]'), '')) ??
          0;
    }

    // currency — API sends bare "INR"; map to display string "₹ INR"
    final rawCur = _s(j['currency'], 'INR')
        .replaceAll(RegExp(r'[₹$€£¥\s]'), '')
        .toUpperCase();
    final currency = DealConstants.currencies.firstWhere(
      (c) => c.toUpperCase().contains(rawCur),
      orElse: () => '₹ INR',
    );

    // attachments
    final List<Attachment> attachments = [];
    final rawAttach = j['attachments'];
    if (rawAttach is List) {
      for (final a in rawAttach) {
        if (a is Map) {
          try {
            attachments
                .add(Attachment.fromJson(Map<String, dynamic>.from(a)));
          } catch (_) {}
        }
      }
    }

    // followUpHistory — used by Deal details "Follow-up history" tab.
    final List<FollowUpHistoryItem> followUpHistory = [];
    final rawHistory =
        j['followUpHistory'] ?? j['follow_up_history'] ?? j['followupHistory'];
    if (rawHistory is List) {
      for (final h in rawHistory) {
        if (h is! Map) continue;
        final m = Map<String, dynamic>.from(h);
        followUpHistory.add(FollowUpHistoryItem(
          date: DateTime.tryParse(m['date']?.toString() ?? ''),
          followUpDate:
              DateTime.tryParse(m['followUpDate']?.toString() ?? ''),
          action: (m['action'] ?? m['status'] ?? '').toString(),
          comment: (m['followUpComment'] ?? m['comment'] ?? '').toString(),
        ));
      }
    }

    return Deal(
      id:              _s(j['_id'] ?? j['id']),
      name:            _s(j['dealName'] ?? j['name']),
      companyName:     _s(j['companyName'] ?? j['company']),
      phone:           _s(j['phone'] ?? j['phoneNumber']),
      email:           _s(j['email']),
      stage:           _s(j['stage'], 'Qualification'),
      industry:        _s(j['industry']),
      source:          _s(j['source']),
      clientType:      _normalizeClientType(j['clientType']),
      country:         _s(j['country']),
      address:         _s(j['address']),
      assignTo:        assignTo,
      notes:           _s(j['notes']),
      currency:        currency,
      countryCode:     _s(j['countryCode'], '+91 IN'),
      value:           val,
      createdAt:       j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt:       j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'].toString())
          : null,
      lastReminderAt:  j['lastReminderAt'] != null
          ? DateTime.tryParse(j['lastReminderAt'].toString())
          : null,
      followUpDate:    j['followUpDate']?.toString(),
      followUpComment: j['followUpComment']?.toString(),
      followUpHistory: followUpHistory,
      attachments:     attachments,
    );
  }

  Deal copyWith({
    String? stage,
    List<Attachment>? attachments,
    List<FollowUpHistoryItem>? followUpHistory,
  }) =>
      Deal(
        id:              id,
        name:            name,
        companyName:     companyName,
        phone:           phone,
        email:           email,
        stage:           stage ?? this.stage,
        industry:        industry,
        source:          source,
        clientType:      clientType,
        country:         country,
        address:         address,
        assignTo:        assignTo,
        notes:           notes,
        currency:        currency,
        countryCode:     countryCode,
        value:           value,
        createdAt:       createdAt,
        updatedAt:       updatedAt,
        lastReminderAt:  lastReminderAt,
        followUpDate:    followUpDate,
        followUpComment: followUpComment,
        followUpHistory: followUpHistory ?? this.followUpHistory,
        attachments:     attachments ?? this.attachments,
      );

  Map<String, dynamic> toPayload() => {
        'dealName':    name,
        'companyName': companyName,
        'phoneNumber': phone,
        'email':       email,
        'stage':       stage,
        'industry':    industry,
        'source':      source,
        'clientType':  clientType,
        'country':     country,
        'address':     address,
        'notes':       notes,
        'currency':    currency,
        'countryCode': countryCode,
        'value':       value,
      };
}

class FollowUpHistoryItem {
  final DateTime? date; // when the action happened
  final DateTime? followUpDate; // scheduled datetime
  final String action; // e.g. "Scheduled", "Completed"
  final String comment;

  const FollowUpHistoryItem({
    this.date,
    this.followUpDate,
    required this.action,
    required this.comment,
  });
}

// ══════════════════════════════════════════════════════════════
// CONSTANTS
// ══════════════════════════════════════════════════════════════
class DealConstants {
  static const stages = [
    'Qualification',
    'Proposal Sent-Negotiation',
    'Invoice Sent',
    'Closed Won',
    'Closed Lost',
  ];

  /// Maps legacy/API stages to a column in [stages].
  static String canonicalStage(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return stages.first;
    final k = t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

    // Keep real "Invoice Sent" stages separate.
    if (k.contains('invoice') && k.contains('sent')) {
      return 'Invoice Sent';
    }

    // Show any proposal/negotiation-related stage under one bucket.
    // This also fixes the "Invoice Sent shows extra data" issue.
    if (k.contains('proposal') || k.contains('negotiation')) {
      return 'Proposal Sent-Negotiation';
    }

    return t;
  }
  static const currencies = [
    '₹ INR', '\$ USD', '€ EUR', '£ GBP', '¥ JPY', '¥ CNY',
  ];
  static const countryCodes = [
    '+91 IN', '+1 US', '+44 UK', '+61 AU', '+971 UAE',
    '+65 SG', '+81 JP', '+86 CN', '+49 DE', '+33 FR',
  ];
  static const industries = [
    'IT', 'Finance', 'Healthcare', 'Education',
    'Manufacturing', 'Retail', 'Others',
  ];

  static String currencySymbol(String s) => s.split(' ').first;
}

// ══════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════
abstract class DealsState extends Equatable {
  const DealsState();
  @override List<Object?> get props => [];
}

class DealsInitial       extends DealsState {}
class DealsLoading       extends DealsState {}

class DealsActionSuccess extends DealsState {
  final String message;
  const DealsActionSuccess(this.message);
  @override List<Object?> get props => [message];
}

class DealsError extends DealsState {
  final String message;
  const DealsError(this.message);
  @override List<Object?> get props => [message];
}

class DealsLoaded extends DealsState {
  final List<Deal>   allDeals;
  final List<Deal>   pendingDeals;
  final List<Deal>   lostDeals;
  final List<String> salesUsers;

  const DealsLoaded({
    required this.allDeals,
    required this.pendingDeals,
    required this.lostDeals,
    required this.salesUsers,
  });

  DealsLoaded copyWithDeals(List<Deal> d) => DealsLoaded(
        allDeals: d, pendingDeals: pendingDeals,
        lostDeals: lostDeals, salesUsers: salesUsers);

  @override
  List<Object?> get props =>
      [allDeals, pendingDeals, lostDeals, salesUsers];
}

// ══════════════════════════════════════════════════════════════
// CUBIT
// ══════════════════════════════════════════════════════════════
class DealsCubit extends Cubit<DealsState> {
  static const _base = 'https://sales.stagingzar.com/api';

  late final Dio _dio;
  String? _cachedToken;

  DealsCubit() : super(DealsInitial()) {
    // ── FIX: Do NOT set Content-Type globally. ─────────────────
    // Dio must set it automatically per-request so that multipart
    // requests get the correct boundary in their Content-Type header.
    // Setting 'application/json' globally breaks FormData uploads.
    _dio = Dio(BaseOptions(
      baseUrl:        _base,
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
        if (err.response?.statusCode == 401) _cachedToken = null;
        handler.next(err);
      },
    ));

    _initToken();
  }

  Future<void> _initToken() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
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
        PermissionHelper.can('admin_access') && !_isSalesRole(roleName);

    final allDeals     = await _safeGet('/deals/getAll');
    final pendingDeals = await _safeGet('/deals/pending');
    final lostDeals    = await _safeGet('/lost-deals');
    final userMaps     = await _safeGet('/users/sales');

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

    final deals   = _parseDeals(scopedAllRows);
    final pending = _parseDeals(scopedPendingRows);
    final lost    = _parseDeals(scopedLostRows);

    List<String> users = userMaps.map((e) {
      final fn   = e['firstName']?.toString().trim() ?? '';
      final ln   = e['lastName']?.toString().trim()  ?? '';
      final id   = e['_id']?.toString()              ?? '';
      final name = [fn, ln].where((s) => s.isNotEmpty).join(' ');
      return name.isNotEmpty && id.isNotEmpty ? '$name||$id' : '';
    }).where((s) => s.isNotEmpty).toList();

    if (users.isEmpty) {
      users = deals.map((d) => d.assignTo).where((s) => s.isNotEmpty)
          .toSet().toList()..sort();
    }

    if (isClosed) return;
    emit(DealsLoaded(
      allDeals: deals, pendingDeals: pending,
      lostDeals: lost, salesUsers: users,
    ));
  }

  Future<void> refresh() async {
    if (state is! DealsLoading) await loadDeals();
  }

  Future<Deal?> getDealById(String id) async {
    try {
      final res  = await _dio.get('/deals/getAll/$id');
      final data = res.data;
      Map<String, dynamic>? map;
      if (data is Map) map = Map<String, dynamic>.from(data);
      if (data is List && data.isNotEmpty) {
        map = Map<String, dynamic>.from(data.first as Map);
      }
      return map != null ? Deal.fromJson(map) : null;
    } catch (_) { return null; }
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
    List<PlatformFile> files,
  ) async {
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
      debugPrint('[DealsCubit] createDeal → fields=${formData.fields.length} files=${formData.files.length}');

      final res  = await _dio.post('/deals/createManual', data: formData);
      final body = res.data;

      // ── FIX: Extract ID from confirmed API shape ────────────
      // Response: { "message": "...", "deal": { "_id": "69e07c...", ... } }
      String? newId;
      Map<String, dynamic>? dealMap;

      if (body is Map) {
        // Primary path: body['deal'] is the deal object
        if (body['deal'] is Map) {
          dealMap = Map<String, dynamic>.from(body['deal'] as Map);
          newId   = dealMap['_id']?.toString();
        }
        // Fallback: body itself is the deal
        if (newId == null && body['_id'] != null) {
          dealMap = Map<String, dynamic>.from(body);
          newId   = dealMap['_id']?.toString();
        }
        // Fallback: body['data'] wraps the deal
        if (newId == null && body['data'] is Map) {
          dealMap = Map<String, dynamic>.from(body['data'] as Map);
          newId   = dealMap['_id']?.toString();
        }
      }

      debugPrint('[DealsCubit] createDeal → newId=$newId');

      // Optimistic insert if we have the deal map
      if (dealMap != null && prev is DealsLoaded && !isClosed) {
        try {
          final newDeal = Deal.fromJson(dealMap);
          emit(prev.copyWithDeals([newDeal, ...prev.allDeals]));
        } catch (_) {}
      }

      // Always reload to get consistent server state
      await loadDeals();
      if (!isClosed) emit(const DealsActionSuccess('Deal created successfully'));

      return newId;
    } on DioException catch (e) {
      debugPrint('[DealsCubit] createDeal DioException: ${e.response?.statusCode} ${e.response?.data}');
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
      await _dio.post('/deals/fromLead/$leadId');
      await loadDeals();
      if (!isClosed) emit(const DealsActionSuccess('Deal created from lead'));
    } on DioException catch (e) {
      if (!isClosed) {
        emit(DealsError(_dioMsg(e, 'Failed to create deal from lead')));
      }
    }
  }

  // ── UPDATE ────────────────────────────────────────────────────

  /// PATCH /deals/update-deal/:id  (JSON — no files)
  /// NOTE: Does NOT emit DealsActionSuccess so deal_screen._save()
  /// can run follow-up + attachments before closing the modal.
  Future<void> updateDeal(String id, Map<String, dynamic> payload) async {
    if (isClosed) return;
    final prev = state;
    try {
      final res  = await _dio.patch('/deals/update-deal/$id', data: payload);
      final body = res.data;

      Map<String, dynamic>? dealMap;
      if (body is Map) {
        final m = Map<String, dynamic>.from(body);
        for (final k in ['deal', 'data', 'result']) {
          if (m[k] is Map) { dealMap = Map<String, dynamic>.from(m[k] as Map); break; }
        }
        dealMap ??= (m.containsKey('_id') ? m : null);
      }

      if (dealMap != null && prev is DealsLoaded && !isClosed) {
        final updated = Deal.fromJson(dealMap);
        emit(prev.copyWithDeals(
            prev.allDeals.map((d) => d.id == id ? updated : d).toList()));
      } else {
        await loadDeals();
      }
      // Intentionally no DealsActionSuccess — caller owns modal close.
    } on DioException catch (e) {
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
      if (!isClosed) { emit(prev); emit(DealsError(_dioMsg(e, 'Failed to update stage'))); }
    }
  }

  // ── FOLLOW-UP ─────────────────────────────────────────────────

  /// POST /deals/schedule-followup/:id
  Future<bool> scheduleFollowUp(
    String dealId, {
    required DateTime followUpDate,
    required String comment,
  }) async {
    try {
      await _dio.post(
        '/deals/schedule-followup/$dealId',
        data: {
          'followUpDate':    followUpDate.toUtc().toIso8601String(),
          'followUpComment': comment.trim(),
        },
      );
      debugPrint('[DealsCubit] follow-up scheduled for $dealId');
      return true;
    } catch (e) {
      debugPrint('[DealsCubit] scheduleFollowUp error: $e');
      return false;
    }
  }

  /// POST /deals/:id/complete-followup
  Future<void> completeFollowUp(String id) async {
    if (isClosed) return;
    try {
      await _dio.post('/deals/$id/complete-followup');
      await loadDeals();
      if (!isClosed) emit(const DealsActionSuccess('Follow-up completed'));
    } on DioException catch (e) {
      if (!isClosed) emit(DealsError(_dioMsg(e, 'Failed to complete follow-up')));
    }
  }

  // ── ATTACHMENTS ───────────────────────────────────────────────

  /// POST /deals/:id/attachments  (multipart)
  /// Used ONLY for edit flow — create flow sends files in createDeal().
  ///
  /// FIX: Content-Type NOT pre-set; interceptor skips it for FormData.
  Future<bool> uploadAttachments(String dealId, List<PlatformFile> files) async {
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

      debugPrint('[DealsCubit] uploadAttachments → dealId=$dealId files=${formData.files.length}');

      final res = await _dio.post('/deals/$dealId/attachments', data: formData);
      debugPrint('[DealsCubit] uploadAttachments response: ${res.statusCode}');
      return true;
    } on DioException catch (e) {
      debugPrint('[DealsCubit] uploadAttachments error: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('[DealsCubit] uploadAttachments error: $e');
      return false;
    }
  }

  // ── DELETE ────────────────────────────────────────────────────

  Future<void> deleteDeal(String id) async {
    if (isClosed || state is! DealsLoaded) return;
    final prev = state as DealsLoaded;
    emit(prev.copyWithDeals(prev.allDeals.where((d) => d.id != id).toList()));
    try {
      await _dio.delete('/deals/delete-deal/$id');
      if (!isClosed) emit(const DealsActionSuccess('Deal deleted'));
    } on DioException catch (e) {
      if (!isClosed) { emit(prev); emit(DealsError(_dioMsg(e, 'Failed to delete deal'))); }
    }
  }

  Future<void> bulkDeleteDeals(List<String> ids) async {
    if (isClosed || state is! DealsLoaded) return;
    final prev = state as DealsLoaded;
    final idSet = ids.toSet();
    emit(prev.copyWithDeals(prev.allDeals.where((d) => !idSet.contains(d.id)).toList()));
    try {
      await _dio.delete('/deals/bulk-delete', data: {'ids': ids});
      if (!isClosed) emit(DealsActionSuccess('${ids.length} deals deleted'));
    } on DioException catch (e) {
      if (!isClosed) { emit(prev); emit(DealsError(_dioMsg(e, 'Failed to bulk delete deals'))); }
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
      try { out.add(Deal.fromJson(item)); }
      catch (e) { debugPrint('[DealsCubit] skipping bad deal: $e'); }
    }
    return out;
  }

  List<Map<String, dynamic>> _toList(dynamic d) {
    try {
      List<dynamic> raw = [];
      if (d is List) {
        raw = d;
      } else if (d is Map) {
        for (final k in ['data', 'deals', 'result', 'results',
                          'items', 'users', 'lostDeals', 'pendingDeals']) {
          if (d[k] is List) { raw = d[k] as List; break; }
        }
      }
      return raw.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) { return []; }
  }

  String _dioMsg(DioException e, String fallback) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return data['message']?.toString() ??
               data['error']?.toString()   ?? fallback;
      }
    } catch (_) {}
    return e.message?.isNotEmpty == true ? e.message! : fallback;
  }

  List<Map<String, dynamic>> _scopeDealsForUser(
    List<Map<String, dynamic>> rows, {
    required bool canViewAll,
    required String userId,
    required String userName,
  }) {
    if (canViewAll) return List<Map<String, dynamic>>.from(rows);
    return rows
        .where((m) => _dealAssignedToUser(m, userId, userName))
        .toList();
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
      final id = assignRaw['_id']?.toString() ??
          assignRaw['id']?.toString() ??
          '';
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

    final topId = m['assignToId']?.toString() ??
        m['assignedToId']?.toString() ??
        '';
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