// ╔══════════════════════════════════════════════════════════════╗
// ║       lib/screen/tasks/model/target/target_modal.dart        ║
// ║  MODELS — targets (/targets/my) and the dashboard stats       ║
// ║  (/targets/my-dashboard-stats). JSON in, typed fields out.    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/model/task/target_call_response.dart';
import 'package:crm_app/screen/tasks/model/task/task_modal.dart';

// GET /targets/my
class TargetModel {
  final String? id;
  final UserModel? salesPerson;
  final String? period; // 'monthly' | 'weekly' | ...
  final String? title;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status; // 'New' | 'Completed' | ...
  final String? description;

  final int targetLeads;
  final int targetDeals;
  final int targetCalls;
  final int targetMeetings;

  final List<LeadModel> linkedLeads;
  final List<DealModel> linkedDeals;
  final List<DealModel> convertedLeadDeals;

  final UserModel? createdBy;

  final DateTime? reminderSentAt;
  final DateTime? dueTodaySentAt;
  final DateTime? expiredAt;

  final String? inProcessNote;

  final bool rejectionRequested;
  final String? rejectionReason;
  final DateTime? rejectionApprovedAt;

  final bool holdRequested;
  final String? holdReason;
  final DateTime? holdRequestedAt;
  final dynamic holdSnapshotProgress;

  final List<TargetNoteModel> notes;
  final List<ReasonNoteModel> reasonNotes;

  final List<ReportedCallModel> reportedCalls;
  final List<ReportedMeetingModel> reportedMeetings;

  final TargetActualsModel actuals;
  final TargetPercentagesModel percentages;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? version;

  TargetModel({
    this.id,
    this.salesPerson,
    this.period,
    this.title,
    this.startDate,
    this.endDate,
    this.status,
    this.description,
    this.targetLeads = 0,
    this.targetDeals = 0,
    this.targetCalls = 0,
    this.targetMeetings = 0,
    this.linkedLeads = const [],
    this.linkedDeals = const [],
    this.convertedLeadDeals = const [],
    this.createdBy,
    this.reminderSentAt,
    this.dueTodaySentAt,
    this.expiredAt,
    this.inProcessNote,
    this.rejectionRequested = false,
    this.rejectionReason,
    this.rejectionApprovedAt,
    this.holdRequested = false,
    this.holdReason,
    this.holdRequestedAt,
    this.holdSnapshotProgress,
    this.notes = const [],
    this.reasonNotes = const [],
    this.reportedCalls = const [],
    this.reportedMeetings = const [],
    this.actuals = const TargetActualsModel(),
    this.percentages = const TargetPercentagesModel(),
    this.createdAt,
    this.updatedAt,
    this.version,
  });

  factory TargetModel.fromJson(Map<String, dynamic> json) {
    return TargetModel(
      id: json['_id'],
      salesPerson: json['salesPerson'] is Map<String, dynamic>
          ? UserModel.fromJson(json['salesPerson'])
          : null,
      period: json['period'],
      title: json['title'],
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      status: json['status'],
      description: json['description'],

      targetLeads: (json['targetLeads'] as num?)?.toInt() ?? 0,
      targetDeals: (json['targetDeals'] as num?)?.toInt() ?? 0,
      targetCalls: (json['targetCalls'] as num?)?.toInt() ?? 0,
      targetMeetings: (json['targetMeetings'] as num?)?.toInt() ?? 0,

      linkedLeads: (json['linkedLeads'] as List?)
              ?.map((e) => LeadModel.fromJson(e))
              .toList() ??
          [],

      linkedDeals: (json['linkedDeals'] as List?)
              ?.map((e) => DealModel.fromJson(e))
              .toList() ??
          [],

      convertedLeadDeals: (json['convertedLeadDeals'] as List?)
              ?.map((e) => DealModel.fromJson(e))
              .toList() ??
          [],

      createdBy: json['createdBy'] is Map<String, dynamic>
          ? UserModel.fromJson(json['createdBy'])
          : null,

      reminderSentAt: _parseDate(json['reminderSentAt']),
      dueTodaySentAt: _parseDate(json['dueTodaySentAt']),
      expiredAt: _parseDate(json['expiredAt']),

      inProcessNote: json['inProcessNote'],

      rejectionRequested: json['rejectionRequested'] == true,
      rejectionReason: json['rejectionReason'],
      rejectionApprovedAt: _parseDate(json['rejectionApprovedAt']),

      holdRequested: json['holdRequested'] == true,
      holdReason: json['holdReason'],
      holdRequestedAt: _parseDate(json['holdRequestedAt']),
      holdSnapshotProgress: json['holdSnapshotProgress'],

      notes: (json['notes'] as List?)
              ?.map((e) => TargetNoteModel.fromJson(e))
              .toList() ??
          [],

      reasonNotes: (json['reasonNotes'] as List?)
              ?.map((e) => ReasonNoteModel.fromJson(e))
              .toList() ??
          [],

      reportedCalls: [
        for (final e in _mapList(json['reportedCalls']))
          ReportedCallModel.fromJson(e),
      ],
      reportedMeetings: [
        for (final e in _mapList(json['reportedMeetings']))
          ReportedMeetingModel.fromJson(e),
      ],

      actuals: json['actuals'] is Map<String, dynamic>
          ? TargetActualsModel.fromJson(json['actuals'])
          : const TargetActualsModel(),

      percentages: json['percentages'] is Map<String, dynamic>
          ? TargetPercentagesModel.fromJson(json['percentages'])
          : const TargetPercentagesModel(),

      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      version: (json['__v'] as num?)?.toInt(),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) => [
        for (final e in (value as List? ?? const []))
          if (e is Map<String, dynamic>) e,
      ];

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
}

class TargetNoteModel {
  final String? id;
  final String? text;
  final UserModel? addedBy;
  final DateTime? addedAt;

