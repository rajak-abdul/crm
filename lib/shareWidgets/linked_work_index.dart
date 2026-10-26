// lib/shareWidgets/linked_work_index.dart
//
// Which tasks / targets are linked to each lead and deal, so the lead and
// deal lists can show a "☑ 1 ◎ 1" pill and, on tap, the Linked Work
// Details popup. Built from two list calls (GET /tasks, GET /targets/my)
// instead of one linked-endpoint call per card, and topped up per record
// whenever its "Tasks & Targets" tab loads.

import 'package:crm_app/screen/tasks/api_service/target_api_service.dart';
import 'package:crm_app/screen/tasks/api_service/task_api_service.dart';
import 'package:crm_app/screen/tasks/model/target/target_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/repository/target_repository.dart';
import 'package:crm_app/screen/tasks/repository/task_repository.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:crm_app/utils/permission_helper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Which record a linked-work lookup or tab is for — also the `:kind`
/// path segment.
enum LinkedWorkKind {
  lead('lead'),
  deal('deal');

  final String path;
  const LinkedWorkKind(this.path);
}

/// Icon colours from the design: blue check box = task, purple bullseye
/// = target.
const kLinkedTaskColor = Color(0xFF2563EB);
const kLinkedTargetColor = Color(0xFF9333EA);

typedef _ByRecord<T> = Map<LinkedWorkKind, Map<String, List<T>>>;

class LinkedWorkIndex {
  final _ByRecord<TaskModel> _tasks;
  final _ByRecord<TargetModel> _targets;

  const LinkedWorkIndex._(this._tasks, this._targets);

  static const empty = LinkedWorkIndex._({}, {});

  List<TaskModel> tasksFor(LinkedWorkKind kind, String id) =>
      _tasks[kind]?[id] ?? const [];

  List<TargetModel> targetsFor(LinkedWorkKind kind, String id) =>
      _targets[kind]?[id] ?? const [];

  /// Ids of every [kind] record with an active task ([tasks] true) or an
  /// active target ([tasks] false).
  Set<String> activeIds(LinkedWorkKind kind, {required bool tasks}) => tasks
      ? {
          for (final e in (_tasks[kind] ?? const {}).entries)
            if (e.value.any(isActiveTask)) e.key,
        }
      : {
          for (final e in (_targets[kind] ?? const {}).entries)
            if (e.value.any(isActiveTarget)) e.key,
        };

  /// A linked task that's still open (not Completed / Rejected).
  bool hasActiveTask(LinkedWorkKind kind, String id) =>
      tasksFor(kind, id).any((t) => isActiveTask(t));

  /// A linked target that's still running: not Completed / Rejected and
  /// its end day (midnight UTC) not yet passed.
  bool hasActiveTarget(LinkedWorkKind kind, String id) =>
      targetsFor(kind, id).any((t) => isActiveTarget(t));

  static bool isActiveTask(TaskModel t) {
    final s = (t.status ?? '').trim().toLowerCase();
    return t.archived != true && s != 'completed' && s != 'rejected';
  }

  static bool isActiveTarget(TargetModel t) {
    final s = (t.status ?? '').trim().toLowerCase();
    if (s == 'completed' || s == 'rejected') return false;
    final end = t.endDate?.toUtc();
    if (end == null) return true;
    final now = DateTime.now().toUtc();
    return !DateTime.utc(end.year, end.month, end.day)
        .isBefore(DateTime.utc(now.year, now.month, now.day));
  }

  static final ValueNotifier<LinkedWorkIndex> notifier =
      ValueNotifier(empty);

  static Future<void>? _inFlight;

  /// Rebuilds the index from the user's tasks and targets. Concurrent calls
  /// share one request; a side that fails keeps its previous entries.
  static Future<void> refresh() => _inFlight ??= _refresh().whenComplete(
        () => _inFlight = null,
      );

