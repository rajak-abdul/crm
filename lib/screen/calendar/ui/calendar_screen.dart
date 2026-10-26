// ╔══════════════════════════════════════════════════════════════╗
// ║           lib/screen/calendar/UI/calendar_screen.dart         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/calendar/UI/calendar_category.dart';
import 'package:crm_app/screen/calendar/UI/calendar_data_source.dart';
import 'package:crm_app/screen/calendar/cubit/calendar_cubit.dart';
import 'package:crm_app/screen/calendar/cubit/calendar_state.dart';
import 'package:crm_app/screen/calendar/modal/calendar_model.dart';
import 'package:crm_app/screen/deals/ui/deal_screen.dart' show DealsScreen;
import 'package:crm_app/screen/email/cubit/email_cubit.dart';
import 'package:crm_app/screen/email/cubit/email_history_cubit.dart';
import 'package:crm_app/screen/email/ui/EmailContactsScreen.dart';
import 'package:crm_app/screen/invoice/ui/invoice_screen.dart';
import 'package:crm_app/screen/leads/ui/lead_screen.dart' show LeadsScreen;
import 'package:crm_app/screen/meeting/UI/meeting.dart' show MeetingsScreen;
import 'package:crm_app/screen/proposal/UI/proposal_screen.dart'
    show ProposalListScreen;
import 'package:crm_app/screen/proposal/cubit/proposal_cubit.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show LoadingState, ErrorState;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

