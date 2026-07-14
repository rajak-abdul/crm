enum FollowUpType { lead, deal }

class FollowUpItem {
  final FollowUpType type;
  final String title;       // Lead name / Deal company name
  final String subtitle;    // Lead: notes  |  Deal: followUpComment
  final DateTime followUpDate;
  final String id;
  final String? phone;      // lead phone (call action)
  final double? dealValue;  // deal value (deals only)
  final String? currency;   // deal currency (deals only)

  const FollowUpItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.followUpDate,
    required this.id,
    this.phone,
    this.dealValue,
    this.currency,
  });
}