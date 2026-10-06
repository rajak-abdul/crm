// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/tasks/viewmodel/target_state.dart         ║
// ║  UI state exposed by TargetViewModel to the View.             ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/model/target/target_modal.dart';

import 'package:crm_app/screen/tasks/model/task/task_notification_modal.dart';

import 'linked_items_state.dart';
import 'task_notification_data.dart';
import 'task_state.dart' show TaskPipelineColumn, TaskViewStatus;

enum TargetViewStatus { initial, loading, success, empty, error }

/// All / Weekly / Monthly filter the targets by period; notifications
/// swaps the list for target notifications & reminders.
enum TargetFilter { all, weekly, monthly, notifications }

/// Card = target cards; pipeline = stage board (same as My Tasks).
enum TargetViewMode { card, pipeline }

/// Target status badge colour — the View maps it to colours.
enum TargetStatusTone { fresh, inProgress, completed, expired, other }

/// Overall progress message colour.
enum TargetProgressTone { ongoing, achieved, ended, none }

enum TargetMetricKind {
  leadsConverted,
  dealsClosed,
  convLeadsClosed,
  dealsLost,
  calls,
  meetings,
}

/// One half-ring tile on a target card.
class TargetMetricData {
  final TargetMetricKind kind;
  final String label; // e.g. "Leads\nconverted"

  final int actual;

  /// null = no goal set for this metric ("None"). Deals lost never has one.
  final int? target;

  /// Ring fill, 0..1.
  final double fraction;

  /// Calls / meetings on an open target — shows "+" and "Tap to report".
  final bool canReport;

  const TargetMetricData({
    required this.kind,
    required this.label,
    required this.actual,
    required this.target,
    required this.fraction,
    this.canReport = false,
  });

  bool get hasGoal => target != null;
}

/// Everything a target card needs, already computed for display.
class TargetCardData {
  final TargetModel target;

  final String title;
  final String statusLabel;
  final TargetStatusTone statusTone;

  final String dateRange; // e.g. "1 to 30 Oct"
  final String? timeNote; // e.g. "29 days left", "Monthly"
  final bool timeNoteUrgent; // days-left style (orange) vs plain

  final String? description;

  final int overallPercent;
  final int goalsDone;
  final int goalsTotal;
  final String progressMessage;
  final TargetProgressTone progressTone;

  final List<TargetMetricData> metrics; // always 6, fixed order

  final String linkedSummary; // e.g. "1 deal, 4 leads"

  final TargetDetailsData details;

  /// Newest first.
  final List<ReportedEntryRow> reportedCalls;
  final List<ReportedEntryRow> reportedMeetings;

  const TargetCardData({
    required this.target,
    required this.title,
    required this.statusLabel,
    required this.statusTone,
    required this.dateRange,
    required this.timeNote,
    required this.timeNoteUrgent,
    required this.description,
    required this.overallPercent,
    required this.goalsDone,
    required this.goalsTotal,
    required this.progressMessage,
    required this.progressTone,
    required this.metrics,
    required this.linkedSummary,
    required this.details,
    this.reportedCalls = const [],
    this.reportedMeetings = const [],
  });

  bool get achieved => progressTone == TargetProgressTone.achieved;
}

// ============================================================
// DETAILS SHEET DATA
// ============================================================

/// A linked lead or deal row.
class TargetLinkedRow {
  final bool isDeal;
  final String title;
  final String badge; // deal stage / lead status
  final String? valueText; // deal: "INR 1,000"; lead: company
  final String? phone;
  final String? email;
  final String? convertedBy; // "Converted by Abdul Rajak"

  const TargetLinkedRow({
    required this.isDeal,
    required this.title,
    required this.badge,
    required this.valueText,
    required this.phone,
    this.email,
    required this.convertedBy,
  });
}

class TargetNoteRow {
  final String text;
  final String? byText;
  final String? atText;

  const TargetNoteRow({required this.text, this.byText, this.atText});
}

/// An issue the salesperson reported, with the admin's answer.
class TargetIssueRow {
  final String note;
  final String? itemText; // e.g. "Lead: NCUBE NEET"
  final String? itemType; // 'lead' | 'deal' | 'task' (lowercase)
  final String? itemId; // the lead / deal the issue is about
  final String status; // "resolved", "pending", ...
  final String? adminReply;
  final String? atText;

  const TargetIssueRow({
    required this.note,
    this.itemType,
    this.itemId,
    required this.itemText,
    required this.status,
    required this.adminReply,
    required this.atText,
  });
}

