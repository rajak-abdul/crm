import 'package:crm_app/database/local_db.dart';
import 'package:crm_app/screen/login/cubit/location_api.dart';
import 'package:crm_app/services/device_service.dart';
import 'package:crm_app/services/location_service.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:dio/dio.dart'
    show DioExceptionType, DioException, Dio, BaseOptions;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

import '../ui/login_screen.dart';

class ForgotPasswordResult {
  final bool success;
  final String message;

  const ForgotPasswordResult({
    required this.success,
    required this.message,
  });
}

class LoginCubit extends Cubit<LoginState> {
  static const _base = 'https://crm-backend-api.techzarinfo.cloud/api';

  late final Dio _dio;
  
  LoginCubit() : super(LoginIdle()) {
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Map<String, dynamic> _extractUserMap(dynamic body) {
    if (body is! Map) return <String, dynamic>{};
    final root = Map<String, dynamic>.from(body);
    if (root['data'] is Map) {
      final data = Map<String, dynamic>.from(root['data'] as Map);
      if (data['user'] is Map) {
        return Map<String, dynamic>.from(data['user'] as Map);
      }
      return data;
    }
    if (root['user'] is Map) {
      return Map<String, dynamic>.from(root['user'] as Map);
    }
    return root;
  }

  String _extractImagePath(Map<String, dynamic> map) {
    final raw = map['profileImage'] ?? map['avatarUrl'] ?? map['avatar'];
    if (raw is Map) {
      return (raw['url'] ??
              raw['path'] ??
              raw['location'] ??
              raw['secure_url'] ??
              '')
          .toString()
          .trim();
    }
    return (raw ?? '').toString().trim();
  }

  // ── POST /api/auth/login ──────────────────────────────────
  Future<void> login(String email, String password, String tenantSlug) async {
    if (email.trim().isEmpty) {
      emit(const LoginError('Email is required'));
      return;
    }
    if (password.isEmpty) {
      emit(const LoginError('Password is required'));
      return;
    }
    if (tenantSlug.trim().isEmpty) {
      emit(const LoginError('Tenant slug is required'));
      return;
    }

    emit(LoginLoading());
    try {
      final deviceId = await DeviceService.getDeviceId();
      final deviceLabel = await DeviceService.getDeviceLabel();
      
      final res = await _dio.post(
        '/users/login',
        data: {
  'email': email.trim(),
  'password': password,
  'tenantSlug': tenantSlug.trim(),
  'deviceType': 'mobile',
  'deviceId': deviceId,
  'deviceLabel': deviceLabel,
},
      );
debugPrint("Device Type : mobile");
debugPrint("Device ID: $deviceId");
debugPrint("Device Label: $deviceLabel");
      debugPrint('[LoginCubit] full body: ${res.data}');

      final body = res.data;
      final userMap =
          _extractUserMap(body); // falls back to root map, still works

      // ✅ token is at root now
      String? token;
      if (body is Map) {
        token = body['token'] as String?;
      }

      // Handle backend business errors first
if (body is Map && body['success'] == false) {
  emit(
    LoginError(
      body['message']?.toString() ?? 'Login failed',
    ),
  );
  return;
}

// Extract token only after confirming success
if (body is Map) {
  token = body['token'] as String?;
}

if (token == null || token.isEmpty) {
  emit(
    const LoginError(
      'Login failed: no token received from server.',
    ),
  );
  return;
}

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      // ✅ NEW: persist tenant slug for building tenant-scoped API calls later
      await prefs.setString('tenant_slug', tenantSlug.trim());

      await prefs.setString('device_id', deviceId);
await prefs.setString('device_label', deviceLabel);

      // ✅ role + permissions — role is at root now, not nested under data
      Map<String, dynamic>? role;
      Map<String, dynamic>? permissions;
      if (body is Map) {
        role = body['role'] as Map<String, dynamic>?;
        permissions = role?['permissions'] as Map<String, dynamic>?;
      }

      if (role != null && role['name'] != null) {
        await prefs.setString('role', role['name']);
      }

      if (permissions != null) {
        final allowedPermissions = permissions.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toList();
        await prefs.setStringList('permissions', allowedPermissions);
      }

      await PermissionHelper.load();

      // ✅ user id — at root now
      String? userId;
      if (body is Map) {
        userId = body['_id']?.toString() ?? body['id']?.toString();
      }
      if (userId != null && userId.isNotEmpty) {
        await prefs.setString('user_id', userId);
      }

      // ✅ name/email — root has "name" directly, not firstName/lastName
      String userName =
          (userMap['name'] ?? userMap['fullName'] ?? '').toString().trim();
      String userEmail = (userMap['email'] ?? '').toString().trim();
      String profileImage = _extractImagePath(userMap);

      if (userName.isNotEmpty) {
        await prefs.setString('user_name', userName);
      }
      if (userEmail.isNotEmpty) {
        await prefs.setString('email', userEmail);
      }
      if (profileImage.isNotEmpty) {
        await prefs.setString('profileImage', profileImage);
        await prefs.setString('profile_image', profileImage);
      }
      await LocalDb.instance.clearAll();
      debugPrint("Before updateLocation");
final hasPermission = await LocationService.requestPermission();

      if (!hasPermission) {
  emit(
    const LoginError(
      "Location permission is required to use this application.",
    ),
  );
  return;
}

await LocationApiService.startLiveLocation();

debugPrint("After updateLocation");


      emit(LoginSuccess());
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = 'Login failed';

      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        msg = 'Invalid email, password, or tenant slug';
      } else if (body is Map) {
        msg = body['message'] as String? ?? body['error'] as String? ?? msg;
      } else {
        msg = switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout =>
            'Connection timed out',
          DioExceptionType.connectionError => 'No internet connection',
          _ => 'Server error (${e.response?.statusCode})',
        };
      }
      emit(LoginError(msg));
    } catch (e) {
      emit(LoginError(e.toString()));
    }
  }

  Future<ForgotPasswordResult> requestPasswordReset(
  String email,
  String tenantSlug,
) async {
  final cleanEmail = email.trim();
  final cleanTenantSlug = tenantSlug.trim();

  if (cleanTenantSlug.isEmpty) {
    return const ForgotPasswordResult(
      success: false,
      message: 'Tenant slug is required',
    );
  }

  if (cleanEmail.isEmpty) {
    return const ForgotPasswordResult(
      success: false,
      message: 'Email is required',
    );
  }

  try {
    final response = await _dio.post(
      'https://crm-backend-api.techzarinfo.cloud/'
      '$cleanTenantSlug/api/users/forgot-password',
      data: {
        'email': cleanEmail,
      },
    );

    final body = response.data;

    if (body is Map) {
      return ForgotPasswordResult(
        success: body['success'] == true,
        message: body['message']?.toString() ??
            'Failed to send reset link',
      );
    }

    return const ForgotPasswordResult(
      success: false,
      message: 'Invalid response from server',
    );
  } on DioException catch (e) {
    final body = e.response?.data;

    if (body is Map) {
      return ForgotPasswordResult(
        success: false,
        message: body['message']?.toString() ??
            body['error']?.toString() ??
            'Failed to send reset link',
      );
    }

    return const ForgotPasswordResult(
      success: false,
      message: 'Failed to send reset link',
    );
  } catch (e) {
    return const ForgotPasswordResult(
      success: false,
      message: 'Failed to send reset link',
    );
  }
}

  /// POST /users/forgot-password/:token
  Future<String?> resetPasswordWithToken({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return 'Reset token is required';
    if (newPassword.isEmpty) return 'New password is required';
    if (newPassword != confirmPassword) {
      return 'Passwords do not match';
    }

    try {
      await _dio.post(
        '/users/forgot-password/$cleanToken',
        data: {
          // Keep multiple common keys for backend compatibility.
          'password': newPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
      return null;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) {
        return (body['message'] as String?) ??
            (body['error'] as String?) ??
            'Failed to reset password';
      }
      return 'Failed to reset password';
    } catch (_) {
      return 'Failed to reset password';
    }
  }

  /// Clear saved token (logout)
  Future<void> logout() async {
      await LocationApiService.stopLiveLocation();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('permissions'); // ✅ ADD
    await prefs.remove('user_name');
    await prefs.remove('email');
    await prefs.remove('profileImage');
    await prefs.remove('tenant_slug'); // ✅ NEW — clear tenant slug too

    await LocalDb.instance.clearAll();
    PermissionHelper.clear(); // ✅ ADD// ✅ ADD

    emit(LoginIdle());
  }
}