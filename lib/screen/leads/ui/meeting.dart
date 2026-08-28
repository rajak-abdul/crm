import 'package:crm_app/screen/meeting/UI/meeting.dart';
import 'package:crm_app/screen/meeting/cubit/meeting_cubit.dart';
import 'package:crm_app/screen/meeting/modal/meeting.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart' show showApiSnack;
import 'package:crm_app/thems/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final MeetingsCubit meetingsCubit;
  final Future<void> Function(String message)? onMeetingUpdated;

const MeetingCard({
  required this.meeting,
  required this.meetingsCubit,
  this.onMeetingUpdated,
  super.key,
});

  String _status() {
    if (meeting.status.toLowerCase() == 'cancelled') {
      return 'Cancelled';
    }

    if (meeting.endDateTime.toLocal().isBefore(DateTime.now())) {
      return 'Completed';
    }

    return 'Scheduled';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();

    final statusColor = status == 'Cancelled'
        ? Colors.red
        : status == 'Completed'
            ? Colors.green
            : AppColors.primary;

    final provider = meeting.provider.toLowerCase() == 'google_meet'
        ? 'Google Meet'
        : meeting.provider.toLowerCase() == 'zoom'
            ? 'Zoom'
            : meeting.provider;

    return Card(
      margin: const EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: 8,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MeetingsScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Column(
            children: [
              // ─────────────────────────────────────
              // ROW 1 : ICON + TITLE + STATUS
              // ─────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.video_call_outlined,
                      color: AppColors.primary,
                      size: 19,
                    ),
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      meeting.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              // ─────────────────────────────────────
              // ROW 2 : DATE + PROVIDER + ACTIONS
              // ─────────────────────────────────────
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: Colors.grey.shade500,
                  ),

                  const SizedBox(width: 5),

                  Expanded(
                    child: Text(
                      '${DateFormat('dd MMM yyyy, h:mm a').format(
                        meeting.startDateTime.toLocal(),
                      )}  •  $provider',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                  if (status == 'Scheduled') ...[
                    IconButton(
  tooltip: 'Edit',
  onPressed: () async {
    final message = await _editMeeting(
      context,
      meeting,
    );

    if (message == null) return;

    if (onMeetingUpdated != null) {
      await onMeetingUpdated!(message);
    } else if (context.mounted) {
      showApiSnack(context, message);
    }
  },
  icon: const Icon(
    Icons.edit_outlined,
    size: 18,
    color: AppColors.primary,
  ),
),

                    IconButton(
  tooltip: 'Cancel',
  onPressed: () {
    _cancelMeeting(
      context,
      meeting,
    );
  },
  icon: const Icon(
    Icons.cancel_outlined,
    size: 18,
    color: Colors.red,
  ),
),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

Future<String?> _editMeeting(
  BuildContext context,
  Meeting meeting,
) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return CreateMeetingSheet(
        meeting: meeting,
        leadId: meeting.leadId,
        checkZoomConnection: meetingsCubit.checkZoomConnection,
        onSubmit: ({
          required title,
          required description,
          required startDateTime,
          required endDateTime,
          required attendees,
          required reminderMinutes,
          required provider,
        }) async {
          final success = await meetingsCubit.updateMeeting(
            meetingId: meeting.id,
            title: title,
            description: description,
            dealId: meeting.dealId,
            leadId: meeting.leadId,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            attendees: attendees,
            reminderMinutes: reminderMinutes,
            provider: provider,
          );

          if (!success) {
            throw Exception('Failed to update meeting');
          }

          // Refresh meetings
          await meetingsCubit.loadMeetings();

          // Close edit sheet and return success message
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop(
              'Meeting updated successfully.',
            );
          }
        },
      );
    },
  );

  return result;
}
Future<void> _cancelMeeting(
  BuildContext context,
  Meeting meeting,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Cancel Meeting'),
        content: Text(
          'Are you sure you want to cancel "${meeting.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Cancel Meeting'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  final success = await meetingsCubit.cancelMeeting(
    meetingId: meeting.id,
  );

  if (!success) {
    if (!context.mounted) return;

    showApiSnack(context, 'Failed to cancel meeting.', isError: true);
    return;
  }

  await meetingsCubit.loadMeetings();

  if (!context.mounted) return;

  showApiSnack(context, 'Meeting cancelled successfully.');
}}