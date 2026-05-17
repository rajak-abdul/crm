import 'package:crm_app/database/local_db.dart' show LocalDb;
import 'package:crm_app/modals/modals.dart' show AppUser, AppRole;
import 'package:crm_app/screen/userRole/cubit/user_role_state.dart';
import 'package:dio/dio.dart'
    show
        DioExceptionType,
        DioException,
        Dio,
        BaseOptions,
        InterceptorsWrapper,
        FormData,
        MultipartFile;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

class UserRoleCubit extends Cubit<UserRoleState> {
  static const _base = 'https://sales.stagingzar.com/api';

  late final Dio _dio;
  final _db = LocalDb.instance;

  UserRoleCubit() : super(UserRoleInitial()) {
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      // ↓ RIGHT HERE ↓
      onRequest: (opt, handler) async {
        final p = await SharedPreferences.getInstance();
        final t = p.getString('token');
        debugPrint('🔑 Token: $t'); // ← change to print()
        debugPrint('🌐 URL: ${opt.baseUrl}${opt.path}'); // ← change to print()
        if (t != null) opt.headers['Authorization'] = 'Bearer $t';
        handler.next(opt);
      },

      onError: (e, handler) {
        debugPrint('❌ ${e.response?.statusCode} → ${e.requestOptions.path}');
        debugPrint('❌ Response body: ${e.response?.data}');
        handler.next(e);
      },
    ));
  }

  UserRoleLoaded? get _loaded =>
      state is UserRoleLoaded ? state as UserRoleLoaded : null;

  // Local records must NEVER hit the API — their ids are not valid ObjectIds
  bool _isLocalId(String id) => id.startsWith('local_');

  Map<String, dynamic> _unwrap(dynamic raw, List<String> keys) {
    if (raw is Map<String, dynamic>) {
      for (final k in keys) {
        if (raw[k] is Map) return Map<String, dynamic>.from(raw[k] as Map);
      }
      if (raw['_id'] != null || raw['id'] != null) return raw;
    }
    return {};
  }

  // ── 🌐 LOAD ALL ────────────────────────────────────────────
  Future<void> loadAll() async {
    // Step 1: show cached data immediately (never block on network)
    final cachedUsers = await _db.getAllCachedUsers();
    final cachedRoles = await _db.getLocalRoles();

    if (cachedUsers.isNotEmpty || cachedRoles.isNotEmpty) {
      emit(UserRoleLoaded(
        users: cachedUsers,
        salesUsers: cachedUsers.where((u) => u.role != 'admin').toList(),
        roles: cachedRoles,
      ));
    } else {
      emit(UserRoleLoading());
    }

    // Step 2: try API in background — silently update if online
    try {
      final results = await Future.wait([
        _dio.get('/users'),
        _dio.get('/users/sales'),
        _dio.get('/roles'),
      ]);

      final apiUsers = _toList(results[0].data).map(AppUser.fromJson).toList();
      final apiSales = _toList(results[1].data).map(AppUser.fromJson).toList();
      final apiRoles = _toList(results[2].data).map(AppRole.fromJson).toList();

      // Persist to SQLite so next cold-start has fresh data
      for (final u in apiUsers) await _db.upsertUserFromApi(u);
      for (final r in apiRoles) await _db.upsertRoleFromApi(r);

      final localUsers = await _db.getAllCachedUsers();
      final localRoles = await _db.getLocalRoles();
      final apiUserIds = apiUsers.map((u) => u.id).toSet();
      final apiRoleIds = apiRoles.map((r) => r.id).toSet();

      emit(UserRoleLoaded(
        users: [
          ...apiUsers,
          ...localUsers.where((u) => !apiUserIds.contains(u.id)),
        ],
        salesUsers: apiSales,
        roles: [
          ...apiRoles,
          ...localRoles.where((r) => !apiRoleIds.contains(r.id)),
        ],
      ));
    } on DioException catch (e) {
      // Network failed — keep showing whatever cache we already emitted
      // Only emit error if we had nothing cached to show
      if (state is UserRoleLoading) {
        emit(UserRoleError(_dioMsg(e)));
      }
      // else: silently keep the cached state visible
    }
  }

  // ── 🌐 CREATE USER  POST /users/create ─────────────────────
  Future<String?> createUser(
    AppUser user, {
    String? password,
    String? imagePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'firstName': user.firstName,
        'lastName': user.lastName,
        'email': user.email,
        'password': password ?? '',
        'mobileNumber': user.phone, // ✅ FIX: API field is 'mobileNumber'
        'role': user.role,
        'status': user.status,
        'gender': user.gender,
        'dateOfBirth': user.dob?.toIso8601String(),
        'address': user.address,
        if (imagePath != null)
          'profileImage': await MultipartFile.fromFile(imagePath),
      });

      final res = await _dio.post('/users/create', data: formData);
      final newUser =
          AppUser.fromJson(_unwrap(res.data, ['user', 'data', 'result']));

      final cur = _loaded;
      if (cur != null) {
        emit(UserRoleActionSuccess(
          users: [newUser, ...cur.users],
          roles: cur.roles,
          salesUsers: cur.salesUsers,
          message: 'User created successfully ✅',
        ));
      }
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        try {
          final localUser = await _db.insertUser(user);
          final cur = _loaded;
          if (cur != null) {
            emit(UserRoleActionSuccess(
              users: [localUser, ...cur.users],
              roles: cur.roles,
              salesUsers: cur.salesUsers,
              message: 'Saved locally (offline) 💾',
            ));
          }
          return null;
        } catch (_) {
          return 'Failed to save locally: ${_dioMsg(e)}';
        }
      }
      return _extractMsg(e) ?? _dioMsg(e);
    } catch (e) {
      return 'Failed to create user: $e';
    }
  }

  // ── 🌐 UPDATE USER  PUT /users/update-user/:id ─────────────
  Future<String?> updateUser(
    String id,
    AppUser user, {
    String? imagePath,
  }) async {
    // Local-only record — skip API, just update SQLite
    if (_isLocalId(id)) {
      try {
        final localUser = await _db.updateUser(id, user);
        final cur = _loaded;
        if (cur != null) {
          emit(UserRoleActionSuccess(
            users: cur.users.map((u) => u.id == id ? localUser : u).toList(),
            roles: cur.roles,
            salesUsers: cur.salesUsers,
            message: 'Local record updated 💾',
          ));
        }
        return null;
      } catch (e) {
        return 'Failed to update local record: $e';
      }
    }

    try {
      final formData = FormData.fromMap({
        'firstName': user.firstName,
        'lastName': user.lastName,
        'email': user.email,
        'mobileNumber': user.phone, // ✅ FIX: API field is 'mobileNumber'
        'role': user.role,
        'status': user.status,
        'gender': user.gender,
        'dateOfBirth': user.dob?.toIso8601String(),
        'address': user.address,
        if (imagePath != null)
          'profileImage': await MultipartFile.fromFile(imagePath),
      });

      final res = await _dio.put('/users/update-user/$id', data: formData);
      final updatedUser =
          AppUser.fromJson(_unwrap(res.data, ['user', 'data', 'result']));

      final cur = _loaded;
      if (cur != null) {
        emit(UserRoleActionSuccess(
          users: cur.users.map((u) => u.id == id ? updatedUser : u).toList(),
          roles: cur.roles,
          salesUsers: cur.salesUsers,
          message: 'User updated successfully ✏️',
        ));
      }
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        try {
          final localUser = await _db.updateUser(id, user);
          final cur = _loaded;
          if (cur != null) {
            emit(UserRoleActionSuccess(
              users: cur.users.map((u) => u.id == id ? localUser : u).toList(),
              roles: cur.roles,
              salesUsers: cur.salesUsers,
              message: 'Updated locally (offline) 💾',
            ));
          }
          return null;
        } catch (_) {
          return 'Failed to save locally: ${_dioMsg(e)}';
        }
      }
      return _extractMsg(e) ?? _dioMsg(e);
    } catch (e) {
      return 'Failed to update user: $e';
    }
  }

  // ── 🌐 DELETE USER  DELETE /users/delete-user/:id ──────────
  Future<String?> deleteUser(String id) async {
    try {
      // Local records must NOT hit the API — id is not a valid ObjectId
      if (!_isLocalId(id)) {
        try {
          await _dio.delete('/users/delete-user/$id');
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
        }
      }

      await _db.deleteUser(id);

      final cur = _loaded;
      if (cur != null) {
        emit(UserRoleActionSuccess(
          users: cur.users.where((u) => u.id != id).toList(),
          roles: cur.roles,
          salesUsers: cur.salesUsers,
          message: 'User deleted 🗑️',
        ));
      }
      return null;
    } on DioException catch (e) {
      return _extractMsg(e) ?? _dioMsg(e);
    } catch (e) {
      return 'Failed to delete user: $e';
    }
  }

  // ── 🌐 CREATE ROLE  POST /roles ────────────────────────────
  Future<String?> createRole(AppRole role) async {
    try {
      final res = await _dio.post('/roles', data: {
        'name': role.name,
        'permissions': _buildPermissions(role.permissions),
      });

      final newRole =
          AppRole.fromJson(_unwrap(res.data, ['role', 'data', 'result']));

      final cur = _loaded;
      if (cur != null) {
        emit(UserRoleActionSuccess(
          users: cur.users,
          roles: [...cur.roles, newRole],
          salesUsers: cur.salesUsers,
          message: 'Role created successfully ✅',
        ));
      }
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        try {
          final localRole = await _db.insertRole(role);
          final cur = _loaded;
          if (cur != null) {
            emit(UserRoleActionSuccess(
              users: cur.users,
              roles: [...cur.roles, localRole],
              salesUsers: cur.salesUsers,
              message: 'Role saved locally (offline) 💾',
            ));
          }
          return null;
        } catch (_) {
          return 'Failed to save locally: ${_dioMsg(e)}';
        }
      }
      return _extractMsg(e) ?? _dioMsg(e);
    } catch (e) {
      return 'Failed to create role: $e';
    }
  }

  // ── 🌐 UPDATE ROLE  PUT /roles/:id ─────────────────────────
  Future<String?> updateRole(String id, AppRole role) async {
    if (_isLocalId(id)) {
      final cur = _loaded;
      if (cur != null) {
        emit(UserRoleActionSuccess(
          users: cur.users,
          roles: cur.roles
              .map((r) => r.id == id
                  ? AppRole(
                      id: id,
                      name: role.name,
                      permissions: role.permissions,
                      isLocal: true)
                  : r)
              .toList(),
          salesUsers: cur.salesUsers,
          message: 'Local role updated 💾',
        ));
      }
      return null;
    }

    try {
      final res = await _dio.put('/roles/$id', data: {
        'name': role.name,
        'permissions': _buildPermissions(role.permissions),
      });

      final updatedRole =
          AppRole.fromJson(_unwrap(res.data, ['role', 'data', 'result']));

      final cur = _loaded;
      if (cur != null) {
        emit(UserRoleActionSuccess(
          users: cur.users,
          roles: cur.roles.map((r) => r.id == id ? updatedRole : r).toList(),
          salesUsers: cur.salesUsers,
          message: 'Role updated successfully ✏️',
        ));
      }
      return null;
    } on DioException catch (e) {
      return _extractMsg(e) ?? _dioMsg(e);
    } catch (e) {
      return 'Failed to update role: $e';
    }
  }

  // ── 🌐 DELETE ROLE  DELETE /roles/:id ──────────────────────
  Future<String?> deleteRole(String id) async {
    try {
      if (!_isLocalId(id)) {
        try {
          await _dio.delete('/roles/$id');
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
        }
      }

      await _db.deleteRole(id);

      final cur = _loaded;
      if (cur != null) {
        emit(UserRoleActionSuccess(
          users: cur.users,
          roles: cur.roles.where((r) => r.id != id).toList(),
          salesUsers: cur.salesUsers,
          message: 'Role deleted 🗑️',
        ));
      }
      return null;
    } on DioException catch (e) {
      return _extractMsg(e) ?? _dioMsg(e);
    } catch (e) {
      return 'Failed to delete role: $e';
    }
  }

  // ── HELPERS ────────────────────────────────────────────────

  String? _extractMsg(DioException e) {
    final body = e.response?.data;
    if (body == null) return null;
    if (body is Map) {
      if (body['message'] is String) return body['message'] as String;
      if (body['error'] is String) return body['error'] as String;
      if (body['errors'] is List) {
        final list = body['errors'] as List;
        if (list.isNotEmpty) return list.first.toString();
      }
    }
    if (body is String && body.isNotEmpty) return body;
    return null;
  }

  Map<String, bool> _buildPermissions(List<String> selected) {
    String normalize(String s) => s
        .toLowerCase()
        .replaceAll('&', '')
        .replaceAll('  ', ' ')
        .replaceAll(' ', '_')
        .replaceAll('__', '_');

    final normalizedSelected = selected.map(normalize).toSet();

    const allPerms = [
      'dashboard',
      'leads',
      'deals_all',
      'deals_pipeline',
      'invoices',
      'proposal',
      'activities',
      'activities_calendar',
      'activities_list',
      'users_roles',
      'admin_access',
      'email_chat',
      'whatsapp_chat',
      'reports',
    ];

    return {for (final p in allPerms) p: normalizedSelected.contains(p)};
  }

  List<Map<String, dynamic>> _toList(dynamic d) {
    List<dynamic> raw = [];
    if (d is List) {
      raw = d;
    } else if (d is Map) {
      for (final k in ['data', 'users', 'roles', 'result']) {
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
  }

  String _dioMsg(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout =>
          'Connection timed out.',
        DioExceptionType.connectionError => 'No internet connection.',
        DioExceptionType.badResponse =>
          'Server error (${e.response?.statusCode}).',
        _ => 'Something went wrong.',
      };
}
