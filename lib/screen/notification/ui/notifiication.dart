// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/notifications/notification.dart           ║
// ║                                                              ║
// ║  Model + State + Cubit for the notification system           ║
// ║                      FULLY FIXED VERSION                     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:async';

import 'package:crm_app/screen/notification/cubit/notification_cubit.dart';
import 'package:crm_app/screen/notification/cubit/notification_state.dart';
import 'package:crm_app/screen/notification/model/notification_model.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:dio/dio.dart'
    show DioExceptionType, DioException, Dio, BaseOptions, InterceptorsWrapper;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit, BlocBuilder;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;




// ══════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════
IconData notifIcon(String type) => switch (type.toLowerCase()) {
      'followup' || 'follow_up' => Icons.access_time_rounded,
      'deal' => Icons.handshake_outlined,
      'lead' => Icons.people_outline,
      'invoice' => Icons.receipt_long_outlined,
      'payment' => Icons.account_balance_wallet_outlined,
      'reminder' => Icons.alarm_rounded,
      'admin' => Icons.admin_panel_settings_outlined,
      _ => Icons.notifications_outlined,
    };

Color notifColor(String type) => switch (type.toLowerCase()) {
      'followup' || 'follow_up' => AppColors.warning,
      'deal' => AppColors.purple,
      'lead' => AppColors.success,
      'invoice' => AppColors.primary,
      'payment' => const Color(0xFF10B981),
      'reminder' => AppColors.danger,
      'admin' => const Color(0xFF6366F1),
      _ => AppColors.primary,
    };

String timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

String typeLabel(String type) => switch (type.toLowerCase()) {
      'followup' || 'follow_up' => 'Follow-up',
      'deal' => 'Deal Update',
      'lead' => 'Lead',
      'invoice' => 'Invoice',
      'payment' => 'Payment',
      'reminder' => 'Reminder',
      'admin' => 'Admin',
      _ => 'Notification',
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
                    final uid = prefs.getString('user_id') ?? '';
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

        final all = state.notifications;
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
                  notif: e.value,
                  onRead: () => cubit.markAsRead(e.value.id),
                  onDelete: () => _showDeleteDialog(context, cubit, e.value.id),
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              cubit.delete(id);
            },
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
        final prefs = await SharedPreferences.getInstance();
        final uid = prefs.getString('user_id') ?? '';
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
  final VoidCallback onRead;
  final VoidCallback onDelete;
  final bool showDivider;

  const _NotifTile({
    required this.notif,
    required this.onRead,
    required this.onDelete,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = notifColor(notif.type);
    final icon = notifIcon(notif.type);

    return Column(children: [
      GestureDetector(
        onTap: notif.read ? null : onRead,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: notif.read ? Colors.transparent : color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _NotifAvatar(notif: notif, color: color, icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (!notif.read)
                        Container(
                          width: 7,
                          height: 7,
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
      if (showDivider) const Divider(height: 1, color: AppColors.divider),
    ]);
  }
}

// ── Avatar (no buildProfileImageUrl — just icon fallback) ────
class _NotifAvatar extends StatelessWidget {
  final AppNotification notif;
  final Color color;
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

class _NotificationsScreenState extends State<NotificationsScreen> {
  
final TextEditingController _searchController = TextEditingController();

String _selectedDateRange = 'All Time';
DateTime? _startDate;
DateTime? _endDate;

String _searchQuery = '';

      String _selectedFilter = 'All';
      bool get _isDateFilterActive => _selectedDateRange != 'All Time';

final List<String> _notificationFilters = [
  'All',
  'Unread',
  'Tasks',
  'Targets',
  'Leads',
  'Deals',
  'Follow-ups',
  'Scheduled Emails',
  'Invoices',
  'Other',
];
  late TabController _tabController;
  final Set<String> _selected = {};
  bool _isSelecting = false;
  Timer? _autoRefreshTimer;
  static const _autoRefreshInterval = Duration(seconds: 15);

@override
void initState() {
  super.initState();
  _loadOnOpen();

  _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
    if (_isSelecting) return;
    _autoRefresh();
  });
}
  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
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
    final uid = prefs.getString('user_id') ?? '';
    if (uid.isEmpty) return;
    widget.cubit.load(uid, refresh: true);
  }

  Future<void> _autoRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id') ?? '';
    if (uid.isEmpty) return;
    widget.cubit.refresh(userId: uid, silent: true);
  }

  Future<void> _handleRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id') ?? '';
    widget.cubit.refresh(userId: uid);
  }
  Widget _buildNotificationFilters(int unreadCount) {
  return SizedBox(
    height: 52,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      itemCount: _notificationFilters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final filter = _notificationFilters[index];
        final isSelected = _selectedFilter == filter;

        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(filter),
              if (filter == 'Unread' && unreadCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) {
            setState(() {
              _selectedFilter = filter;
            });
          },
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 12,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(
            color: isSelected
                ? AppColors.primary
                : AppColors.divider,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        );
      },
    ),
  );
}



