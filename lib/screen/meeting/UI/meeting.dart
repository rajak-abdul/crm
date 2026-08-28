import 'package:crm_app/screen/meeting/cubit/meeting_cubit.dart';
import 'package:crm_app/screen/meeting/cubit/meeting_state.dart';
import 'package:crm_app/screen/meeting/modal/meeting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';


class MeetingsScreen extends StatelessWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MeetingsCubit()..loadMeetings(),
      child: const _MeetingsView(),
    );
  }
}
class _MeetingsView extends StatefulWidget {
  const _MeetingsView();

  @override
  State<_MeetingsView> createState() => _MeetingsViewState();
}

class _MeetingsViewState extends State<_MeetingsView>
    with WidgetsBindingObserver {

  final TextEditingController _searchController =
      TextEditingController();

  String _activeFilter = 'all';
  String _searchQuery = '';

  @override
void initState() {
  super.initState();
  
  WidgetsBinding.instance.addObserver(this);

}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<MeetingsCubit>().checkGoogleConnection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  List<Meeting> _filterMeetings(List<Meeting> meetings) {
  var result = meetings;

  if (_activeFilter != 'all') {
    result = result.where((meeting) {
      final displayStatus = getMeetingDisplayStatus(meeting);

      return displayStatus == _activeFilter;
    }).toList();
  }

  if (_searchQuery.isNotEmpty) {
    result = result.where((meeting) {
      return meeting.title.toLowerCase().contains(_searchQuery) ||
          meeting.description.toLowerCase().contains(_searchQuery) ||
          (meeting.creatorEmail ?? '')
              .toLowerCase()
              .contains(_searchQuery);
    }).toList();
  }

  return result;
}

  int _countStatus(
  List<Meeting> meetings,
  String status,
) {
  return meetings.where((meeting) {
    return getMeetingDisplayStatus(meeting) == status;
  }).length;
}

  // Future<void> _connectGoogle() async {
  //   final cubit = context.read<MeetingsCubit>();

  //   try {
  //     final authUrl = await cubit.getGoogleAuthUrl();

  //     if (authUrl == null || authUrl.isEmpty) {
  //       if (!mounted) return;

  //       _showMessage(
  //         'Unable to start Google authentication.',
  //       );
  //       return;
  //     }

  //     final uri = Uri.parse(authUrl);

  //     final launched = await launchUrl(
  //       uri,
  //       mode: LaunchMode.externalApplication,
  //     );

  //     if (!launched && mounted) {
  //       _showMessage(
  //         'Could not open Google authentication.',
  //       );
  //     }
  //   } catch (e) {
  //     if (!mounted) return;

  //     _showMessage(
  //       'Google connection failed.',
  //     );
  //   }
  // }

  String getMeetingDisplayStatus(Meeting meeting) {
  // Cancelled always stays cancelled
  if (meeting.status.toLowerCase() == 'cancelled') {
    return 'cancelled';
  }

  // Compare the complete end date + time with now
  final now = DateTime.now();
  final endDateTime = meeting.endDateTime.toLocal();

  if (endDateTime.isBefore(now)) {
    return 'completed';
  }

  return 'scheduled';
}

  void _showConnectGoogleDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: Colors.blue,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connect Google',
                ),
              ),
            ],
          ),
          content: const Text(
            'You need to connect your Google account before creating a meeting.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // _connectGoogle();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Connect Google',
              ),
            ),
          ],
        );
      },
    );
  }

  void _onNewMeeting() {
    final state = context.read<MeetingsCubit>().state;

    if (state is MeetingsLoaded &&
        !state.googleConnected) {
      _showConnectGoogleDialog();
      return;
    }

    if (state is MeetingsCreating) {
      return;
    }

    _showCreateMeetingSheet();
  }

  _showCreateMeetingSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return CreateMeetingSheet(
        checkZoomConnection: () =>
            context.read<MeetingsCubit>().checkZoomConnection(),
        onSubmit: ({
          required title,
          required description,
          required startDateTime,
          required endDateTime,
          required attendees,
          required reminderMinutes,
          required provider,
        }) async {
          final success =
              await context
                  .read<MeetingsCubit>()
                  .createMeeting(
                    title: title,
                    description: description,
                    startDateTime: startDateTime,
                    endDateTime: endDateTime,
                    attendees: attendees,
                    reminderMinutes:
                        reminderMinutes,
                    provider: provider,
                  );

          if (!mounted) return;

          if (success) {
            Navigator.pop(context);

            _showMessage(
              'Meeting created successfully.',
            );
          }
        },
      );
    },
  );
}

