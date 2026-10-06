class CalendarResponse {
  final List<CalendarEvent> events;

  CalendarResponse({
    required this.events,
  });

  factory CalendarResponse.fromJson(Map<String, dynamic> json) {
    return CalendarResponse(
      events: (json['events'] as List<dynamic>?)
              ?.map(
                (e) => CalendarEvent.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
    );
  }
}

class CalendarEvent {
  final String id;
  final String type;
  final String title;
  final DateTime date;
  final DateTime? endDate;
  final String? status;
  final bool? pending;

  final String? dealId;
  final String? dealName;

  final String? leadId;
  final String? leadName;

  final bool? editable;

  final CalendarEventLink? link;

  CalendarEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.endDate,
    this.status,
    this.pending,
    this.dealId,
    this.dealName,
    this.leadId,
    this.leadName,
    this.editable,
    this.link,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      date: DateTime.parse(json['date'].toString()),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      status: json['status']?.toString(),
      pending: json['pending'],
      dealId: json['dealId']?.toString(),
      dealName: json['dealName']?.toString(),
      leadId: json['leadId']?.toString(),
      leadName: json['leadName']?.toString(),
      editable: json['editable'],
      link: json['link'] != null
          ? CalendarEventLink.fromJson(
              json['link'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class CalendarEventLink {
  final String? page;
  final String? dealId;
  final String? leadId;
  final String? invoiceId;
  final String? proposalId;
  final String? emailId;

  CalendarEventLink({
    this.page,
    this.dealId,
    this.leadId,
    this.invoiceId,
    this.proposalId,
    this.emailId,
  });

  factory CalendarEventLink.fromJson(Map<String, dynamic> json) {
    return CalendarEventLink(
      page: json['page']?.toString(),
      dealId: json['dealId']?.toString(),
      leadId: json['leadId']?.toString(),
      invoiceId: json['invoiceId']?.toString(),
      proposalId: json['proposalId']?.toString(),
      emailId: json['emailId']?.toString(),
    );
  }
}