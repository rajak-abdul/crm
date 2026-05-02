// ══════════════════════════════════════════════════════════════
// 1️⃣  STATE
// ══════════════════════════════════════════════════════════════
import 'package:crm_app/database/local_db.dart';
import 'package:crm_app/modals/modals.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LeadState extends Equatable {
  const LeadState();
  @override
  List<Object?> get props => [];
}

class LeadInitial extends LeadState {}

class LeadLoading extends LeadState {}

class LeadLoaded extends LeadState {
  final List<Lead> leads;
  final List<AppUser> salesUsers;
  const LeadLoaded({required this.leads, this.salesUsers = const []});
  @override
  List<Object?> get props => [leads, salesUsers];
}

class LeadActionSuccess extends LeadLoaded {
  final String message;
  const LeadActionSuccess(
      {required super.leads, super.salesUsers, required this.message});
  @override
  List<Object?> get props => [leads, salesUsers, message];
}

class LeadError extends LeadState {
  final String message;
  const LeadError(this.message);
  @override
  List<Object?> get props => [message];
}

// Top-level function required by compute()
List<Map<String, dynamic>> _parseListIsolate(dynamic d) {
  List<dynamic> raw = [];
  if (d is List) {
    raw = d;
  } else if (d is Map) {
    for (final k in [
      'data', 'leads', 'users', 'salesUsers', 'staff',
      'employees', 'result', 'results', 'records', 'items'
    ]) {
      if (d[k] is List) {
        raw = d[k] as List;
        break;
      }
    }
    if (raw.isEmpty &&
        (d.containsKey('_id') || d.containsKey('id'))) {
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

// ══════════════════════════════════════════════════════════════
// 2️⃣  CUBIT
// ══════════════════════════════════════════════════════════════
class LeadCubit extends Cubit<LeadState> {
  static const _base = 'https://sales.stagingzar.com/api';

  late final Dio _dio;
  // ignore: unused_field
  final _db = LocalDb.instance;
  List<AppUser> _salesUsers = [];
  String? _cachedToken;

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
   _initToken();
  }

  Future<void> _initToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('token');
    } catch (_) {}
  }

  List<AppUser> get salesUsers => List.unmodifiable(_salesUsers);

  // ── 🌐 GET /leads/getAllLead ───────────────────────────────
  Future<void> fetchAllLeads(
      {int page = 1, int limit = 50, String? status}) async {
    if (isClosed) return;
    emit(LeadLoading());
    try {
      await _initToken();

final queryParams = <String, dynamic>{
  'page': page,
  'limit': limit,
  if (status != null && status != 'All Status') 'status': status,
};

// ✅ API CALL FIRST
final results = await Future.wait([
  _dio.get('/leads/getAllLead', queryParameters: queryParams),
  _dio.get('/users/sales').catchError((_) => Response(
        requestOptions: RequestOptions(path: '/users/sales'),
        data: [],
      )),
]);

final leadsRaw = results[0].data;
final usersRaw = results[1].data;

// ✅ PARSE DATA
final apiLeads = await compute(_parseListIsolate, leadsRaw)
    .then((list) => list.map((e) => Lead.fromJson(e)).toList());

final parsedUsers = _parseListIsolate(usersRaw);

final prefs = await SharedPreferences.getInstance();
final currentUserId = prefs.getString('user_id'); // save this at login

final filteredLeads = PermissionHelper.can('admin_access')
    ? apiLeads
    : apiLeads.where((l) =>
        l.assignedToId == currentUserId
      ).toList();
      _salesUsers = parsedUsers.map((e) {
        final m = Map<String, dynamic>.from(e);
        if (!m.containsKey('id') ||
            (m['id'] == null || m['id'].toString().isEmpty)) {
          m['id'] = m['_id']?.toString() ?? '';
        }
        if (!m.containsKey('fullName') ||
            m['fullName'] == null ||
            m['fullName'].toString().isEmpty) {
          final fn = m['firstName']?.toString() ?? '';
          final ln = m['lastName']?.toString() ?? '';
          final combined = '$fn $ln'.trim();
          m['fullName'] =
              combined.isNotEmpty ? combined : (m['name']?.toString() ?? '');
        }
        return AppUser.fromJson(m);
      }).where((u) => u.id.isNotEmpty).toList();

      if (isClosed) return;
      emit(LeadLoaded(leads: filteredLeads, salesUsers: _salesUsers));
    } on DioException catch (e) {
      if (isClosed) return;
      emit(LeadError(_dioMsg(e)));
    } catch (e) {
      if (isClosed) return;
      emit(LeadError(e.toString()));
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

  // ── 🌐 POST /leads/create ─────────────────────────────────
  // The API accepts multipart/form-data.
  // Attachments are sent as repeated 'attachments' entries:
  //   attachments: <file1>
  //   attachments: <file2>
  //   ...other fields as plain string values...
  Future<String?> createLead(Lead lead,
      {List<MultipartFile> attachments = const []}) async {
    try {
      final payload = _buildPayload(lead, attachments: attachments);
      debugPrint('=== CREATE LEAD PAYLOAD ===: $payload');
      final res = await _dio.post('/leads/create', data: payload);
      debugPrint('=== CREATE LEAD RESPONSE ===: ${res.data}');
      final saved = _extractLead(res.data) ?? lead;
      if (!isClosed) {
        final current = state is LeadLoaded
            ? (state as LeadLoaded).leads
            : <Lead>[];
        emit(LeadActionSuccess(
            leads: [saved, ...current],
            salesUsers: _salesUsers,
            message: 'Lead created ✓'));
      }
      return null;
    } on DioException catch (e) {
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
    List<String>? retainedAttachmentPaths,
  }) async {
    try {
      final res = await _dio.put('/leads/updateLead/$id',
          data: _buildPayload(
            lead,
            attachments: attachments,
            retainedAttachmentPaths: retainedAttachmentPaths,
          ));
      final updated = _extractLead(res.data) ?? lead.copyWith(id: id);
      if (!isClosed && state is LeadLoaded) {
        final newList = (state as LeadLoaded)
            .leads
            .map((l) => l.id == id ? updated : l)
            .toList();
        emit(LeadActionSuccess(
            leads: newList,
            salesUsers: _salesUsers,
            message: 'Lead updated ✓'));
      }
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to update lead: $e';
    }
  }

  // ── 🌐 DELETE /leads/deleteLead/:id ──────────────────────
  Future<String?> deleteLead(String id) async {
    try {
      await _dio.delete('/leads/deleteLead/$id');
      if (!isClosed && state is LeadLoaded) {
        final newList = (state as LeadLoaded)
            .leads
            .where((l) => l.id != id)
            .toList();
        emit(LeadActionSuccess(
            leads: newList,
            salesUsers: _salesUsers,
            message: 'Lead deleted'));
      }
      return null;
    } on DioException catch (e) {
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
        emit(LeadActionSuccess(
            leads: newList,
            salesUsers: _salesUsers,
            message: 'Status updated to $status'));
      }
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to update status: $e';
    }
  }

  // ── 🌐 PATCH /leads/:id/followup ─────────────────────────
  Future<String?> updateFollowUp(String id, DateTime date) async {
    try {
      await _dio.patch('/leads/$id/followup',
          data: {
            'followUpDate': DateFormat('yyyy-MM-dd').format(date)
          });
      if (!isClosed && state is LeadLoaded) {
        final newList = (state as LeadLoaded)
            .leads
            .map((l) =>
                l.id == id ? l.copyWith(followUpDate: date) : l)
            .toList();
        emit(LeadActionSuccess(
            leads: newList,
            salesUsers: _salesUsers,
            message: 'Follow-up date updated'));
      }
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to update follow-up: $e';
    }
  }

  // ── 🌐 PATCH /leads/:id/convert ──────────────────────────
  Future<String?> convertToDeal(
      String id, double dealValue, DateTime expectedCloseDate) async {
    try {
      await _dio.patch('/leads/$id/convert', data: {
        'dealValue': dealValue,
        'expectedCloseDate':
            DateFormat('yyyy-MM-dd').format(expectedCloseDate),
      });
      if (!isClosed && state is LeadLoaded) {
        final newList = (state as LeadLoaded)
            .leads
            .map((l) =>
                l.id == id ? l.copyWith(status: 'converted') : l)
            .toList();
        emit(LeadActionSuccess(
            leads: newList,
            salesUsers: _salesUsers,
            message: 'Lead converted to deal ✓'));
      }
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    } catch (e) {
      return 'Failed to convert lead: $e';
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Builds the request payload.
  ///
  /// • No attachments → returns a plain [Map] (Dio sends as JSON).
  /// • With attachments → returns [FormData] where each file is
  ///   added as a separate 'attachments' entry (key-value pair).
  ///   This matches the POST /leads/create multipart expectation.
  dynamic _buildPayload(
    Lead lead, {
    List<MultipartFile> attachments = const [],
    List<String>? retainedAttachmentPaths,
  }) {
    // Plain field map — uses the exact field names the API expects
    final map = <String, dynamic>{
      'leadName':    lead.name,
      'phoneNumber': lead.phone,
      'email':       lead.email,
      'companyName': lead.companyName,
      'address':     lead.address,
      'country':     lead.country,
      'industry':    lead.industry,
      'source':      lead.source,
      if (lead.clientType.isNotEmpty) 'clientType': lead.clientType,
      'requirement': lead.requirement,
      'status':      lead.status,
      'notes':       lead.notes,
      if (lead.assignTo.isNotEmpty) 'assignTo': lead.assignTo,
      if (lead.followUpDate != null)
        'followUpDate':
            DateFormat('yyyy-MM-dd').format(lead.followUpDate!),
      if (retainedAttachmentPaths != null)
        'retainedAttachmentPaths': retainedAttachmentPaths,
    };

    // If no files → plain JSON body
    if (attachments.isEmpty) return map;

    // With files → multipart/form-data
    // Each attachment is a separate MapEntry with the SAME key 'attachments'
    // so the server receives:  attachments: file1, attachments: file2, ...
    final fd = FormData.fromMap(map);
    for (final file in attachments) {
      fd.files.add(MapEntry('attachments', file));
    }
    return fd;
  }

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

  String _dioMsg(DioException e) {
    debugPrint(
        '=== DIO ERROR ===: type=${e.type} status=${e.response?.statusCode} body=${e.response?.data}');
    if (e.type == DioExceptionType.badResponse) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = (data['message'] ?? data['error'] ?? data['msg'])
            ?.toString();
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
}