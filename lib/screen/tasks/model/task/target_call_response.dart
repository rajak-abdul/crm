// ╔══════════════════════════════════════════════════════════════╗
// ║    lib/screen/tasks/model/task/target_call_response.dart     ║
// ║  MODELS — POST /targets/:id/reports/{call,meeting} responses  ║
// ║  and the reported call / meeting entries on a target.         ║
// ╚══════════════════════════════════════════════════════════════╝

// The response's `target` is unpopulated (linked leads/deals are plain ids
// and there are no actuals), so only the parts the app needs are kept;
// the screen reloads /targets/my for the full, populated target.
class CallReportResponseModel {
  final String? message;
  final String? targetId;
  final List<ReportedCallModel> reportedCalls;

  const CallReportResponseModel({
    this.message,
    this.targetId,
    this.reportedCalls = const [],
  });

  factory CallReportResponseModel.fromJson(Map<String, dynamic> json) {
    final target = json['target'] is Map<String, dynamic>
        ? json['target'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return CallReportResponseModel(
      message: json['message']?.toString(),
      targetId: target['_id']?.toString(),
      reportedCalls: [
        for (final e in (target['reportedCalls'] as List? ?? const []))
          if (e is Map<String, dynamic>) ReportedCallModel.fromJson(e),
      ],
    );
  }
}

/// POST /targets/:id/reports/meeting response — same shape as the call
/// one, keeping the target's reported meetings.
class MeetingReportResponseModel {
  final String? message;
  final String? targetId;
  final List<ReportedMeetingModel> reportedMeetings;

  const MeetingReportResponseModel({
    this.message,
    this.targetId,
    this.reportedMeetings = const [],
  });

  factory MeetingReportResponseModel.fromJson(Map<String, dynamic> json) {
    final target = json['target'] is Map<String, dynamic>
        ? json['target'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return MeetingReportResponseModel(
      message: json['message']?.toString(),
      targetId: target['_id']?.toString(),
      reportedMeetings: [
        for (final e in (target['reportedMeetings'] as List? ?? const []))
          if (e is Map<String, dynamic>) ReportedMeetingModel.fromJson(e),
      ],
    );
  }
}

class ReportedCallModel {
  final String? companyName;
  final String? callSummary;
  final String? companyUrl;
  final String? recordingUrl;
  final String? addedBy;
  final String? id;
  final DateTime? addedAt;

  const ReportedCallModel({
    this.companyName,
    this.callSummary,
    this.companyUrl,
    this.recordingUrl,
    this.addedBy,
    this.id,
    this.addedAt,
  });

  factory ReportedCallModel.fromJson(Map<String, dynamic> json) {
    return ReportedCallModel(
      companyName: json['companyName'],
      callSummary: json['callSummary'],
      companyUrl: json['companyUrl'],
      recordingUrl: json['recordingUrl'],
      addedBy: json['addedBy']?.toString(),
      id: json['_id'],
      addedAt: _parseDate(json['addedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'callSummary': callSummary,
      'companyUrl': companyUrl,
      'recordingUrl': recordingUrl,
      'addedBy': addedBy,
      '_id': id,
      'addedAt': addedAt?.toIso8601String(),
    };
  }
}

class ReportedMeetingModel {
  final String? companyName;
  final String? meetingSummary;
  final String? companyUrl;
  final String? screenshotUrl;
  final String? addedBy;
  final String? id;
  final DateTime? addedAt;

  const ReportedMeetingModel({
    this.companyName,
    this.meetingSummary,
    this.companyUrl,
    this.screenshotUrl,
    this.addedBy,
    this.id,
    this.addedAt,
  });

  factory ReportedMeetingModel.fromJson(Map<String, dynamic> json) {
    return ReportedMeetingModel(
      companyName: json['companyName'],
      meetingSummary: json['meetingSummary'],
      companyUrl: json['companyUrl'],
      screenshotUrl: json['screenshotUrl'],
      addedBy: json['addedBy']?.toString(),
      id: json['_id'],
      addedAt: _parseDate(json['addedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'meetingSummary': meetingSummary,
      'companyUrl': companyUrl,
      'screenshotUrl': screenshotUrl,
      'addedBy': addedBy,
      '_id': id,
      'addedAt': addedAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
