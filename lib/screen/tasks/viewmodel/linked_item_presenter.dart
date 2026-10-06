// ╔══════════════════════════════════════════════════════════════╗
// ║    lib/screen/tasks/viewmodel/linked_item_presenter.dart      ║
// ║  Turns a linked LeadModel / DealModel into LinkedItemData     ║
// ║  (card + detail + journey). Shared by the Task screen's       ║
// ║  Linked items sheet and the Target screen's Records sheet.    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:intl/intl.dart';

import 'linked_items_state.dart';

class LinkedItemPresenter {
  /// Logged-in user, for "Converted by you". Empty = unknown.
  final String currentUserId;

  const LinkedItemPresenter({this.currentUserId = ''});

  LinkedItemData deal(DealModel deal) {
    return LinkedItemData(
      kind: LinkedItemKind.deal,
      id: deal.id,
      title: _nonEmpty(deal.dealName) ?? _nonEmpty(deal.dealTitle) ?? '-',
      badge: deal.stage ?? '-',
      valueText: _formatDealValue(deal),
      phone: _nonEmpty(deal.phoneNumber),
      whatsAppNumber: _whatsAppNumber(deal.phoneNumber),
      email: _cleanEmail(deal.email),
      convertedByLabel: _convertedByLabel(deal.convertedBy),
      convertedByMe: _isMe(deal.convertedBy),
      journey: _dealJourney(deal),
    );
  }

  LinkedItemData lead(LeadModel lead) {
    return LinkedItemData(
      kind: LinkedItemKind.lead,
      id: lead.id,
      title: _nonEmpty(lead.leadName) ?? '-',
      badge: lead.status ?? '-',
      valueText: _nonEmpty(lead.companyName),
      phone: _nonEmpty(lead.phoneNumber),
      whatsAppNumber: _whatsAppNumber(lead.phoneNumber),
      email: _cleanEmail(lead.email),
      convertedByLabel: _convertedByLabel(lead.convertedBy),
      convertedByMe: _isMe(lead.convertedBy),
      journey: _leadJourney(lead),
    );
  }

  /// Newest first: deal stages → conversion → lead statuses → lead created.
  List<JourneyStep> _dealJourney(DealModel deal) {
    final stages = [...deal.stageHistory]
      ..sort((a, b) => _compareDesc(a.movedAt, b.movedAt));
    final leadStatuses = [...deal.leadStatusHistory]
      ..sort((a, b) => _compareDesc(a.changedAt, b.changedAt));
    final currentStage = _nonEmpty(deal.stage);

    return [
      for (var i = 0; i < stages.length; i++)
        JourneyStep(
          title: stages[i].stage ?? '-',
          atText: _formatDateTime(stages[i].movedAt),
          kind: JourneyKind.dealStage,
          isCurrent: i == 0 && stages[i].stage == deal.stage,
        ),
      // No stage history yet: the deal entered its current stage on conversion.
      if (stages.isEmpty && currentStage != null)
        JourneyStep(
          title: currentStage,
          atText: _formatDateTime(deal.convertedAt ?? deal.createdAt),
          kind: JourneyKind.dealStage,
          isCurrent: true,
        ),
      if (deal.convertedAt != null)
        JourneyStep(
          title: 'Converted to deal',
          atText: _formatDateTime(deal.convertedAt),
          kind: JourneyKind.converted,
        ),
      for (final s in leadStatuses)
        JourneyStep(
          title: s.status ?? '-',
          atText: _formatDateTime(s.changedAt),
          kind: JourneyKind.leadStatus,
        ),
      if (deal.leadCreatedAt != null)
        JourneyStep(
          title: 'Lead created',
          atText: _formatDateTime(deal.leadCreatedAt),
          kind: JourneyKind.leadCreated,
        ),
    ];
  }

  /// Newest first: lead statuses → lead created.
  List<JourneyStep> _leadJourney(LeadModel lead) {
    final statuses = [...lead.statusHistory]
      ..sort((a, b) => _compareDesc(a.changedAt, b.changedAt));

    // No status history yet: the lead has held its current status since it
    // was created, so show that status at the created time.
    final currentStatus = _nonEmpty(lead.status);
    if (statuses.isEmpty && currentStatus != null) {
      return [
        JourneyStep(
          title: currentStatus,
          atText: _formatDateTime(lead.createdAt),
          kind: _leadStatusKind(currentStatus),
          isCurrent: true,
        ),
      ];
    }

    return [
      for (var i = 0; i < statuses.length; i++)
        JourneyStep(
          title: statuses[i].status ?? '-',
          atText: _formatDateTime(statuses[i].changedAt),
          kind: _leadStatusKind(statuses[i].status),
          isCurrent: i == 0 && statuses[i].status == lead.status,
        ),
      if (lead.createdAt != null)
        JourneyStep(
          title: 'Lead created',
          atText: _formatDateTime(lead.createdAt),
          kind: JourneyKind.leadCreated,
          isCurrent: statuses.isEmpty,
        ),
    ];
  }

  JourneyKind _leadStatusKind(String? status) =>
      (status ?? '').toLowerCase() == 'converted'
          ? JourneyKind.converted
          : JourneyKind.leadStatus;

  bool _isMe(UserModel? user) =>
      currentUserId.isNotEmpty && user?.id == currentUserId;

  String? _convertedByLabel(UserModel? user) {
    if (user == null) return null;
    if (_isMe(user)) return 'you';

    final name = user.fullName.isEmpty ? 'Unknown' : user.fullName;
    final role = user.role?.name;
    return role == null || role.isEmpty ? name : '$name ($role)';
  }

  /// "1,75,000 INR" → "INR 1,75,000"; falls back to the currency field.
  String _formatDealValue(DealModel deal) {
    final value = (deal.value ?? '').trim();
    final currency = (deal.currency ?? '').trim();

    if (value.isEmpty) return currency.isEmpty ? '-' : '$currency 0';

    final parts = value.split(RegExp(r'\s+'));
    if (parts.length > 1 && RegExp(r'^[A-Za-z]{3}$').hasMatch(parts.last)) {
      final amount = parts.sublist(0, parts.length - 1).join(' ');
      return '${parts.last.toUpperCase()} $amount';
    }
    return currency.isEmpty ? value : '$currency $value';
  }

  /// Digits only; bare 10-digit numbers are assumed to be Indian (+91).
  String? _whatsAppNumber(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return digits.length == 10 ? '91$digits' : digits;
  }

  String? _cleanEmail(String? email) {
    final e = (email ?? '').trim();
    return e.isEmpty || e == '-' ? null : e;
  }

  String? _nonEmpty(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }

  /// Always shown in IST (UTC+5:30), whatever the device timezone.
  String? _formatDateTime(DateTime? dt) {
    if (dt == null) return null;
    final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    final text = DateFormat('d MMM yyyy, hh:mm a')
        .format(ist)
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');
    return '$text IST';
  }

  int _compareDesc(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null ? 1 : -1;
    return b.compareTo(a);
  }
}
