import 'package:crm_app/screen/deals/modal/deal_modal.dart' show Attachment, Deal;

class Proposal {
  final String id;
  final String title;
  final Deal? deal;
  final String dealTitle;
  final String createdBy;
  final String lastUpdatedBy;
  final String email;
  final String cc;
  final String content;
  final String image;
  final String value;
  final String companyName;
  final String status;
  final List<ProposalStatusHistory> statusHistory;
  final DateTime? followUpDate;
  final String followUpComment;
  final DateTime? lastReminderAt;
  final List<Attachment> attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Proposal({
    required this.id,
    required this.title,
    this.deal,
    required this.dealTitle,
    required this.createdBy,
    required this.lastUpdatedBy,
    required this.email,
    required this.cc,
    required this.content,
    required this.image,
    required this.value,
    required this.companyName,
    required this.status,
    this.statusHistory = const [],
    this.followUpDate,
    required this.followUpComment,
    this.lastReminderAt,
    this.attachments = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) {
    return Proposal(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',

      deal: json['deal'] is Map
          ? Deal.fromJson(
              Map<String, dynamic>.from(json['deal']),
            )
          : null,

      dealTitle: json['dealTitle']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      lastUpdatedBy: json['lastUpdatedBy']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      cc: json['cc']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      followUpDate: json['followUpDate'] != null
          ? DateTime.tryParse(json['followUpDate'].toString())
          : null,
      followUpComment: json['followUpComment']?.toString() ?? '',
      lastReminderAt: json['lastReminderAt'] != null
          ? DateTime.tryParse(json['lastReminderAt'].toString())
          : null,
      attachments: json['attachments'] is List
          ? (json['attachments'] as List)
              .whereType<Map>()
              .map(
                (e) => Attachment.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      statusHistory: json['statusHistory'] is List
          ? (json['statusHistory'] as List)
              .whereType<Map>()
              .map(
                (e) => ProposalStatusHistory.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

class ProposalStatusHistory {
  final String id;
  final String status;
  final DateTime? changedAt;
  final String changedBy;

  const ProposalStatusHistory({
    this.id = '',
    required this.status,
    this.changedAt,
    this.changedBy = '',
  });

  factory ProposalStatusHistory.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProposalStatusHistory(
      id: json['_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      changedAt: json['changedAt'] != null
          ? DateTime.tryParse(
              json['changedAt'].toString(),
            )
          : null,
      changedBy: json['changedBy']?.toString() ?? '',
    );
  }
}
