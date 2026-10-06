class EmailTemplate {
  final String id;
  final String title;
  final String subject;
  final String content;
  final dynamic createdBy;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EmailTemplate({
    required this.id,
    required this.title,
    required this.subject,
    required this.content,
    required this.createdBy,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmailTemplate.fromJson(
    Map<String, dynamic> json,
  ) {
    return EmailTemplate(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdBy: json['createdBy'],
      version: int.tryParse(
            json['__v']?.toString() ?? '0',
          ) ??
          0,
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

class EmailTemplatesResponse {
  final bool success;
  final List<EmailTemplate> templates;
    final int total; // NEW


  EmailTemplatesResponse({
    required this.success,
    required this.templates,
    required this.total,
  });

  factory EmailTemplatesResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = json['templates'] as List? ?? [];

    return EmailTemplatesResponse(
      success: json['success'] == true,
      templates: data
          .map(
            (item) => EmailTemplate.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
          total: json['total'] ?? 0, // NEW
    );
  }
}