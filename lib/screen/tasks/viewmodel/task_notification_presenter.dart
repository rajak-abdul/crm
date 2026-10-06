// ╔══════════════════════════════════════════════════════════════╗
// ║  lib/screen/tasks/viewmodel/task_notification_presenter.dart  ║
// ║  Presentation logic used by TaskViewModel: turns raw task     ║
// ║  notifications into grouped, display-ready items.             ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_notification_modal.dart';
import 'package:intl/intl.dart';

import 'task_notification_data.dart';

class TaskNotificationPresenter {
  const TaskNotificationPresenter();

  /// Only task notifications belong on the My Tasks screen.
  bool isTaskNotification(TaskNotificationModel n) =>
      (n.type ?? '').toLowerCase() == 'task';

  /// Only target notifications & reminders belong on the My Targets screen.
  bool isTargetNotification(TaskNotificationModel n) =>
      (n.type ?? '').toLowerCase() == 'target';

  /// Groups [notifications] (newest first) by day. [tasks] is used to
  /// resolve task names and linked lead/deal counts from meta.taskId.
  List<NotificationGroup> buildGroups(
    List<TaskNotificationModel> notifications,
    List<TaskModel> tasks,
  ) {
    final tasksById = {
      for (final t in tasks)
        if (t.id != null) t.id!: t,
    };

    final sorted = [...notifications]..sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        if (at == null || bt == null) return at == null ? 1 : -1;
        return bt.compareTo(at);
      });

    final groups = <String, List<TaskNotificationItem>>{};
    for (final n in sorted) {
      final label = _dayLabel(n.createdAt);
      groups.putIfAbsent(label, () => []).add(_toItem(n, tasksById));
    }

    return [
      for (final e in groups.entries) NotificationGroup(e.key, e.value),
    ];
  }

  // ============================================================
  // ITEM
  // ============================================================

  TaskNotificationItem _toItem(
    TaskNotificationModel n,
    Map<String, TaskModel> tasksById,
  ) {
    final meta = n.meta;
    final task = meta.taskId == null ? null : tasksById[meta.taskId];
    final message = n.message ?? '';
    final taskName = task?.title ?? _lastQuoted(message) ?? 'your task';

    late TaskNotificationKind kind;
    late String title;
    late List<MessagePart> parts;

    if (meta.taskCompletedBySelf) {
      kind = TaskNotificationKind.completed;
      title = 'Task completed';
      parts = [
        const MessagePart('You completed '),
        MessagePart(taskName, bold: true),
        const MessagePart('. Thank you for the great work!'),
      ];
    } else if (meta.taskAssigned) {
      kind = TaskNotificationKind.assigned;
      title = 'New task assigned';
      parts = [
        MessagePart('${_actor(message, 'assigned') ?? 'Your admin'} '
            'assigned you '),
        MessagePart(taskName, bold: true),
      ];
    } else if (meta.taskDueToday) {
      kind = TaskNotificationKind.dueToday;
      title = 'Task due today';
      parts = [
        MessagePart(taskName, bold: true),
        const MessagePart(' is due today'),
      ];
    } else if (meta.taskReminder) {
      kind = TaskNotificationKind.dueTomorrow;
      title = 'Due tomorrow';
      final due = task?.dueDate?.toUtc();
      parts = [
        MessagePart(taskName, bold: true),
        MessagePart(due == null
            ? ' is due tomorrow'
            : ' is due tomorrow, ${DateFormat('d MMM').format(due)}'),
      ];
    } else if (meta.reasonNoteReplied) {
      kind = TaskNotificationKind.adminReplied;
      title = 'Admin replied';
      final reply = RegExp(r'replied:\s*"([^"]*)"').firstMatch(message);
      parts = [
        MessagePart('${_actor(message, 'replied') ?? 'Your admin'} replied'),
        if (reply != null) MessagePart(' "${reply.group(1)}"'),
        const MessagePart(' on '),
        MessagePart(taskName, bold: true),
      ];
    } else if (meta.taskReactivated) {
      kind = TaskNotificationKind.keptWithYou;
      title = 'Task kept with you';
      final newDue =
          RegExp(r'New due date:\s*([^.]+)\.').firstMatch(message)?.group(1);
      parts = [
        const MessagePart('Your reported issue on '),
        MessagePart(taskName, bold: true),
        const MessagePart(' was reviewed and the task stays with you'),
        if (newDue != null) MessagePart('. New due date: ${newDue.trim()}'),
      ];
    } else if (meta.taskRejectionAction != null) {
      final approved = meta.taskRejectionAction == 'approve';
      kind = approved
          ? TaskNotificationKind.rejectionApproved
          : TaskNotificationKind.rejectionDeclined;
      title = approved ? 'Rejection approved' : 'Rejection declined';
      parts = [
        const MessagePart('Your request to reject '),
        MessagePart(taskName, bold: true),
        MessagePart(approved ? ' was approved' : ' was declined'),
      ];
    } else if (meta.leadOrDealAssigned) {
      kind = TaskNotificationKind.itemAssigned;
      final type = _capitalize(meta.itemType ?? 'item');
      title = meta.isReassignment
          ? '$type reassigned to you'
          : '$type assigned to you';
      parts = [
        MessagePart('${meta.actorName ?? 'Your admin'} '
            '${meta.isReassignment ? 'reassigned' : 'assigned'} '
            'the ${type.toLowerCase()} '),
        MessagePart(meta.itemName ?? '', bold: true),
        const MessagePart(' to you'),
      ];
    } else {
      kind = TaskNotificationKind.other;
      title = n.title ?? 'Notification';
      parts = [MessagePart(message)];
    }

    return TaskNotificationItem(
      id: n.id ?? '',
      kind: kind,
      title: title,
      message: parts,
      timeText: _formatTime(n.createdAt),
      read: n.read,
      chips: _chips(n, task),
    );
  }

  /// Linked item from meta when present; otherwise the task's linked
  /// deal/lead counts.
  List<NotificationChip> _chips(TaskNotificationModel n, TaskModel? task) {
    final meta = n.meta;

    if (meta.leadOrDealAssigned && (meta.itemName ?? '').isNotEmpty) {
      return [
        NotificationChip(
          meta.itemType == 'lead'
              ? NotificationChipKind.lead
              : NotificationChipKind.deal,
          '${_capitalize(meta.itemType ?? 'item')}: ${meta.itemName}',
        ),
      ];
    }

    if ((meta.linkedName ?? '').isNotEmpty) {
      final isDeal = meta.linkedType == 'deal';
      return [
        NotificationChip(
          isDeal ? NotificationChipKind.deal : NotificationChipKind.lead,
          '${isDeal ? 'Deal' : 'Lead'}: ${meta.linkedName}',
        ),
      ];
    }

    if (task == null) return const [];

    String count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
    return [
      if (task.dealRefs.isNotEmpty)
        NotificationChip(
            NotificationChipKind.deal, count(task.dealRefs.length, 'deal')),
      if (task.leadRefs.isNotEmpty)
        NotificationChip(
            NotificationChipKind.lead, count(task.leadRefs.length, 'lead')),
    ];
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Last "quoted" text in the message — the backend quotes task names.
  String? _lastQuoted(String message) {
    final matches = RegExp(r'"([^"]+)"').allMatches(message);
    return matches.isEmpty ? null : matches.last.group(1);
  }

  /// "Admin kishore kishore assigned …" → "kishore kishore".
  String? _actor(String message, String verb) {
    final m = RegExp('^(?:Admin\\s+)?(.+?)\\s+$verb').firstMatch(message);
    return m?.group(1);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('h:mm a')
        .format(dt.toLocal())
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');
  }

  String _dayLabel(DateTime? dt) {
    if (dt == null) return 'Earlier';
    // Compare calendar days as UTC dates so DST shifts can't skew the
    // day difference.
    final local = dt.toLocal();
    final day = DateTime.utc(local.year, local.month, local.day);
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(local);
  }
}
