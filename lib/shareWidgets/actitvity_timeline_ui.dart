import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../thems/app_themes.dart';

// Activity timeline shared by the lead and deal detail sheets — same look
// as the proposal sheet's Activity tab: "Activity timeline" header, round
// icon per entry joined by a thin vertical line, bold title + grey time.

class ActivityTimelineItem {
  final String type;
  final String title;
  final String description;
  final String? performedBy;
  final DateTime? timestamp;

  const ActivityTimelineItem({
    required this.type,
    required this.title,
    required this.description,
    this.performedBy,
    this.timestamp,
  });
}

class ActivityTimeline extends StatelessWidget {
  final List<ActivityTimelineItem> activities;
  final ScrollController? controller;
  final bool isLoading;
  final String emptyMessage;

  /// Line under the "Activity timeline" header, e.g.
  /// "Recent activity and updates for this lead".
  final String subtitle;

  const ActivityTimeline({
    super.key,
    required this.activities,
    this.controller,
    this.isLoading = false,
    this.emptyMessage = 'No activity available',
    this.subtitle = 'Recent activity and updates',
  });

  // ALL ACTIVITY ICONS ARE CENTRALIZED HERE
  static IconData getIcon(String type) {
    switch (type) {
      // Lead
      case 'lead_created':
        return Icons.person_add_outlined;

      case 'lead_edited':
        return Icons.edit_outlined;

      case 'lead_converted':
        return Icons.swap_horiz_outlined;

      // Deal
      case 'deal_created':
        return Icons.add_business_outlined;

      case 'deal_edited':
        return Icons.edit_outlined;

      // Status / stage
      case 'status_changed':
        return Icons.sync_alt_outlined;

      case 'stage_changed':
      case 'stage_change':
        return Icons.swap_vert_outlined;

      // Files
      case 'attachment_uploaded':
        return Icons.attach_file_outlined;

      case 'attachment_deleted':
        return Icons.delete_outline;

      case 'image_uploaded':
        return Icons.image_outlined;

      case 'image_deleted':
        return Icons.delete_outline;

      // Notes
      case 'notes_updated':
        return Icons.note_alt_outlined;

      case 'note_added':
        return Icons.note_add_outlined;

      case 'note_updated':
        return Icons.edit_note_outlined;

      case 'note_deleted':
        return Icons.delete_sweep_outlined;

      // Follow-up
      case 'followup':
        return Icons.event_available_outlined;

      case 'followup_rescheduled':
        return Icons.event_repeat_outlined;

      case 'followup_completed':
        return Icons.task_alt_outlined;

      case 'followup_missed':
        return Icons.event_busy_outlined;

      // Meetings
      case 'meeting_scheduled':
        return Icons.event_outlined;

      case 'meeting_updated':
        return Icons.edit_calendar_outlined;

      case 'meeting_cancelled':
        return Icons.event_busy_outlined;

      // Tasks
      case 'task_activity':
        return Icons.task_alt_outlined;

      case 'task_created':
        return Icons.add_task_outlined;

      case 'task_completed':
        return Icons.task_alt_outlined;

      // Target
      case 'target_linked':
        return Icons.link_outlined;

      case 'target_unlinked':
        return Icons.link_off_outlined;

      // Assignment
      case 'assigned':
        return Icons.person_add_alt_1_outlined;

      case 'reassigned':
        return Icons.swap_horiz_outlined;

      // Default
      default:
        return Icons.history_outlined;
    }
  }

  /// Icon colour by kind of event (order matters: e.g. a completed
  /// follow-up is green, a cancelled meeting is red).
  static Color getColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('delete') ||
        t.contains('cancel') ||
        t.contains('missed') ||
        t.contains('unlinked')) {
      return AppColors.danger;
    }
    if (t.contains('status') ||
        t.contains('stage') ||
        t.contains('converted') ||
        t.contains('completed')) {
      return AppColors.success;
    }
    if (t.contains('followup') || t.contains('meeting')) {
      return AppColors.warning;
    }
    if (t.contains('created') || t.contains('added') || t == 'assigned') {
      return AppColors.primary;
    }
    if (t.contains('task') || t.contains('target')) return AppColors.purple;
    if (t.contains('attachment') || t.contains('image')) {
      return AppColors.accent;
    }
    if (t.contains('edit') || t.contains('update') || t.contains('assign')) {
      return AppColors.purple;
    }
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: activities.isEmpty ? 2 : activities.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) return _Header(subtitle: subtitle);

        if (activities.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        final i = index - 1;
        return _TimelineEntry(
          activity: activities[i],
          isLast: i == activities.length - 1,
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String subtitle;
  const _Header({required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity timeline',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
}

class _TimelineEntry extends StatelessWidget {
  final ActivityTimelineItem activity;
  final bool isLast;

  const _TimelineEntry({
    required this.activity,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final description = activity.description.trim();
    final by = activity.performedBy?.trim() ?? '';
    final time = activity.timestamp == null
        ? ''
        : DateFormat('M/d/yyyy, h:mm:ss a')
            .format(activity.timestamp!.toLocal());

    // IntrinsicHeight lets the connecting line run the full height of the
    // entry, however many lines its text wraps to.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Icon + connecting line ──
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    ActivityTimeline.getIcon(activity.type),
                    size: 16,
                    color: ActivityTimeline.getColor(activity.type),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Text ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (description.isNotEmpty && description != activity.title)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (time.isNotEmpty || by.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          if (time.isNotEmpty) time,
                          if (by.isNotEmpty) 'by $by',
                        ].join('  ·  '),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
