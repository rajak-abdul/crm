// ══════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════
import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String text;
  final bool read;
  final String? profileImage;
  final String? userName;
  final String? dealId;
  final String? dealName;
  final String? leadId;
  final String? proposalId;
  final String? proposalTitle;
  final String? salesmanName;
  final String? salesmanId;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.text,
    required this.read,
    this.profileImage,
    this.userName,
    this.dealId,
    this.dealName,
    this.leadId,
    this.proposalId,
    this.proposalTitle,
    this.salesmanName,
    this.salesmanId,
    this.createdAt,
    this.expiresAt,
  });

  static String _s(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString().trim();

  static String? _nullableStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] is Map
        ? Map<String, dynamic>.from(j['meta'] as Map)
        : <String, dynamic>{};

    return AppNotification(
      id: _s(j['_id'] ?? j['id']),
      userId: _s(j['userId']),
      type: _s(j['type'], 'general'),
      text: _s(j['text'] ?? j['message'] ?? j['title']),
      read: j['read'] == true || j['isRead'] == true,
      // removed buildProfileImageUrl — store raw filename only
      profileImage: _nullableStr(j['profileImage'] ?? meta['profileImage']),
      userName: _nullableStr(j['userName'] ?? meta['salesmanName']),
      dealId: _nullableStr(meta['dealId']),
      dealName: _nullableStr(meta['dealName']),
      leadId: _nullableStr(meta['leadId']),
      proposalId: _nullableStr(meta['proposalId']),
      proposalTitle: _nullableStr(meta['proposalTitle']),
      salesmanName: _nullableStr(meta['salesmanName']),
      salesmanId: _nullableStr(meta['salesmanId']),
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString())
          : null,
      expiresAt: j['expiresAt'] != null
          ? DateTime.tryParse(j['expiresAt'].toString())
          : null,
    );
  }

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        userId: userId,
        type: type,
        text: text,
        read: read ?? this.read,
        profileImage: profileImage,
        userName: userName,
        dealId: dealId,
        dealName: dealName,
        leadId: leadId,
        proposalId: proposalId,
        proposalTitle: proposalTitle,
        salesmanName: salesmanName,
        salesmanId: salesmanId,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );

  String get subtitle {
    if (dealName != null) return dealName!;
    if (proposalTitle != null) return proposalTitle!;
    return '';
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  List<Object?> get props => [id, read];
}
