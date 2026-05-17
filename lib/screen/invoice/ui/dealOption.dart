// lib/screen/invoice/ui/dealOption.dart

class DealOption {
  final String id, name;
  final double value;
  final String currency;
  final String requirement;
  const DealOption(
    this.id,
    this.name,
    this.value,
    this.currency, {
    this.requirement = '',
  });

  /// Identity-based [==] breaks [DropdownButton]: after a refresh, `deals` are
  /// new instances while `_selectedDeal` may still point at an old one. Match by [id].
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DealOption && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override String toString() => name;
}

// ── NEW: carries both display name and _id so the form can send the right value ──
class SalesUser {
  final String id;   // _id from API
  final String name; // "First Last" display name
  const SalesUser(this.id, this.name);
  @override String toString() => name;
}