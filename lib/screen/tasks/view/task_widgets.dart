// ╔══════════════════════════════════════════════════════════════╗
// ║            lib/screen/tasks/view/task_widgets.dart            ║
// ║  VIEW — building blocks for the My Tasks screen. Renders      ║
// ║  values prepared by TaskViewModel; no calculations here.      ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/viewmodel/task_state.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskPalette {
  static const accent = Color(0xFF0B6FB5);
  static const link = Color(0xFF1D6FB8);
  static const linkBg = Color(0xFFF0F7FF);
  static const linkBorder = Color(0xFFBFDBFE);
  static const indigo = Color(0xFF3730A3);
  static const indigoBg = Color(0xFFEEF2FF);
  static const indigoBorder = Color(0xFFC7D2FE);
  static const orange = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);
  static const track = Color(0xFFE2E8F0);
}

// ══════════════════════════════════════════════════════════════
// STYLE MAPPINGS
// ══════════════════════════════════════════════════════════════
Color dueToneColor(DueTone tone) {
  switch (tone) {
    case DueTone.overdue:
      return TaskPalette.red;
    case DueTone.soon:
      return TaskPalette.orange;
    case DueTone.normal:
      return AppColors.textSecondary;
  }
}

(Color, Color) statusColors(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'pending':
      return (const Color(0xFFE0F2FE), const Color(0xFF0369A1));
    case 'in progress':
      return (AppColors.primaryLight, AppColors.primary);
    case 'completed':
      return (AppColors.successLight, const Color(0xFF047857));
    case 'in hold':
    case 'on hold':
      return (AppColors.purpleLight, const Color(0xFF6D28D9));
    case 'rejected':
      return (AppColors.dangerLight, TaskPalette.red);
    default:
      return (const Color(0xFFF1F5F9), const Color(0xFF475569));
  }
}

(Color, Color) priorityColors(String? priority) {
  switch ((priority ?? '').toLowerCase()) {
    case 'urgent':
      return (const Color(0xFFFEE2E2), TaskPalette.red);
    case 'high':
      return (const Color(0xFFFFEDD5), const Color(0xFFEA580C));
    case 'medium':
      return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
    default:
      return (const Color(0xFFF1F5F9), const Color(0xFF475569));
  }
}

// ══════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════
class TaskHeader extends StatelessWidget {
  final VoidCallback onInfoTap;
  final VoidCallback onBellTap;

  const TaskHeader({
    super.key,
    required this.onInfoTap,
    required this.onBellTap,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop) ...[
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 22, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_outlined,
                  size: 20, color: Color(0xFF0369A1)),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'My Tasks',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onInfoTap,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.primary),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onBellTap,
              icon: const Icon(Icons.notifications_none_rounded,
                  size: 22, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tasks assigned to you by your admin',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class TaskFlowBanner extends StatelessWidget {
  const TaskFlowBanner({super.key});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: TaskPalette.indigo,
    );
    const arrow = Icon(Icons.arrow_forward_rounded,
        size: 14, color: Color(0xFF6366F1));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TaskPalette.indigoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TaskPalette.indigoBorder),
      ),
      child: const Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Start Task', style: textStyle),
          arrow,
          Text('Mark as Done', style: textStyle),
          arrow,
          Text('Admin Approves', style: textStyle),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DASHBOARD OVERVIEW
// ══════════════════════════════════════════════════════════════
class OverviewPeriodDropdown extends StatelessWidget {
  static const periods = {
    'all': 'All Time',
    'this_month': 'This Month',
    'custom': 'Custom Date',
  };

  final String value;
  final ValueChanged<String> onChanged;

