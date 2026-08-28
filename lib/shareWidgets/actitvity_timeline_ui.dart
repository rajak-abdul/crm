import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../thems/app_themes.dart';

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

  const ActivityTimeline({
    super.key,
    required this.activities,
    this.controller,
    this.isLoading = false,
    this.emptyMessage = 'No activity available',
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (activities.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20,
      ),
      itemCount: activities.length,
      separatorBuilder: (_, __) {
        return const SizedBox(height: 10);
      },
      itemBuilder: (_, index) {
        final activity = activities[index];

        return _ActivityTimelineCard(
          activity: activity,
        );
      },
    );
  }
}

class _ActivityTimelineCard extends StatelessWidget {
  final ActivityTimelineItem activity;

  const _ActivityTimelineCard({
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              ActivityTimeline.getIcon(activity.type),
              size: 17,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  activity.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),

                if (activity.performedBy != null &&
                    activity.performedBy!.isNotEmpty) ...[
                  const SizedBox(height: 6),

                  Text(
                    'By ${activity.performedBy}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],

                if (activity.timestamp != null) ...[
                  const SizedBox(height: 3),

                  Text(
                    DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(
                      activity.timestamp!.toLocal(),
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}