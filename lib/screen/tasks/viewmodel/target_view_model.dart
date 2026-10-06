// ╔══════════════════════════════════════════════════════════════╗
// ║      lib/screen/tasks/viewmodel/target_view_model.dart       ║
// ║  VIEWMODEL (Cubit) — UI state + presentation logic.           ║
// ║  Talks only to the Repository: no Dio, no JSON, no widgets.   ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/model/target/target_modal.dart';
import 'package:crm_app/screen/tasks/repository/target_repository.dart';
import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_notification_modal.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'linked_item_presenter.dart';
import 'linked_items_state.dart';
import 'target_state.dart';
import 'task_notification_presenter.dart';
import 'task_state.dart'
    show TaskPipelineColumn, TaskStage, TaskViewStatus;

class TargetViewModel extends Cubit<TargetState> {
  final TargetRepository repository;

  /// Builds linked lead / deal cards + detail (shared with the Task screen).
  LinkedItemPresenter _presenter = const LinkedItemPresenter();

  TargetViewModel(this.repository) : super(const TargetState());

  // ============================================================
  // LOAD / REFRESH
  // ============================================================

  Future<void> load() async {
    emit(state.copyWith(status: TargetViewStatus.loading));

    // Notifications load alongside targets but never fail the list.
    final notifications = _loadNotifications();

    try {
      await _fetch();
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: TargetViewStatus.error,
        errorMessage: e.toString(),
      ));
    }

    await notifications;
  }

  /// Pull-to-refresh: keeps the current data on screen. Returns an error
  /// message on failure so the View can show it without losing the data.
  Future<String?> refresh() async {
    if (!state.hasData) {
      await load();
      return null;
    }

    final notifications = _loadNotifications(silent: true);

    try {
      await _fetch();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      await notifications;
    }
  }

  // ============================================================
  // NOTIFICATIONS & REMINDERS (target ones only)
  // ============================================================

  static const _notificationPresenter = TaskNotificationPresenter();

  Future<void> reloadNotifications() => _loadNotifications();

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(notificationStatus: TaskViewStatus.loading));
    }

    try {
      final all = await repository.getMyNotifications(limit: 100);
      final targetOnly =
          all.where(_notificationPresenter.isTargetNotification).toList();

      if (isClosed) return;
      emit(_withNotifications(state.copyWith(
        notificationStatus:
            targetOnly.isEmpty ? TaskViewStatus.empty : TaskViewStatus.success,
        notifications: targetOnly,
      )));
    } catch (e) {
      if (isClosed) return;
      // Keep any list already on screen after a failed silent refresh.
      if (silent && state.notifications.isNotEmpty) return;
      emit(state.copyWith(
        notificationStatus: TaskViewStatus.error,
        notificationError: e.toString(),
      ));
    }
  }

  /// Marks one notification read (optimistic; reverted on failure).
  Future<void> markNotificationRead(String id) async {
    final match = state.notifications.where((n) => n.id == id);
    if (match.isEmpty || match.first.read) return;

    final before = state.notifications;
    _setNotifications(
      [for (final n in before) n.id == id ? n.copyWith(read: true) : n],
    );

    try {
      await repository.markNotificationRead(id);
    } catch (_) {
      if (!isClosed) _setNotifications(before);
    }
  }

  /// Marks every unread notification read. Returns an error message on
  /// failure (the unread ones are restored).
  Future<String?> markAllNotificationsRead() async {
    final before = state.notifications;
    final unreadIds = [
      for (final n in before)
        if (!n.read && n.id != null) n.id!,
    ];
    if (unreadIds.isEmpty) return null;

    _setNotifications([for (final n in before) n.copyWith(read: true)]);

    try {
      await Future.wait(unreadIds.map(repository.markNotificationRead));
      return null;
    } catch (e) {
      if (!isClosed) _setNotifications(before);
      return e.toString();
    }
  }

  /// Removes a notification (optimistic — comes back if the delete
  /// fails). Returns an error message on failure.
  Future<String?> deleteNotification(String id) async {
    final index = state.notifications.indexWhere((n) => n.id == id);
    if (index < 0) return null;
    final removed = state.notifications[index];

    final remaining = [...state.notifications]..removeAt(index);
    emit(_withNotifications(state.copyWith(
      notifications: remaining,
      notificationStatus:
          remaining.isEmpty ? TaskViewStatus.empty : TaskViewStatus.success,
    )));

    try {
      await repository.deleteNotification(id);
      return null;
    } catch (e) {
      // Put back only this item — other deletes may have happened since.
      if (!isClosed && !state.notifications.any((n) => n.id == id)) {
        final restored = [...state.notifications]
          ..insert(index.clamp(0, state.notifications.length), removed);
        emit(_withNotifications(state.copyWith(
          notifications: restored,
          notificationStatus: TaskViewStatus.success,
        )));
      }
      return e.toString();
    }
  }

  void _setNotifications(List<TaskNotificationModel> notifications) {
    emit(_withNotifications(state.copyWith(notifications: notifications)));
  }

  TargetState _withNotifications(TargetState s) {
    return s.copyWith(
      notificationGroups:
          _notificationPresenter.buildGroups(s.notifications, const []),
      unreadCount: s.notifications.where((n) => !n.read).length,
    );
  }

  /// Stats and targets load together; the screen needs both.
  Future<void> _fetch() async {
    final results = await Future.wait<Object>([
      repository.getMyDashboardStats(period: state.period),
      repository.getMyTargets(),
      repository.getCurrentUserId(),
    ]);

    final stats = results[0] as MyDashboardStatsModel;
    final targets = results[1] as List<TargetModel>;
    _presenter = LinkedItemPresenter(currentUserId: results[2] as String);

    if (isClosed) return;
    emit(_withDerived(state.copyWith(
      status:
          targets.isEmpty ? TargetViewStatus.empty : TargetViewStatus.success,
      stats: stats,
      targets: targets,
    )));
  }

  // ============================================================
  // USER ACTIONS
  // ============================================================

  /// Reloads only the overview stats for [period]. Returns an error
  /// message on failure (the previous period and stats are kept).
  Future<String?> changePeriod(String period) async {
    if (period == state.period) return null;

    try {
      final stats = await repository.getMyDashboardStats(period: period);
      if (!isClosed) emit(state.copyWith(stats: stats, period: period));
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Reports a call on [targetId], then reloads so the calls count and
  /// progress update. Returns an error message on failure.
  Future<String?> reportCall({
    required String targetId,
    required String companyName,
    required String callSummary,
    String? companyUrl,
    String? recordingPath,
    List<int>? recordingBytes,
    String? recordingName,
  }) async {
    try {
      await repository.reportCall(
        targetId: targetId,
        companyName: companyName.trim(),
        callSummary: callSummary.trim(),
        companyUrl: companyUrl?.trim(),
        recordingPath: recordingPath,
        recordingBytes: recordingBytes,
        recordingName: recordingName,
      );
    } catch (e) {
      return e.toString();
    }

    // The report is saved; a failed reload only leaves stale counts.
    await refresh();
    return null;
  }

  /// Reports a meeting on [targetId], then reloads so the meetings count
  /// and progress update. Returns an error message on failure.
  Future<String?> reportMeeting({
    required String targetId,
    required String companyName,
    required String meetingSummary,
    String? companyUrl,
    String? screenshotPath,
    List<int>? screenshotBytes,
    String? screenshotName,
  }) async {
    try {
      await repository.reportMeeting(
        targetId: targetId,
        companyName: companyName.trim(),
        meetingSummary: meetingSummary.trim(),
        companyUrl: companyUrl?.trim(),
        screenshotPath: screenshotPath,
        screenshotBytes: screenshotBytes,
        screenshotName: screenshotName,
      );
    } catch (e) {
      return e.toString();
    }

    // The report is saved; a failed reload only leaves stale counts.
    await refresh();
    return null;
  }

  /// Adds a note to [targetId], then reloads so it shows in the Notes
  /// list. Returns an error message on failure.
  Future<String?> addNote({
    required String targetId,
    required String text,
  }) async {
    try {
      await repository.addNote(targetId: targetId, text: text.trim());
    } catch (e) {
      return e.toString();
    }

    // The note is saved; a failed reload only leaves the list stale.
    await refresh();
    return null;
  }

  /// Reports an issue about a linked lead / deal of [targetId], then
  /// reloads so it shows under the target's issues. Returns an error
  /// message on failure.
  Future<String?> reportItemIssue({
    required String targetId,
    required LinkedItemData item,
    required String note,
  }) async {
    final target = state.targets.where((t) => t.id == targetId).firstOrNull;
    final isDeal = item.kind == LinkedItemKind.deal;

    try {
      if (isDeal) {
        final deal = [
          ...?target?.linkedDeals,
          ...?target?.convertedLeadDeals,
        ].where((d) => d.id == item.id).firstOrNull;

        await repository.reportIssue(
          targetId: targetId,
          note: note.trim(),
          itemType: 'deal',
          itemId: item.id,
          itemName: item.title,
          companyName: deal?.companyName,
          phoneNumber: deal?.phoneNumber,
          email: deal?.email,
          value: deal?.value,
          currency: deal?.currency,
          stageOrStatus: deal?.stage,
        );
      } else {
        final lead =
            target?.linkedLeads.where((l) => l.id == item.id).firstOrNull;

        await repository.reportIssue(
          targetId: targetId,
          note: note.trim(),
          itemType: 'lead',
          itemId: item.id,
          itemName: item.title,
          companyName: lead?.companyName,
          phoneNumber: lead?.phoneNumber,
          email: lead?.email,
          stageOrStatus: lead?.status,
        );
      }
    } catch (e) {
      return e.toString();
    }

    // The note is saved; a failed reload only leaves the list stale.
    await refresh();
    return null;
  }

  /// URL + auth headers for a reported call's recording or a meeting's
  /// screenshot.
  Future<({String url, Map<String, String> headers})> mediaSource(
    String filePath,
  ) =>
      repository.mediaSource(filePath);

  void selectFilter(TargetFilter filter) {
    if (filter == state.filter) return;
    emit(_withDerived(state.copyWith(filter: filter)));
  }

  // ============================================================
  // PRESENTATION LOGIC
  // ============================================================

  TargetState _withDerived(TargetState s) {
    final today = _today();
    final cards = [for (final t in s.targets) _toCardData(t, today)];

    final summary = TargetSummary(
      averagePercent: cards.isEmpty
          ? 0
          : (cards.fold<int>(0, (sum, c) => sum + c.overallPercent) /
                  cards.length)
              .round(),
      total: cards.length,
      achieved: cards.where((c) => c.achieved).length,
    );

    final visible = [
      for (final c in cards)
        if (_matchesFilter(c, s.filter)) c,
    ];

    return s.copyWith(
      visibleTargets: visible,
      summary: summary,
      pipeline: [
        for (final stage in TaskStage.values)
          TaskPipelineColumn<TargetCardData>(stage, [
            for (final c in visible)
              if (TaskStage.fromTargetStatus(c.target.status) == stage) c,
          ]),
      ],
    );
  }

  /// Moves [target] to [stage] (PUT /targets/:id), then reloads. In Hold
  /// sends [reason] as holdReason — the backend may keep the status until
  /// the admin approves (holdRequested). Returns an error message or null.
  Future<String?> moveTarget(
    TargetModel target,
    TaskStage stage, {
    String? reason,
  }) async {
    final targetId = target.id;
    if (targetId == null) return 'Target not found';

    try {
      await repository.updateTargetStatus(
        targetId: targetId,
        status: stage.targetStatus,
        reason: reason,
      );
    } catch (e) {
      return e.toString();
    }

    // The move is saved; a failed reload only leaves the board stale.
    await refresh();
    return null;
  }

  void setViewMode(TargetViewMode mode) {
    if (mode == state.viewMode) return;
    emit(state.copyWith(viewMode: mode));
  }

  bool _matchesFilter(TargetCardData card, TargetFilter filter) {
    final period = (card.target.period ?? '').toLowerCase();
    switch (filter) {
      case TargetFilter.all:
        return true;
      case TargetFilter.weekly:
        return period == 'weekly';
      case TargetFilter.monthly:
        return period == 'monthly';
      // The notifications view doesn't list targets.
      case TargetFilter.notifications:
        return true;
    }
  }

  TargetCardData _toCardData(TargetModel t, DateTime today) {
    final status = (t.status ?? '').trim();
    final tone = _statusTone(status);
    final end = _utcDay(t.endDate);
    final daysLeft = end?.difference(today).inDays;
    final ended = t.expiredAt != null || (daysLeft != null && daysLeft < 0);

    // Calls / meetings can only be reported while the target is open.
    final open = tone != TargetStatusTone.completed && !ended;
    final metrics = _metrics(t, canReport: open);
    final goals = metrics.where(
      (m) => m.hasGoal && m.kind != TargetMetricKind.dealsLost,
    );
    final goalsDone = goals.where((m) => m.actual >= m.target!).length;
    final goalsTotal = goals.length;

    final overall = t.percentages.overall.clamp(0, 100);
    final achieved = tone == TargetStatusTone.completed ||
        overall >= 100 ||
        (goalsTotal > 0 && goalsDone == goalsTotal);

    final (message, progressTone) = achieved
        ? ('Target achieved', TargetProgressTone.achieved)
        : ended
            ? ('Target period ended', TargetProgressTone.ended)
            : goalsTotal == 0
                ? ('No goals set', TargetProgressTone.none)
                : ('Keep pushing, you can do it!', TargetProgressTone.ongoing);

    final (timeNote, urgent) = _timeNote(t, tone, daysLeft);

    return TargetCardData(
      target: t,
      title: _nonEmpty(t.title) ?? '-',
      statusLabel: status.isEmpty ? '-' : status,
      statusTone: tone,
      dateRange: _dateRange(_utcDay(t.startDate), end),
      timeNote: timeNote,
      timeNoteUrgent: urgent,
      description: _nonEmpty(t.description),
      overallPercent: overall,
      goalsDone: goalsDone,
      goalsTotal: goalsTotal,
      progressMessage: message,
      progressTone: progressTone,
      metrics: metrics,
      linkedSummary: _linkedSummary(t),
      details: _details(t),
      reportedCalls: _reportedRows([
        for (final c in t.reportedCalls)
          (
            id: c.id,
            company: c.companyName,
            summary: c.callSummary,
            url: c.companyUrl,
            media: c.recordingUrl,
            at: c.addedAt,
          ),
      ], today),
      reportedMeetings: _reportedRows([
        for (final m in t.reportedMeetings)
          (
            id: m.id,
            company: m.companyName,
            summary: m.meetingSummary,
            url: m.companyUrl,
            media: m.screenshotUrl,
            at: m.addedAt,
          ),
      ], today),
    );
  }

  // ============================================================
  // REPORTED CALLS / MEETINGS
  // ============================================================

  /// Newest first; grouped by local calendar day.
  List<ReportedEntryRow> _reportedRows(
    List<
            ({
              String? id,
              String? company,
              String? summary,
              String? url,
              String? media,
              DateTime? at,
            })>
        entries,
    DateTime todayUtc,
  ) {
    final sorted = [...entries]..sort((a, b) => _compareDesc(a.at, b.at));
    final now = DateTime.now();

    return [
      for (var i = 0; i < sorted.length; i++)
        () {
          final e = sorted[i];
          final local = e.at?.toLocal();
          final isToday = local != null &&
              local.year == now.year &&
              local.month == now.month &&
              local.day == now.day;
          final title = _nonEmpty(e.company) ?? '-';

          return ReportedEntryRow(
            id: e.id ?? 'row-$i',
            title: title,
            initial: title == '-' ? '?' : title[0].toUpperCase(),
            summary: _nonEmpty(e.summary) ?? '-',
            timeText: local == null
                ? ''
                : DateFormat('h:mm a')
                    .format(local)
                    .replaceAll('AM', 'am')
                    .replaceAll('PM', 'pm'),
            dayLabel: local == null
                ? 'Earlier'
                : isToday
                    ? 'Today'
                    : DateFormat('EEE, d MMM yyyy').format(local),
            isToday: isToday,
            companyUrl: _nonEmpty(e.url),
            mediaPath: _nonEmpty(e.media),
          );
        }(),
    ];
  }

  int _compareDesc(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null ? 1 : -1;
    return b.compareTo(a);
  }

  TargetStatusTone _statusTone(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return TargetStatusTone.fresh;
      case 'in progress':
      case 'active':
        return TargetStatusTone.inProgress;
      case 'completed':
        return TargetStatusTone.completed;
      case 'expired':
        return TargetStatusTone.expired;
      default:
        return TargetStatusTone.other;
    }
  }

  /// Open targets show time left; closed ones show their period.
  (String?, bool) _timeNote(
    TargetModel t,
    TargetStatusTone tone,
    int? daysLeft,
  ) {
    final period = _nonEmpty(t.period);
    final periodLabel = period == null ? null : _capitalize(period);

    if (tone == TargetStatusTone.completed || daysLeft == null) {
      return (periodLabel, false);
    }
    if (daysLeft < 0) return ('Ended', false);
    if (daysLeft == 0) return ('Ends today', true);
    return ('$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left', true);
  }

  /// Fixed order, matching the card grid:
  /// leads converted · deals closed · conv. leads closed
  /// deals lost      · calls made   · meetings done
  List<TargetMetricData> _metrics(TargetModel t, {required bool canReport}) {
    final a = t.actuals;
    final p = t.percentages;

    // The percentages are measured against the "effective" targets.
    final leadsGoal = p.effTargetLeads > 0 ? p.effTargetLeads : t.targetLeads;
    final dealsGoal = p.effTargetDeals > 0 ? p.effTargetDeals : t.targetDeals;

    // Assumption: "converted leads closed" (lead → deal → won) is only a
    // goal when the target asks for both leads and deals; its goal is the
    // lead count.
    final convGoal = leadsGoal > 0 && dealsGoal > 0 ? leadsGoal : 0;

    return [
      _metric(TargetMetricKind.leadsConverted, 'Leads\nconverted',
          a.leadsConverted, leadsGoal),
      _metric(TargetMetricKind.dealsClosed, 'Deals\nclosed', a.dealsWon,
          dealsGoal),
      _metric(TargetMetricKind.convLeadsClosed, 'Conv. leads\nclosed',
          a.leadDealWon, convGoal),
      TargetMetricData(
        kind: TargetMetricKind.dealsLost,
        label: 'Deals\nlost',
        actual: a.dealsLost,
        target: null,
        // No goal — the ring fills red once any deal is lost.
        fraction: a.dealsLost > 0 ? 1 : 0,
      ),
      _metric(TargetMetricKind.calls, 'Calls\nmade', a.calls, t.targetCalls,
          canReport: canReport),
      _metric(TargetMetricKind.meetings, 'Meetings\ndone', a.meetings,
          t.targetMeetings,
          canReport: canReport),
    ];
  }

  TargetMetricData _metric(
    TargetMetricKind kind,
    String label,
    int actual,
    int goal, {
    bool canReport = false,
  }) {
    return TargetMetricData(
      kind: kind,
      label: label,
      actual: actual,
      target: goal > 0 ? goal : null,
      fraction: goal > 0 ? (actual / goal).clamp(0.0, 1.0) : 0,
      canReport: canReport,
    );
  }

  String _linkedSummary(TargetModel t) {
    String count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

    final summary = [
      if (t.linkedDeals.isNotEmpty) count(t.linkedDeals.length, 'deal'),
      if (t.linkedLeads.isNotEmpty) count(t.linkedLeads.length, 'lead'),
    ].join(', ');

    return summary.isEmpty ? 'No linked items' : summary;
  }

  // ============================================================
  // DETAILS
  // ============================================================

  TargetDetailsData _details(TargetModel t) {
    return TargetDetailsData(
      deals: t.linkedDeals.map(_dealRow).toList(),
      leads: t.linkedLeads.map(_leadRow).toList(),
      convertedDeals: t.convertedLeadDeals.map(_dealRow).toList(),
      leadItems: t.linkedLeads.map(_presenter.lead).toList(),
      dealItems: t.linkedDeals.map(_presenter.deal).toList(),
      convertedDealItems:
          t.convertedLeadDeals.map(_presenter.deal).toList(),
      notes: [
        for (final n in t.notes)
          if (_nonEmpty(n.text) != null)
            TargetNoteRow(
              text: n.text!.trim(),
              byText: _nonEmpty(n.addedBy?.fullName),
              atText: _formatDateTime(n.addedAt),
            ),
      ],
      issues: [
        for (final r in t.reasonNotes)
          TargetIssueRow(
            note: _nonEmpty(r.note) ?? '-',
            itemText: _nonEmpty(r.itemName) == null
                ? null
                : '${_capitalize(r.itemType ?? 'item')}: ${r.itemName!.trim()}',
            itemType: _nonEmpty(r.itemType)?.toLowerCase(),
            itemId: _nonEmpty(r.itemId),
            status: _nonEmpty(r.status) ?? '-',
            adminReply: _nonEmpty(r.adminReply),
            atText: _formatDateTime(r.addedAt),
          ),
      ],
    );
  }

  TargetLinkedRow _dealRow(DealModel d) {
    final convertedBy =
        _nonEmpty(d.convertedByName) ?? _nonEmpty(d.convertedBy?.fullName);

    return TargetLinkedRow(
      isDeal: true,
      title: _nonEmpty(d.dealName) ?? _nonEmpty(d.dealTitle) ?? '-',
      badge: _nonEmpty(d.stage) ?? '-',
      valueText: _formatDealValue(d),
      phone: _nonEmpty(d.phoneNumber),
      email: _cleanEmail(d.email),
      convertedBy: convertedBy == null ? null : 'Converted by $convertedBy',
    );
  }

  /// The backend sends "-" for a missing email.
  String? _cleanEmail(String? email) {
    final e = _nonEmpty(email);
    return e == null || e == '-' ? null : e;
  }

  TargetLinkedRow _leadRow(LeadModel l) {
    final convertedBy = _nonEmpty(l.convertedBy?.fullName);

    return TargetLinkedRow(
      isDeal: false,
      title: _nonEmpty(l.leadName) ?? '-',
      badge: _nonEmpty(l.status) ?? '-',
      valueText: _nonEmpty(l.companyName),
      phone: _nonEmpty(l.phoneNumber),
      email: _cleanEmail(l.email),
      convertedBy: convertedBy == null ? null : 'Converted by $convertedBy',
    );
  }

  /// "1,000 INR" → "INR 1,000"; falls back to the currency field.
  String? _formatDealValue(DealModel deal) {
    final value = (deal.value ?? '').trim();
    final currency = (deal.currency ?? '').trim();

    if (value.isEmpty) return null;

    final parts = value.split(RegExp(r'\s+'));
    if (parts.length > 1 && RegExp(r'^[A-Za-z]{3}$').hasMatch(parts.last)) {
      final amount = parts.sublist(0, parts.length - 1).join(' ');
      return '${parts.last.toUpperCase()} $amount';
    }
    return currency.isEmpty ? value : '$currency $value';
  }

  // ============================================================
  // HELPERS
  // ============================================================

  // Start/end dates are stored as midnight UTC for the chosen calendar
  // day, so compare on the UTC date against today's local date —
  // converting to local time would shift the day behind UTC.
  DateTime? _utcDay(DateTime? d) {
    if (d == null) return null;
    final u = d.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// "1 to 30 Oct", "28 Sep to 3 Oct", "20 Dec 2026 to 5 Jan 2027".
  String _dateRange(DateTime? start, DateTime? end) {
    final dayMonth = DateFormat('d MMM');
    final full = DateFormat('d MMM yyyy');

    if (start == null && end == null) return '-';
    if (start == null) return 'Until ${dayMonth.format(end!)}';
    if (end == null) return 'From ${dayMonth.format(start)}';

    if (start.year != end.year) {
      return '${full.format(start)} to ${full.format(end)}';
    }
    if (start.month != end.month) {
      return '${dayMonth.format(start)} to ${dayMonth.format(end)}';
    }
    return '${start.day} to ${dayMonth.format(end)}';
  }

  String? _formatDateTime(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('d MMM yyyy, h:mm a')
        .format(dt.toLocal())
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');
  }

  String? _nonEmpty(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
