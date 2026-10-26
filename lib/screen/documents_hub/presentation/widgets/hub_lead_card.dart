// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/widgets/                ║
// ║                            hub_lead_card.dart                 ║
// ║  LEAD CARD — Lead tab: initial avatar tinted by stage, lead   ║
// ║  name, file count; footer with the assignee and               ║
// ║  one pill per file state (Not assigned / Pending / Viewed /   ║
// ║  Replied).                                                    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_lead_group.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_document_card.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_styles.dart';
import 'package:flutter/material.dart';

class HubLeadCard extends StatelessWidget {
  final HubLeadGroup group;
  final VoidCallback? onTap;

  const HubLeadCard({super.key, required this.group, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = HubStageTone.of(group.stage);
    final radius = BorderRadius.circular(20);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: tone.glow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: HubPalette.border),
            ),
            child: Column(
              children: [
                // The Stack clips, so the tinted circle stays in the top
                // section and stops at the dashed line.
                Stack(
                  children: [
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Ink(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: tone.wash,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: _Top(group: group, tone: tone),
                    ),
                  ],
                ),
                const HubDashedDivider(),
                _Footer(group: group),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Top extends StatelessWidget {
  final HubLeadGroup group;
  final HubStageTone tone;

  const _Top({required this.group, required this.tone});

  @override
  Widget build(BuildContext context) {
    final name = group.leadName.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tone.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: tone.glow,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            name.isEmpty
                ? (group.isDeal ? 'Unnamed deal' : 'Unnamed lead')
                : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HubPalette.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                size: 15,
                color: HubPalette.ink,
              ),
              const SizedBox(width: 4),
              Text(
                '${group.files.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: HubPalette.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final HubLeadGroup group;

  const _Footer({required this.group});

  @override
  Widget build(BuildContext context) {
    final assignee = group.assignee;
    final name = assignee?.fullName ?? '';
    final pills = [
      for (final MapEntry(key: state, value: n) in group.stateCounts.entries)
        HubFileStatePill(state: state, count: n),
    ];

    final person = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Initials(name: name),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name.isEmpty ? 'Unassigned' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: HubPalette.ink),
          ),
        ),
      ],
    );

    // Up to two pills share the row with the assignee (the name gives
    // way first); three or more get their own right-aligned row so the
    // footer never wraps unevenly.
    final oneRow = pills.length <= 2;

    return Ink(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      child: oneRow
          ? Row(
              children: [
                Expanded(child: person),
                const SizedBox(width: 8),
                for (final (i, pill) in pills.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  pill,
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: person),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: pills,
                ),
              ],
            ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String name;

  const _Initials({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).take(2);
    final initials = parts.map((p) => p[0].toUpperCase()).join();

    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFEEF2FF),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isEmpty ? '–' : initials,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4338CA),
        ),
      ),
    );
  }
}

class HubFileStatePill extends StatelessWidget {
  final HubFileState state;
  final int count;

  const HubFileStatePill({
    super.key,
    required this.state,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (state) {
      HubFileState.notAssigned => (
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626),
          'Not assigned',
        ),
      HubFileState.pending => (
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
          'Pending',
        ),
      HubFileState.viewed => (
          const Color(0xFFE0E7FF),
          const Color(0xFF4338CA),
          'Viewed',
        ),
      HubFileState.replied => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          'Replied',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Colours for a lead stage: label, avatar gradient, glow, corner wash.
class HubStageTone {
  final String label;
  final Color text;
  final List<Color> gradient;
  final Color glow;
  final Color wash;

  const HubStageTone({
    required this.label,
    required this.text,
    required this.gradient,
    required this.glow,
    required this.wash,
  });

  static HubStageTone of(HubLeadStage stage) {
    switch (stage) {
      case HubLeadStage.needsAction:
        return const HubStageTone(
          label: 'NEEDS ACTION',
          text: Color(0xFFEA580C),
          gradient: [Color(0xFFF59E0B), Color(0xFFEA580C)],
          glow: Color(0x33EA580C),
          wash: Color(0xFFFFF7ED),
        );
      case HubLeadStage.inProgress:
        return const HubStageTone(
          label: 'IN PROGRESS',
          text: Color(0xFF2563EB),
          gradient: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          glow: Color(0x332563EB),
          wash: Color(0xFFEFF4FF),
        );
      case HubLeadStage.done:
        return const HubStageTone(
          label: 'DONE',
          text: Color(0xFF16A34A),
          gradient: [Color(0xFF22C55E), Color(0xFF15803D)],
          glow: Color(0x3316A34A),
          wash: Color(0xFFF0FDF4),
        );
    }
  }
}