  TargetNoteModel({
    this.id,
    this.text,
    this.addedBy,
    this.addedAt,
  });

  factory TargetNoteModel.fromJson(Map<String, dynamic> json) {
    return TargetNoteModel(
      id: json['_id'],
      text: json['text'],
      addedBy: json['addedBy'] is Map<String, dynamic>
          ? UserModel.fromJson(json['addedBy'])
          : null,
      addedAt: _parseDate(json['addedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
}

class TargetActualsModel {
  final int leadsConverted;
  final int dealsWon;
  final int calls;
  final int meetings;
  final int leadDealWon;
  final int dealsLost;

  const TargetActualsModel({
    this.leadsConverted = 0,
    this.dealsWon = 0,
    this.calls = 0,
    this.meetings = 0,
    this.leadDealWon = 0,
    this.dealsLost = 0,
  });

  factory TargetActualsModel.fromJson(Map<String, dynamic> json) {
    return TargetActualsModel(
      leadsConverted: (json['leadsConverted'] as num?)?.toInt() ?? 0,
      dealsWon: (json['dealsWon'] as num?)?.toInt() ?? 0,
      calls: (json['calls'] as num?)?.toInt() ?? 0,
      meetings: (json['meetings'] as num?)?.toInt() ?? 0,
      leadDealWon: (json['leadDealWon'] as num?)?.toInt() ?? 0,
      dealsLost: (json['dealsLost'] as num?)?.toInt() ?? 0,
    );
  }
}

class TargetPercentagesModel {
  final int leadsPercent;
  final int dealsPercent;
  final int callsPercent;
  final int meetingsPercent;
  final int overall;

  /// Targets the percentages are measured against (may differ from
  /// targetLeads / targetDeals on the target itself).
  final int effTargetLeads;
  final int effTargetDeals;
  final int leadDealWonPercent;

  const TargetPercentagesModel({
    this.leadsPercent = 0,
    this.dealsPercent = 0,
    this.callsPercent = 0,
    this.meetingsPercent = 0,
    this.overall = 0,
    this.effTargetLeads = 0,
    this.effTargetDeals = 0,
    this.leadDealWonPercent = 0,
  });

  factory TargetPercentagesModel.fromJson(Map<String, dynamic> json) {
    return TargetPercentagesModel(
      leadsPercent: (json['leadsPercent'] as num?)?.toInt() ?? 0,
      dealsPercent: (json['dealsPercent'] as num?)?.toInt() ?? 0,
      callsPercent: (json['callsPercent'] as num?)?.toInt() ?? 0,
      meetingsPercent: (json['meetingsPercent'] as num?)?.toInt() ?? 0,
      overall: (json['overall'] as num?)?.toInt() ?? 0,
      effTargetLeads: (json['effTargetLeads'] as num?)?.toInt() ?? 0,
      effTargetDeals: (json['effTargetDeals'] as num?)?.toInt() ?? 0,
      leadDealWonPercent:
          (json['leadDealWonPercent'] as num?)?.toInt() ?? 0,
    );
  }
}

// GET /targets/my-dashboard-stats
class MyDashboardStatsModel {
  final int totalLeads;
  final int convertedLeads;
  final int leadToDealRate;
  final int totalDeals;
  final int wonDeals;
  final int lostDeals;
  final int monthlyCalls;
  final int monthlyMeetings;
  final int weeklyCalls;
  final int weeklyMeetings;

  const MyDashboardStatsModel({
    this.totalLeads = 0,
    this.convertedLeads = 0,
    this.leadToDealRate = 0,
    this.totalDeals = 0,
    this.wonDeals = 0,
    this.lostDeals = 0,
    this.monthlyCalls = 0,
    this.monthlyMeetings = 0,
    this.weeklyCalls = 0,
    this.weeklyMeetings = 0,
  });

  factory MyDashboardStatsModel.fromJson(Map<String, dynamic> json) {
    final monthly = (json['monthly'] as Map<String, dynamic>?) ?? {};
    final weekly = (json['weekly'] as Map<String, dynamic>?) ?? {};

    return MyDashboardStatsModel(
      totalLeads: (monthly['totalLeads'] as num?)?.toInt() ?? 0,
      convertedLeads: (monthly['convertedLeads'] as num?)?.toInt() ?? 0,
      leadToDealRate: (monthly['leadToDealRate'] as num?)?.toInt() ?? 0,
      totalDeals: (monthly['totalDeals'] as num?)?.toInt() ?? 0,
      wonDeals: (monthly['wonDeals'] as num?)?.toInt() ?? 0,
      lostDeals: (monthly['lostDeals'] as num?)?.toInt() ?? 0,
      monthlyCalls: (monthly['calls'] as num?)?.toInt() ?? 0,
      monthlyMeetings: (monthly['meetings'] as num?)?.toInt() ?? 0,
      weeklyCalls: (weekly['calls'] as num?)?.toInt() ?? 0,
      weeklyMeetings: (weekly['meetings'] as num?)?.toInt() ?? 0,
    );
  }
}
