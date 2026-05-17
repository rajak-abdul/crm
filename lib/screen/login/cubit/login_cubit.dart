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
  static const _base = 'https://sales.stagingzar.com/api';

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
  Future<void> login(String email, String password) async {
    if (email.trim().isEmpty) {
      emit(const LoginError('Email is required'));
      return;
    }
    if (password.isEmpty) {
      emit(const LoginError('Password is required'));
      return;
    }

    emit(LoginLoading());
    try {
      final res = await _dio.post(
        '/users/login',
        data: {'email': email.trim(), 'password': password},
      );

      // ── Extract token from response ──────────────────────
      // Handles common shapes:
      //   { "token": "..." }
      //   { "data": { "token": "..." } }
      //   { "accessToken": "..." }
      //   { "data": { "accessToken": "..." } }
      debugPrint('[LoginCubit] full body: ${res.data}');

      final body = res.data;
      final userMap = _extractUserMap(body);
      String? token;

      if (body is Map) {
        token = body['token'] as String? ??
            body['accessToken'] as String? ??
            body['access_token'] as String? ??
            (body['data'] is Map
                ? (body['data']['token'] as String? ??
                    body['data']['accessToken'] as String? ??
                    body['data']['access_token'] as String?)
                : null);
      }

      if (token == null || token.isEmpty) {
        emit(const LoginError('Login failed: no token in response'));
        return;
      }

      // Save token for all future API calls
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      // ✅ Extract role + permissions
      Map<String, dynamic>? role;
      Map<String, dynamic>? permissions;

      if (body is Map) {
        role = body['role'] as Map<String, dynamic>? ??
            (body['data'] is Map
                ? (body['data']['role'] as Map<String, dynamic>?)
                : null) ??
            (userMap['role'] is Map
                ? Map<String, dynamic>.from(userMap['role'] as Map)
                : null);
        permissions = role?['permissions'] as Map<String, dynamic>?;
      }

// ✅ Save role name
      if (role != null && role['name'] != null) {
        await prefs.setString('role', role['name']);
      }

// ✅ Convert permissions map → list
      if (permissions != null) {
        final allowedPermissions = permissions.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toList();

        await prefs.setStringList('permissions', allowedPermissions);
      }

// ✅ ALWAYS LOAD (important)
      await PermissionHelper.load();

// ADD: save user_id from login response
// ADD: save user_id from login response
      String? userId;
      if (body is Map) {
        userId = userMap['_id']?.toString() // ← check userMap FIRST
            ??
            userMap['id']?.toString() ??
            body['_id']?.toString() ??
            body['id']?.toString() ??
            body['userId']?.toString() ??
            (body['data'] is Map
                ? (body['data']['_id']?.toString() ??
                    body['data']['id']?.toString() ??
                    body['data']['userId']?.toString())
                : null);
      }
      if (userId != null && userId.isNotEmpty) {
        await prefs.setString('user_id', userId);
      }
      String userName = '';
      String userEmail = '';
      String profileImage = '';

      final firstName = (userMap['firstName'] ?? userMap['first_name'] ?? '')
          .toString()
          .trim();
      final lastName =
          (userMap['lastName'] ?? userMap['last_name'] ?? '').toString().trim();
      final combinedName = '$firstName $lastName'.trim();

      userName = combinedName.isNotEmpty
          ? combinedName
          : (userMap['name'] ?? userMap['fullName'] ?? '').toString().trim();
      userEmail = (userMap['email'] ?? '').toString().trim();
      profileImage = _extractImagePath(userMap);

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

      emit(LoginSuccess());
      debugPrint('[LoginCubit] full response body: $body');
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = 'Login failed';

      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        msg = 'Invalid email or password';
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

  /// POST /users/forgot-password
  Future<ForgotPasswordResult> requestPasswordReset(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      return const ForgotPasswordResult(
        success: false,
        message: 'Email is required',
      );
    }

    try {
      final res = await _dio.post(
        '/users/forgot-password',
        data: {'email': cleanEmail},
      );

      final body = res.data;
      if (body is Map) {
        final success = body['success'];
        final message = body['message'] as String?;

        if (success == false) {
          return ForgotPasswordResult(
            success: false,
            message: message ?? 'Failed to send reset link',
          );
        }

        return ForgotPasswordResult(
          success: true,
          message: message ?? 'Reset link sent successfully',
        );
      }
      return const ForgotPasswordResult(
        success: true,
        message: 'Reset link sent successfully',
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) {
        return ForgotPasswordResult(
          success: false,
          message: (body['message'] as String?) ??
              (body['error'] as String?) ??
              'Failed to send reset link',
        );
      }
      return const ForgotPasswordResult(
        success: false,
        message: 'Failed to send reset link',
      );
    } catch (_) {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('permissions'); // ✅ ADD
    await prefs.remove('user_name');
    await prefs.remove('email');
    await prefs.remove('profileImage');

    PermissionHelper.clear(); // ✅ ADD// ✅ ADD

    emit(LoginIdle());
  }
}
