class DraftProposal {
  final String id;
  final String title;
  final String dealTitle;
  final String email;
  final String createdAt;
  final String status;

  DraftProposal({
    required this.id,
    required this.title,
    required this.dealTitle,
    required this.email,
    required this.createdAt,
    required this.status,
  });

  factory DraftProposal.fromJson(Map<String, dynamic> json) {
    final deal = json['deal'];

    return DraftProposal(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      dealTitle: deal is Map
          ? deal['dealName']?.toString() ?? ''
          : json['dealTitle']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
    );
  }
}