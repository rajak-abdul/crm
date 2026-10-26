// ══════════════════════════════════════════════════════════════
// CUBIT
// ══════════════════════════════════════════════════════════════
import 'package:crm_app/screen/notification/cubit/notification_state.dart';
import 'package:crm_app/screen/notification/model/notification_model.dart' show AppNotification;
import 'package:crm_app/services/auth_interceptor.dart' show AuthInterceptor;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

class NotificationCubit extends Cubit<NotificationState> {
  static const _base = 'https://crm-backend-api.techzarinfo.cloud/api';

  Dio? _dio;
  String? _cachedToken;
  String? _currentUserId;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  DateTime? _lastLoadTime;
  static const _minLoadInterval = Duration(seconds: 2);

  NotificationCubit() : super(NotificationInitial()) {
    _initDio();
  }

  Future<void> _initDio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('token');
      _currentUserId = prefs.getString('user_id');

      debugPrint(
          '[NotifCubit] token=${_cachedToken != null ? "found" : "NULL"}');
      debugPrint('[NotifCubit] user_id=$_currentUserId');

      final dio = Dio(BaseOptions(
        baseUrl: _base,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ));

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (opt, handler) {
          if (_cachedToken != null) {
            opt.headers['Authorization'] = 'Bearer $_cachedToken';
          }
          handler.next(opt);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            emit(const NotificationError(
                'Session expired. Please login again.'));
          }
          handler.next(error);
        },
      ));
      dio.interceptors.add(AuthInterceptor());

      _dio = dio;

      // ✅ If user_id missing but token exists, fetch profile to get userId
      if ((_currentUserId == null || _currentUserId!.isEmpty) &&
          _cachedToken != null) {
        try {
          final res = await dio.get('/users/profile');
          debugPrint('[NotifCubit] profile response: ${res.data}');
          final body = res.data;
          String? fetchedId;
          if (body is Map) {
            fetchedId = body['_id'] as String? ??
                body['id'] as String? ??
                body['userId'] as String? ??
                (body['data'] is Map
                    ? (body['data']['_id'] as String? ??
                        body['data']['id'] as String?)
                    : null);
          }
          if (fetchedId != null && fetchedId.isNotEmpty) {
            _currentUserId = fetchedId;
            await prefs.setString('user_id', fetchedId); // save for next time
            debugPrint('[NotifCubit] fetched user_id: $_currentUserId');
          }
        } catch (e) {
          debugPrint('[NotifCubit] failed to fetch profile: $e');
        }
      }

      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        await load(_currentUserId!, refresh: true);
      }
    } catch (e) {
      debugPrint('[NotifCubit] _initDio error: $e');
      emit(NotificationError('Failed to initialize: $e'));
    }
  }

  NotificationLoaded? get _loaded =>
      state is NotificationLoaded ? state as NotificationLoaded : null;

  // ── Called from dashboard after login ──────────────────────
  // Pass userId directly — no need to re-read from prefs.
  Future<void> load(String userId,
      {bool refresh = false, bool silent = false}) async {
    if (userId.isEmpty) {
      emit(const NotificationError('User ID is required'));
      return;
    }

    // Wait for _dio to be ready (edge case: called before _initDio finishes)
    if (_dio == null) {
      debugPrint('[NotifCubit] _dio not ready, retrying in 500ms…');
      await Future.delayed(const Duration(milliseconds: 500));
      if (_dio == null) {
        emit(const NotificationError('Not ready yet. Please try again.'));
        return;
      }
    }

    _currentUserId = userId;

    // Debounce non-refresh calls
    if (!refresh && _lastLoadTime != null) {
      final elapsed = DateTime.now().difference(_lastLoadTime!);
      if (elapsed < _minLoadInterval) return;
    }
    _lastLoadTime = DateTime.now();

    if (_isLoadingMore) return;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      if (!silent) emit(NotificationLoading());
    } else if (state is NotificationInitial) {
      emit(NotificationLoading());
    }

    _isLoadingMore = true;

    try {
      debugPrint('[NotifCubit] GET /notifications/$userId?page=$_currentPage');

      final res = await _dio!.get(
        '/notifications/$userId',
        queryParameters: {'page': _currentPage, 'limit': 20},
      );

      debugPrint('[NotifCubit] response type: ${res.data.runtimeType}');

      final newNotifications = _parse(res.data);
      debugPrint(
          '[NotifCubit] parsed ${newNotifications.length} notifications');

      _hasMore = newNotifications.length == 20;

      List<AppNotification> allNotifications;
      if (refresh || _currentPage == 1) {
        allNotifications = newNotifications;
      } else {
        final current = _loaded?.notifications ?? [];
        allNotifications = [...current, ...newNotifications];
      }

      if (refresh) {
        _currentPage = 2;
      } else if (_hasMore) {
        _currentPage++;
      }

      final unread = allNotifications.where((n) => !n.read).length;

      emit(NotificationLoaded(
        notifications: allNotifications,
        unreadCount: unread,
        hasMore: _hasMore,
        currentPage: _currentPage,
      ));
    } on DioException catch (e) {
      debugPrint(
          '[NotifCubit] DioException: ${e.type} ${e.response?.statusCode}');
      if (!refresh && _currentPage > 1) {
        // Pagination failure — keep existing list silently
      } else {
        emit(NotificationError(_dioMsg(e)));
      }
    } catch (e) {
      debugPrint('[NotifCubit] error: $e');
      emit(NotificationError(e.toString()));
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> loadMore() async {
    if (_loaded == null) return;
    if (!_hasMore || _isLoadingMore) return;
    if (_currentUserId == null) return;
    await load(_currentUserId!);
  }

  // ✅ Safer refresh()
  Future<void> refresh({String? userId, bool silent = false}) async {
    final id = userId ?? _currentUserId;
    if (id == null || id.isEmpty) {
      debugPrint('[NotifCubit] refresh() called but no userId available');
      return;
    }
    _currentUserId = id;
    await load(id, refresh: true, silent: silent);
  }

  Future<void> markAsRead(String notifId) async {
    if (_dio == null) return;
    final cur = _loaded;
    if (cur == null) return;

    final notif = cur.notifications.cast<AppNotification?>().firstWhere(
          (n) => n?.id == notifId,
          orElse: () => null,
        );
    if (notif == null || notif.read) return;

    // Optimistic update
    final updated = cur.notifications
        .map((n) => n.id == notifId ? n.copyWith(read: true) : n)
        .toList();
    emit(NotificationLoaded(
      notifications: updated,
      unreadCount: updated.where((n) => !n.read).length,
      hasMore: cur.hasMore,
      currentPage: cur.currentPage,
    ));

    try {
      await _dio!.patch('/notifications/read/$notifId');
    } catch (_) {
      emit(cur); // revert
    }
  }

  Future<void> markAllAsRead(String userId) async {
    if (_dio == null) return;
    final cur = _loaded;
    if (cur == null) return;

    final unreadIds =
        cur.notifications.where((n) => !n.read).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    final originalState = cur;

    final updated =
        cur.notifications.map((n) => n.copyWith(read: true)).toList();
    emit(NotificationLoaded(
      notifications: updated,
      unreadCount: 0,
      hasMore: cur.hasMore,
      currentPage: cur.currentPage,
    ));

    try {
      const batchSize = 10;
      for (var i = 0; i < unreadIds.length; i += batchSize) {
        final batch = unreadIds.skip(i).take(batchSize);
        await Future.wait(
          batch.map((id) => _dio!.patch('/notifications/read/$id')),
        );
      }
    } catch (_) {
      emit(originalState); // revert
    }
  }

  Future<void> delete(String notifId) async {
    if (_dio == null) return;
    final cur = _loaded;
    if (cur == null) return;

    final originalState = cur;
    final updated = cur.notifications.where((n) => n.id != notifId).toList();
    emit(NotificationLoaded(
      notifications: updated,
      unreadCount: updated.where((n) => !n.read).length,
      hasMore: cur.hasMore,
      currentPage: cur.currentPage,
    ));

    try {
      await _dio!.delete('/notifications/$notifId');
    } catch (_) {
      emit(originalState);
    }
  }

  Future<bool> bulkDelete(List<String> ids) async {
    if (_dio == null) return false;
    final cur = _loaded;
    if (cur == null || ids.isEmpty) return false;

    final originalState = cur;
    final updated =
        cur.notifications.where((n) => !ids.contains(n.id)).toList();
    emit(NotificationLoaded(
      notifications: updated,
      unreadCount: updated.where((n) => !n.read).length,
      hasMore: cur.hasMore,
      currentPage: cur.currentPage,
    ));

    try {
      await _dio!.delete('/notifications/bulk', data: {'notificationIds': ids});
      return true;
    } catch (_) {
      emit(originalState);
      return false;
    }
  }

  Future<bool> clearAll() async {
    final cur = _loaded;
    if (cur == null || cur.notifications.isEmpty) return false;
    return bulkDelete(cur.notifications.map((n) => n.id).toList());
  }

  List<AppNotification> _parse(dynamic data) {
    List<dynamic> raw = [];
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      for (final k in ['data', 'notifications', 'result', 'records']) {
        if (data[k] is List) {
          raw = data[k] as List;
          break;
        }
      }
    }
    final out = <AppNotification>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          out.add(AppNotification.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('[NotifCubit] parse error: $e');
        }
      }
    }
    return out;
  }

  String _dioMsg(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout =>
          'Connection timed out.',
        DioExceptionType.connectionError => 'No internet connection.',
        DioExceptionType.badResponse =>
          'Server error (${e.response?.statusCode}).',
        _ => 'Something went wrong. Please try again.',
      };

  @override
  Future<void> close() {
    _dio?.close();
    return super.close();
  }
}