// ══════════════════════════════════════════════════════════════
// ENTRY POINT — builds a tenant/auth-scoped Dio + CalendarCubit
// then hands off to the mobile calendar view.
// ══════════════════════════════════════════════════════════════
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarCubit? _cubit;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final cubit = CalendarCubit(Dio());
      await cubit.initialize();

      final now = DateTime.now();

      await cubit.loadCalendar(
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month + 2, 0, 23, 59, 59),
      );

      if (!mounted) return;
      setState(() => _cubit = cubit);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Calendar')),
        body: ErrorState(
          message: _initError!,
          onRetry: () {
            setState(() => _initError = null);
            _bootstrap();
          },
        ),
      );
    }

    final cubit = _cubit;

    if (cubit == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Calendar')),
        body: const LoadingState(message: 'Loading calendar...'),
      );
    }

    return BlocProvider.value(
      value: cubit,
      child: const _CalendarView(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MOBILE CALENDAR VIEW
// ══════════════════════════════════════════════════════════════
class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  final CalendarController _controller = CalendarController();
  final ScrollController _categoryScrollController = ScrollController();

  CalendarView _view = CalendarView.month;
  final Set<CalendarCategory> _selected = kCalendarCategories.keys.toSet();

  List<CalendarEvent> _events = [];
  bool _hasData = false;

  late DateTime _displayDate;
  late DateTime _loadedStart;
  late DateTime _loadedEnd;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _displayDate = now;
    _loadedStart = DateTime(now.year, now.month - 1, 1);
    _loadedEnd = DateTime(now.year, now.month + 2, 0, 23, 59, 59);

    _controller.view = _view;
    _controller.displayDate = now;

    // BlocConsumer's listener only fires on FUTURE state changes — by the
    // time this widget mounts, CalendarScreen has already awaited the
    // initial loadCalendar() call, so that state must be read here directly
    // or it's missed entirely and the loading spinner never clears.
    final initialState = context.read<CalendarCubit>().state;
    if (initialState is CalendarLoaded) {
      _events = initialState.events;
      _hasData = true;
    } else if (initialState is CalendarEmpty) {
      _events = [];
      _hasData = true;
    }
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    super.dispose();
  }

  // ── Filtering ────────────────────────────────────────────────

  List<CalendarEvent> get _filteredEvents {
    if (_selected.length == kCalendarCategories.length) return _events;
    return _events
        .where((e) => _selected.contains(categorizeEventType(e.type)))
        .toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Data loading ────────────────────────────────────────────

  void _ensureRangeLoaded(
    DateTime visibleStart,
    DateTime visibleEnd, {
    bool force = false,
  }) {
    final needsLoad = force ||
        visibleStart.isBefore(_loadedStart) ||
        visibleEnd.isAfter(_loadedEnd);

    if (!needsLoad) return;

    final newStart = DateTime(visibleStart.year, visibleStart.month - 1, 1);
    final newEnd =
        DateTime(visibleEnd.year, visibleEnd.month + 2, 0, 23, 59, 59);

    setState(() {
      _loadedStart = newStart;
      _loadedEnd = newEnd;
    });

    context.read<CalendarCubit>().loadCalendar(start: newStart, end: newEnd);
  }

  void _reloadCurrentRange() {
    context
        .read<CalendarCubit>()
        .loadCalendar(start: _loadedStart, end: _loadedEnd);
  }

  void _onViewChanged(ViewChangedDetails details) {
    if (details.visibleDates.isEmpty) return;

    final visibleStart = details.visibleDates.first;
    final visibleEnd = details.visibleDates.last;
    final mid = details.visibleDates[details.visibleDates.length ~/ 2];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _displayDate = mid);
      _ensureRangeLoaded(visibleStart, visibleEnd);
    });
  }

  // ── Navigation controls ─────────────────────────────────────

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _displayDate = now;
      _controller.displayDate = now;
    });
  }

  void _navigate(int direction) {
    DateTime next;

    switch (_view) {
      case CalendarView.week:
        next = _displayDate.add(Duration(days: 7 * direction));
        break;
      case CalendarView.day:
        next = _displayDate.add(Duration(days: direction));
        break;
      default:
        next = DateTime(_displayDate.year, _displayDate.month + direction, 1);
    }

    setState(() {
      _displayDate = next;
      _controller.displayDate = next;
    });
  }

  void _changeView(CalendarView view) {
    setState(() {
      _view = view;
      _controller.view = view;
    });
  }

  String _viewLabel(CalendarView view) => switch (view) {
        CalendarView.month => 'Month',
        CalendarView.week => 'Week',
        CalendarView.day => 'Day',
        CalendarView.schedule => 'Agenda',
        _ => 'Month',
      };

  String _headerLabel() {
    switch (_view) {
      case CalendarView.week:
        final start =
            _displayDate.subtract(Duration(days: _displayDate.weekday % 7));
        final end = start.add(const Duration(days: 6));
        return start.month == end.month
            ? '${DateFormat('MMM d').format(start)} - ${DateFormat('d, yyyy').format(end)}'
            : '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
      case CalendarView.day:
        return DateFormat('EEEE, MMM d, yyyy').format(_displayDate);
      default:
        return DateFormat('MMMM yyyy').format(_displayDate);
    }
  }

  // ── Tap handling ─────────────────────────────────────────────

  void _onCalendarTap(CalendarTapDetails details, List<CalendarEvent> events) {
    if (details.targetElement == CalendarElement.appointment) {
      final tapped =
          (details.appointments ?? const []).whereType<CalendarEvent>().toList();

      if (tapped.length == 1) {
        _showEventDetail(tapped.first);
        return;
      }
    }

    final date = details.date;
    if (date == null) return;

    final dayEvents =
        events.where((e) => _isSameDay(e.date.toLocal(), date)).toList();
    _showDayOptions(date, dayEvents);
  }

  // ── Bottom sheets ────────────────────────────────────────────

  void _showDayOptions(DateTime date, List<CalendarEvent> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: events.isEmpty ? 0.32 : 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.25,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, MMM d, yyyy').format(date),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (events.isNotEmpty)
                      Text(
                        '${events.length} event${events.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Material(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showAddNoteDialog(date);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.note_add_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Add Note',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Text(
                    'No events on this day.',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final isEditableNote =
                          categorizeEventType(event.type) ==
                                  CalendarCategory.note &&
                              event.editable != false;
                      return _EventRow(
                        event: event,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showEventDetail(event);
                        },
                        onDelete: isEditableNote
                            ? () {
                                Navigator.pop(sheetContext);
                                _confirmDeleteNote(event);
                              }
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddNoteDialog(DateTime date) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add Note • ${DateFormat('MMM d, yyyy').format(date)}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a note for this day...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogContext);
              // No time picker here — stamp the note with the actual
              // moment it's created (on the tapped day) so it reflects
              // real creation time instead of defaulting to midnight.
              final now = DateTime.now();
              final noteDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                now.hour,
                now.minute,
                now.second,
              );
              context.read<CalendarCubit>().addCalendarNote(
                    date: noteDateTime,
                    text: text,
                  );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Existing note → pre-fill the current text/date and PUT it back, which
  // overrides the stored note rather than creating a duplicate.
  void _showEditNoteDialog(CalendarEvent note) {
    final controller = TextEditingController(text: note.title);
    final date = note.date.toLocal();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Note • ${DateFormat('MMM d, yyyy').format(date)}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a note for this day...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogContext);
              context.read<CalendarCubit>().updateCalendarNote(
                    noteId: note.id,
                    date: note.date,
                    text: text,
                  );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNote(CalendarEvent note) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<CalendarCubit>().deleteCalendarNote(
                    noteId: note.id,
                  );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEventDetail(CalendarEvent event) {
    final info = categoryInfoOf(event.type);
    final category = categorizeEventType(event.type);
    final navigable = _isNavigable(category);
    final isEditableNote =
        category == CalendarCategory.note && event.editable != false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: info.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(info.icon, size: 18, color: info.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        info.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: info.color,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: _formatEventDate(event),
                ),
                if ((event.status ?? '').trim().isNotEmpty)
                  _DetailRow(icon: Icons.flag_outlined, label: event.status!),
                if ((event.dealName ?? '').trim().isNotEmpty)
                  _DetailRow(
                    icon: Icons.handshake_outlined,
                    label: 'Deal: ${event.dealName}',
                  ),
                if ((event.leadName ?? '').trim().isNotEmpty)
                  _DetailRow(
                    icon: Icons.person_outline,
                    label: 'Lead: ${event.leadName}',
                  ),
                if (event.pending == true)
                  const _DetailRow(
                    icon: Icons.hourglass_top_outlined,
                    label: 'Pending',
                  ),
                if (navigable) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: info.color,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _navigateToEvent(event);
                      },
                      child: const Text('View'),
                    ),
                  ),
                ],
                if (isEditableNote) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: info.color,
                        side: BorderSide(color: info.color),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showEditNoteDialog(event);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Note'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatEventDate(CalendarEvent event) {
    final start =
        DateFormat('MMM d, yyyy • h:mm a').format(event.date.toLocal());
    if (event.endDate == null) return start;
    final end =
        DateFormat('MMM d, yyyy • h:mm a').format(event.endDate!.toLocal());
    return '$start  →  $end';
  }

  bool _isNavigable(CalendarCategory category) => const {
        CalendarCategory.leadFollowup,
        CalendarCategory.dealFollowup,
        CalendarCategory.invoice,
        CalendarCategory.proposal,
        CalendarCategory.meeting,
        CalendarCategory.email,
      }.contains(category);

  // ── Navigation to linked screens ────────────────────────────

  void _navigateToEvent(CalendarEvent event) {
    final category = categorizeEventType(event.type);
    final link = event.link;

    switch (category) {
      case CalendarCategory.leadFollowup:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => LeadsScreen(
              selectedLeadId: link?.leadId ?? event.leadId,
              showBackButton: true,
            ),
          ),
        );
        break;

      case CalendarCategory.dealFollowup:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => const DealsScreen(showBackButton: true),
          ),
        );
        break;

      case CalendarCategory.invoice:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const InvoiceScreen()),
        );
        break;

      case CalendarCategory.proposal:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => ProposalCubit(),
              child: const ProposalListScreen(),
            ),
          ),
        );
        break;

      case CalendarCategory.meeting:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const MeetingsScreen()),
        );
        break;

      case CalendarCategory.email:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => EmailContactsCubit()),
                BlocProvider(create: (_) => EmailHistoryCubit()),
              ],
              child: const EmailContactsScreen(),
            ),
          ),
        );
        break;

      case CalendarCategory.task:
      case CalendarCategory.target:
      case CalendarCategory.note:
      case CalendarCategory.other:
        break;
    }
  }

  // ── Appointment rendering ───────────────────────────────────

  