List<AppNotification> _filterNotifications(
  List<AppNotification> notifications,
) {
  final now = DateTime.now();
  DateTime? from;
  DateTime? to;

  switch (_selectedDateRange) {
    case 'Today':
      from = DateTime(now.year, now.month, now.day);
      to = from.add(const Duration(days: 1));
      break;

    case 'This Week':
      final today = DateTime(now.year, now.month, now.day);
      from = today.subtract(Duration(days: today.weekday - 1));
      to = from.add(const Duration(days: 7));
      break;

    case 'This Month':
      from = DateTime(now.year, now.month, 1);
      to = DateTime(now.year, now.month + 1, 1);
      break;

    case 'Custom':
      from = _startDate == null
          ? null
          : DateTime(
              _startDate!.year,
              _startDate!.month,
              _startDate!.day,
            );
      to = _endDate == null
          ? null
          : DateTime(
              _endDate!.year,
              _endDate!.month,
              _endDate!.day,
            ).add(const Duration(days: 1));
      break;
  }

  return notifications.where((n) {
    // Category filter
    final type = n.type.toLowerCase().replaceAll('_', '-');

    bool matchesCategory;

    switch (_selectedFilter) {
      case 'Unread':
        matchesCategory = !n.read;
        break;
      case 'Tasks':
        matchesCategory = type == 'task';
        break;
      case 'Targets':
        matchesCategory = type == 'target';
        break;
      case 'Leads':
        matchesCategory = type == 'lead';
        break;
      case 'Deals':
        matchesCategory = type == 'deal';
        break;
      case 'Follow-ups':
        matchesCategory =
            type == 'follow-up' || type == 'followup';
        break;
      case 'Scheduled Emails':
        matchesCategory = type == 'scheduled-email' ||
            type == 'scheduled-email-reminder';
        break;
      case 'Invoices':
        matchesCategory = type == 'invoice';
        break;
      case 'Other':
        const knownTypes = {
          'task',
          'target',
          'lead',
          'deal',
          'follow-up',
          'followup',
          'scheduled-email',
          'scheduled-email-reminder',
          'invoice',
        };
        matchesCategory = !knownTypes.contains(type);
        break;
      default:
        matchesCategory = true;
    }

    if (!matchesCategory) return false;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery;
      final matchesSearch =
          n.text.toLowerCase().contains(query) ||
          n.type.toLowerCase().contains(query) ||
          (n.userName?.toLowerCase().contains(query) ?? false) ||
          (n.dealName?.toLowerCase().contains(query) ?? false) ||
          (n.proposalTitle?.toLowerCase().contains(query) ?? false);

      if (!matchesSearch) return false;
    }

    // Date filter
    if (from != null || to != null) {
      final createdAt = n.createdAt;
      if (createdAt == null) return false;
      if (from != null && createdAt.isBefore(from)) return false;
      if (to != null && !createdAt.isBefore(to)) return false;
    }

    return true;
  }).toList();
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
                      color: AppColors.danger, fontWeight: FontWeight.w600)),
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
bottom: PreferredSize(
preferredSize: Size.fromHeight(
  _isDateFilterActive ? 144 : 112,
),  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search notifications...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            
IconButton(
  onPressed: _showNotificationFilters,
  tooltip: 'Filter notifications',
  icon: const Icon(Icons.filter_alt_outlined),
),

          ],
        ),
      ),
