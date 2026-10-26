// ╔══════════════════════════════════════════════════════════════╗
// ║       lib/screen/tasks/viewmodel/task_view_model.dart         ║
// ║  VIEWMODEL (Cubit) — UI state + presentation logic.           ║
// ║  Talks only to the Repository: no Dio, no JSON, no widgets.   ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:async';

import 'package:crm_app/screen/deals/modal/deal_modal.dart'
    show DealConstants;
import 'package:crm_app/screen/tasks/model/target/target_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_notification_modal.dart';
import 'package:crm_app/screen/tasks/repository/task_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'task_notification_presenter.dart';
import 'task_state.dart';

class TaskViewModel extends Cubit<TaskState> {
  final TaskRepository repository;
  String? _customStartDate;
String? _customEndDate;
int _periodRequestId = 0;

  static const _notificationPresenter = TaskNotificationPresenter();

  /// Tasks whose delay reason was sent this session — not asked again
  /// even if the reload after sending fails.
  final _reasonSent = <String>{};

  TaskViewModel(this.repository) : super(const TaskState());

  // ============================================================
  // LOAD / REFRESH
  // ============================================================

  Future<void> load() async {
    emit(state.copyWith(status: TaskViewStatus.loading));

    // Notifications load alongside tasks but never fail the task list.
    final notifications = _loadNotifications();

    try {
      await _fetch();
    } catch (e) {
      emit(state.copyWith(
        status: TaskViewStatus.error,
        errorMessage: e.toString(),
      ));
    }

    await notifications;
  }

  /// Pull-to-refresh: keeps the current list on screen. Returns an error
  /// message on failure so the View can show it without losing the list.
  Future<String?> refresh() async {
    if (!state.hasData) {
      await load();
      return null;
    }

    final notifications = _loadNotifications(silent: true);

    try {
      await _fetch();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      await notifications;
    }
  }

  Future<void> reloadNotifications() => _loadNotifications();

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(notificationStatus: TaskViewStatus.loading));
    }

    try {
      final all = await repository.getMyNotifications(limit: 100);
      final taskOnly =
          all.where(_notificationPresenter.isTaskNotification).toList();

      if (isClosed) return;
      emit(_withNotifications(state.copyWith(
        notificationStatus:
            taskOnly.isEmpty ? TaskViewStatus.empty : TaskViewStatus.success,
        notifications: taskOnly,
      )));
    } catch (e) {
      if (isClosed) return;
      // Keep any list already on screen after a failed silent refresh.
      if (silent && state.notifications.isNotEmpty) return;
      emit(state.copyWith(
        notificationStatus: TaskViewStatus.error,
        notificationError: e.toString(),
      ));
    }
  }

Future<void> _fetch() async {
  final results = await Future.wait<Object>([
    repository.getMyTasks(),
    repository.getMyDashboardStats(
      period: state.period,
      startDate: _customStartDate,
      endDate: _customEndDate,
    ),
  ]);

  if (isClosed) return;

  final tasks = results[0] as List<TaskModel>;
  final stats = results[1] as MyDashboardStatsModel;

  emit(_withDerived(
    state.copyWith(
      status: tasks.isEmpty
          ? TaskViewStatus.empty
          : TaskViewStatus.success,
      tasks: tasks,
      stats: stats,
    ),
  ));
}
  // ============================================================
  // USER ACTIONS
  // ============================================================

  /// Reloads only the overview stats for [period]. Returns an error
  /// message on failure (the previous period and stats are kept).