Widget _appointmentBuilder(
  BuildContext context,
  CalendarAppointmentDetails details,
) {
  final event = details.appointments.first as CalendarEvent;
  final info = categoryInfoOf(event.type);

  if (_view == CalendarView.schedule) {
    return _ScheduleEventTile(event: event, info: info);
  }

  final isMonth = _view == CalendarView.month;
  final isCompact = details.bounds.height < 38;

  final fontSize = isMonth ? 10.0 : 11.0;

  return Container(
    width: details.bounds.width,
    height: details.bounds.height,
    padding: EdgeInsets.symmetric(
      horizontal: isMonth ? 3 : 5,
      vertical: isCompact ? 0 : 3,
    ),
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: info.color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(5),
      border: Border(
        left: BorderSide(
          color: info.color,
          width: 3,
        ),
      ),
    ),
    alignment: Alignment.centerLeft,
    child: Text(
      event.title,
      maxLines: isMonth || isCompact ? 1 : 2,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.left,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: info.color,
      ),
    ),
  );
}

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _hasData ? _reloadCurrentRange : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCategoryChips(),
            _buildNavBar(),
            Expanded(
              child: BlocConsumer<CalendarCubit, CalendarState>(
                listener: (context, state) {
                  if (state is CalendarLoaded) {
                    setState(() {
                      _events = state.events;
                      _hasData = true;
                    });
                  } else if (state is CalendarEmpty) {
                    setState(() {
                      _events = [];
                      _hasData = true;
                    });
                  } else if (state is CalendarNoteAdded) {
                    setState(() {
                      _events = [..._events, state.note];
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note added'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } else if (state is CalendarNoteUpdated) {
                    setState(() {
                      _events = [
                        for (final e in _events)
                          if (e.id == state.note.id) state.note else e,
                      ];
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note updated'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } else if (state is CalendarNoteDeleted) {
                    setState(() {
                      _events =
                          _events.where((e) => e.id != state.noteId).toList();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note deleted'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } else if (state is CalendarError && _hasData) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.message)),
                    );
                  }
                },
                builder: (context, state) {
                  if (!_hasData) {
                    if (state is CalendarError) {
                      return ErrorState(
                        message: state.message,
                        onRetry: _reloadCurrentRange,
                      );
                    }
                    return const LoadingState(message: 'Loading calendar...');
                  }

                  final events = _filteredEvents;
                  final loading = state is CalendarLoading;

                  return Stack(
                    children: [
                      SfCalendar(
  view: _view,
  controller: _controller,
  dataSource: CalendarEventDataSource(events),
  headerHeight: 0,
  viewHeaderHeight: _view == CalendarView.month ? 28 : 50,
  todayHighlightColor: AppColors.primary,
  cellBorderColor: AppColors.border,
  backgroundColor: AppColors.surface,

  // Month view
monthViewSettings: const MonthViewSettings(
  appointmentDisplayMode:
      MonthAppointmentDisplayMode.appointment,
  showAgenda: false,
  appointmentDisplayCount: 3,
),
  // Week and day views
  timeSlotViewSettings: const TimeSlotViewSettings(
  startHour: 6,
  endHour: 22,
  timeInterval: Duration(minutes: 30),
  timeIntervalHeight: 30,
  timeFormat: 'h a',
  minimumAppointmentDuration: Duration(minutes: 30),
),

  // Agenda view
  scheduleViewSettings: const ScheduleViewSettings(
    hideEmptyScheduleWeek: true,
    appointmentItemHeight: 74,
  ),

  appointmentBuilder: _appointmentBuilder,
  onTap: (details) => _onCalendarTap(details, events),
  onViewChanged: _onViewChanged,
),
                      if (loading)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      // On desktop/web, the ListView's own mouse-drag-to-scroll recognizer
      // competes with each chip's InkWell tap recognizer in the same
      // gesture arena — a click with even a pixel of jitter gets claimed
      // as "drag start" instead of "tap", so chips silently stop
      // responding to clicks while the scrollbar thumb / wheel still
      // scroll fine. Excluding mouse from dragDevices here removes that
      // contest; the Scrollbar thumb and mouse wheel scroll independently
      // of dragDevices, so scrolling still works.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        child: Scrollbar(
          controller: _categoryScrollController,
          thumbVisibility: false,
          child: ListView.separated(
            controller: _categoryScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: kCalendarCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final info = kCalendarCategories.values.elementAt(index);
              final active = _selected.contains(info.category);

              return Material(
                key: ValueKey(info.category),
                color:
                    active ? info.color.withOpacity(0.12) : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    debugPrint(
                      '[CalendarChip] tapped ${info.label} '
                      '(before: ${_selected.contains(info.category)})',
                    );
                    setState(() {
                      if (_selected.contains(info.category)) {
                        _selected.remove(info.category);
                      } else {
                        _selected.add(info.category);
                      }
                    });
                    debugPrint(
                      '[CalendarChip] after tap, selected = '
                      '${_selected.map((c) => c.name).toList()}',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? info.color.withOpacity(0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          active
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: active ? info.color : AppColors.textHint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          info.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active ? info.color : AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _goToday,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text(
              'Today',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => _navigate(-1),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
          ),
          Expanded(
            child: Text(
              _headerLabel(),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _navigate(1),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
          ),
          PopupMenuButton<CalendarView>(
            initialValue: _view,
            onSelected: _changeView,
            itemBuilder: (context) => const [
              PopupMenuItem(value: CalendarView.month, child: Text('Month')),
              PopupMenuItem(value: CalendarView.week, child: Text('Week')),
              PopupMenuItem(value: CalendarView.day, child: Text('Day')),
              PopupMenuItem(
                value: CalendarView.schedule,
                child: Text('Agenda'),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _viewLabel(_view),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: AppColors.primary,
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

// ══════════════════════════════════════════════════════════════
// SMALL SHARED WIDGETS
// ══════════════════════════════════════════════════════════════

class _EventRow extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _EventRow({required this.event, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final info = categoryInfoOf(event.type);

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: info.color, width: 3)),
          ),
          child: Row(
            children: [
              Icon(info.icon, size: 16, color: info.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${info.label} • ${DateFormat('h:mm a').format(event.date.toLocal())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                )
              else
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleEventTile extends StatelessWidget {
  final CalendarEvent event;
  final CalendarCategoryInfo info;
  const _ScheduleEventTile({required this.event, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: info.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.label} • ${DateFormat('h:mm a').format(event.date.toLocal())}',
                  style: TextStyle(
                    fontSize: 11,
                    color: info.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
