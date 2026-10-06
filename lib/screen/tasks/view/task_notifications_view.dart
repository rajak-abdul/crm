// ╔══════════════════════════════════════════════════════════════╗
// ║       lib/screen/tasks/view/task_notifications_view.dart      ║
// ║  VIEW — task notifications shown when the Notifications       ║
// ║  chip is selected. Renders TaskViewModel's grouped items.     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/view/task_widgets.dart'
    show TaskPalette;
import 'package:crm_app/screen/tasks/viewmodel/task_state.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show EmptyState, LoadingState, ErrorState;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';

/// Shared by the Task screen (task notifications) and the Target screen
/// (target notifications) — each passes its own grouped items.
class TaskNotificationsView extends StatelessWidget {
  final TaskViewStatus status;
  final String? errorMessage;
  final List<NotificationGroup> groups;
  final int total;
  final int unread;
  final String emptyMessage;

  final VoidCallback onRetry;
  final VoidCallback onReadAll;
  final ValueChanged<String> onTapNotification;

  /// Deletes a notification; returns an error message on failure.
  final Future<String?> Function(String id) onDelete;

  const TaskNotificationsView({
    super.key,
    required this.status,
    required this.groups,
    required this.total,
    required this.unread,
    required this.onRetry,
    required this.onReadAll,
    required this.onTapNotification,
    required this.onDelete,
    this.errorMessage,
    this.emptyMessage = 'No notifications yet',
  });

  Future<bool> _confirmDelete(
    BuildContext context,
    TaskNotificationItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(title: item.title),
    );
    return confirmed == true;
  }

  Future<void> _delete(BuildContext context, TaskNotificationItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await onDelete(item.id);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(error ?? 'Notification deleted'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TaskViewStatus.initial:
      case TaskViewStatus.loading:
        return const Padding(
          padding: EdgeInsets.only(top: 60),
          child: LoadingState(message: 'Loading notifications...'),
        );

      case TaskViewStatus.error:
        return Padding(
          padding: const EdgeInsets.only(top: 30),
          child: ErrorState(
            message: errorMessage ?? 'Something went wrong',
            onRetry: onRetry,
          ),
        );

      case TaskViewStatus.empty:
        return Padding(
          padding: const EdgeInsets.only(top: 40),
          child: EmptyState(
            message: emptyMessage,
            icon: Icons.notifications_none_rounded,
          ),
        );

      case TaskViewStatus.success:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryBar(
              total: total,
              unread: unread,
              onReadAll: onReadAll,
            ),
            const Divider(height: 1, color: AppColors.border),
            for (final group in groups) ...[
              _GroupHeader(group.label),
              for (final item in group.items)
                // Swipe right → left to delete (asks for confirmation).
                Dismissible(
                  key: ValueKey('notification-${item.id}'),
                  direction: DismissDirection.endToStart,
                  background: const _DeleteSwipeBackground(),
                  confirmDismiss: (_) => _confirmDelete(context, item),
                  onDismissed: (_) => _delete(context, item),
                  child: _NotificationTile(
                    item: item,
                    onTap: () => onTapNotification(item.id),
                  ),
                ),
            ],
          ],
        );
    }
  }
}

class _SummaryBar extends StatelessWidget {
  final int total;
  final int unread;
  final VoidCallback onReadAll;

  const _SummaryBar({
    required this.total,
    required this.unread,
    required this.onReadAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$total ${total == 1 ? 'notification' : 'notifications'}'
              '${unread > 0 ? ', $unread unread' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: unread > 0 ? onReadAll : null,
            style: TextButton.styleFrom(
              foregroundColor: TaskPalette.accent,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.done_all_rounded, size: 16),
            label: const Text('Read all'),
          ),
        ],
      ),
    );
  }
}

class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TaskPalette.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, size: 20, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Delete',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  final String title;

  const _DeleteConfirmDialog({required this.title});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 26, color: TaskPalette.red),
            ),
            const SizedBox(height: 14),
            const Text(
              'Delete notification?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '"$title"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const TextSpan(
                    text: ' will be permanently removed. '
                        'This action cannot be undone.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: TaskPalette.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;

  const _GroupHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final TaskNotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  static (IconData, Color) _iconFor(TaskNotificationKind kind) {
    switch (kind) {
      case TaskNotificationKind.completed:
        return (Icons.check_circle_outline_rounded, const Color(0xFF059669));
      case TaskNotificationKind.assigned:
        return (Icons.post_add_rounded, AppColors.primary);
      case TaskNotificationKind.dueToday:
        return (Icons.schedule_rounded, const Color(0xFFD97706));
      case TaskNotificationKind.dueTomorrow:
        return (Icons.notifications_none_rounded, const Color(0xFFD97706));
      case TaskNotificationKind.adminReplied:
        return (Icons.chat_bubble_outline_rounded, AppColors.purple);
      case TaskNotificationKind.keptWithYou:
        return (Icons.assignment_return_outlined, const Color(0xFF4F46E5));
      case TaskNotificationKind.rejectionApproved:
        return (Icons.cancel_outlined, TaskPalette.red);
      case TaskNotificationKind.rejectionDeclined:
        return (Icons.block_rounded, AppColors.textSecondary);
      case TaskNotificationKind.itemAssigned:
        return (Icons.swap_horiz_rounded, AppColors.primary);
      case TaskNotificationKind.other:
        return (Icons.notifications_none_rounded, AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconFor(item.kind);

    return Material(
      color: item.read ? AppColors.surface : const Color(0xFFF0F7FF),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.timeText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (!item.read) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: TaskPalette.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          for (final part in item.message)
                            TextSpan(
                              text: part.text,
                              style: part.bold
                                  ? const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (item.chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final chip in item.chips) _Chip(chip: chip),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final NotificationChip chip;

  const _Chip({required this.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            chip.kind == NotificationChipKind.lead
                ? Icons.people_outline_rounded
                : Icons.work_outline_rounded,
            size: 13,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            chip.label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
