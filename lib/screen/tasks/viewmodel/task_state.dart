// ╔══════════════════════════════════════════════════════════════╗
// ║          lib/screen/tasks/viewmodel/task_state.dart           ║
// ║  UI state exposed by TaskViewModel to the View.               ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/model/target/target_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_notification_modal.dart';

import 'task_notification_data.dart';

export 'task_notification_data.dart';

enum TaskViewStatus { initial, loading, success, empty, error }

enum TaskFilter { all, newTask, notifications }

enum TaskViewMode { grid, list, pipeline }

/// Pipeline columns, in board order. [status] is the backend value sent
/// with PUT /tasks/:id.
enum TaskStage {
  newTask('New', 'Pending'),
  inProgress('In Progress', 'In Progress'),
  inHold('In Hold', 'In Hold'),
  completed('Completed', 'Completed'),
  rejected('Rejected', 'Rejected');

  final String label;
  final String status;

  const TaskStage(this.label, this.status);

  /// Unknown / missing statuses land in New.
  static TaskStage fromStatus(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    for (final stage in values) {
      if (stage.status.toLowerCase() == s) return stage;
    }
    return newTask;
  }

  /// Targets use "New" (not "Pending") for the first stage; the rest match.
  String get targetStatus => this == newTask ? 'New' : status;

  /// Target status → column. "Active" counts as In Progress; unknown
  /// statuses (e.g. "Expired") land in New with their own badge.
  static TaskStage fromTargetStatus(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    if (s == 'active') return inProgress;
    for (final stage in values) {
      if (stage.targetStatus.toLowerCase() == s) return stage;
    }
    return newTask;
  }
}

/// One pipeline column with its cards — [T] is TaskCardData on the Task
/// screen and TargetCardData on the Target screen.
class TaskPipelineColumn<T> {
  final TaskStage stage;
  final List<T> items;

  const TaskPipelineColumn(this.stage, this.items);
}

/// How urgent a due date is — the View maps this to a colour.
enum DueTone { normal, soon, overdue }

/// Everything a task card/row needs, already computed for display.
class TaskCardData {
  final TaskModel task;
  final String assignedBy;

  final String? dueLabel; // e.g. "Due tomorrow", "Overdue 6 days"
  final String? dueSuffix; // e.g. "23 Sep" (shown after overdue label)
  final DueTone dueTone;

  final int progressPercent;
  final int leadsDone;
  final int leadsTotal;
  final int dealsDone;
  final int dealsTotal;

  final bool pendingAdminReview;

  /// e.g. "2 deals, 2 leads", "3 leads", "No linked items".
  final String linkedSummary;

  const TaskCardData({
    required this.task,
    required this.assignedBy,
    required this.dueLabel,
    required this.dueSuffix,
    required this.dueTone,
    required this.progressPercent,
    required this.leadsDone,
    required this.leadsTotal,
    required this.dealsDone,
    required this.dealsTotal,
    required this.pendingAdminReview,
    required this.linkedSummary,
  });
}

class TaskState {
  final TaskViewStatus status;
  final String? errorMessage;

  // Source data from the repository.
  final List<TaskModel> tasks;
  final MyDashboardStatsModel stats;

  // Period sent to /targets/my-dashboard-stats ('all', 'monthly', 'weekly').
  final String period;

  // User selections.
  final TaskFilter filter;
  final TaskViewMode viewMode;

  // Derived for display — recomputed by the ViewModel whenever
  // tasks or filter change.
  final List<TaskCardData> visibleTasks;

  /// Pipeline board — every stage, even empty ones.
  final List<TaskPipelineColumn<TaskCardData>> pipeline;

  // Notifications — loaded separately so a failure never hides tasks.
  final TaskViewStatus notificationStatus;
  final String? notificationError;
  final List<TaskNotificationModel> notifications; // task-type only
  final List<NotificationGroup> notificationGroups;
  final int unreadCount;

  const TaskState({
    this.status = TaskViewStatus.initial,
    this.errorMessage,
    this.tasks = const [],
    this.stats = const MyDashboardStatsModel(),
    this.period = 'all',
    this.filter = TaskFilter.all,
    this.viewMode = TaskViewMode.grid,
    this.visibleTasks = const [],
    this.pipeline = const [],
    this.notificationStatus = TaskViewStatus.initial,
    this.notificationError,
    this.notifications = const [],
    this.notificationGroups = const [],
    this.unreadCount = 0,
  });

  bool get hasData =>
      status == TaskViewStatus.success || status == TaskViewStatus.empty;

  // Error messages are only shown while their status is `error`, so they
  // can safely be kept across copies.
  TaskState copyWith({
    TaskViewStatus? status,
    String? errorMessage,
    List<TaskModel>? tasks,
    MyDashboardStatsModel? stats,
    String? period,
    TaskFilter? filter,
    TaskViewMode? viewMode,
    List<TaskCardData>? visibleTasks,
    List<TaskPipelineColumn<TaskCardData>>? pipeline,
    TaskViewStatus? notificationStatus,
    String? notificationError,
    List<TaskNotificationModel>? notifications,
    List<NotificationGroup>? notificationGroups,
    int? unreadCount,
  }) {
    return TaskState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      tasks: tasks ?? this.tasks,
      stats: stats ?? this.stats,
      period: period ?? this.period,
      filter: filter ?? this.filter,
      viewMode: viewMode ?? this.viewMode,
      visibleTasks: visibleTasks ?? this.visibleTasks,
      pipeline: pipeline ?? this.pipeline,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      notificationError: notificationError ?? this.notificationError,
      notifications: notifications ?? this.notifications,
      notificationGroups: notificationGroups ?? this.notificationGroups,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
