// ╔══════════════════════════════════════════════════════════════╗
// ║          lib/screen/tasks/view/target_widgets.dart           ║
// ║  VIEW — building blocks for the My Targets screen. Renders    ║
// ║  values prepared by TargetViewModel; no calculations here.    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:math' as math;

import 'package:crm_app/screen/tasks/viewmodel/target_state.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TargetPalette {
  static const accent = Color(0xFF0B6FB5);
  static const link = Color(0xFF1D6FB8);
  static const indigo = Color(0xFF3730A3);
  static const indigoDot = Color(0xFF4F46E5);
  static const indigoBg = Color(0xFFEEF2FF);
  static const indigoBorder = Color(0xFFC7D2FE);
  static const tile = Color(0xFFF8FAFC);
  static const noneTrack = Color(0xFFE2E8F0);
  static const cold = Color(0xFF22C55E);
  static const warm = Color(0xFFF59E0B);
  static const hot = Color(0xFFEF4444);
  static const green = Color(0xFF059669);
  static const blue = Color(0xFF2563EB);
  static const blueTrack = Color(0xFFDBEAFE);
  static const orange = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);
}

// ══════════════════════════════════════════════════════════════
// STYLE MAPPINGS
// ══════════════════════════════════════════════════════════════
(Color, Color) targetStatusColors(TargetStatusTone tone) {
  switch (tone) {
    case TargetStatusTone.fresh:
      return (const Color(0xFFE0F2FE), const Color(0xFF0369A1));
    case TargetStatusTone.inProgress:
      return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
    case TargetStatusTone.completed:
      return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    case TargetStatusTone.expired:
      return (const Color(0xFFFEE2E2), TargetPalette.red);
    case TargetStatusTone.other:
      return (const Color(0xFFF1F5F9), const Color(0xFF475569));
  }
}

Color progressToneColor(TargetProgressTone tone) {
  switch (tone) {
    case TargetProgressTone.ongoing:
      return const Color(0xFF0284C7);
    case TargetProgressTone.achieved:
      return TargetPalette.green;
    case TargetProgressTone.ended:
      return TargetPalette.red;
    case TargetProgressTone.none:
      return AppColors.textSecondary;
  }
}

/// Icon, ring colour and ring track for a metric tile.
(IconData, Color, Color) metricStyle(TargetMetricKind kind) {
  switch (kind) {
    case TargetMetricKind.leadsConverted:
      return (
        Icons.people_outline_rounded,
        TargetPalette.blue,
        TargetPalette.blueTrack,
      );
    case TargetMetricKind.dealsClosed:
      return (
        Icons.payments_outlined,
        TargetPalette.green,
        const Color(0xFFD1FAE5),
      );
    case TargetMetricKind.convLeadsClosed:
      return (
        Icons.trending_up_rounded,
        const Color(0xFF7C3AED),
        const Color(0xFFEDE9FE),
      );
    case TargetMetricKind.dealsLost:
      return (
        Icons.cancel_outlined,
        TargetPalette.red,
        TargetPalette.noneTrack,
      );
    case TargetMetricKind.calls:
      return (
        Icons.phone_outlined,
        const Color(0xFFEA580C),
        const Color(0xFFFFEDD5),
      );
    case TargetMetricKind.meetings:
      return (
        Icons.groups_outlined,
        const Color(0xFF9333EA),
        const Color(0xFFF3E8FF),
      );
  }
}

// ══════════════════════════════════════════════════════════════
// HEADER + STEPS
// ══════════════════════════════════════════════════════════════
class TargetHeader extends StatelessWidget {
  final VoidCallback onInfoTap;

  /// Hidden when null.
  final VoidCallback? onBellTap;

