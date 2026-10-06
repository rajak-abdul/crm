// ╔══════════════════════════════════════════════════════════════╗
// ║    lib/screen/tasks/viewmodel/task_notification_data.dart     ║
// ║  Display-ready notification types built by the ViewModel.     ║
// ╚══════════════════════════════════════════════════════════════╝

/// What happened — the View maps this to an icon and colour.
enum TaskNotificationKind {
  completed,
  assigned,
  dueToday,
  dueTomorrow,
  adminReplied,
  keptWithYou,
  rejectionApproved,
  rejectionDeclined,
  itemAssigned,
  other,
}

enum NotificationChipKind { lead, deal }

class NotificationChip {
  final NotificationChipKind kind;
  final String label; // e.g. "Lead: NCUBE NEET", "2 deals"

  const NotificationChip(this.kind, this.label);
}

/// A piece of the message; [bold] parts are names (task, deal, …).
class MessagePart {
  final String text;
  final bool bold;

  const MessagePart(this.text, {this.bold = false});
}

class TaskNotificationItem {
  final String id;
  final TaskNotificationKind kind;
  final String title;
  final List<MessagePart> message;
  final String timeText; // e.g. "1:19 pm"
  final bool read;
  final List<NotificationChip> chips;

  const TaskNotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.timeText,
    required this.read,
    required this.chips,
  });
}

class NotificationGroup {
  final String label; // "Today", "Yesterday", "Mon, 28 Sep"
  final List<TaskNotificationItem> items;

  const NotificationGroup(this.label, this.items);
}