void _showEditMeetingSheet(Meeting meeting) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return CreateMeetingSheet(
        meeting: meeting,
        checkZoomConnection: () =>
            context.read<MeetingsCubit>().checkZoomConnection(),
        onSubmit: ({
          required title,
          required description,
          required startDateTime,
          required endDateTime,
          required attendees,
          required reminderMinutes,
          required provider,
        }) async {
          final success = await context
              .read<MeetingsCubit>()
              .updateMeeting(
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

          if (!mounted) return;

          if (success) {
            if (sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }

            _showMessage(
              'Meeting updated successfully.',
            );
          }
        },
      );
    },
  );
}

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8fc),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xfff6f8fc),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Meetings',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: Color(0xff172033),
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<MeetingsCubit, MeetingsState>(
            builder: (context, state) {
              return IconButton(
                onPressed: state is MeetingsLoading
                    ? null
                    : () {
                        context
                            .read<MeetingsCubit>()
                            .refreshMeetings();
                      },
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 22,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<MeetingsCubit, MeetingsState>(
        listener: (context, state) {
          if (state is MeetingsError) {
            _showMessage(state.message);
          }
        },
        builder: (context, state) {
          if (state is MeetingsInitial ||
              state is MeetingsLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is MeetingsError) {
            return _ErrorView(
              message: state.message,
              onRetry: () {
                context
                    .read<MeetingsCubit>()
                    .loadMeetings();
              },
            );
          }

          List<Meeting> meetings = [];
          bool googleConnected = false;
          bool creating = false;

          if (state is MeetingsLoaded) {
            meetings = state.meetings;
            googleConnected = state.googleConnected;
          }

          if (state is MeetingsCreating) {
            meetings = state.meetings;
            googleConnected = state.googleConnected;
            creating = true;
          }

          final filtered =
              _filterMeetings(meetings);

          return RefreshIndicator(
            onRefresh: () {
              return context
                  .read<MeetingsCubit>()
                  .refreshMeetings();
            },
            child: Column(
              children: [
                const SizedBox(height: 4),

                // Google connection
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: googleConnected
                      ? _GoogleConnectedCard(
                          email: meetings.isNotEmpty
                              ? meetings.first.creatorEmail
                              : null,
                        )
                      : _GoogleDisconnectedCard(
                          onConnect: () async {
  final success =
      await context.read<MeetingsCubit>().connectGoogle();

  if (!success && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to connect Google Calendar',
        ),
      ),
    );
  }
},
                        ),
                ),

                const SizedBox(height: 12),

                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search meetings...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xffe2e7ef),
                        ),
                      ),
                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xffe2e7ef),
                        ),
                      ),
                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Filters
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    children: [
                      _FilterChip(
                        label: 'All',
                        count: meetings.length,
                        active:
                            _activeFilter == 'all',
                        onTap: () {
                          setState(() {
                            _activeFilter = 'all';
                          });
                        },
                      ),
                      _FilterChip(
                        label: 'Scheduled',
                        count: _countStatus(
                          meetings,
                          'scheduled',
                        ),
                        active:
                            _activeFilter == 'scheduled',
                        onTap: () {
                          setState(() {
                            _activeFilter =
                                'scheduled';
                          });
                        },
                      ),
                      _FilterChip(
                        label: 'Completed',
                        count: _countStatus(
                          meetings,
                          'completed',
                        ),
                        active:
                            _activeFilter == 'completed',
                        onTap: () {
                          setState(() {
                            _activeFilter =
                                'completed';
                          });
                        },
                      ),
                      _FilterChip(
                        label: 'Cancelled',
                        count: _countStatus(
                          meetings,
                          'cancelled',
                        ),
                        active:
                            _activeFilter ==
                                'cancelled',
                        onTap: () {
                          setState(() {
                            _activeFilter =
                                'cancelled';
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Section title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'UPCOMING',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Color(0xff8a94a6),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filtered.length} meetings',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff8a94a6),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Meeting list
                Expanded(
                  child: filtered.isEmpty
                      ? _EmptyMeetings()
                      : ListView.separated(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            110,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(
                            height: 10,
                          ),
                          itemBuilder:
                              (context, index) {
                            final meeting = filtered[index];

return _MeetingCard(
  meeting: meeting,
  displayStatus: getMeetingDisplayStatus(meeting),
  onJoin: () {
    _joinMeeting(meeting);
  },
  onEdit: () {
    _showEditMeetingSheet(meeting);
  },
  onCancel: () {
    _showCancelConfirmation(meeting);
  },
);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          12,
        ),
        child: BlocBuilder<MeetingsCubit, MeetingsState>(
          builder: (context, state) {
            bool connected = false;
            bool creating = false;

            if (state is MeetingsLoaded) {
              connected = state.googleConnected;
            }

            if (state is MeetingsCreating) {
              connected = state.googleConnected;
              creating = true;
            }

            return SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: creating
                    ? null
                    : _onNewMeeting,
                icon: Icon(
                  connected
                      ? Icons.add_rounded
                      : Icons.lock_outline_rounded,
                ),
                label: Text(
                  connected
                      ? 'New Meeting'
                      : 'Connect Google to create',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: connected
                      ? Colors.blue
                      : const Color(0xffdfe5ee),
                  foregroundColor: connected
                      ? Colors.white
                      : const Color(0xff7d8796),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCancelConfirmation(Meeting meeting) {
  showDialog(
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
              Navigator.pop(dialogContext);
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              final success = await context
                  .read<MeetingsCubit>()
                  .cancelMeeting(
                    meetingId: meeting.id,
                  );

              if (!mounted) return;

              _showMessage(
                success
                    ? 'Meeting cancelled successfully.'
                    : 'Failed to cancel meeting.',
              );
            },
            child: const Text('Cancel Meeting'),
          ),
        ],
      );
    },
  );
}
  
  Future<void> _joinMeeting(
    Meeting meeting,
  ) async {
    if (meeting.meetLink == null ||
        meeting.meetLink!.isEmpty) {
      _showMessage(
        'Meeting link is not available.',
      );
      return;
    }

    final uri = Uri.parse(meeting.meetLink!);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}

// ============================================================
// GOOGLE CONNECTED CARD
// ============================================================

class _GoogleConnectedCard extends StatelessWidget {
  final String? email;

  const _GoogleConnectedCard({
    this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffecfdf3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffb7ebc9),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xffd1fae5),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xff16a34a),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google account connected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff166534),
                  ),
                ),
                if (email != null &&
                    email!.isNotEmpty)
                  Text(
                    email!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xff4d7c5b),
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

// ============================================================
// GOOGLE DISCONNECTED CARD
// ============================================================

class _GoogleDisconnectedCard
    extends StatelessWidget {
  final VoidCallback onConnect;

  const _GoogleDisconnectedCard({
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffff4f4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffffd0d0),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xffffe1e1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xffdc2626),
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Google account not connected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff991b1b),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Connect Google to create meetings.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xffb45353),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onConnect,
            child: const Text(
              'Connect',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FILTER CHIP
// ============================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            color: active
                ? Colors.blue
                : Colors.white,
            borderRadius:
                BorderRadius.circular(30),
            border: Border.all(
              color: active
                  ? Colors.blue
                  : const Color(0xffe1e6ee),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : const Color(0xff5c6678),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints:
                    const BoxConstraints(
                  minWidth: 18,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white
                          .withOpacity(.2)
                      : const Color(0xfff0f3f7),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Colors.white
                        : const Color(0xff6b7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MEETING CARD
// ============================================================

String _providerLabel(String provider) {
  switch (provider.toLowerCase().trim()) {
    case 'zoom':
      return 'Zoom';
    case 'google_meet':
    case '':
      return 'Google Meet';
    default:
      return provider;
  }
}

class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final String displayStatus;
  final VoidCallback onJoin;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _MeetingCard({
    required this.meeting,
    required this.onJoin,
    required this.onEdit,
    required this.onCancel, 
    required this.displayStatus,
  });

  @override
  Widget build(BuildContext context) {
    final start = meeting.startDateTime.toLocal();
    final end = meeting.endDateTime.toLocal();

    final date =
        DateFormat('MMM dd, yyyy').format(start);

    final startTime =
        DateFormat('h:mm a').format(start);

    final endTime =
        DateFormat('h:mm a').format(end);

    final cancelled =
        meeting.status.toLowerCase() ==
            'cancelled';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffe4e8ef),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xffeff6ff),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.videocam_outlined,
                  size: 19,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff172033),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _providerLabel(meeting.provider),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xff7b8494),
                          ),
                        ),
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(
                            horizontal: 5,
                          ),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color:
                                  Color(0xffc4cad3),
                            ),
                          ),
                        ),
                        _StatusBadge(
                          status: displayStatus,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          const Divider(
            height: 1,
            color: Color(0xffeef1f5),
          ),

          const SizedBox(height: 11),

          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: Color(0xff8a94a6),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$date · $startTime – $endTime',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff667085),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Row(
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 15,
                color: Color(0xff9aa3b1),
              ),
              const SizedBox(width: 7),
              Text(
                'Reminder: ${meeting.reminderMinutes} min before',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xff8a94a6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          const Divider(
            height: 1,
            color: Color(0xffeef1f5),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      cancelled ? null : onJoin,
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 14,
                  ),
                  label: const Text(
                    'Join link',
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        const Color(0xff475467),
                    backgroundColor:
                        const Color(0xfff5f7fa),
                    side: BorderSide.none,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 9,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(9),
                    ),
                    textStyle:
                        const TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed:
                    cancelled ? null : onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                ),
                color:
                    const Color(0xff8a94a6),
              ),
              IconButton(
                onPressed:
                    cancelled ? null : onCancel,
                icon: const Icon(
                  Icons.block_outlined,
                  size: 18,
                ),
                color:
                    const Color(0xff8a94a6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STATUS BADGE
// ============================================================

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final cancelled =
        status.toLowerCase() == 'cancelled';

    final completed =
        status.toLowerCase() == 'completed';

    final Color background;
    final Color foreground;

    if (cancelled) {
      background = const Color(0xffffeeee);
      foreground = const Color(0xffdc2626);
    } else if (completed) {
      background = const Color(0xffecfdf3);
      foreground = const Color(0xff16a34a);
    } else {
      background = const Color(0xffeff6ff);
      foreground = const Color(0xff2563eb);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY
// ============================================================

class _EmptyMeetings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        Icon(
          Icons.event_busy_outlined,
          size: 48,
          color: Color(0xffaab2bf),
        ),
        SizedBox(height: 12),
        Center(
          child: Text(
            'No meetings found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xff667085),
            ),
          ),
        ),
        SizedBox(height: 4),
        Center(
          child: Text(
            'Your meetings will appear here.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xff98a2b3),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff667085),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CREATE MEETING SHEET
// ============================================================

class CreateMeetingSheet extends StatefulWidget {
  final Meeting? meeting;
  final String? leadId;
  final String? dealId;

  final Future<void> Function({
    required String title,
    required String description,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required List<String> attendees,
    required int reminderMinutes,
    required String provider,
  }) onSubmit;

  final Future<bool> Function()? checkZoomConnection;

  const CreateMeetingSheet({
    this.meeting,
    this.leadId,
    this.dealId,
    required this.onSubmit,
    this.checkZoomConnection,
  });


  @override
  State<CreateMeetingSheet> createState() =>
      CreateMeetingSheetState();
}

class CreateMeetingSheetState
    extends State<CreateMeetingSheet> {

  bool get isEdit => widget.meeting != null;
  final _titleController =
      TextEditingController();

  final _descriptionController =
      TextEditingController();

  final _attendeeController =
      TextEditingController();

  final List<String> _attendees = [];

  DateTime _startDateTime =
      DateTime.now().add(
    const Duration(hours: 1),
  );

  DateTime _endDateTime =
      DateTime.now().add(
    const Duration(hours: 2),
  );

  int _reminderMinutes = 10;

  String _provider = 'google_meet';

  bool _creating = false;

  bool _zoomConnected = true;

  @override
void initState() {
  super.initState();

  final meeting = widget.meeting;

  if (meeting != null) {
    _titleController.text = meeting.title;
    _descriptionController.text = meeting.description;

    _startDateTime =
        meeting.startDateTime.toLocal();

    _endDateTime =
        meeting.endDateTime.toLocal();

    _reminderMinutes =
        meeting.reminderMinutes;

    if (meeting.provider.toLowerCase().trim() == 'zoom') {
      _provider = 'zoom';
    }

    _attendees.addAll(
      meeting.attendees,
    );
  }

  widget.checkZoomConnection?.call().then((connected) {
    if (!mounted) return;
    setState(() {
      _zoomConnected = connected;
      if (!connected && _provider == 'zoom') {
        _provider = 'google_meet';
      }
    });
  });
}
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _attendeeController.dispose();

    super.dispose();
  }

  void _addAttendee() {
  final email = _attendeeController.text.trim();

  if (email.isEmpty) {
    return;
  }

  // Basic email validation
  final emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  if (!emailRegex.hasMatch(email)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a valid email address.'),
      ),
    );
    return;
  }

  if (_attendees.contains(email)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This email is already added.'),
      ),
    );
    return;
  }

  setState(() {
    _attendees.add(email);
    _attendeeController.clear();
  });
}

