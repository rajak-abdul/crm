import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm_app/screen/meeting/UI/meeting.dart';
import 'package:crm_app/screen/meeting/cubit/meeting_cubit.dart';
import 'package:crm_app/screen/meeting/cubit/meeting_state.dart';
import 'package:crm_app/screen/meeting/modal/meeting.dart';
import 'package:crm_app/thems/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _completedMeetingStatuses = {
  'completed',
  'done',
  'finished',
};

const _cancelledMeetingStatuses = {
  'cancelled',
  'canceled',
};

class MeetingsCard extends StatelessWidget {
  final String filterRange;
  final int? filterMonth;
  final int? filterYear;

  const MeetingsCard({
    super.key,
    this.filterRange = 'all',
    this.filterMonth,
    this.filterYear,
  });
static ({
  int total,
  int scheduled,
  int completed,
  int cancelled,
  int googleMeet,
  int zoom,
}) _countByStatus(List<Meeting> meetings) {
  int scheduled = 0;
  int completed = 0;
  int cancelled = 0;
  int googleMeet = 0;
  int zoom = 0;

  final now = DateTime.now();

  for (final meeting in meetings) {
    final status = meeting.status.trim().toLowerCase();

    if (meeting.provider.trim().toLowerCase() == 'zoom') {
      zoom++;
    } else {
      googleMeet++;
    }

    // Cancelled always stays cancelled
    if (status == 'cancelled' || status == 'canceled') {
      cancelled++;
      continue;
    }

    final startDateTime = meeting.startDateTime.toLocal();
    final isToday = startDateTime.year == now.year &&
        startDateTime.month == now.month &&
        startDateTime.day == now.day;

    final endDateTime = meeting.endDateTime.toLocal();

    // A meeting scheduled for today stays "Scheduled" all day, even after
    // its end time passes — it only becomes "Completed" once today is over.
    if (!isToday &&
        (now.isAfter(endDateTime) ||
            now.isAtSameMomentAs(endDateTime))) {
      completed++;
    } else {
      scheduled++;
    }
  }

  return (
    total: meetings.length,
    scheduled: scheduled,
    completed: completed,
    cancelled: cancelled,
    googleMeet: googleMeet,
    zoom: zoom,
  );
}

DateTimeRange? _getDateRange() {
  final now = DateTime.now();

  switch (filterRange) {
    case 'today':
      return DateTimeRange(
        start: DateTime(
          now.year,
          now.month,
          now.day,
        ),
        end: DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
          999,
        ),
      );

    case 'last7':
      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      return DateTimeRange(
        start: today.subtract(
          const Duration(days: 6),
        ),
        end: DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
          999,
        ),
      );

    case 'month':
      if (filterMonth == null || filterYear == null) {
        return null;
      }

      return DateTimeRange(
        start: DateTime(
          filterYear!,
          filterMonth!,
          1,
        ),
        end: DateTime(
          filterYear!,
          filterMonth! + 1,
          0,
          23,
          59,
          59,
          999,
        ),
      );

    case 'year':
      if (filterYear == null) {
        return null;
      }

      return DateTimeRange(
        start: DateTime(
          filterYear!,
          1,
          1,
        ),
        end: DateTime(
          filterYear!,
          12,
          31,
          23,
          59,
          59,
          999,
        ),
      );

    case 'all':
    default:
      return null;
  }
}

List<Meeting> _filterByDate(List<Meeting> meetings) {
  final range = _getDateRange();

  if (range == null) {
    return meetings;
  }

  return meetings.where((meeting) {
    final meetingDate =
        meeting.startDateTime.toLocal();

    return !meetingDate.isBefore(range.start) &&
        !meetingDate.isAfter(range.end);
  }).toList();
}

