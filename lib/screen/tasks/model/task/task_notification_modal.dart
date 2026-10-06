
// GET /notifications/:userId
class TaskNotificationModel {
  final String? id;
  final String? userId;
  final String? type; // 'task' | 'followup' | ...
  final String? title;
  final String? message;
  final String? referenceId;
  final DateTime? followUpDate;
  final bool read;
  final TaskNotificationMetaModel meta;
  final String? profileImage;
  final String? userName;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskNotificationModel({
    this.id,
    this.userId,
    this.type,
    this.title,
    this.message,
    this.referenceId,
    this.followUpDate,
    this.read = false,
    this.meta = const TaskNotificationMetaModel(),
    this.profileImage,
    this.userName,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskNotificationModel.fromJson(Map<String, dynamic> json) {
    return TaskNotificationModel(
      id: json['_id'],
      userId: json['userId'],
      type: json['type'],
      title: json['title'],
      message: json['message'] ?? json['text'],
      referenceId: json['referenceId'],
      followUpDate: _parseDate(json['followUpDate']),
      read: json['read'] == true || json['isRead'] == true,
      meta: json['meta'] is Map<String, dynamic>
          ? TaskNotificationMetaModel.fromJson(json['meta'])
          : const TaskNotificationMetaModel(),
      profileImage: json['profileImage'],
      userName: json['userName'],
      expiresAt: _parseDate(json['expiresAt']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'referenceId': referenceId,
      'followUpDate': followUpDate?.toIso8601String(),
      'read': read,
      'meta': meta.toJson(),
      'profileImage': profileImage,
      'userName': userName,
      'expiresAt': expiresAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  TaskNotificationModel copyWith({bool? read}) {
    return TaskNotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      referenceId: referenceId,
      followUpDate: followUpDate,
      read: read ?? this.read,
      meta: meta,
      profileImage: profileImage,
      userName: userName,
      expiresAt: expiresAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
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

/// `meta` varies by notification kind — every field is optional.
class TaskNotificationMetaModel {
  // Task notifications
  final String? taskId;
  final bool taskAssigned;
  final bool taskDueToday;
  final bool taskReminder;
  final bool taskReactivated;
  final bool taskCompletedBySelf;
  final bool reasonNoteReplied;
  final String? taskRejectionAction; // e.g. 'approve'

  // Lead / deal (re)assignment
  final bool leadOrDealAssigned;
  final bool isReassignment;
  final String? itemType; // 'lead' | 'deal'
  final String? itemId;
  final String? itemName;
  final String? actorName;

  // Linked item attached to a task notification
  final String? linkedType;
  final String? linkedName;
  final String? linkedCompany;
  final String? linkedPhone;
  final String? linkedEmail;

  // Follow-up notifications
  final String? leadId;
  final String? leadName;
  final String? dealId;
  final String? dealName;
  final String? proposalId;
  final String? proposalTitle;

  final String? profileImage;

  const TaskNotificationMetaModel({
    this.taskId,
    this.taskAssigned = false,
    this.taskDueToday = false,
    this.taskReminder = false,
    this.taskReactivated = false,
    this.taskCompletedBySelf = false,
    this.reasonNoteReplied = false,
    this.taskRejectionAction,
    this.leadOrDealAssigned = false,
    this.isReassignment = false,
    this.itemType,
    this.itemId,
    this.itemName,
    this.actorName,
    this.linkedType,
    this.linkedName,
    this.linkedCompany,
    this.linkedPhone,
    this.linkedEmail,
    this.leadId,
    this.leadName,
    this.dealId,
    this.dealName,
    this.proposalId,
    this.proposalTitle,
    this.profileImage,
  });

  factory TaskNotificationMetaModel.fromJson(Map<String, dynamic> json) {
    return TaskNotificationMetaModel(
      taskId: json['taskId'],
      taskAssigned: json['taskAssigned'] == true,
      taskDueToday: json['taskDueToday'] == true,
      taskReminder: json['taskReminder'] == true,
      taskReactivated: json['taskReactivated'] == true,
      taskCompletedBySelf: json['taskCompletedBySelf'] == true,
      reasonNoteReplied: json['reasonNoteReplied'] == true,
      taskRejectionAction: json['taskRejectionAction'],
      leadOrDealAssigned: json['leadOrDealAssigned'] == true,
      isReassignment: json['isReassignment'] == true,
      itemType: json['itemType'],
      itemId: json['itemId'],
      itemName: json['itemName'],
      actorName: json['actorName'],
      linkedType: json['linkedType'],
      linkedName: json['linkedName'],
      linkedCompany: json['linkedCompany'],
      linkedPhone: json['linkedPhone'],
      linkedEmail: json['linkedEmail'],
      leadId: json['leadId'],
      leadName: json['leadName'],
      dealId: json['dealId'],
      dealName: json['dealName'],
      proposalId: json['proposalId'],
      proposalTitle: json['proposalTitle'],
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'taskAssigned': taskAssigned,
      'taskDueToday': taskDueToday,
      'taskReminder': taskReminder,
      'taskReactivated': taskReactivated,
      'taskCompletedBySelf': taskCompletedBySelf,
      'reasonNoteReplied': reasonNoteReplied,
      'taskRejectionAction': taskRejectionAction,
      'leadOrDealAssigned': leadOrDealAssigned,
      'isReassignment': isReassignment,
      'itemType': itemType,
      'itemId': itemId,
      'itemName': itemName,
      'actorName': actorName,
      'linkedType': linkedType,
      'linkedName': linkedName,
      'linkedCompany': linkedCompany,
      'linkedPhone': linkedPhone,
      'linkedEmail': linkedEmail,
      'leadId': leadId,
      'leadName': leadName,
      'dealId': dealId,
      'dealName': dealName,
      'proposalId': proposalId,
      'proposalTitle': proposalTitle,
      'profileImage': profileImage,
    };
  }
}
