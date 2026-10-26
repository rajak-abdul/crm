// lib/shareWidgets/linked_work_tab.dart
//
// "Tasks & Targets" tab for a lead or deal detail sheet: the tasks and
// targets linked to that one record, as ticket cards.
//
// Data: GET /tasks/linked/{lead|deal}/:id and
//       GET /targets/linked/{lead|deal}/:id (tasks module repositories).
// If a linked endpoint 404s, falls back to GET /tasks · GET /targets/my
// filtered to items referencing the record.

import 'package:crm_app/screen/tasks/api_service/target_api_service.dart';
import 'package:crm_app/screen/tasks/api_service/task_api_service.dart';
import 'package:crm_app/screen/tasks/model/target/target_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/repository/target_repository.dart';
import 'package:crm_app/screen/tasks/repository/task_repository.dart';
import 'package:crm_app/shareWidgets/linked_work_index.dart';

export 'package:crm_app/shareWidgets/linked_work_index.dart'
    show LinkedWorkKind;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const double _stubWidth = 92;
const double _notch = 14;


/// The "Tasks & Targets" tab page: pull-to-refresh, and kept alive so
/// switching tabs doesn't refetch.
class LinkedWorkTab extends StatefulWidget {
  final LinkedWorkKind kind;
  final String id;

  /// Role permissions: assigned_tasks → tasks, my_targets → targets.
  final bool showTasks;
  final bool showTargets;

  const LinkedWorkTab({
    super.key,
    required this.kind,
    required this.id,
    this.showTasks = true,
    this.showTargets = true,
  });

  /// Tab label for the sections shown.
  static String labelFor({required bool tasks, required bool targets}) =>
      tasks && targets ? 'Tasks & Targets' : (tasks ? 'Tasks' : 'Targets');

  @override
  State<LinkedWorkTab> createState() => _LinkedWorkTabState();
}

class _LinkedWorkTabState extends State<LinkedWorkTab>
    with AutomaticKeepAliveClientMixin {
  final _sectionKey = GlobalKey<_LinkedWorkSectionState>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          _sectionKey.currentState?._load(silent: true) ?? Future.value(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _LinkedWorkSection(
            key: _sectionKey,
            kind: widget.kind,
            id: widget.id,
            showTasks: widget.showTasks,
            showTargets: widget.showTargets,
          ),
        ],
      ),
    );
  }
}

class _LinkedWorkSection extends StatefulWidget {
  final LinkedWorkKind kind;
  final String id;
  final bool showTasks;
  final bool showTargets;
  const _LinkedWorkSection({
    super.key,
    required this.kind,
    required this.id,
    required this.showTasks,
    required this.showTargets,
  });

  @override
  State<_LinkedWorkSection> createState() => _LinkedWorkSectionState();
}

class _LinkedWorkSectionState extends State<_LinkedWorkSection> {
  final _tasksRepo = TaskRepository(TaskApiService(Dio()));
  final _targetsRepo = TargetRepository(TargetApiService(Dio()));

  bool _loading = true;
  List<TaskModel> _tasks = const [];
  List<TargetModel> _targets = const [];
  String? _tasksError;
  String? _targetsError;

