// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/entities/                     ║
// ║                            recycled_document.dart             ║
// ║  ENTITY — a deleted assignment in the recycle bin and when it ║
// ║  is purged (30 days after deletion).                          ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:equatable/equatable.dart';

class RecycledDocument extends Equatable {
  /// The backend purges the bin this long after deletion.
  static const retention = Duration(days: 30);

  /// "Expiring soon" once this many days or fewer are left.
  static const expiringSoonDays = 7;

  final HubDocument document;
  final DateTime deletedAt;

  const RecycledDocument({required this.document, required this.deletedAt});

  DateTime get expiresAt => deletedAt.add(retention);

  /// Whole days until the purge, rounded up; 0 once it's due.
  int daysLeft(DateTime now) {
    final left = expiresAt.difference(now);
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  bool expiringSoon(DateTime now) => daysLeft(now) <= expiringSoonDays;

  /// Share of the retention already used up, 0 → 1.
  double elapsed(DateTime now) {
    final used = now.difference(deletedAt).inMinutes / retention.inMinutes;
    return used.clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [document, deletedAt];
}