void _removeAttendee(String email) {
  setState(() {
    _attendees.remove(email);
  });
}

  Future<void> _selectStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(_startDateTime),
    );

    if (time == null) return;

    setState(() {
      _startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      if (!_endDateTime.isAfter(_startDateTime)) {
        _endDateTime = _startDateTime.add(
          const Duration(hours: 1),
        );
      }
    });
  }

  Future<void> _selectEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDateTime,
      firstDate: _startDateTime,
      lastDate: DateTime(2035),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(_endDateTime),
    );

    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!selected.isAfter(_startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'End time must be after start time.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _endDateTime = selected;
    });
  }

  Future<void> _submit() async {
  final title = _titleController.text.trim();

  if (title.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a meeting title.'),
      ),
    );
    return;
  }

  if (!_endDateTime.isAfter(_startDateTime)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('End time must be after start time.'),
      ),
    );
    return;
  }

  setState(() {
    _creating = true;
  });

  try {
    await widget.onSubmit(
      title: title,
      description: _descriptionController.text.trim(),
      startDateTime: _startDateTime,
      endDateTime: _endDateTime,
      attendees: List<String>.from(_attendees),
      reminderMinutes: _reminderMinutes,
      provider: _provider,
    );
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _creating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to save meeting: $e'),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        bottom: bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffd5d9e0),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
  isEdit
      ? 'Edit Meeting'
      : 'New Meeting',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _ProviderTab(
                provider: _provider,
                zoomEnabled: _zoomConnected,
                onChanged: (value) {
                  if (value == 'zoom' && !_zoomConnected) return;
                  setState(() {
                    _provider = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration:
                    const InputDecoration(
                  labelText: 'Meeting title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller:
                    _descriptionController,
                maxLines: 3,
                decoration:
                    const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _DateTimeTile(
                icon: Icons.play_circle_outline,
                title: 'Start',
                value: DateFormat(
                  'MMM dd, yyyy · h:mm a',
                ).format(_startDateTime),
                onTap: _selectStart,
              ),
              const SizedBox(height: 8),
              _DateTimeTile(
                icon: Icons.stop_circle_outlined,
                title: 'End',
                value: DateFormat(
                  'MMM dd, yyyy · h:mm a',
                ).format(_endDateTime),
                onTap: _selectEnd,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _reminderMinutes,
                decoration:
                    const InputDecoration(
                  labelText: 'Reminder',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 5,
                    child: Text('5 minutes before'),
                  ),
                  DropdownMenuItem(
                    value: 10,
                    child:
                        Text('10 minutes before'),
                  ),
                  DropdownMenuItem(
                    value: 15,
                    child:
                        Text('15 minutes before'),
                  ),
                  DropdownMenuItem(
                    value: 30,
                    child:
                        Text('30 minutes before'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _reminderMinutes = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              
const Text(
  'Attendees (emails)',
  style: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xff344054),
  ),
),

const SizedBox(height: 8),

Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: TextField(
        controller: _attendeeController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _addAttendee(),
        decoration: InputDecoration(
          hintText: 'name@email.com',
          hintStyle: const TextStyle(
            color: Color(0xff98a2b3),
            fontSize: 13,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xffe2e7ef),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xffe2e7ef),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.blue,
            ),
          ),
        ),
      ),
    ),

    const SizedBox(width: 8),

    SizedBox(
      height: 48,
      width: 48,
      child: ElevatedButton(
        onPressed: _addAttendee,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xffeff6ff),
          foregroundColor: Colors.blue,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Icon(
          Icons.add,
          size: 20,
        ),
      ),
    ),
  ],
),