  static Future<void> _refresh() async {
    final current = notifier.value;
    final canTasks = PermissionHelper.can('assigned_tasks');
    final canTargets = PermissionHelper.can('my_targets');

    final results = await Future.wait<Object?>([
      if (canTasks)
        TaskRepository(TaskApiService(Dio()))
            .getMyTasks()
            .then<Object?>((v) => v)
            .catchError((Object e) => null)
      else
        Future.value(<TaskModel>[]),
      if (canTargets)
        TargetRepository(TargetApiService(Dio()))
            .getMyTargets()
            .then<Object?>((v) => v)
            .catchError((Object e) => null)
      else
        Future.value(<TargetModel>[]),
    ]);

    var tasks = current._tasks;
    final taskList = results[0];
    if (taskList is List<TaskModel>) {
      tasks = {for (final k in LinkedWorkKind.values) k: {}};
      for (final t in taskList) {
        if (t.archived == true) continue;
        void add(LinkedWorkKind kind, String? id) {
          if (id == null || id.isEmpty) return;
          final list = tasks[kind]!.putIfAbsent(id, () => []);
          if (!list.any((x) => x.id == t.id)) list.add(t);
        }

        add(LinkedWorkKind.lead, t.leadRef?.id);
        for (final l in t.leadRefs) {
          add(LinkedWorkKind.lead, l.id);
        }
        add(LinkedWorkKind.deal, t.dealRef?.id);
        for (final d in t.dealRefs) {
          add(LinkedWorkKind.deal, d.id);
        }
      }
    }

    var targets = current._targets;
    final targetList = results[1];
    if (targetList is List<TargetModel>) {
      targets = {for (final k in LinkedWorkKind.values) k: {}};
      for (final t in targetList) {
        void add(LinkedWorkKind kind, String? id) {
          if (id == null || id.isEmpty) return;
          final list = targets[kind]!.putIfAbsent(id, () => []);
          if (!list.any((x) => x.id == t.id)) list.add(t);
        }

        for (final l in t.linkedLeads) {
          add(LinkedWorkKind.lead, l.id);
        }
        for (final d in t.linkedDeals) {
          add(LinkedWorkKind.deal, d.id);
        }
      }
    }

    notifier.value = LinkedWorkIndex._(tasks, targets);
  }

  /// Records what one record's "Tasks & Targets" tab loaded, so its card
  /// matches even when the record isn't in the user's own tasks/targets.
  /// A null list leaves that side unchanged.
  static void setFor(
    LinkedWorkKind kind,
    String id, {
    List<TaskModel>? tasks,
    List<TargetModel>? targets,
  }) {
    final v = notifier.value;
    _ByRecord<T> put<T>(_ByRecord<T> src, List<T>? items) {
      if (items == null) return src;
      final copy = {for (final e in src.entries) e.key: {...e.value}};
      final forKind = copy.putIfAbsent(kind, () => {});
      if (items.isEmpty) {
        forKind.remove(id);
      } else {
        forKind[id] = List.of(items);
      }
      return copy;
    }

    notifier.value =
        LinkedWorkIndex._(put(v._tasks, tasks), put(v._targets, targets));
  }
}

/// "☑ 1 ◎ 1" pill for one lead or deal card; empty when nothing is linked.
/// Tapping it opens the Linked Work Details popup.
class LinkedWorkBadges extends StatelessWidget {
  final LinkedWorkKind kind;
  final String id;
  final double size;

