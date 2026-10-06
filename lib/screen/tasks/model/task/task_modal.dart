
import 'dart:convert';

List<TaskModel> taskModelFromJson(String str) =>
    (json.decode(str) as List)
        .map((e) => TaskModel.fromJson(e))
        .toList();

String taskModelToJson(List<TaskModel> data) =>
    json.encode(data.map((e) => e.toJson()).toList());

class TaskModel {
  final String? id;
  final String? title;
  final String? description;
  final String? priority;
  final String? status;
  final DateTime? dueDate;

  final UserModel? assignedTo;
  final UserModel? createdBy;

  final LeadModel? leadRef;
  final DealModel? dealRef;

  final List<LeadModel> leadRefs;
  final List<DealModel> dealRefs;

  // Per linked item, keyed by lead/deal id.
  final Map<String, DateTime> leadDueDates;
  final Map<String, DateTime> dealDueDates;
  final Map<String, DateTime> leadDueReminderSentAt;
  final Map<String, DateTime> leadDueTodaySentAt;
  final Map<String, DateTime> dealDueReminderSentAt;
  final Map<String, DateTime> dealDueTodaySentAt;

  final int? callsMade;
  final int? meetingsDone;

  final String? completionNotes;
  final String? inProcessNote;

  final bool? rejectionRequested;
  final String? rejectionReason;
  final DateTime? rejectionApprovedAt;
  final bool? approvedByAdmin;
  final DateTime? completedAt;

  final bool? holdRequested;
  final String? holdReason;
  final DateTime? holdRequestedAt;

  final dynamic holdSnapshotProgress;
  final bool? archived;

  final List<TaskHistoryModel> history;

  final DateTime? reminderSentAt;
  final DateTime? dueTodaySentAt;

  final List<ReasonNoteModel> reasonNotes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final int? version;

  final LinkedItemBadgeModel? linkedItemBadge;

  final Map<String, DealModel> convertedDealRefsByLeadId;

  final DealModel? convertedDealRef;

