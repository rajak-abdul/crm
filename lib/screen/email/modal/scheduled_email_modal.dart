class ScheduledEmail {
  final String id;
  final List<String> recipients;
  final String templateTitle;
  final String subject;
  final String content;
  final List<ScheduledAttachment> attachments;
  final DateTime? scheduledFor;
  final String status;
  final ScheduledCreatedBy? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ScheduledEmail({
    required this.id,
    required this.recipients,
    required this.templateTitle,
    required this.subject,
    required this.content,
    required this.attachments,
    required this.scheduledFor,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScheduledEmail.fromJson(
    Map<String, dynamic> json,
  ) {
    return ScheduledEmail(
      id: json['_id']?.toString() ?? '',
      recipients: (json['recipients'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),

      templateTitle:
          json['templateTitle']?.toString() ?? '',

      subject:
          json['subject']?.toString() ?? '',

      content:
          json['content']?.toString() ?? '',

      attachments:
          (json['attachments'] as List? ?? [])
              .map(
                (item) => ScheduledAttachment.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),

      scheduledFor: json['scheduledFor'] != null
          ? DateTime.tryParse(
              json['scheduledFor'].toString(),
            )
          : null,

      status:
          json['status']?.toString() ?? '',

createdBy: json['createdBy'] is Map
    ? ScheduledCreatedBy.fromJson(
        Map<String, dynamic>.from(
          json['createdBy'],
        ),
      )
    : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(
              json['createdAt'].toString(),
            )
          : null,

      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(
              json['updatedAt'].toString(),
            )
          : null,
    );
  }
}

// ============================================================
// ATTACHMENT
// ============================================================

class ScheduledAttachment {
  final String id;
  final String filename;
  final String path;

  const ScheduledAttachment({
    required this.id,
    required this.filename,
    required this.path,
  });

  factory ScheduledAttachment.fromJson(
    Map<String, dynamic> json,
  ) {
    return ScheduledAttachment(
      id: json['_id']?.toString() ?? '',
      filename:
          json['filename']?.toString() ?? '',
      path:
          json['path']?.toString() ?? '',
    );
  }
}

// ============================================================
// CREATED BY
// ============================================================

class ScheduledCreatedBy {
  final String id;
  final String firstName;
  final String lastName;
  final String email;

  const ScheduledCreatedBy({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory ScheduledCreatedBy.fromJson(
    Map<String, dynamic> json,
  ) {
    return ScheduledCreatedBy(
      id: json['_id']?.toString() ?? '',
      firstName:
          json['firstName']?.toString() ?? '',
      lastName:
          json['lastName']?.toString() ?? '',
      email:
          json['email']?.toString() ?? '',
    );
  }

  String get fullName {
    return '$firstName $lastName'.trim();
  }

  // ============================================================
  // Cancel Scheduled Email
  // ============================================================

  
}