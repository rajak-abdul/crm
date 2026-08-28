class Meeting {
  final String id;
  final String title;
  final String description;
  final String? dealId;
  final String? leadId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final List<String> attendees;
  final String provider;
  final String? meetLink;
  final String? googleEventId;
  final String? zoomMeetingId;
  final String? zoomStartUrl;
  final String? zoomPassword;
  final int reminderMinutes;
  final String status;
  final String? creatorEmail;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Meeting({
    required this.id,
    required this.title,
    required this.description,
    this.dealId,
    this.leadId,
    required this.startDateTime,
    required this.endDateTime,
    required this.attendees,
    required this.provider,
    this.meetLink,
    this.googleEventId,
    this.zoomMeetingId,
    this.zoomStartUrl,
    this.zoomPassword,
    required this.reminderMinutes,
    required this.status,
    this.creatorEmail,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      dealId: json['dealId']?.toString(),
      leadId: json['leadId']?.toString(),
      startDateTime: DateTime.parse(
        json['startDateTime'].toString(),
      ),
      endDateTime: DateTime.parse(
        json['endDateTime'].toString(),
      ),
      attendees: json['attendees'] is List
          ? List<String>.from(
              json['attendees'].map(
                (e) => e.toString(),
              ),
            )
          : [],
      provider: json['provider']?.toString() ?? '',
      meetLink: json['meetLink']?.toString(),
      googleEventId: json['googleEventId']?.toString(),
      zoomMeetingId: json['zoomMeetingId']?.toString(),
      zoomStartUrl: json['zoomStartUrl']?.toString(),
      zoomPassword: json['zoomPassword']?.toString(),
      reminderMinutes:
          int.tryParse(
                json['reminderMinutes']?.toString() ?? '',
              ) ??
              0,
      status: json['status']?.toString() ?? '',
      creatorEmail: json['creatorEmail']?.toString(),
      createdBy: json['createdBy'] is Map
          ? json['createdBy']['_id']?.toString()
          : json['createdBy']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}