Future<String?> changePeriod(
  String period, {
  String? startDate,
  String? endDate,
}) async {
  if (period == 'custom' &&
      (startDate == null || endDate == null)) {
    return 'Please select a start date and end date.';
  }

  if (period == state.period &&
      period != 'custom') {
    return null;
  }

  final requestId = ++_periodRequestId;

  try {
    final stats = await repository.getMyDashboardStats(
      period: period,
      startDate: startDate,
      endDate: endDate,
    );

    if (isClosed || requestId != _periodRequestId) {
      return null;
    }

    if (period == 'custom') {
      _customStartDate = startDate;
      _customEndDate = endDate;
    } else {
      _customStartDate = null;
      _customEndDate = null;
    }

    emit(state.copyWith(
      stats: stats,
      period: period,
    ));

    return null;
  } catch (e) {
    if (requestId != _periodRequestId) return null;
    return e.toString();
  }
}
  void selectFilter(TaskFilter filter) {
    if (filter == state.filter) return;
    emit(_withDerived(state.copyWith(filter: filter)));
  }

  /// Moves [task] to [stage] (PUT /tasks/:id), then reloads. In Hold sends
  /// [reason] as holdReason — the backend may keep the status until the
  /// admin approves (holdRequested). Returns an error message on failure.
  Future<String?> moveTask(
    TaskModel task,
    TaskStage stage, {
    String? reason,
  }) async {
    final taskId = task.id;
    if (taskId == null) return 'Task not found';

    try {
      await repository.updateTaskStatus(
        taskId: taskId,
        status: stage.status,
        reason: reason,
      );
    } catch (e) {
      return e.toString();
    }

    // The move is saved; a failed reload only leaves the board stale.
    await refresh();
    return null;
  }

  /// Sends why [task] is overdue (POST /tasks/:id/reason-note with
  /// itemType 'task'), drops it from [TaskState.overdueTasks] and
  /// reloads. Returns an error message on failure.
  Future<String?> submitOverdueReason(TaskModel task, String reason) async {
    final taskId = task.id;
    if (taskId == null) return 'Task not found';

    final note = reason.trim();
    if (note.isEmpty) return 'Please add a reason';

    try {
      await repository.reportTaskIssue(
        taskId: taskId,
        note: note,
        itemType: 'task',
        itemName: task.title,
      );
    } catch (e) {
      return e.toString();
    }

    _reasonSent.add(taskId);
    emit(_withDerived(state));
    // The reason is saved — don't hold the popup open for the reload; a
    // failed reload only leaves the list stale.
    unawaited(refresh());
    return null;
  }

  void setViewMode(TaskViewMode mode) {
    if (mode == state.viewMode) return;
    emit(state.copyWith(viewMode: mode));
  }

  /// Marks one notification read (optimistic; reverted on failure).
  Future<void> markNotificationRead(String id) async {
    final target = state.notifications.where((n) => n.id == id);
    if (target.isEmpty || target.first.read) return;

    final before = state.notifications;
    _setNotifications(
      [for (final n in before) n.id == id ? n.copyWith(read: true) : n],
    );

    try {
      await repository.markNotificationRead(id);
    } catch (_) {
      if (!isClosed) _setNotifications(before);
    }
  }

  /// Marks every unread notification read. Returns an error message on
  /// failure (the unread ones are restored).
  Future<String?> markAllNotificationsRead() async {
    final before = state.notifications;
    final unreadIds = [
      for (final n in before)
        if (!n.read && n.id != null) n.id!,
    ];
    if (unreadIds.isEmpty) return null;

    _setNotifications([for (final n in before) n.copyWith(read: true)]);

    try {
      await Future.wait(unreadIds.map(repository.markNotificationRead));
      return null;
    } catch (e) {
      if (!isClosed) _setNotifications(before);
      return e.toString();
    }
  }

  /// Removes a notification (optimistic — the row disappears at once and
  /// comes back if the delete fails). Returns an error message on failure.
  Future<String?> deleteNotification(String id) async {
    final index = state.notifications.indexWhere((n) => n.id == id);
    if (index < 0) return null;
    final removed = state.notifications[index];

    final remaining = [...state.notifications]..removeAt(index);
    emit(_withNotifications(state.copyWith(
      notifications: remaining,
      notificationStatus:
          remaining.isEmpty ? TaskViewStatus.empty : TaskViewStatus.success,
    )));

    try {
      await repository.deleteNotification(id);
      return null;
    } catch (e) {
      // Put back only this item — other deletes may have happened since.
      if (!isClosed && !state.notifications.any((n) => n.id == id)) {
        final restored = [...state.notifications]
          ..insert(index.clamp(0, state.notifications.length), removed);
        emit(_withNotifications(state.copyWith(
          notifications: restored,
          notificationStatus: TaskViewStatus.success,
        )));
      }
      return e.toString();
    }
  }

  void _setNotifications(List<TaskNotificationModel> notifications) {
    emit(_withNotifications(state.copyWith(notifications: notifications)));
  }

  // ============================================================
  // PRESENTATION LOGIC
  // ============================================================

  TaskState _withDerived(TaskState s) {
    final filtered = s.tasks.where((t) => _matchesFilter(t, s.filter));

    // Task names in notifications come from the task list, so rebuild
    // them whenever tasks change.
    final cards = filtered.map(_toCardData).toList();

    return _withNotifications(s.copyWith(
      visibleTasks: cards,
      pipeline: [
        for (final stage in TaskStage.values)
          TaskPipelineColumn(stage, [
            for (final c in cards)
              if (TaskStage.fromStatus(c.task.status) == stage) c,
          ]),
      ],
      // Every task, whatever the filter.
      overdueTasks: s.tasks.where(_needsOverdueReason).toList()
        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!)),
    ));
  }

  /// Open, past its due day, and no task-level reason added since it
  /// went overdue (a reason note from before the due date doesn't count).
  bool _needsOverdueReason(TaskModel task) {
    final id = task.id;
    final overdueSince = _overdueSince(task);
    if (id == null || overdueSince == null || _reasonSent.contains(id)) {
      return false;
    }

    return !task.reasonNotes.any(
      (n) =>
          (n.itemType ?? '').toLowerCase() == 'task' &&
          n.addedAt != null &&
          !_calendarDay(n.addedAt!).isBefore(overdueSince),
    );
  }

  /// The day after the due date (when the task became overdue), or null
  /// when it isn't overdue. Same day rule as [_dueInfo]'s "Overdue" label.
  DateTime? _overdueSince(TaskModel task) {
    final status = (task.status ?? '').toLowerCase();
    if (status == 'completed' || status == 'rejected') return null;

    final d = task.dueDate?.toUtc();
    if (d == null) return null;

    final since = DateTime.utc(d.year, d.month, d.day + 1);
    return _calendarDay(DateTime.now()).isBefore(since) ? null : since;
  }

  /// [time]'s local calendar day as a UTC date, comparable with due days
  /// (stored as midnight UTC of the chosen day).
  static DateTime _calendarDay(DateTime time) {
    final local = time.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  TaskState _withNotifications(TaskState s) {
    return s.copyWith(
      notificationGroups:
          _notificationPresenter.buildGroups(s.notifications, s.tasks),
      unreadCount: s.notifications.where((n) => !n.read).length,
    );
  }

  bool _matchesFilter(TaskModel task, TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return true;
      // Assumption: "New Task" = not started yet.
      case TaskFilter.newTask:
        return (task.status ?? '').toLowerCase() == 'pending';
      // The notifications view doesn't list tasks.
      case TaskFilter.notifications:
        return true;
    }
  }

  TaskCardData _toCardData(TaskModel task) {
    // A linked lead counts once it is converted; a linked deal once it
    // reaches the "Closed Won" stage.
    final leadsDone = task.leadRefs
        .where((l) =>
            (l.status ?? '').toLowerCase() == 'converted' ||
            task.convertedDealRefsByLeadId.containsKey(l.id))
        .length;

    final dealsDone = task.dealRefs
        .where((d) =>
            DealConstants.canonicalStage(d.stage ?? '') == 'Closed Won')
        .length;

    final total = task.leadRefs.length + task.dealRefs.length;
    final percent =
        total == 0 ? 0 : ((leadsDone + dealsDone) * 100 / total).round();

    final due = _dueInfo(task);

    return TaskCardData(
      task: task,
      assignedBy: task.createdBy?.fullName ?? '',
      dueLabel: due?.label,
      dueSuffix: due?.suffix,
      dueTone: due?.tone ?? DueTone.normal,
      progressPercent: percent,
      leadsDone: leadsDone,
      leadsTotal: task.leadRefs.length,
      dealsDone: dealsDone,
      dealsTotal: task.dealRefs.length,
      pendingAdminReview: _isPendingAdminReview(task),
      linkedSummary: _linkedSummary(task),
    );
  }

  String _linkedSummary(TaskModel task) {
    String count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

    final summary = [
      if (task.dealRefs.isNotEmpty) count(task.dealRefs.length, 'deal'),
      if (task.leadRefs.isNotEmpty) count(task.leadRefs.length, 'lead'),
    ].join(', ');

    return summary.isEmpty ? 'No linked items' : summary;
  }

  // Due dates are stored as midnight UTC for the chosen calendar day,
  // so compare on the UTC date — converting to local time would shift
  // the day for timezones behind UTC.
  ({String label, String? suffix, DueTone tone})? _dueInfo(TaskModel task) {
    final d = task.dueDate?.toUtc();
    if (d == null) return null;

    final due = DateTime.utc(d.year, d.month, d.day);
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final diff = due.difference(today).inDays;
    final dateText = DateFormat('dd MMM').format(due);

    // Closed tasks can't be overdue — just show the date.
    final status = (task.status ?? '').toLowerCase();
    if (status == 'completed' || status == 'rejected') {
      return (label: 'Due $dateText', suffix: null, tone: DueTone.normal);
    }
    if (diff < 0) {
      final days = -diff;
      return (
        label: 'Overdue $days ${days == 1 ? 'day' : 'days'}',
        suffix: dateText,
        tone: DueTone.overdue,
      );
    }
    if (diff == 0) {
      return (label: 'Due today', suffix: null, tone: DueTone.soon);
    }
    if (diff == 1) {
      return (label: 'Due tomorrow', suffix: null, tone: DueTone.soon);
    }
    return (label: 'Due $dateText', suffix: null, tone: DueTone.normal);
  }

  /// An issue report, rejection or hold request is waiting on the admin.
  bool _isPendingAdminReview(TaskModel task) =>
      task.reasonNotes
          .any((n) => (n.status ?? '').toLowerCase() == 'pending') ||
      task.rejectionRequested == true ||
      task.holdRequested == true;
}
