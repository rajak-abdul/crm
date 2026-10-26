// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/widgets/                ║
// ║                            hub_source_tabs.dart               ║
// ║  TABS — Assigned / Lead / Deal / Invoice / External segmented ║
// ║  control with counts; scrolls sideways when it doesn't fit.   ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/presentation/cubit/documents_hub_cubit.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_styles.dart';
import 'package:flutter/material.dart';

/// (filter, label, icon) — one tab in the strip.
typedef HubSourceTab = (HubSourceFilter, String, IconData);

class HubSourceTabs extends StatelessWidget {
  final HubSourceFilter selected;
  final Map<HubSourceFilter, int> counts;
  final ValueChanged<HubSourceFilter> onChanged;

  /// Which tabs to show and how; defaults to the hub's five.
  final List<HubSourceTab> tabs;

  const HubSourceTabs({
    super.key,
    required this.selected,
    required this.counts,
    required this.onChanged,
    this.tabs = hubTabs,
  });

  static const hubTabs = <HubSourceTab>[
    (HubSourceFilter.assigned, 'Assigned', Icons.inbox_outlined),
    (HubSourceFilter.lead, 'Lead', Icons.person_outline_rounded),
    (HubSourceFilter.deal, 'Deal', Icons.work_outline_rounded),
    (HubSourceFilter.invoice, 'Invoice', Icons.receipt_long_outlined),
    (HubSourceFilter.external, 'External', Icons.public_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HubPalette.track,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (filter, label, icon) in tabs)
              _Tab(
                label: label,
                icon: icon,
                count: counts[filter] ?? 0,
                selected: filter == selected,
                onTap: () => onChanged(filter),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? HubPalette.ink : HubPalette.muted;

    return GestureDetector(
      onTap: () {
        onTap();
        // Bring a half-hidden tab fully into the strip. Only the strip
        // scrolls — Scrollable.ensureVisible would move the page too.
        final box = context.findRenderObject();
        if (box != null) {
          Scrollable.of(context).position.ensureVisible(
                box,
                alignment: 0.5,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? HubPalette.accentBg : HubPalette.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? HubPalette.accent : HubPalette.muted,
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