  const LinkedWorkBadges({
    super.key,
    required this.kind,
    required this.id,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LinkedWorkIndex>(
      valueListenable: LinkedWorkIndex.notifier,
      builder: (_, index, __) {
        final tasks = index.tasksFor(kind, id).length;
        final targets = index.targetsFor(kind, id).length;
        if (tasks == 0 && targets == 0) return const SizedBox.shrink();

        // A count only when there's more than one; a single item is just
        // its icon.
        Widget count(int n, Color color) => n < 2
            ? const SizedBox.shrink()
            : Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            );

        return Material(
          color: AppColors.background,
          shape: StadiumBorder(
            side: BorderSide(color: AppColors.border.withOpacity(0.8)),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => showLinkedWorkDetails(context, kind: kind, id: id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tasks > 0) ...[
                    Icon(
                      Icons.check_box_outlined,
                      size: size,
                      color: kLinkedTaskColor,
                    ),
                    count(tasks, kLinkedTaskColor),
                  ],
                  if (tasks > 0 && targets > 0) const SizedBox(width: 6),
                  if (targets > 0) ...[
                    TargetIcon(size: size),
                    count(targets, kLinkedTargetColor),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LINKED WORK DETAILS POPUP — rail list + countdown
// ══════════════════════════════════════════════════════════════

/// Tasks then targets linked to one record; tap outside (or back) to close.
Future<void> showLinkedWorkDetails(
  BuildContext context, {
  required LinkedWorkKind kind,
  required String id,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _LinkedWorkDialog(kind: kind, id: id),
  );
}

class _LinkedWorkDialog extends StatelessWidget {
  final LinkedWorkKind kind;
  final String id;
  const _LinkedWorkDialog({required this.kind, required this.id});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
        child: ValueListenableBuilder<LinkedWorkIndex>(
          valueListenable: LinkedWorkIndex.notifier,
          builder: (_, index, __) {
            final tasks = index.tasksFor(kind, id);
            final targets = index.targetsFor(kind, id);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.link_rounded,
                          size: 19,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Linked Work Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Rail list ──
                Flexible(
                  child: tasks.isEmpty && targets.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 22),
                          child: Text(
                            'No linked tasks or targets.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                          children: [
                            for (final t in tasks)
                              _RailRow.task(
                                t,
                                due: (kind == LinkedWorkKind.lead
                                        ? t.leadDueDates
                                        : t.dealDueDates)[id] ??
                                    t.dueDate,
                              ),
                            for (final t in targets) _RailRow.target(t),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One rail-list card: coloured left rail, icon + name, date, countdown pill.
class _RailRow extends StatelessWidget {
  final Color color;
  final Widget icon;
  final String title;
  final String dateText;
  final _Countdown countdown;

  const _RailRow._({
    required this.color,
    required this.icon,
    required this.title,
    required this.dateText,
    required this.countdown,
  });

  factory _RailRow.task(TaskModel t, {DateTime? due}) {
    final status = (t.status ?? '').toLowerCase();
    return _RailRow._(
      color: kLinkedTaskColor,
      icon: const Icon(
        Icons.check_box_outlined,
        size: 17,
        color: kLinkedTaskColor,
      ),
      title: (t.title ?? '').trim().isEmpty ? 'Untitled task' : t.title!,
      dateText: due == null
          ? 'No due date'
          : DateFormat('MMM d, y · h:mm a').format(due.toLocal()),
      countdown: status == 'completed'
          ? const _Countdown('Completed', AppColors.success)
          : status == 'rejected'
              ? const _Countdown('Rejected', AppColors.textSecondary)
              : _Countdown.until(due, accent: kLinkedTaskColor),
    );
  }

  factory _RailRow.target(TargetModel t) {
    final status = (t.status ?? '').toLowerCase();
    final end = t.endDate;
    final title = (t.title ?? '').trim();
    return _RailRow._(
      color: kLinkedTargetColor,
      icon: const TargetIcon(size: 17),
      title: title.isNotEmpty ? title : 'Target',
      // Date-only field (midnight UTC) — show the UTC day.
      dateText: end == null
          ? 'No end date'
          : DateFormat('MMM d, y').format(end.isUtc ? end : end.toUtc()),
      countdown: status == 'completed'
          ? const _Countdown('Completed', AppColors.success)
          : _Countdown.until(end, accent: kLinkedTargetColor, isTarget: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left rail
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 3.5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CountdownPill(countdown),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Countdown text + colour: "Due today", "28 days left", "Overdue · 3 days".
class _Countdown {
  final String text;
  final Color color;
  const _Countdown(this.text, this.color);

  /// Compared on the UTC day, like the Task screen (dates arrive as
  /// midnight UTC).
  factory _Countdown.until(
    DateTime? date, {
    required Color accent,
    bool isTarget = false,
  }) {
    if (date == null) return const _Countdown('No date', AppColors.textHint);
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final d = date.toUtc();
    final day = DateTime.utc(d.year, d.month, d.day);
    final days = day.difference(today).inDays;

    if (days == 0) {
      return _Countdown(isTarget ? 'Ends today' : 'Due today', AppColors.danger);
    }
    if (days < 0) {
      final n = -days;
      return _Countdown(
        isTarget
            ? 'Ended'
            : 'Overdue · $n day${n == 1 ? '' : 's'}',
        isTarget ? AppColors.textSecondary : AppColors.danger,
      );
    }
    return _Countdown('$days day${days == 1 ? '' : 's'} left', accent);
  }
}

class _CountdownPill extends StatelessWidget {
  final _Countdown c;
  const _CountdownPill(this.c);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: c.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          c.text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.color,
          ),
        ),
      );
}

/// Purple bullseye (two rings + centre dot) used for targets.
class TargetIcon extends StatelessWidget {
  final double size;
  final Color color;
  const TargetIcon({
    super.key,
    this.size = 15,
    this.color = kLinkedTargetColor,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BullseyePainter(color)),
      );
}

class _BullseyePainter extends CustomPainter {
  final Color color;
  _BullseyePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final stroke = r * 0.17;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(c, r * 0.92 - stroke / 2, ring);
    canvas.drawCircle(c, r * 0.55 - stroke / 2, ring);
    canvas.drawCircle(c, r * 0.17, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BullseyePainter old) => old.color != color;
}