  TaskModel({
    this.id,
    this.title,
    this.description,
    this.priority,
    this.status,
    this.dueDate,
    this.assignedTo,
    this.createdBy,
    this.leadRef,
    this.dealRef,
    this.leadRefs = const [],
    this.dealRefs = const [],
    this.leadDueDates = const {},
    this.dealDueDates = const {},
    this.leadDueReminderSentAt = const {},
    this.leadDueTodaySentAt = const {},
    this.dealDueReminderSentAt = const {},
    this.dealDueTodaySentAt = const {},
    this.callsMade,
    this.meetingsDone,
    this.completionNotes,
    this.inProcessNote,
    this.rejectionRequested,
    this.rejectionReason,
    this.rejectionApprovedAt,
    this.approvedByAdmin,
    this.completedAt,
    this.holdRequested,
    this.holdReason,
    this.holdRequestedAt,
    this.holdSnapshotProgress,
    this.archived,
    this.history = const [],
    this.reminderSentAt,
    this.dueTodaySentAt,
    this.reasonNotes = const [],
    this.createdAt,
    this.updatedAt,
    this.version,
    this.linkedItemBadge,
    this.convertedDealRefsByLeadId = const {},
    this.convertedDealRef,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['_id'],
      title: json['title'],
      description: json['description'],
      priority: json['priority'],
      status: json['status'],

      dueDate: _parseDate(json['dueDate']),

      assignedTo: json['assignedTo'] != null
          ? UserModel.fromJson(json['assignedTo'])
          : null,

      createdBy: json['createdBy'] != null
          ? UserModel.fromJson(json['createdBy'])
          : null,

      leadRef: json['leadRef'] != null
          ? LeadModel.fromJson(json['leadRef'])
          : null,

      dealRef: json['dealRef'] != null
          ? DealModel.fromJson(json['dealRef'])
          : null,

      leadRefs: (json['leadRefs'] as List?)
              ?.map((e) => LeadModel.fromJson(e))
              .toList() ??
          [],

      dealRefs: (json['dealRefs'] as List?)
              ?.map((e) => DealModel.fromJson(e))
              .toList() ??
          [],

      leadDueDates: _parseDateMap(json['leadDueDates']),
      dealDueDates: _parseDateMap(json['dealDueDates']),

      leadDueReminderSentAt:
          _parseDateMap(json['leadDueReminderSentAt']),
      leadDueTodaySentAt:
          _parseDateMap(json['leadDueTodaySentAt']),

      dealDueReminderSentAt:
          _parseDateMap(json['dealDueReminderSentAt']),
      dealDueTodaySentAt:
          _parseDateMap(json['dealDueTodaySentAt']),

      callsMade: json['callsMade'],
      meetingsDone: json['meetingsDone'],

      completionNotes: json['completionNotes'],
      inProcessNote: json['inProcessNote'],

      rejectionRequested: json['rejectionRequested'],
      rejectionReason: json['rejectionReason'],

      rejectionApprovedAt:
          _parseDate(json['rejectionApprovedAt']),

      approvedByAdmin: json['approvedByAdmin'],

      completedAt:
          _parseDate(json['completedAt']),

      holdRequested: json['holdRequested'],
      holdReason: json['holdReason'],

      holdRequestedAt:
          _parseDate(json['holdRequestedAt']),

      holdSnapshotProgress:
          json['holdSnapshotProgress'],

      archived: json['archived'],

      history: (json['history'] as List?)
              ?.map((e) => TaskHistoryModel.fromJson(e))
              .toList() ??
          [],

      reminderSentAt:
          _parseDate(json['reminderSentAt']),

      dueTodaySentAt:
          _parseDate(json['dueTodaySentAt']),

      reasonNotes: (json['reasonNotes'] as List?)
              ?.map((e) => ReasonNoteModel.fromJson(e))
              .toList() ??
          [],

      createdAt:
          _parseDate(json['createdAt']),

      updatedAt:
          _parseDate(json['updatedAt']),

      version: json['__v'],

      linkedItemBadge: json['linkedItemBadge'] != null
          ? LinkedItemBadgeModel.fromJson(
              json['linkedItemBadge'],
            )
          : null,

      convertedDealRefsByLeadId:
          (json['convertedDealRefsByLeadId']
                  as Map<String, dynamic>?)
              ?.map(
                (key, value) => MapEntry(
                  key,
                  DealModel.fromJson(value),
                ),
              ) ??
              {},

      convertedDealRef: json['convertedDealRef'] != null
          ? DealModel.fromJson(json['convertedDealRef'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'dueDate': dueDate?.toIso8601String(),
      'assignedTo': assignedTo?.toJson(),
      'createdBy': createdBy?.toJson(),
      'leadRef': leadRef?.toJson(),
      'dealRef': dealRef?.toJson(),
      'leadRefs': leadRefs.map((e) => e.toJson()).toList(),
      'dealRefs': dealRefs.map((e) => e.toJson()).toList(),
      'leadDueDates': _dateMapToJson(leadDueDates),
      'dealDueDates': _dateMapToJson(dealDueDates),
      'leadDueReminderSentAt': _dateMapToJson(leadDueReminderSentAt),
      'leadDueTodaySentAt': _dateMapToJson(leadDueTodaySentAt),
      'dealDueReminderSentAt': _dateMapToJson(dealDueReminderSentAt),
      'dealDueTodaySentAt': _dateMapToJson(dealDueTodaySentAt),
      'callsMade': callsMade,
      'meetingsDone': meetingsDone,
      'completionNotes': completionNotes,
      'inProcessNote': inProcessNote,
      'rejectionRequested': rejectionRequested,
      'rejectionReason': rejectionReason,
      'rejectionApprovedAt':
          rejectionApprovedAt?.toIso8601String(),
      'approvedByAdmin': approvedByAdmin,
      'completedAt': completedAt?.toIso8601String(),
      'holdRequested': holdRequested,
      'holdReason': holdReason,
      'holdRequestedAt':
          holdRequestedAt?.toIso8601String(),
      'holdSnapshotProgress': holdSnapshotProgress,
      'archived': archived,
      'history': history.map((e) => e.toJson()).toList(),
      'reminderSentAt':
          reminderSentAt?.toIso8601String(),
      'dueTodaySentAt':
          dueTodaySentAt?.toIso8601String(),
      'reasonNotes':
          reasonNotes.map((e) => e.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      '__v': version,
      'linkedItemBadge':
          linkedItemBadge?.toJson(),
      'convertedDealRefsByLeadId':
          convertedDealRefsByLeadId.map(
        (key, value) => MapEntry(
          key,
          value.toJson(),
        ),
      ),
      'convertedDealRef':
          convertedDealRef?.toJson(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  /// { "<itemId>": "<ISO date>" } → { itemId: DateTime }; bad dates dropped.
  static Map<String, DateTime> _parseDateMap(dynamic value) {
    if (value is! Map) return const {};

    return {
      for (final e in value.entries)
        if (_parseDate(e.value) case final date?) e.key.toString(): date,
    };
  }

  static Map<String, String> _dateMapToJson(Map<String, DateTime> map) =>
      map.map((key, value) => MapEntry(key, value.toIso8601String()));
}

class UserModel {
  final String? id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? profileImage;
  final RoleModel? role;

  UserModel({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.profileImage,
    this.role,
  });

  String get fullName =>
      '${firstName ?? ''} ${lastName ?? ''}'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      profileImage: json['profileImage'],
      role: json['role'] != null
          ? RoleModel.fromJson(json['role'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'profileImage': profileImage,
      'role': role?.toJson(),
    };
  }
}

class RoleModel {
  final String? id;
  final String? name;

  RoleModel({
    this.id,
    this.name,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['_id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
    };
  }
}

class LeadModel {
  final String? id;
  final String? leadName;
  final String? phoneNumber;
  final String? email;
  final String? companyName;
  final String? status;
  final UserModel? convertedBy;
  final List<LeadStatusHistoryModel> statusHistory;
  final DateTime? createdAt;

  LeadModel({
    this.id,
    this.leadName,
    this.phoneNumber,
    this.email,
    this.companyName,
    this.status,
    this.convertedBy,
    this.statusHistory = const [],
    this.createdAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: json['_id'],
      leadName: json['leadName'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      companyName: json['companyName'],
      status: json['status'],

      convertedBy: json['convertedBy'] != null
          ? UserModel.fromJson(json['convertedBy'])
          : null,

      statusHistory: (json['statusHistory'] as List?)
              ?.map(
                (e) => LeadStatusHistoryModel.fromJson(e),
              )
              .toList() ??
          [],

      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'leadName': leadName,
      'phoneNumber': phoneNumber,
      'email': email,
      'companyName': companyName,
      'status': status,
      'convertedBy': convertedBy?.toJson(),
      'statusHistory':
          statusHistory.map((e) => e.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
    };
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

class LeadStatusHistoryModel {
  final String? status;
  final DateTime? changedAt;
  final String? changedBy;
  final String? id;

  LeadStatusHistoryModel({
    this.status,
    this.changedAt,
    this.changedBy,
    this.id,
  });

  factory LeadStatusHistoryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeadStatusHistoryModel(
      status: json['status'],
      changedAt: _parseDate(json['changedAt']),
      changedBy: json['changedBy'],
      id: json['_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'changedAt': changedAt?.toIso8601String(),
      'changedBy': changedBy,
      '_id': id,
    };
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

class DealModel {
  final String? id;
  final String? leadId;
  final String? dealTitle;
  final String? dealName;
  final String? assignedTo;
  final String? value;
  final String? currency;
  final String? stage;
  final DateTime? convertedAt;
  final String? phoneNumber;
  final String? email;
  final String? companyName;

  final List<DealStageHistoryModel> stageHistory;

  final UserModel? convertedBy;

  final List<LeadStatusHistoryModel> leadStatusHistory;

  final DateTime? leadCreatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? lossReason;
  final String? lossNotes;
  final DateTime? stageLostAt;

  final bool? salesPersonConverted;
  final String? convertedByName;
  final String? takenByAdminName;

  DealModel({
    this.id,
    this.leadId,
    this.dealTitle,
    this.dealName,
    this.assignedTo,
    this.value,
    this.currency,
    this.stage,
    this.convertedAt,
    this.phoneNumber,
    this.email,
    this.companyName,
    this.stageHistory = const [],
    this.convertedBy,
    this.leadStatusHistory = const [],
    this.leadCreatedAt,
    this.createdAt,
    this.updatedAt,
    this.lossReason,
    this.lossNotes,
    this.stageLostAt,
    this.salesPersonConverted,
    this.convertedByName,
    this.takenByAdminName,
  });

  factory DealModel.fromJson(Map<String, dynamic> json) {
    return DealModel(
      id: json['_id'],
      leadId: json['leadId'],
      dealTitle: json['dealTitle'],
      dealName: json['dealName'],
      assignedTo: json['assignedTo'],
      value: json['value']?.toString(),
      currency: json['currency'],
      stage: json['stage'],

      convertedAt:
          _parseDate(json['convertedAt']),

      phoneNumber: json['phoneNumber'],
      email: json['email'],
      companyName: json['companyName'],

      stageHistory: (json['stageHistory'] as List?)
              ?.map(
                (e) => DealStageHistoryModel.fromJson(e),
              )
              .toList() ??
          [],

      convertedBy: json['convertedBy'] != null
          ? UserModel.fromJson(json['convertedBy'])
          : null,

      leadStatusHistory:
          (json['leadStatusHistory'] as List?)
                  ?.map(
                    (e) =>
                        LeadStatusHistoryModel.fromJson(e),
                  )
                  .toList() ??
              [],

      leadCreatedAt:
          _parseDate(json['leadCreatedAt']),

      createdAt:
          _parseDate(json['createdAt']),

      updatedAt:
          _parseDate(json['updatedAt']),

      lossReason: json['lossReason'],
      lossNotes: json['lossNotes'],

      stageLostAt:
          _parseDate(json['stageLostAt']),

      salesPersonConverted: json['salesPersonConverted'],
      convertedByName: json['convertedByName'],
      takenByAdminName: json['takenByAdminName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'leadId': leadId,
      'dealTitle': dealTitle,
      'dealName': dealName,
      'assignedTo': assignedTo,
      'value': value,
      'currency': currency,
      'stage': stage,
      'convertedAt': convertedAt?.toIso8601String(),
      'phoneNumber': phoneNumber,
      'email': email,
      'companyName': companyName,
      'stageHistory':
          stageHistory.map((e) => e.toJson()).toList(),
      'convertedBy': convertedBy?.toJson(),
      'leadStatusHistory':
          leadStatusHistory.map((e) => e.toJson()).toList(),
      'leadCreatedAt':
          leadCreatedAt?.toIso8601String(),
      'createdAt':
          createdAt?.toIso8601String(),
      'updatedAt':
          updatedAt?.toIso8601String(),
      'lossReason': lossReason,
      'lossNotes': lossNotes,
      'stageLostAt':
          stageLostAt?.toIso8601String(),
      'salesPersonConverted': salesPersonConverted,
      'convertedByName': convertedByName,
      'takenByAdminName': takenByAdminName,
    };
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

class DealStageHistoryModel {
  final String? stage;
  final DateTime? movedAt;
  final UserModel? movedBy;
  final String? id;

  DealStageHistoryModel({
    this.stage,
    this.movedAt,
    this.movedBy,
    this.id,
  });

  factory DealStageHistoryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return DealStageHistoryModel(
      stage: json['stage'],
      movedAt: _parseDate(json['movedAt']),
      movedBy: json['movedBy'] != null
          ? UserModel.fromJson(json['movedBy'])
          : null,
      id: json['_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage': stage,
      'movedAt': movedAt?.toIso8601String(),
      'movedBy': movedBy?.toJson(),
      '_id': id,
    };
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

class TaskHistoryModel {
  final String? event;
  final String? detail;
  final UserModel? by;
  final DateTime? at;
  final String? id;

  TaskHistoryModel({
    this.event,
    this.detail,
    this.by,
    this.at,
    this.id,
  });

  factory TaskHistoryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TaskHistoryModel(
      event: json['event'],
      detail: json['detail'],

      by: json['by'] != null
          ? UserModel.fromJson(json['by'])
          : null,

      at: _parseDate(json['at']),
      id: json['_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event': event,
      'detail': detail,
      'by': by?.toJson(),
      'at': at?.toIso8601String(),
      '_id': id,
    };
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

class ReasonNoteModel {
  final String? note;
  final String? addedBy;
  final DateTime? addedAt;
  final String? status;
  final String? itemType;
  final String? itemId;
  final String? itemName;
  final String? id;
  final String? reassignNote;
  final String? reassignedTo;
  final String? adminReply;
  final DateTime? resolvedAt;

  // Snapshot of the reported lead/deal at the time of the report.
  final String? companyName;
  final String? phoneNumber;
  final String? email;
  final String? value;
  final String? currency;
  final String? stageOrStatus;

  ReasonNoteModel({
    this.note,
    this.addedBy,
    this.addedAt,
    this.status,
    this.itemType,
    this.itemId,
    this.itemName,
    this.id,
    this.reassignNote,
    this.reassignedTo,
    this.adminReply,
    this.resolvedAt,
    this.companyName,
    this.phoneNumber,
    this.email,
    this.value,
    this.currency,
    this.stageOrStatus,
  });

  factory ReasonNoteModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReasonNoteModel(
      note: json['note'],
      addedBy: json['addedBy'],
      addedAt: _parseDate(json['addedAt']),
      status: json['status'],
      itemType: json['itemType'],
      itemId: json['itemId'],
      itemName: json['itemName'],
      id: json['_id'],
      reassignNote: json['reassignNote'],
      reassignedTo: json['reassignedTo'],
      adminReply: json['adminReply'],
      resolvedAt: _parseDate(json['resolvedAt']),
      companyName: json['companyName'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      value: json['value']?.toString(),
      currency: json['currency'],
      stageOrStatus: json['stageOrStatus'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'note': note,
      'addedBy': addedBy,
      'addedAt': addedAt?.toIso8601String(),
      'status': status,
      'itemType': itemType,
      'itemId': itemId,
      'itemName': itemName,
      '_id': id,
      'reassignNote': reassignNote,
      'reassignedTo': reassignedTo,
      'adminReply': adminReply,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'companyName': companyName,
      'phoneNumber': phoneNumber,
      'email': email,
      'value': value,
      'currency': currency,
      'stageOrStatus': stageOrStatus,
    };
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

class LinkedItemBadgeModel {
  final String? kind;
  final bool? isSelf;
  final bool? isAdmin;
  final String? name;

  LinkedItemBadgeModel({
    this.kind,
    this.isSelf,
    this.isAdmin,
    this.name,
  });

  factory LinkedItemBadgeModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return LinkedItemBadgeModel(
      kind: json['kind'],
      isSelf: json['isSelf'],
      isAdmin: json['isAdmin'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'isSelf': isSelf,
      'isAdmin': isAdmin,
      'name': name,
    };
  }
}

