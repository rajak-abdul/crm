// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/notifications/notification.dart           ║
// ║                                                              ║
// ║  Model + State + Cubit for the notification system           ║
// ║                      FULLY FIXED VERSION                     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:dio/dio.dart'
    show DioExceptionType, DioException, Dio, BaseOptions, InterceptorsWrapper;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit, BlocBuilder;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

// ══════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════
class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String text;
  final bool read;
  final String? profileImage;
  final String? userName;
  final String? dealId;
  final String? dealName;
  final String? leadId;
  final String? proposalId;
  final String? proposalTitle;
  final String? salesmanName;
  final String? salesmanId;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.text,
    required this.read,
    this.profileImage,
    this.userName,
    this.dealId,
    this.dealName,
    this.leadId,
    this.proposalId,
    this.proposalTitle,
    this.salesmanName,
    this.salesmanId,
    this.createdAt,
    this.expiresAt,
  });

  static String _s(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString().trim();

  static String? _nullableStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] is Map
        ? Map<String, dynamic>.from(j['meta'] as Map)
        : <String, dynamic>{};

    return AppNotification(
      id:            _s(j['_id'] ?? j['id']),
      userId:        _s(j['userId']),
      type:          _s(j['type'], 'general'),
      text:          _s(j['text'] ?? j['message'] ?? j['title']),
      read:          j['read'] == true || j['isRead'] == true,
      // removed buildProfileImageUrl — store raw filename only
      profileImage:  _nullableStr(j['profileImage'] ?? meta['profileImage']),
      userName:      _nullableStr(j['userName'] ?? meta['salesmanName']),
      dealId:        _nullableStr(meta['dealId']),
      dealName:      _nullableStr(meta['dealName']),
      leadId:        _nullableStr(meta['leadId']),
      proposalId:    _nullableStr(meta['proposalId']),
      proposalTitle: _nullableStr(meta['proposalTitle']),
      salesmanName:  _nullableStr(meta['salesmanName']),
      salesmanId:    _nullableStr(meta['salesmanId']),
      createdAt:     j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString())
          : null,
      expiresAt:     j['expiresAt'] != null
          ? DateTime.tryParse(j['expiresAt'].toString())
          : null,
    );
  }

  AppNotification copyWith({bool? read}) => AppNotification(
        id:            id,
        userId:        userId,
        type:          type,
        text:          text,
        read:          read ?? this.read,
        profileImage:  profileImage,
        userName:      userName,
        dealId:        dealId,
        dealName:      dealName,
        leadId:        leadId,
        proposalId:    proposalId,
        proposalTitle: proposalTitle,
        salesmanName:  salesmanName,
        salesmanId:    salesmanId,
        createdAt:     createdAt,
        expiresAt:     expiresAt,
      );

  String get subtitle {
    if (dealName != null) return dealName!;
    if (proposalTitle != null) return proposalTitle!;
    return '';
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  List<Object?> get props => [id, read];
}

