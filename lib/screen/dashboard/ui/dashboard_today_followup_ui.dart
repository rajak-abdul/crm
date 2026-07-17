import 'package:crm_app/modals/followup_model.dart';
import 'package:crm_app/thems/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TodaysFollowUpsCard extends StatelessWidget {
  final List<FollowUpItem> items;
  final VoidCallback? onViewAll;
  const TodaysFollowUpsCard({super.key, required this.items, this.onViewAll});

  static const _visibleCount = 2;

  Color _accentColor(FollowUpType t) =>
      t == FollowUpType.lead ? AppColors.primary : AppColors.success;

  String _typeLabel(FollowUpType t) => t == FollowUpType.lead ? 'Lead' : 'Deal';

  String _timeLabel(DateTime d) => DateFormat('hh:mm a').format(d);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final visible = items.take(_visibleCount).toList();
    final remaining = items.length - visible.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              const Icon(Icons.event_available_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("Today's Follow-ups",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: const Row(children: [
                  Text('View All',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.primary),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1, color: AppColors.divider),
          for (final item in visible) ...[
            _FollowUpRow(
              item: item,
              color: _accentColor(item.type),
              typeLabel: _typeLabel(item.type),
              timeLabel: _timeLabel(item.followUpDate),
            ),
            const Divider(height: 1, color: AppColors.divider),
          ],
          if (remaining > 0)
            GestureDetector(
              onTap: onViewAll,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '+$remaining more follow-up${remaining == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  final FollowUpItem item;
  final Color color;
  final String typeLabel;
  final String timeLabel;
  const _FollowUpRow({
    required this.item,
    required this.color,
    required this.typeLabel,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(item.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(item.subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(timeLabel,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
}