if (_attendees.isNotEmpty) ...[
  const SizedBox(height: 10),

  ..._attendees.map(
    (email) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xffe2e7ef),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.email_outlined,
              size: 16,
              color: Color(0xff667085),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                email,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xff344054),
                ),
              ),
            ),

            IconButton(
              onPressed: () => _removeAttendee(email),
              icon: const Icon(
                Icons.close,
                size: 17,
              ),
              color: const Color(0xff98a2b3),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 30,
              ),
            ),
          ],
        ),
      );
    },
  ),
],
SizedBox(height:20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _creating ? null : _submit,
                  child: _creating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      :  Text(
                          isEdit
                         ? 'Save Changes'
                         : 'Create Meeting',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DATE TIME TILE
// ============================================================

class _DateTimeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _DateTimeTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xfff8fafc),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xffe2e7ef),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xff8a94a6),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xff98a2b3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderTab extends StatelessWidget {
  final String provider;
  final ValueChanged<String> onChanged;
  final bool zoomEnabled;

  const _ProviderTab({
    required this.provider,
    required this.onChanged,
    this.zoomEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ProviderOption(
              icon: Icons.videocam_outlined,
              label: 'Google Meet',
              selected: provider == 'google_meet',
              onTap: () => onChanged('google_meet'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ProviderOption(
              icon: Icons.laptop_mac_outlined,
              label: 'Zoom',
              selected: provider == 'zoom',
              enabled: zoomEnabled,
              disabledMessage: 'Connect Zoom in settings first',
              onTap: () => onChanged('zoom'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final String? disabledMessage;

  const _ProviderOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    final content = Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 9,
            horizontal: 6,
          ),
          decoration: BoxDecoration(
            color: selected && enabled ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected && enabled
                ? Border.all(color: Colors.blue, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                enabled ? icon : Icons.lock_outline,
                size: 18,
                color: selected && enabled
                    ? Colors.blue
                    : const Color(0xff8a94a6),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected && enabled
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: selected && enabled
                      ? Colors.blue
                      : const Color(0xff8a94a6),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!enabled && disabledMessage != null) {
      return Tooltip(message: disabledMessage!, child: content);
    }

    return content;
  }
}