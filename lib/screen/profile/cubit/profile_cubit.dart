import 'dart:io';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileUser extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? profileImage;

  const ProfileUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.profileImage,
  });

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    if (combined.isNotEmpty) return combined;
    if (email.trim().isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }
    return 'User';
  }

  bool get isAdmin => role.toLowerCase().contains('admin');

  String? get imageUrl {
    return _resolveImageUrl(profileImage);
  }

  static String _s(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString().trim();

  factory ProfileUser.fromApiBody(dynamic body) {
    Map<String, dynamic> map = _extractUserMap(body);
    if (map['user'] is Map) {
      map = Map<String, dynamic>.from(map['user'] as Map);
    }

    var firstName = _s(map['firstName'] ?? map['first_name']);
    var lastName = _s(map['lastName'] ?? map['last_name']);
    if (firstName.isEmpty && lastName.isEmpty) {
      final full = _s(map['name'] ?? map['fullName']);
      if (full.isNotEmpty) {
        final parts = full.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
        if (parts.isNotEmpty) firstName = parts.first;
        if (parts.length > 1) lastName = parts.sublist(1).join(' ');
      }
    }

    final roleRaw = map['role'];
    final roleName = roleRaw is Map
        ? _s(roleRaw['name'] ?? roleRaw['roleName'] ?? roleRaw['_id'], 'User')
        : _s(roleRaw, 'User');

    return ProfileUser(
      id: _s(map['_id'] ?? map['id']),
      firstName: firstName,
      lastName: lastName,
      email: _s(map['email'], 'No email'),
      role: roleName.isEmpty ? 'User' : roleName,
      profileImage: _extractImagePath(map),
    );
  }

  static String _extractImagePath(Map<String, dynamic> map) {
    final raw = map['profileImage'] ?? map['avatarUrl'] ?? map['avatar'];
    if (raw is Map) {
      return _s(raw['url'] ?? raw['path'] ?? raw['location'] ??  raw['secure_url']);
    }
    return _s(raw);
  }

  static String? _resolveImageUrl(String? rawInput) {
    final raw = rawInput?.trim() ?? '';
    if (raw.isEmpty) return null;
 
    var path = raw.replaceAll('\\', '/');
 
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
 
    if (!path.contains('/')) {
      path = '/uploads/users/$path';
    }
 
    if (!path.startsWith('/')) {
      path = '/$path';
    }
 
    return 'https://sales.stagingzar.com$path';
  }

  static Map<String, dynamic> _extractUserMap(dynamic body) {
    if (body is! Map) return <String, dynamic>{};
    final root = Map<String, dynamic>.from(body);
    if (root['data'] is Map) return Map<String, dynamic>.from(root['data'] as Map);
    if (root['user'] is Map) return Map<String, dynamic>.from(root['user'] as Map);
    if (root['result'] is Map) return Map<String, dynamic>.from(root['result'] as Map);
    return root;
  }

  ProfileUser copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? role,
    String? profileImage,
  }) {
    return ProfileUser(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  @override
  List<Object?> get props => [id, firstName, lastName, email, role, profileImage];
}

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final ProfileUser user;
  final bool isUpdating;

  const ProfileLoaded(this.user, {this.isUpdating = false});

  ProfileLoaded copyWith({
    ProfileUser? user,
    bool? isUpdating,
  }) {
    return ProfileLoaded(
      user ?? this.user,
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }

  @override
  List<Object?> get props => [user, isUpdating];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProfileCubit extends Cubit<ProfileState> {
  static const _base = 'https://sales.stagingzar.com/api';
  late final Dio _dio;
  String? _token;

  ProfileCubit() : super(ProfileInitial()) {
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Content-Type': 'application/json'},
    ));
  }

  Future<void> _initToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> loadProfile() async {
    emit(ProfileLoading());
    try {
      await _initToken();
      final token = _token;
      if (token == null || token.isEmpty) {
        emit(const ProfileError('Session expired. Please login again.'));
        return;
      }

      final res = await _dio.get(
        '/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      var user = ProfileUser.fromApiBody(res.data);
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name')?.trim() ?? '';
      if (user.firstName.isEmpty && user.lastName.isEmpty && savedName.isNotEmpty) {
        final parts = savedName
            .split(RegExp(r'\s+'))
            .where((e) => e.isNotEmpty)
            .toList();
        user = user.copyWith(
          firstName: parts.isNotEmpty ? parts.first : user.firstName,
          lastName: parts.length > 1 ? parts.sublist(1).join(' ') : user.lastName,
        );
      }
      final savedImage = prefs.getString('profile_image')?.trim() ?? '';
      if ((user.profileImage ?? '').isEmpty && savedImage.isNotEmpty) {
        user = user.copyWith(profileImage: savedImage);
      }
      if (user.id.isNotEmpty) await prefs.setString('user_id', user.id);
      await prefs.setString('user_name', user.fullName);
      await prefs.setString('email', user.email);
      await prefs.setString('role', user.role);
      await prefs.setString('profile_image', user.profileImage ?? '');

      emit(ProfileLoaded(user));
    } on DioException catch (e) {
      emit(ProfileError(_mapDioError(e)));
    } catch (_) {
      emit(const ProfileError('Failed to load profile. Please try again.'));
    }
  }

  Future<void> refresh() async => loadProfile();

  Future<String?> updateProfile({
    required String firstName,
    required String lastName,
    String? imagePath,
  }) async {
    final cur = state;
    if (cur is! ProfileLoaded) return 'Profile is not ready.';

    final fName = firstName.trim();
    final lName = lastName.trim();
    if (fName.isEmpty || lName.isEmpty) {
      return 'First name and last name are required.';
    }

    try {
      emit(cur.copyWith(isUpdating: true));
      await _initToken();
      final token = _token;
      if (token == null || token.isEmpty) {
        emit(cur.copyWith(isUpdating: false));
        return 'Session expired. Please login again.';
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id')?.trim().isNotEmpty == true
          ? prefs.getString('user_id')!.trim()
          : cur.user.id;
      if (userId.isEmpty) {
        emit(cur.copyWith(isUpdating: false));
        return 'Unable to identify user id.';
      }

      final formMap = <String, dynamic>{
        'firstName': fName,
        'lastName': lName,
      };
      if (imagePath != null && imagePath.trim().isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          formMap['profileImage'] = await MultipartFile.fromFile(
            imagePath,
            filename: imagePath.split(Platform.pathSeparator).last,
          );
        }
      }

      await _dio.put(
        '/users/update-user/$userId',
        data: FormData.fromMap(formMap),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      await loadProfile();
      return null;
    } on DioException catch (e) {
      if (state is ProfileLoaded) {
        emit((state as ProfileLoaded).copyWith(isUpdating: false));
      }
      return _mapDioError(e);
    } catch (_) {
      if (state is ProfileLoaded) {
        emit((state as ProfileLoaded).copyWith(isUpdating: false));
      }
      return 'Failed to update profile. Please retry.';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.remove('permissions');
    await prefs.remove('profile_image');
  }

  String _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please retry.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    if (e.response?.statusCode == 401) {
      return 'Unauthorized. Please login again.';
    }
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString() ?? data['error']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return 'Unable to fetch profile right now.';
  }
}