BlocBuilder<NotificationCubit, NotificationState>(
  bloc: widget.cubit,
  builder: (context, state) {
    final unreadCount = state is NotificationLoaded
        ? state.notifications.where((n) => !n.read).length
        : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNotificationFilters(unreadCount),

        if (_isDateFilterActive)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 16,
                bottom: 8,
              ),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedDateRange = 'All Time';
                    _startDate = null;
                    _endDate = null;
                  });
                },
                icon: const Icon(
                  Icons.filter_alt_off_outlined,
                  size: 16,
                ),
                label: const Text('Clear Filter'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
      ],
    );
  },
),    ],
  ),
),
   ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        
        child: BlocBuilder<NotificationCubit, NotificationState>(
          bloc: widget.cubit,
          builder: (ctx, state) {
            if (state is NotificationLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (state is NotificationError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text(state.message,
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      // ── FIX: read 'user_id' ──
                      final prefs = await SharedPreferences.getInstance();
                      final uid = prefs.getString('user_id') ?? '';
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




final all = state.notifications;
final filteredNotifications = _filterNotifications(all);

return _NotifList(
  items: filteredNotifications,
  emptyText: _selectedFilter == 'Unread'
      ? 'No unread notifications 🎉'
      : _selectedFilter == 'All'
          ? 'No notifications yet'
          : 'No $_selectedFilter notifications yet',
  cubit: widget.cubit,
  selected: _selected,
  isSelecting: _isSelecting,
  onToggle: _toggleSelection,
  onLoadMore: widget.cubit.loadMore,
  hasMore: state.hasMore,
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
        content: Text('Delete ${_selected.length} notification(s)?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await widget.cubit.bulkDelete(_selected.toList());
              if (!mounted) return;
              _clearSelection();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Notifications deleted'
                    : 'Failed to delete notifications'),
                backgroundColor: ok ? Colors.green : AppColors.danger,
              ));
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
        content: const Text('Mark all notifications as read?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // ── FIX: read 'user_id' ──
              final prefs = await SharedPreferences.getInstance();
              final uid = prefs.getString('user_id') ?? '';
              widget.cubit.markAllAsRead(uid);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
    );
  }

  
Future<void> _showNotificationFilters() async {
  String selectedRange = _selectedDateRange;
  DateTime? startDate = _startDate;
  DateTime? endDate = _endDate;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> chooseDate({required bool isStart}) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: isStart
                  ? startDate ?? DateTime.now()
                  : endDate ?? startDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );

            if (picked != null) {
              setSheetState(() {
                if (isStart) {
                  startDate = picked;
                  if (endDate != null && endDate!.isBefore(picked)) {
                    endDate = picked;
                  }
                } else {
                  endDate = picked;
                }
              });
            }
          }

          Widget rangeChip(String label) {
            final selected = selectedRange == label;

            return ChoiceChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              avatar: Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: selected ? Colors.white : Colors.black87,
              ),
              selectedColor: const Color(0xFF1769FF),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF1769FF)
                      : const Color(0xFFE1E5ED),
                ),
              ),
              onSelected: (_) {
                setSheetState(() {
                  selectedRange = label;
                });
              },
            );
          }

          String formatDate(DateTime? date) {
            if (date == null) return 'Select date';
            return '${date.day.toString().padLeft(2, '0')} '
                '${_monthName(date.month)} ${date.year}';
          }

          return SafeArea(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB7BDC8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_outlined,
                          color: Color(0xFF1769FF),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Filter Notifications',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Date Range',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        rangeChip('All Time'),
                        rangeChip('Today'),
                        rangeChip('This Week'),
                        rangeChip('This Month'),
                        rangeChip('Custom'),
                      ],
                    ),

                    // Date fields appear ONLY for Custom.
                    if (selectedRange == 'Custom') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _dateField(
                              label: 'Start Date',
                              value: formatDate(startDate),
                              onTap: () => chooseDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dateField(
                              label: 'End Date',
                              value: formatDate(endDate),
                              onTap: () => chooseDate(isStart: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1769FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          if (selectedRange == 'Custom') {
                            if (startDate == null || endDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select both start and end dates.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (endDate!.isBefore(startDate!)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'End date must be on or after start date.',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          setState(() {
                            _selectedDateRange = selectedRange;
                            _startDate = startDate;
                            _endDate = endDate;
                          });

                          Navigator.pop(sheetContext);
                        },
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

String _monthName(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[month - 1];
}

Widget _dateField({
  required String label,
  required String value,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE1E5ED)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

}

// ── List with pagination ──────────────────────────────────────
class _NotifList extends StatelessWidget {
  final List<AppNotification> items;
  final String emptyText;
  final NotificationCubit cubit;
  final Set<String> selected;
  final bool isSelecting;
  final void Function(String) onToggle;
  final VoidCallback onLoadMore;
  final bool hasMore;

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
            info.metrics.pixels >= info.metrics.maxScrollExtent - 200) {
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
                      child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }

          final n = items[i];
          final isSelected = selected.contains(n.id);
          final color = notifColor(n.type);
          final icon = notifIcon(n.type);

          return GestureDetector(
            onLongPress: () => onToggle(n.id),
            onTap: isSelecting ? () => onToggle(n.id) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
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
                          padding: const EdgeInsets.only(right: 10, top: 2),
                          child: AnimatedScale(
                            scale: isSelected ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 150),
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
                                    width: 7,
                                    height: 7,
                                    margin:
                                        const EdgeInsets.only(right: 6, top: 2),
                                    decoration: BoxDecoration(
                                        color: color, shape: BoxShape.circle),
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
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.done_rounded,
                                    size: 14, color: AppColors.primary),
                              ),
                            ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _showDeleteDialog(context, n.id),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: AppColors.dangerLight,
                                  borderRadius: BorderRadius.circular(8)),
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
        content: const Text('Delete this notification?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              cubit.delete(id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)));
}