  const OverviewPeriodDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (_) => [
        for (final entry in periods.entries)
          PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Icon(
                  entry.key == value
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 18,
                  color: entry.key == value
                      ? TaskPalette.accent
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(entry.value),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              periods[value] ?? 'All Time',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

enum OverviewChart { bars, line }

class OverviewStatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color lightColor;
  final Color bgStart;
  final Color bgEnd;
  final Color borderColor;
  final OverviewChart chart;
  final List<double> chartValues;
  final VoidCallback? onTap;

  const OverviewStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.lightColor,
    required this.bgStart,
    required this.bgEnd,
    required this.borderColor,
    required this.chart,
    required this.chartValues,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 136,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgStart, bgEnd],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (onTap != null)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 16, color: color),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                NumberFormat.decimalPattern().format(value),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 34,
              width: double.infinity,
              child: CustomPaint(
                painter: chart == OverviewChart.bars
                    ? _BarSparkPainter(
                        values: chartValues,
                        light: lightColor,
                        dark: color,
                      )
                    : _LineSparkPainter(values: chartValues, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Decorative trend shapes for the overview cards — the stats endpoint
// returns totals only, not a time series.
class _BarSparkPainter extends CustomPainter {
  final List<double> values;
  final Color light;
  final Color dark;

  _BarSparkPainter({
    required this.values,
    required this.light,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const gap = 5.0;
    final barW = (size.width - gap * (values.length - 1)) / values.length;

    for (var i = 0; i < values.length; i++) {
      final t = values.length == 1 ? 1.0 : i / (values.length - 1);
      final h = (size.height * values[i]).clamp(4.0, size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (barW + gap), size.height - h, barW, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = Color.lerp(light, dark, t * t)!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarSparkPainter old) =>
      old.values != values || old.light != light || old.dark != dark;
}

class _LineSparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _LineSparkPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const pad = 4.0;
    final h = size.height - pad * 2;
    final dx = (size.width - pad * 2) / (values.length - 1);

    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(pad + i * dx, pad + h - values[i] * h),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), color.withOpacity(0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], i == points.length - 1 ? 4 : 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LineSparkPainter old) =>
      old.values != values || old.color != color;
}

// ══════════════════════════════════════════════════════════════
// FILTERS + VIEW TOGGLE
// ══════════════════════════════════════════════════════════════
class TaskFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const TaskFilterChip({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? TaskPalette.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? TaskPalette.accent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : TaskPalette.red,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? TaskPalette.accent : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TaskViewToggle extends StatelessWidget {
  final TaskViewMode value;
  final ValueChanged<TaskViewMode> onChanged;

  const TaskViewToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _icons = {
    TaskViewMode.grid: Icons.grid_view_rounded,
    TaskViewMode.list: Icons.format_list_bulleted_rounded,
    TaskViewMode.pipeline: Icons.view_week_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in TaskViewMode.values)
            GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 30,
                decoration: BoxDecoration(
                  color: value == mode
                      ? TaskPalette.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _icons[mode],
                  size: 17,
                  color: value == mode
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TASK CARD (grid view)
// ══════════════════════════════════════════════════════════════
class TaskCard extends StatelessWidget {
  final TaskCardData data;
  final VoidCallback onViewLinked;

  const TaskCard({
    super.key,
    required this.data,
    required this.onViewLinked,
  });

  @override
  Widget build(BuildContext context) {
    final task = data.task;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title ?? '-',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TaskBadge.status(task.status),
              const SizedBox(width: 6),
              TaskBadge.priority(task.priority),
            ],
          ),
          if (data.pendingAdminReview) ...[
            const SizedBox(height: 10),
            const _PendingReviewPill(),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (data.assignedBy.isNotEmpty)
                _IconLabel(
                  icon: Icons.person_outline_rounded,
                  text: data.assignedBy,
                ),
              if (data.dueLabel != null) _DueLabel(data: data),
            ],
          ),
          if ((task.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.description_outlined,
                    size: 15, color: Color(0xFFEA580C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: data.progressPercent / 100,
                    minHeight: 6,
                    backgroundColor: TaskPalette.track,
                    color: TaskPalette.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${data.progressPercent}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  icon: Icons.people_outline_rounded,
                  iconColor: AppColors.primary,
                  bg: AppColors.primaryLight,
                  label: 'Leads converted',
                  done: data.leadsDone,
                  total: data.leadsTotal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF059669),
                  bg: AppColors.successLight,
                  label: 'Deal closed',
                  done: data.dealsDone,
                  total: data.dealsTotal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.link_rounded,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.linkedSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: TaskPalette.linkBg,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onViewLinked,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TaskPalette.linkBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View linked items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: TaskPalette.link,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_up_rounded,
                            size: 16, color: TaskPalette.link),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TaskBadge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const TaskBadge({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
  });

  factory TaskBadge.status(String? status) {
    final (bg, fg) = statusColors(status);
    return TaskBadge(text: status ?? '-', bg: bg, fg: fg);
  }

  factory TaskBadge.priority(String? priority) {
    final (bg, fg) = priorityColors(priority);
    return TaskBadge(text: priority ?? '-', bg: bg, fg: fg);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
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
}

class _PendingReviewPill extends StatelessWidget {
  const _PendingReviewPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.outlined_flag_rounded, size: 13, color: Color(0xFFE11D48)),
          SizedBox(width: 6),
          Text(
            'Pending admin review',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE11D48),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DueLabel extends StatelessWidget {
  final TaskCardData data;

  const _DueLabel({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.calendar_today_outlined,
            size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: data.dueLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: dueToneColor(data.dueTone),
                ),
              ),
              if (data.dueSuffix != null)
                TextSpan(
                  text: ', ${data.dueSuffix}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String label;
  final int done;
  final int total;

  const _MetricBox({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.label,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                total == 0
                    ? const Text(
                        'No target',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Text(
                        '$done / $total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TASK ROW (list view)
// ══════════════════════════════════════════════════════════════
class TaskListRow extends StatelessWidget {
  final TaskCardData data;
  final VoidCallback onTap;

  const TaskListRow({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final task = data.task;
    final (_, priorityFg) = priorityColors(task.priority);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: priorityFg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (data.dueLabel != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          data.dueSuffix == null
                              ? data.dueLabel!
                              : '${data.dueLabel}, ${data.dueSuffix}',
                          style: TextStyle(
                            fontSize: 11,
                            color: dueToneColor(data.dueTone),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TaskBadge.status(task.status),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