/// One reported call or meeting, ready for the "Reported ..." sheet.
class ReportedEntryRow {
  final String id;
  final String title; // company name
  final String initial; // avatar letter
  final String summary;
  final String timeText; // "3:47 pm"
  final String dayLabel; // "Today" / "Wed, 1 Oct 2026" — group header
  final bool isToday;
  final String? companyUrl;

  /// Server path of the recording (calls) or screenshot (meetings).
  final String? mediaPath;

  const ReportedEntryRow({
    required this.id,
    required this.title,
    required this.initial,
    required this.summary,
    required this.timeText,
    required this.dayLabel,
    required this.isToday,
    required this.companyUrl,
    required this.mediaPath,
  });
}

class TargetDetailsData {
  final List<TargetLinkedRow> deals;
  final List<TargetLinkedRow> leads;
  final List<TargetLinkedRow> convertedDeals;
  final List<TargetNoteRow> notes;
  final List<TargetIssueRow> issues;

  /// Same card + detail data as the Task screen's Linked items.
  final List<LinkedItemData> leadItems;
  final List<LinkedItemData> dealItems;
  final List<LinkedItemData> convertedDealItems;

  const TargetDetailsData({
    required this.deals,
    required this.leads,
    required this.convertedDeals,
    required this.notes,
    required this.issues,
    this.leadItems = const [],
    this.dealItems = const [],
    this.convertedDealItems = const [],
  });
}

/// "Your Targets" summary card.
class TargetSummary {
  final int averagePercent;
  final int total;
  final int achieved;

  const TargetSummary({
    this.averagePercent = 0,
    this.total = 0,
    this.achieved = 0,
  });
}

class TargetState {
  final TargetViewStatus status;
  final String? errorMessage;

  // Source data from the repository.
  final MyDashboardStatsModel stats;
  final List<TargetModel> targets;

  // Period sent to /targets/my-dashboard-stats ('all', 'monthly', 'weekly').
  final String period;

  // User selections.
  final TargetFilter filter;

  // Derived for display — recomputed by the ViewModel whenever
  // targets or filter change.
  final List<TargetCardData> visibleTargets;
  final TargetSummary summary;

  final TargetViewMode viewMode;

  /// Pipeline board — every stage, for the targets in the current filter.
  final List<TaskPipelineColumn<TargetCardData>> pipeline;

  // Target notifications & reminders (only `type == 'target'`).
  final TaskViewStatus notificationStatus;
  final String? notificationError;
  final List<TaskNotificationModel> notifications;
  final List<NotificationGroup> notificationGroups;
  final int unreadCount;

  const TargetState({
    this.status = TargetViewStatus.initial,
    this.errorMessage,
    this.stats = const MyDashboardStatsModel(),
    this.targets = const [],
    this.period = 'monthly',
    this.filter = TargetFilter.all,
    this.visibleTargets = const [],
    this.summary = const TargetSummary(),
    this.viewMode = TargetViewMode.card,
    this.pipeline = const [],
    this.notificationStatus = TaskViewStatus.initial,
    this.notificationError,
    this.notifications = const [],
    this.notificationGroups = const [],
    this.unreadCount = 0,
  });

  bool get hasData =>
      status == TargetViewStatus.success || status == TargetViewStatus.empty;

  // Error messages are only shown while status is `error`, so they can
  // safely be kept across copies.
  TargetState copyWith({
    TargetViewStatus? status,
    String? errorMessage,
    MyDashboardStatsModel? stats,
    List<TargetModel>? targets,
    String? period,
    TargetFilter? filter,
    List<TargetCardData>? visibleTargets,
    TargetSummary? summary,
    TargetViewMode? viewMode,
    List<TaskPipelineColumn<TargetCardData>>? pipeline,
    TaskViewStatus? notificationStatus,
    String? notificationError,
    List<TaskNotificationModel>? notifications,
    List<NotificationGroup>? notificationGroups,
    int? unreadCount,
  }) {
    return TargetState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      stats: stats ?? this.stats,
      targets: targets ?? this.targets,
      period: period ?? this.period,
      filter: filter ?? this.filter,
      visibleTargets: visibleTargets ?? this.visibleTargets,
      summary: summary ?? this.summary,
      viewMode: viewMode ?? this.viewMode,
      pipeline: pipeline ?? this.pipeline,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      notificationError: notificationError ?? this.notificationError,
      notifications: notifications ?? this.notifications,
      notificationGroups: notificationGroups ?? this.notificationGroups,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