  bool get _isLead => widget.kind == LinkedWorkKind.lead;
  String get _noun => _isLead ? 'lead' : 'deal';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Tasks and targets load in parallel; one failing doesn't hide the other.
  /// [silent] (pull-to-refresh) keeps the current cards instead of spinners.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _tasksError = null;
        _targetsError = null;
      });
    }

    // A section the role can't see isn't fetched at all.
    final results = await Future.wait<Object>([
      (widget.showTasks ? _fetchTasks() : Future.value(<TaskModel>[]))
          .then<Object>((v) => v)
          .catchError((Object e) => e),
      (widget.showTargets ? _fetchTargets() : Future.value(<TargetModel>[]))
          .then<Object>((v) => v)
          .catchError((Object e) => e),
    ]);

    if (!mounted) return;
    setState(() {
      _loading = false;
      final tasks = results[0];
      final targets = results[1];
      if (tasks is List<TaskModel>) {
        _tasks = tasks.where((t) => t.archived != true).toList();
        _tasksError = null;
      } else {
        _tasksError = tasks.toString();
      }
      if (targets is List<TargetModel>) {
        _targets = targets;
        _targetsError = null;
      } else {
        _targetsError = targets.toString();
      }
    });

    // Keep the list-card icons in step with what this record really has.
    LinkedWorkIndex.setFor(
      widget.kind,
      widget.id,
      tasks: widget.showTasks && results[0] is List<TaskModel>
          ? _tasks
          : null,
      targets: widget.showTargets && results[1] is List<TargetModel>
          ? _targets
          : null,
    );
  }

  Future<List<TaskModel>> _fetchTasks() async {
    final id = widget.id;
    try {
      return await _tasksRepo.getLinkedTasks(kind: widget.kind.path, id: id);
    } on TaskApiException catch (e) {
      if (e.statusCode != 404) rethrow;
      // Linked endpoint missing → filter the user's own tasks.
      final all = await _tasksRepo.getMyTasks();
      return all
          .where((t) => _isLead
              ? t.leadRef?.id == id || t.leadRefs.any((l) => l.id == id)
              : t.dealRef?.id == id || t.dealRefs.any((d) => d.id == id))
          .toList();
    }
  }

  Future<List<TargetModel>> _fetchTargets() async {
    final id = widget.id;
    try {
      return await _targetsRepo.getLinkedTargets(
        kind: widget.kind.path,
        id: id,
      );
    } on TargetApiException catch (e) {
      if (e.statusCode != 404) rethrow;
      final all = await _targetsRepo.getMyTargets();
      return all
          .where((t) => _isLead
              ? t.linkedLeads.any((l) => l.id == id)
              : t.linkedDeals.any((d) => d.id == id))
          .toList();
    }
  }

  /// A per-record due date on the task overrides the task's own.
  DateTime? _dueFor(TaskModel t) =>
      (_isLead ? t.leadDueDates : t.dealDueDates)[widget.id] ?? t.dueDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showTasks) ...[
          _Header(
            icon: const Icon(
              Icons.check_box_outlined,
              size: 18,
              color: kLinkedTaskColor,
            ),
            title: 'Linked Tasks',
            count: _loading ? null : _tasks.length,
          ),
          const SizedBox(height: 10),
          ..._body(
            error: _tasksError,
            empty: 'No tasks linked to this $_noun',
            children: [
              for (final t in _tasks) _TaskTicket(task: t, due: _dueFor(t)),
            ],
          ),
          ],
          if (widget.showTasks && widget.showTargets)
          const SizedBox(height: 18),
          if (widget.showTargets) ...[
          _Header(
            icon: const TargetIcon(size: 18),
            title: 'Linked Targets',
            count: _loading ? null : _targets.length,
          ),
          const SizedBox(height: 10),
          ..._body(
            error: _targetsError,
            empty: 'No targets linked to this $_noun',
            children: [for (final t in _targets) _TargetTicket(target: t)],
          ),
          ],
        ],
      ),
    );
  }

  List<Widget> _body({
    required String? error,
    required String empty,
    required List<Widget> children,
  }) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }
    if (error != null) {
      return [
        _Message(
          text: 'Couldn\'t load: $error',
          isError: true,
          onRetry: () => _load(),
        ),
      ];
    }
    if (children.isEmpty) return [_Message(text: empty)];
    return [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ],
    ];
  }
}

// ── Section header: icon · title · (count) ────────────────────────
class _Header extends StatelessWidget {
  final Widget icon;
  final String title;
  final int? count;
  const _Header({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  final String text;
  final bool isError;
  final VoidCallback? onRetry;
  const _Message({required this.text, this.isError = false, this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isError ? AppColors.danger : AppColors.textSecondary,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
      );
}

// ── Ticket shell: content | dashed divider with notches | stub ─────
class _Ticket extends StatelessWidget {
  final Widget content;
  final Widget stub;
  const _Ticket({required this.content, required this.stub});

  @override
  Widget build(BuildContext context) {
    Widget notch() => Container(
          width: _notch,
          height: _notch,
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
        );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: content,
                  ),
                ),
                const _DashedLine(axis: Axis.vertical),
                SizedBox(width: _stubWidth, child: stub),
              ],
            ),
          ),
        ),
        Positioned(top: -_notch / 2, right: _stubWidth - _notch / 2, child: notch()),
        Positioned(
          bottom: -_notch / 2,
          right: _stubWidth - _notch / 2,
          child: notch(),
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  final Axis axis;
  const _DashedLine({required this.axis});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: axis == Axis.vertical
            ? const Size(1, double.infinity)
            : const Size(double.infinity, 1),
        painter: _DashPainter(axis, AppColors.border),
      );
}

