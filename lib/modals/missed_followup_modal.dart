class MissedFollowup {
  final String id;
  final String leadName;
  final String companyName;
  final String assignedToId;
  final String assignedToName;
  final DateTime followUpDate;

  MissedFollowup({
    required this.id,
    required this.leadName,
    required this.companyName,
    required this.assignedToId,
    required this.assignedToName,
    required this.followUpDate,
  });

  factory MissedFollowup.fromJson(Map<String, dynamic> json) {
    final assign = json['assignTo'] ?? {};

    return MissedFollowup(
      id: json['_id'] ?? '',
      leadName: json['leadName'] ?? '',
      companyName: json['companyName'] ?? '',
      assignedToId: assign['_id'] ?? '',
      assignedToName:
          "${assign['firstName'] ?? ''} ${assign['lastName'] ?? ''}".trim(),
      followUpDate: DateTime.parse(json['followUpDate']),
    );
  }
}