  const TargetHeader({super.key, required this.onInfoTap, this.onBellTap});

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
              child: const Icon(Icons.track_changes_rounded,
                  size: 21, color: Color(0xFF0369A1)),
            ),
            const SizedBox(width: 10),
            // Title takes all free space (only ellipsised when truly short
            // of room); the bell stays pinned right.
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'My Targets',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
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
                ],
              ),
            ),
            if (onBellTap != null)
              IconButton(
                onPressed: onBellTap,
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 22, color: AppColors.textPrimary),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Targets assigned to you by your admin',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class TargetStepsBanner extends StatelessWidget {
  static const steps = [
    'Admin sets target',
    'You work towards it',
    'Progress tracked automatically',
    'Add notes if delayed',
  ];

  const TargetStepsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 14),
      decoration: BoxDecoration(
        color: TargetPalette.indigoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TargetPalette.indigoBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Line runs between the centres of the first and last circle.
          final inset = constraints.maxWidth / (steps.length * 2);
          // Small phones: shrink labels so "automatically" fits on a line.
          final labelSize =
              constraints.maxWidth / steps.length < 80 ? 8.5 : 9.5;

          return Stack(
            children: [
              Positioned(
                top: 13,
                left: inset,
                right: inset,
                child: Container(height: 2, color: TargetPalette.indigoBorder),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Expanded(
                      child: _Step(
                        number: i + 1,
                        label: steps[i],
                        fontSize: labelSize,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String label;
  final double fontSize;

  const _Step({
    required this.number,
    required this.label,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: TargetPalette.indigoDot,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: TargetPalette.indigo,
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CARD / PIPELINE TOGGLE
// ══════════════════════════════════════════════════════════════
class TargetViewToggle extends StatelessWidget {
  final TargetViewMode value;
  final ValueChanged<TargetViewMode> onChanged;

  const TargetViewToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  // Icons only (same as the My Tasks toggle); the label is the tooltip.
  static const _options = {
    TargetViewMode.card: (Icons.grid_view_rounded, 'Card'),
    TargetViewMode.pipeline: (Icons.view_week_outlined, 'Pipeline'),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in _options.entries)
            Tooltip(
              message: e.value.$2,
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 38,
                  height: 30,
                  decoration: BoxDecoration(
                    color: value == e.key
                        ? TargetPalette.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    e.value.$1,
                    size: 17,
                    color: value == e.key
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PIPELINE CARD
// ══════════════════════════════════════════════════════════════
/// Target card on the pipeline board (same layout as the task one).
class TargetPipelineCard extends StatelessWidget {
  final TargetCardData data;
  final VoidCallback onTap;

  const TargetPipelineCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeFg) = targetStatusColors(data.statusTone);
    final progressColor = progressToneColor(data.progressTone);
    final t = data.target;
    final pills = [
      if (t.holdRequested) 'Hold requested',
      if (t.rejectionRequested) 'Rejection requested',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
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
                        data.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data.statusLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [data.dateRange, data.timeNote]
                      .whereType<String>()
                      .join(' · '),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        data.timeNoteUrgent ? FontWeight.w600 : FontWeight.w400,
                    color: data.timeNoteUrgent
                        ? const Color(0xFFEA580C)
                        : AppColors.textSecondary,
                  ),
                ),
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in pills)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            p,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB45309),
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
                          value: data.overallPercent / 100,
                          minHeight: 6,
                          color: progressColor,
                          backgroundColor: TargetPalette.noneTrack,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${data.overallPercent}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.goalsTotal == 0
                      ? data.linkedSummary
                      : '${data.goalsDone}/${data.goalsTotal} goals · '
                          '${data.linkedSummary}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Tap to change status →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MONTHLY OVERVIEW
// ══════════════════════════════════════════════════════════════
enum OverviewChartStyle { statusBars, trendLine, dotPlot, lollipop }

class OverviewMetricCard extends StatelessWidget {
  final int value;
  final String unit; // "leads", "won", ...
  final String label;
  final OverviewChartStyle chart;
  final VoidCallback? onTap;

  const OverviewMetricCard({
    super.key,
    required this.value,
    required this.unit,
    required this.label,
    required this.chart,
    this.onTap,
  });

  CustomPainter get _painter {
    switch (chart) {
      case OverviewChartStyle.statusBars:
        return const _StatusBarsPainter();
      case OverviewChartStyle.trendLine:
        return const _TrendLinePainter();
      case OverviewChartStyle.dotPlot:
        return const _DotPlotPainter();
      case OverviewChartStyle.lollipop:
        return const _LollipopPainter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 150,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: NumberFormat.decimalPattern().format(value),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: ' $unit',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textHint),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 58,
                width: double.infinity,
                child: CustomPaint(painter: _painter),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OverviewLegend extends StatelessWidget {
  const OverviewLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );

    return Row(
      children: [
        item(TargetPalette.cold, 'Cold'),
        const SizedBox(width: 12),
        item(TargetPalette.warm, 'Warm'),
        const SizedBox(width: 12),
        item(TargetPalette.hot, 'Hot'),
        const Spacer(),
        const Text(
          'Leads by status',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// Decorative chart shapes for the overview cards — the stats endpoint
// returns totals only, not a time series or a status breakdown.

class _StatusBarsPainter extends CustomPainter {
  // (cold, warm, hot) share of the chart height per column.
  static const _columns = [
    (0.14, 0.10, 0.08),
    (0.18, 0.12, 0.08),
    (0.10, 0.08, 0.06),
    (0.26, 0.16, 0.12),
    (0.22, 0.20, 0.14),
    (0.30, 0.18, 0.12),
    (0.26, 0.18, 0.14),
    (0.34, 0.22, 0.16),
    (0.38, 0.26, 0.18),
    (0.44, 0.30, 0.20),
  ];

  const _StatusBarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 6.0;
    const segGap = 2.0;
    final barW = (size.width - gap * (_columns.length - 1)) / _columns.length;

    for (var i = 0; i < _columns.length; i++) {
      final (cold, warm, hot) = _columns[i];
      final x = i * (barW + gap);
      var bottom = size.height;

      for (final (share, color) in [
        (cold, TargetPalette.cold),
        (warm, TargetPalette.warm),
        (hot, TargetPalette.hot),
      ]) {
        final h = math.max(3.0, size.height * share);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, bottom - h, barW, h),
            const Radius.circular(2),
          ),
          Paint()..color = color,
        );
        bottom -= h + segGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrendLinePainter extends CustomPainter {
  static const _values = [0.1, 0.35, 0.55, 0.35, 0.62, 0.48, 0.72, 0.58, 0.88];
  static const _markers = {2, 6};

  const _TrendLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final h = size.height - pad * 2;
    final dx = (size.width - pad * 2) / (_values.length - 1);

    final points = [
      for (var i = 0; i < _values.length; i++)
        Offset(pad + i * dx, pad + h - _values[i] * h),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = TargetPalette.cold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    for (final i in _markers) {
      canvas.drawCircle(points[i], 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        points[i],
        5,
        Paint()
          ..color = TargetPalette.warm
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DotPlotPainter extends CustomPainter {
  static const _values = [
    0.3,
    0.42,
    0.36,
    0.5,
    0.44,
    0.56,
    0.48,
    0.62,
    0.7,
    0.8
  ];
  static const _highlight = 6;

  const _DotPlotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final h = size.height - pad * 2;
    final dx = (size.width - pad * 2) / (_values.length - 1);
    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    for (var i = 0; i < _values.length; i++) {
      final x = pad + i * dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawCircle(
        Offset(x, pad + h - _values[i] * h),
        i == _highlight ? 4.5 : 3.5,
        Paint()
          ..color =
              i == _highlight ? TargetPalette.warm : const Color(0xFF14B8A6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LollipopPainter extends CustomPainter {
  static const _values = [
    0.35,
    0.55,
    0.4,
    0.3,
    0.95,
    0.45,
    0.72,
    0.4,
    0.36,
    0.82
  ];

  const _LollipopPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 5.0;
    final step = (size.width - barW) / (_values.length - 1);

    for (var i = 0; i < _values.length; i++) {
      final last = i == _values.length - 1;
      final h = math.max(barW, size.height * _values[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * step, size.height - h, barW, h),
          const Radius.circular(barW / 2),
        ),
        Paint()
          ..color = last
              ? const Color(0xFFE11D48)
              : i.isEven
                  ? const Color(0xFFF9A8D4)
                  : const Color(0xFFF472B6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
// YOUR TARGETS — SUMMARY
// ══════════════════════════════════════════════════════════════
class TargetSummaryCard extends StatelessWidget {
  final TargetSummary summary;

  const TargetSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final ringColor = summary.averagePercent >= 100
        ? TargetPalette.green
        : TargetPalette.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: CustomPaint(
              painter: _RingPainter(
                fraction: summary.averagePercent / 100,
                color: ringColor,
                track: const Color(0xFFF1F5F9),
                strokeWidth: 7,
              ),
              child: Center(
                child: Text(
                  '${summary.averagePercent}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Average progress',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      _SummaryNumber(
                        value: summary.total,
                        label: 'Total targets',
                        color: AppColors.textPrimary,
                      ),
                      const VerticalDivider(
                        width: 28,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                      _SummaryNumber(
                        value: summary.achieved,
                        label: 'Achieved',
                        color: TargetPalette.green,
                      ),
                    ],
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

class _SummaryNumber extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _SummaryNumber({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Full circle progress ring, starting at 12 o'clock.
class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;
  final double strokeWidth;

  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);

    final sweep = math.pi * 2 * fraction.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// Top half of a ring, filling left → right. Height needed is
/// width / 2 + strokeWidth / 2.
class HalfRingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;
  final double strokeWidth;

  const HalfRingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.width - strokeWidth,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, paint..color = track);

    final sweep = math.pi * fraction.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(rect, math.pi, sweep, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant HalfRingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

// ══════════════════════════════════════════════════════════════
// TARGET CARD
// ══════════════════════════════════════════════════════════════
class TargetCard extends StatelessWidget {
  final TargetCardData data;
  final VoidCallback onDetails;

  /// Tap on a reportable tile (calls / meetings on an open target).
  final ValueChanged<TargetMetricKind>? onReport;

  /// Tap on the calls / meetings tile — lists what was reported.
  final ValueChanged<TargetMetricKind>? onView;

  const TargetCard({
    super.key,
    required this.data,
    required this.onDetails,
    this.onReport,
    this.onView,
  });

  static bool _isActivity(TargetMetricKind kind) =>
      kind == TargetMetricKind.calls || kind == TargetMetricKind.meetings;

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeFg) = targetStatusColors(data.statusTone);
    final m = data.metrics;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
                  data.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.statusLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: data.dateRange),
                if (data.timeNote != null) ...[
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: data.timeNote,
                    style: data.timeNoteUrgent
                        ? const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          )
                        : null,
                  ),
                ],
              ],
            ),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (data.description != null) ...[
            const SizedBox(height: 10),
            _DescriptionNote(text: data.description!),
          ],
          const SizedBox(height: 12),
          _OverallProgress(data: data),
          const SizedBox(height: 10),
          for (final row in [m.sublist(0, 3), m.sublist(3, 6)]) ...[
            // Equal-height tiles even when one has "Tap to report".
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        metric: row[i],
                        onReport: row[i].canReport && onReport != null
                            ? () => onReport!(row[i].kind)
                            : null,
                        onView: _isActivity(row[i].kind) && onView != null
                            ? () => onView!(row[i].kind)
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onDetails,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Records',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: TargetPalette.link,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 18, color: TargetPalette.link),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionNote extends StatelessWidget {
  final String text;

  const _DescriptionNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.speaker_notes_outlined,
                size: 15, color: TargetPalette.orange),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallProgress extends StatelessWidget {
  final TargetCardData data;

  const _OverallProgress({required this.data});

  @override
  Widget build(BuildContext context) {
    final achieved = data.achieved;
    final ringColor = achieved ? TargetPalette.green : TargetPalette.blue;
    final ringTrack =
        achieved ? const Color(0xFFD1FAE5) : TargetPalette.blueTrack;
    final goals = data.goalsTotal == 1 ? 'goal' : 'goals';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      decoration: BoxDecoration(
        color: TargetPalette.tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 67,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: HalfRingPainter(
                      fraction: data.overallPercent / 100,
                      color: ringColor,
                      track: ringTrack,
                      strokeWidth: 13,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    '${data.overallPercent}%',
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall progress',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${data.goalsDone} of ${data.goalsTotal} $goals done',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.progressMessage,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: progressToneColor(data.progressTone),
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

class _MetricTile extends StatelessWidget {
  final TargetMetricData metric;

  /// Set for reportable tiles: shows "Tap to report" and a filled "+";
  /// the "+" opens the report popup.
  final VoidCallback? onReport;

  /// Calls / meetings tiles: tapping the tile lists what was reported.
  final VoidCallback? onView;

  const _MetricTile({required this.metric, this.onReport, this.onView});

  @override
  Widget build(BuildContext context) {
    final (icon, color, track) = metricStyle(metric.kind);
    final isLost = metric.kind == TargetMetricKind.dealsLost;
    final showNone = !metric.hasGoal && !isLost;

    final value = showNone
        ? const Text(
            'None',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${metric.actual}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (metric.hasGoal)
                  TextSpan(
                    text: '/${metric.target}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          );

    final reportable = onReport != null;

    return Stack(
      fit: StackFit.passthrough,
      // The "+" pulse ring may spill slightly past the tile corner.
      clipBehavior: Clip.none,
      children: [
        Material(
          color: TargetPalette.tile,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onView,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
              child: Column(
                children: [
                  SizedBox(
                    width: 76,
                    height: 42,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: HalfRingPainter(
                              fraction: metric.fraction,
                              color: color,
                              track: showNone ? TargetPalette.noneTrack : track,
                              strokeWidth: 7,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 13, color: color),
                              const SizedBox(height: 1),
                              value,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metric.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (reportable) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to report',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (reportable)
          Positioned(
            top: 0,
            right: 0,
            // The "+" opens the report popup too; the padding gives it a
            // finger-sized tap area around the 22px badge.
            child: Semantics(
              button: true,
              label: 'Report ${metric.label.replaceAll('\n', ' ')}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onReport,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _PulsingAddBadge(color: color),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Filled "+" that keeps pulsing (gentle breathe + expanding, fading
/// ring) to invite a tap. Still when the OS asks for reduced motion.
class _PulsingAddBadge extends StatefulWidget {
  final Color color;

  const _PulsingAddBadge({required this.color});

  @override
  State<_PulsingAddBadge> createState() => _PulsingAddBadgeState();
}

class _PulsingAddBadgeState extends State<_PulsingAddBadge>
    with SingleTickerProviderStateMixin {
  static const _size = 22.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
    );

    return SizedBox(
      width: _size,
      height: _size,
      child: AnimatedBuilder(
        animation: _controller,
        child: badge,
        builder: (context, badge) {
          final t = _controller.value;
          // Breathe: 1.0 → 1.1 → 1.0 once per cycle.
          final breathe = 1 + 0.1 * math.sin(t * math.pi);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (_controller.isAnimating)
                Transform.scale(
                  scale: 1 + 0.9 * Curves.easeOut.transform(t),
                  child: Container(
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.35 * (1 - t)),
                    ),
                  ),
                ),
              Transform.scale(scale: breathe, child: badge),
            ],
          );
        },
      ),
    );
  }
}