class _DashPainter extends CustomPainter {
  final Axis axis;
  final Color color;
  _DashPainter(this.axis, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 4.0, gap = 4.0;
    final length = axis == Axis.vertical ? size.height : size.width;
    for (double d = 0; d < length; d += dash + gap) {
      final end = (d + dash).clamp(0, length).toDouble();
      if (axis == Axis.vertical) {
        canvas.drawLine(Offset(0.5, d), Offset(0.5, end), paint);
      } else {
        canvas.drawLine(Offset(d, 0.5), Offset(end, 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) =>
      old.axis != axis || old.color != color;
}

// ── Pills ─────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final Color? border;
  const _Pill({
    required this.text,
    required this.fg,
    required this.bg,
    this.border,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      );
}

String _titleCase(String s) {
  final t = s.trim().replaceAll('_', ' ');
  if (t.isEmpty) return t;
  return t
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

Widget? _priorityPill(String? priority) {
  final p = _titleCase(priority ?? '');
  if (p.isEmpty) return null;
  return switch (p.toLowerCase()) {
    'high' || 'urgent' => _Pill(
        text: p,
        fg: AppColors.danger,
        bg: AppColors.dangerLight,
      ),
    'medium' => _Pill(
        text: p,
        fg: const Color(0xFF92400E),
        bg: const Color(0xFFFEF3C7),
      ),
    _ => _Pill(
        text: p,
        fg: AppColors.textSecondary,
        bg: AppColors.divider,
      ),
  };
}

/// Date-only fields arrive as midnight UTC — format the UTC day so it
/// doesn't shift in timezones behind UTC.
DateTime _day(DateTime d) => d.isUtc ? d : d.toUtc();

// ── Task ticket ───────────────────────────────────────────────────
class _TaskTicket extends StatelessWidget {
  final TaskModel task;
  final DateTime? due;
  const _TaskTicket({required this.task, required this.due});

  @override
  Widget build(BuildContext context) {
    final due = this.due;
    final status = _titleCase(task.status ?? '');
    final done = const {'completed', 'rejected'}
        .contains((task.status ?? '').toLowerCase());
    final overdue = due != null &&
        !done &&
        _day(due).isBefore(_dateOnlyUtc(DateTime.now()));

    return _Ticket(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            (task.title ?? '').trim().isEmpty ? 'Untitled task' : task.title!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_priorityPill(task.priority) case final p?) p,
              if (status.isNotEmpty)
                _Pill(
                  text: status,
                  fg: AppColors.textSecondary,
                  bg: AppColors.surface,
                  border: AppColors.border,
                ),
            ],
          ),
        ],
      ),
      stub: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _StubLabel('DUE'),
          if (due == null)
            const Text(
              '—',
              style: TextStyle(fontSize: 22, color: AppColors.textHint),
            )
          else ...[
            Text(
              DateFormat('d').format(_day(due)),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: overdue ? AppColors.danger : AppColors.textPrimary,
              ),
            ),
            _StubLabel(
              DateFormat('MMM yyyy').format(_day(due)).toUpperCase(),
              color: overdue ? AppColors.danger : null,
            ),
          ],
        ],
      ),
    );
  }

  static DateTime _dateOnlyUtc(DateTime now) =>
      DateTime.utc(now.year, now.month, now.day);
}

class _StubLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const _StubLabel(this.text, {this.color});

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: color ?? AppColors.textSecondary,
          ),
        ),
      );
}

// ── Target ticket ─────────────────────────────────────────────────
class _TargetTicket extends StatelessWidget {
  final TargetModel target;
  const _TargetTicket({required this.target});

  @override
  Widget build(BuildContext context) {
    final t = target;
    final p = t.percentages;
    final leadsGoal = p.effTargetLeads > 0 ? p.effTargetLeads : t.targetLeads;
    final dealsGoal = p.effTargetDeals > 0 ? p.effTargetDeals : t.targetDeals;
    final progress = p.overall.clamp(0, 100);

    final start = t.startDate == null ? null : _day(t.startDate!);
    final end = t.endDate == null ? null : _day(t.endDate!);
    final days = start != null && end != null
        ? DateTime.utc(end.year, end.month, end.day)
                .difference(DateTime.utc(start.year, start.month, start.day))
                .inDays +
            1
        : null;

    final status = _titleCase(t.status ?? '');

    return _Ticket(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (t.title ?? '').trim().isNotEmpty
                ? t.title!
                : '${_titleCase(t.period ?? '')} Target'.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _DateBox(label: 'START', date: start),
              Expanded(
                child: _DaysConnector(
                  text: days == null ? '' : '$days day${days == 1 ? '' : 's'}',
                ),
              ),
              _DateBox(label: 'END', date: end),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (status.isNotEmpty)
                _Pill(
                  text: status,
                  fg: AppColors.primary,
                  bg: AppColors.primaryLight,
                  border: AppColors.primary.withOpacity(0.2),
                ),
              if (_priorityPill(t.priority) case final pill?) pill,
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Count(label: 'Leads', value: '${t.actuals.leadsConverted}/$leadsGoal'),
              _Count(label: 'Deals', value: '${t.actuals.dealsWon}/$dealsGoal'),
            ],
          ),
        ],
      ),
      stub: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(
              painter: _RingPainter(progress / 100),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$progress%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _StubLabel('PROGRESS'),
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final DateTime? date;
  const _DateBox({required this.label, required this.date});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date == null ? '—' : DateFormat('MMM d').format(date!),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}

/// "- - - 30 days - - -" between the start and end boxes: one dashed line
/// with the label laid over its middle; the label scales down on narrow
/// cards instead of overflowing.
class _DaysConnector extends StatelessWidget {
  final String text;
  const _DaysConnector({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          height: 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: double.infinity,
                child: _DashedLine(axis: Axis.horizontal),
              ),
              if (text.isNotEmpty)
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _Count extends StatelessWidget {
  final String label;
  final String value;
  const _Count({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          text: '$label ',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double value; // 0..1
  _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, 6.2832, false, track);
    if (value <= 0) return;
    final arc = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -1.5708, 6.2832 * value.clamp(0, 1), false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}