// ══════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════
abstract class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}
class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool hasMore;
  final int currentPage;

  const NotificationLoaded({
    required this.notifications,
    required this.unreadCount,
    this.hasMore = false,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [notifications, unreadCount, hasMore, currentPage];
}

class NotificationError extends NotificationState {
  final String message;
  const NotificationError(this.message);
  @override
  List<Object?> get props => [message];
}

// ══════════════════════════════════════════════════════════════
// CUBIT
// ══════════════════════════════════════════════════════════════
class NotificationCubit extends Cubit<NotificationState> {
  static const _base = 'https://sales.stagingzar.com/api';

  Dio? _dio;
  String? _cachedToken;
  String? _currentUserId;

  int  _currentPage    = 1;
  bool _hasMore        = true;
  bool _isLoadingMore  = false;

  DateTime? _lastLoadTime;
  static const _minLoadInterval = Duration(seconds: 2);

  NotificationCubit() : super(NotificationInitial()) {
    _initDio();
  }

  Future<void> _initDio() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken   = prefs.getString('token');
    _currentUserId = prefs.getString('user_id');

    debugPrint('[NotifCubit] token=${_cachedToken != null ? "found" : "NULL"}');
    debugPrint('[NotifCubit] user_id=$_currentUserId');

    final dio = Dio(BaseOptions(
      baseUrl:        _base,
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
          emit(const NotificationError('Session expired. Please login again.'));
        }
        handler.next(error);
      },
    ));

    _dio = dio;

    // ✅ If user_id missing but token exists, fetch profile to get userId
    if ((_currentUserId == null || _currentUserId!.isEmpty) 
        && _cachedToken != null) {
      try {
        final res = await dio.get('/users/profile');
        debugPrint('[NotifCubit] profile response: ${res.data}');
        final body = res.data;
        String? fetchedId;
        if (body is Map) {
          fetchedId = body['_id']    as String?
                   ?? body['id']     as String?
                   ?? body['userId'] as String?
                   ?? (body['data'] is Map ? (
                          body['data']['_id'] as String?
                       ?? body['data']['id']  as String?
                      ) : null);
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
  Future<void> load(String userId, {bool refresh = false}) async {
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
      _hasMore     = true;
      emit(NotificationLoading());
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
      debugPrint('[NotifCubit] parsed ${newNotifications.length} notifications');

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
        unreadCount:   unread,
        hasMore:       _hasMore,
        currentPage:   _currentPage,
      ));
    } on DioException catch (e) {
      debugPrint('[NotifCubit] DioException: ${e.type} ${e.response?.statusCode}');
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
Future<void> refresh({String? userId}) async {
  final id = userId ?? _currentUserId;
  if (id == null || id.isEmpty) {
    debugPrint('[NotifCubit] refresh() called but no userId available');
    return;
  }
  _currentUserId = id;
  await load(id, refresh: true);
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
      unreadCount:   updated.where((n) => !n.read).length,
      hasMore:       cur.hasMore,
      currentPage:   cur.currentPage,
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

    final unreadIds = cur.notifications
        .where((n) => !n.read)
        .map((n) => n.id)
        .toList();
    if (unreadIds.isEmpty) return;

    final originalState = cur;

    final updated = cur.notifications.map((n) => n.copyWith(read: true)).toList();
    emit(NotificationLoaded(
      notifications: updated,
      unreadCount:   0,
      hasMore:       cur.hasMore,
      currentPage:   cur.currentPage,
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
      unreadCount:   updated.where((n) => !n.read).length,
      hasMore:       cur.hasMore,
      currentPage:   cur.currentPage,
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
    final updated = cur.notifications.where((n) => !ids.contains(n.id)).toList();
    emit(NotificationLoaded(
      notifications: updated,
      unreadCount:   updated.where((n) => !n.read).length,
      hasMore:       cur.hasMore,
      currentPage:   cur.currentPage,
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
        if (data[k] is List) { raw = data[k] as List; break; }
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
        DioExceptionType.receiveTimeout   => 'Connection timed out.',
        DioExceptionType.connectionError  => 'No internet connection.',
        DioExceptionType.badResponse      =>
            'Server error (${e.response?.statusCode}).',
        _ => 'Something went wrong. Please try again.',
      };

  @override
  Future<void> close() {
    _dio?.close();
    return super.close();
  }
}

// ══════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════
IconData notifIcon(String type) => switch (type.toLowerCase()) {
      'followup' || 'follow_up' => Icons.access_time_rounded,
      'deal'                    => Icons.handshake_outlined,
      'lead'                    => Icons.people_outline,
      'invoice'                 => Icons.receipt_long_outlined,
      'payment'                 => Icons.account_balance_wallet_outlined,
      'reminder'                => Icons.alarm_rounded,
      'admin'                   => Icons.admin_panel_settings_outlined,
      _                         => Icons.notifications_outlined,
    };

Color notifColor(String type) => switch (type.toLowerCase()) {
      'followup' || 'follow_up' => AppColors.warning,
      'deal'                    => AppColors.purple,
      'lead'                    => AppColors.success,
      'invoice'                 => AppColors.primary,
      'payment'                 => const Color(0xFF10B981),
      'reminder'                => AppColors.danger,
      'admin'                   => const Color(0xFF6366F1),
      _                         => AppColors.primary,
    };

String timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60)  return 'Just now';
  if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
  if (diff.inHours   < 24)  return '${diff.inHours}h ago';
  if (diff.inDays    < 7)   return '${diff.inDays}d ago';
  if (diff.inDays    < 30)  return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays    < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

String typeLabel(String type) => switch (type.toLowerCase()) {
      'followup' || 'follow_up' => 'Follow-up',
      'deal'                    => 'Deal Update',
      'lead'                    => 'Lead',
      'invoice'                 => 'Invoice',
      'payment'                 => 'Payment',
      'reminder'                => 'Reminder',
      'admin'                   => 'Admin',
      _                         => 'Notification',
    };

// ══════════════════════════════════════════════════════════════
// NOTIFICATION PANEL (bottom sheet — shows first 5)
// ══════════════════════════════════════════════════════════════
class NotificationPanel extends StatelessWidget {
  final NotificationCubit cubit;
  final VoidCallback onViewAll;

  const NotificationPanel({
    super.key,
    required this.cubit,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      bloc: cubit,
      builder: (ctx, state) {
        if (state is NotificationLoading) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (state is NotificationError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(state.message,
                    style: const TextStyle(color: AppColors.danger),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    // ── FIX: read 'user_id' (not 'auth_token') ──
                    final prefs = await SharedPreferences.getInstance();
                    final uid   = prefs.getString('user_id') ?? '';
                    cubit.load(uid, refresh: true);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is! NotificationLoaded || state.notifications.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(children: [
                Icon(Icons.notifications_off_outlined,
                    size: 40, color: AppColors.textHint),
                SizedBox(height: 8),
                Text('No notifications',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
          );
        }

        final all    = state.notifications;
        final first5 = all.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              child: Row(children: [
                const Expanded(
                  child: Text('Notifications',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                if (state.unreadCount > 0) _MarkAllReadButton(cubit: cubit),
              ]),
            ),
            ...first5.asMap().entries.map((e) => _NotifTile(
                  notif:       e.value,
                  onRead:      () => cubit.markAsRead(e.value.id),
                  onDelete:    () =>
                      _showDeleteDialog(context, cubit, e.value.id),
                  showDivider: e.key != first5.length - 1 || all.length > 5,
                )),
            if (all.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('View all notifications',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('${all.length}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(
      BuildContext context, NotificationCubit cubit, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notification'),
        content:
            const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); cubit.delete(id); },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Mark All Read button ──────────────────────────────────────
class _MarkAllReadButton extends StatelessWidget {
  final NotificationCubit cubit;
  const _MarkAllReadButton({required this.cubit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // ── FIX: read 'user_id' ──
        final prefs   = await SharedPreferences.getInstance();
        final uid     = prefs.getString('user_id') ?? '';
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mark all as read'),
            content: const Text(
                'Are you sure you want to mark all notifications as read?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Mark all read')),
            ],
          ),
        );
        if (confirm == true) cubit.markAllAsRead(uid);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20)),
        child: const Text('Mark all read',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Single notification tile ──────────────────────────────────
class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback    onRead;
  final VoidCallback    onDelete;
  final bool            showDivider;

  const _NotifTile({
    required this.notif,
    required this.onRead,
    required this.onDelete,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = notifColor(notif.type);
    final icon  = notifIcon(notif.type);

    return Column(children: [
      GestureDetector(
        onTap: notif.read ? null : onRead,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: notif.read
                ? Colors.transparent
                : color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _NotifAvatar(notif: notif, color: color, icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  if (!notif.read)
                    Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.only(right: 6, top: 1),
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                  Expanded(
                    child: Text(typeLabel(notif.type),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                  Text(timeAgo(notif.createdAt),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint)),
                ]),
                const SizedBox(height: 3),
                Text(notif.text,
                    style: TextStyle(
                        fontSize: 13,
                        color: notif.read
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontWeight: notif.read
                            ? FontWeight.w400
                            : FontWeight.w500)),
                if (notif.userName != null) ...[
                  const SizedBox(height: 3),
                  Text(notif.userName!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ],
                if (notif.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.folder_outlined,
                        size: 11, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(notif.subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textHint),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              ]),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textHint),
              ),
            ),
          ]),
        ),
      ),
      if (showDivider)
        const Divider(height: 1, color: AppColors.divider),
    ]);
  }
}

// ── Avatar (no buildProfileImageUrl — just icon fallback) ────
class _NotifAvatar extends StatelessWidget {
  final AppNotification notif;
  final Color    color;
  final IconData icon;

  const _NotifAvatar(
      {required this.notif, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color),
      );
}

// ══════════════════════════════════════════════════════════════
// FULL NOTIFICATIONS SCREEN
// ══════════════════════════════════════════════════════════════
class NotificationsScreen extends StatefulWidget {
  final NotificationCubit cubit;
  const NotificationsScreen({super.key, required this.cubit});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selected  = {};
  bool              _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
      _loadOnOpen(); // ← add this

  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) => setState(() {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
        _isSelecting = _selected.isNotEmpty;
      });

  void _clearSelection() => setState(() {
        _selected.clear();
        _isSelecting = false;
      });
Future<void> _loadOnOpen() async {
  final prefs = await SharedPreferences.getInstance();
  final uid   = prefs.getString('user_id') ?? '';
  if (uid.isEmpty) return;
  widget.cubit.load(uid, refresh: true);
}
Future<void> _handleRefresh() async {
  final prefs = await SharedPreferences.getInstance();
  final uid   = prefs.getString('user_id') ?? '';
  widget.cubit.refresh(userId: uid);
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            BlocBuilder<NotificationCubit, NotificationState>(
              bloc: widget.cubit,
              buildWhen: (p, c) {
                if (c is NotificationLoaded && p is NotificationLoaded) {
                  return c.unreadCount != p.unreadCount;
                }
                return true;
              },
              builder: (ctx, state) {
                if (state is NotificationLoaded && state.unreadCount > 0) {
                  return Text('${state.unreadCount} unread',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500));
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        actions: [
          if (_isSelecting) ...[
            TextButton.icon(
              onPressed: () => _confirmBulkDelete(context),
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.danger),
              label: const Text('Delete',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
              tooltip: 'Cancel selection',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _handleRefresh,
              tooltip: 'Refresh',
            ),
            BlocBuilder<NotificationCubit, NotificationState>(
              bloc: widget.cubit,
              buildWhen: (p, c) {
                if (c is NotificationLoaded && p is NotificationLoaded) {
                  return c.unreadCount != p.unreadCount;
                }
                return true;
              },
              builder: (ctx, state) {
                if (state is NotificationLoaded && state.unreadCount > 0) {
                  return IconButton(
                    tooltip: 'Mark all read',
                    icon: const Icon(Icons.done_all_rounded,
                        color: AppColors.primary),
                    onPressed: () => _confirmMarkAllRead(context),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor:            AppColors.primary,
          unselectedLabelColor:  AppColors.textSecondary,
          indicatorColor:        AppColors.primary,
          indicatorWeight:       2.5,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            BlocBuilder<NotificationCubit, NotificationState>(
              bloc: widget.cubit,
              builder: (ctx, state) {
                final count = state is NotificationLoaded
                    ? state.notifications.where((n) => !n.read).length
                    : 0;
                return Tab(
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Text('Unread'),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      _Badge('$count', AppColors.primary),
                    ],
                  ]),
                );
              },
            ),
            BlocBuilder<NotificationCubit, NotificationState>(
              bloc: widget.cubit,
              builder: (ctx, state) {
                final count = state is NotificationLoaded
                    ? state.notifications.length
                    : 0;
                return Tab(
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Text('All'),
                    const SizedBox(width: 6),
                    _Badge('$count', AppColors.textSecondary),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: BlocBuilder<NotificationCubit, NotificationState>(
          bloc: widget.cubit,
          builder: (ctx, state) {
            if (state is NotificationLoading) {
              return const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (state is NotificationError) {
              return Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text(state.message,
                      style: const TextStyle(
                          color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      // ── FIX: read 'user_id' ──
                      final prefs =
                          await SharedPreferences.getInstance();
                      final uid =
                          prefs.getString('user_id') ?? '';
                      widget.cubit.load(uid, refresh: true);
                    },
                    child: const Text('Retry'),
                  ),
                ]),
              );
            }
            if (state is! NotificationLoaded) {
              return const SizedBox.shrink();
            }

            final all    = state.notifications;
            final unread = all.where((n) => !n.read).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _NotifList(
                  items:       unread,
                  emptyText:   'No unread notifications 🎉',
                  cubit:       widget.cubit,
                  selected:    _selected,
                  isSelecting: _isSelecting,
                  onToggle:    _toggleSelection,
                  onLoadMore:  widget.cubit.loadMore,
                  hasMore:     state.hasMore,
                ),
                _NotifList(
                  items:       all,
                  emptyText:   'No notifications yet',
                  cubit:       widget.cubit,
                  selected:    _selected,
                  isSelecting: _isSelecting,
                  onToggle:    _toggleSelection,
                  onLoadMore:  widget.cubit.loadMore,
                  hasMore:     state.hasMore,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notifications'),
        content: Text(
            'Delete ${_selected.length} notification(s)?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok =
                  await widget.cubit.bulkDelete(_selected.toList());
              if (!mounted) return;
              _clearSelection();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Notifications deleted'
                    : 'Failed to delete notifications'),
                backgroundColor:
                    ok ? Colors.green : AppColors.danger,
              ));
            },
            style:
                TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmMarkAllRead(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark All as Read'),
        content: const Text(
            'Mark all notifications as read?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // ── FIX: read 'user_id' ──
              final prefs = await SharedPreferences.getInstance();
              final uid   = prefs.getString('user_id') ?? '';
              widget.cubit.markAllAsRead(uid);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
    );
  }
}

// ── List with pagination ──────────────────────────────────────
class _NotifList extends StatelessWidget {
  final List<AppNotification> items;
  final String                emptyText;
  final NotificationCubit     cubit;
  final Set<String>           selected;
  final bool                  isSelecting;
  final void Function(String) onToggle;
  final VoidCallback          onLoadMore;
  final bool                  hasMore;

  const _NotifList({
    required this.items,
    required this.emptyText,
    required this.cubit,
    required this.selected,
    required this.isSelecting,
    required this.onToggle,
    required this.onLoadMore,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.notifications_none_rounded,
              size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(emptyText,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
        ]),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (info) {
        if (hasMore &&
            info.metrics.pixels >=
                info.metrics.maxScrollExtent - 200) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          if (i == items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2))),
            );
          }

          final n          = items[i];
          final isSelected = selected.contains(n.id);
          final color      = notifColor(n.type);
          final icon       = notifIcon(n.type);

          return GestureDetector(
            onLongPress: () => onToggle(n.id),
            onTap: isSelecting ? () => onToggle(n.id) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryLight
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (isSelecting)
                    Padding(
                      padding:
                          const EdgeInsets.only(right: 10, top: 2),
                      child: AnimatedScale(
                        scale: isSelected ? 1.1 : 1.0,
                        duration:
                            const Duration(milliseconds: 150),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 20,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textHint,
                        ),
                      ),
                    ),
                  _NotifAvatar(notif: n, color: color, icon: icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        if (!n.read)
                          Container(
                            width: 7, height: 7,
                            margin: const EdgeInsets.only(
                                right: 6, top: 2),
                            decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle),
                          ),
                        Expanded(
                          child: Text(typeLabel(n.type),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ),
                        Text(timeAgo(n.createdAt),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint)),
                      ]),
                      const SizedBox(height: 4),
                      Text(n.text,
                          style: TextStyle(
                              fontSize: 13,
                              color: n.read
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontWeight: n.read
                                  ? FontWeight.w400
                                  : FontWeight.w500)),
                      if (n.userName != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.person_outline,
                              size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(n.userName!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint)),
                        ]),
                      ],
                      if (n.dealName != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.handshake_outlined,
                              size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(n.dealName!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint)),
                        ]),
                      ],
                      if (n.proposalTitle != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.description_outlined,
                              size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(n.proposalTitle!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ],
                    ]),
                  ),
                  if (!isSelecting)
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      if (!n.read)
                        GestureDetector(
                          onTap: () => cubit.markAsRead(n.id),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius:
                                    BorderRadius.circular(8)),
                            child: const Icon(Icons.done_rounded,
                                size: 14,
                                color: AppColors.primary),
                          ),
                        ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () =>
                            _showDeleteDialog(context, n.id),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius:
                                  BorderRadius.circular(8)),
                          child: const Icon(Icons.delete_outline,
                              size: 14, color: AppColors.danger),
                        ),
                      ),
                    ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notification'),
        content:
            const Text('Delete this notification?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); cubit.delete(id); },
            style:
                TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Badge widget ──────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color  color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)));
}