Future<void> _goToMeetings(BuildContext context) async {
    final result = await Connectivity().checkConnectivity();

    if (result == ConnectivityResult.none) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You are offline. Only Dashboard is available.',
          ),
        ),
      );

      return;
    }

    if (!context.mounted) return;

    Navigator.of(
      context,
      rootNavigator: true,
    ).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) {
          return const MeetingsScreen();
        },
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT:
    // Do NOT create another MeetingsCubit here.
    //
    // This uses the MeetingsCubit provided above
    // the Dashboard.
    return BlocBuilder<MeetingsCubit, MeetingsState>(
      builder: (context, state) {
if (state is MeetingsLoaded) {
  final meetings = _filterByDate(state.meetings);

  final counts = _countByStatus(meetings);
          return _buildCard(
  context,
  total: counts.total,
  scheduled: counts.scheduled,
  completed: counts.completed,
  cancelled: counts.cancelled,
  googleMeet: counts.googleMeet,
  zoom: counts.zoom,
);
        }

if (state is MeetingsCreating) {
  final meetings = _filterByDate(state.meetings);

  final counts = _countByStatus(meetings);
          return _buildCard(
            context,
            total: counts.total,
            scheduled: counts.scheduled,
            completed: counts.completed,
            cancelled: counts.cancelled,
            googleMeet: counts.googleMeet,
            zoom: counts.zoom,
          );
        }

        if (state is MeetingsError) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _goToMeetings(context),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Couldn't load meetings — tap to view",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Initial/loading state
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const SizedBox(
            height: 178,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required int scheduled,
    required int completed,
    required int total,
    required int cancelled,
    required int googleMeet,
    required int zoom,
  }) {

    final safeTotal = total == 0 ? 1 : total;

    final scheduledFlex =
        scheduled == 0 ? 0 : scheduled;

    final completedFlex =
        completed == 0 ? 0 : completed;

    final scheduledPct =
        (scheduled / safeTotal * 100).round();

    final completedPct =
        (completed / safeTotal * 100).round();

    final cancelledPct =
    (cancelled / safeTotal * 100).round();

    return Material(
  color: Colors.transparent,
  child: InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => _goToMeetings(context),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 10),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meetings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'All meetings',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // PROGRESS BAR
ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: SizedBox(
    height: 7,
    child: total == 0
        ? Container(
            color: AppColors.divider,
          )
        : Row(
            children: [
              // Scheduled
              if (scheduled > 0)
                Expanded(
                  flex: scheduled,
                  child: Container(
                    color: AppColors.primary,
                  ),
                ),

              // Completed
              if (completed > 0)
                Expanded(
                  flex: completed,
                  child: Container(
                    color: AppColors.success,
                  ),
                ),

              // Cancelled
              if (cancelled > 0)
                Expanded(
                  flex: cancelled,
                  child: Container(
                    color: Colors.red,
                  ),
                ),
            ],
          ),
  ),
),
          const SizedBox(height: 8),

          // PERCENTAGES
          Row(
  children: [
    _LegendDot(
      color: AppColors.primary,
      label: '$scheduledPct% scheduled',
    ),

    const SizedBox(width: 10),

    _LegendDot(
      color: AppColors.success,
      label: '$completedPct% completed',
    ),

    const SizedBox(width: 10),

    _LegendDot(
      color: Colors.red,
      label: '$cancelledPct% cancelled',
    ),
  ],
),
          const SizedBox(height: 16),

          Row(
  children: [
    Expanded(
      child: _MeetingIconStat(
        icon: Icons.schedule_rounded,
        iconColor: AppColors.primary,
        iconBg: AppColors.primaryLight,
        value: scheduled,
      ),
    ),

    const SizedBox(width: 8),

    Expanded(
      child: _MeetingIconStat(
        icon: Icons.check_circle_rounded,
        iconColor: AppColors.success,
        iconBg: AppColors.success.withOpacity(0.12),
        value: completed,
      ),
    ),

    const SizedBox(width: 8),

    Expanded(
      child: _MeetingIconStat(
        icon: Icons.cancel_rounded,
        iconColor: Colors.red,
        iconBg: Colors.red.withOpacity(0.10),
        value: cancelled,
      ),
    ),
  ],
),

          const SizedBox(height: 8),

          Row(
  children: [
    Expanded(
      child: _MeetingStatTile(
        icon: Icons.videocam_rounded,
        iconColor: AppColors.primary,
        iconBg: AppColors.primaryLight,
        label: 'Google Meet',
        value: '$googleMeet',
        valueColor: AppColors.textPrimary,
      ),
    ),

    const SizedBox(width: 8),

    Expanded(
      child: _MeetingStatTile(
        icon: Icons.laptop_mac_rounded,
        iconColor: AppColors.accent,
        iconBg: AppColors.accent.withOpacity(0.12),
        label: 'Zoom',
        value: '$zoom',
        valueColor: AppColors.textPrimary,
      ),
    ),
  ],
),

          const SizedBox(height: 14),


        ],
      ),
    ),
  )
    );
  }
}
class _MeetingIconStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final int value;

  const _MeetingIconStat({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
          ),

          const SizedBox(width: 8),

          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MeetingStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final Color valueColor;

  const _MeetingStatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius:
                      BorderRadius.circular(7),
                ),
                child: Icon(
                  icon,
                  size: 13,
                  color: iconColor,
                ),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}