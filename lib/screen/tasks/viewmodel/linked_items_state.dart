// ╔══════════════════════════════════════════════════════════════╗
// ║       lib/screen/tasks/viewmodel/linked_items_state.dart      ║
// ║  UI state for the Linked items sheet + linked item detail.    ║
// ╚══════════════════════════════════════════════════════════════╝

enum LinkedTab { deals, leads }

enum LinkedItemKind { deal, lead }

/// What a journey step represents — the View maps it to icon/colour.
enum JourneyKind { dealStage, converted, leadStatus, leadCreated }

class JourneyStep {
  final String title;
  final String? atText; // e.g. "6 Aug 2026, 10:05 am"
  final JourneyKind kind;
  final bool isCurrent;

  const JourneyStep({
    required this.title,
    required this.atText,
    required this.kind,
    this.isCurrent = false,
  });
}

/// One issue reported on a linked lead / deal, with the admin's answer —
/// shown as a chat on the item's detail page (Task and Target screens).
class ItemIssue {
  final String note;
  final String status; // "pending", "resolved", ...
  final String? adminReply;
  final String? atText; // when it was reported

  const ItemIssue({
    required this.note,
    required this.status,
    this.adminReply,
    this.atText,
  });
}

/// A linked deal or lead, already prepared for display.
class LinkedItemData {
  final LinkedItemKind kind;
  final String? id;
  final String title;

  /// Deal stage or lead status.
  final String badge;

  /// Deal: "INR 1,75,000". Lead: company name.
  final String? valueText;

  final String? phone;
  final String? whatsAppNumber; // digits with country code
  final String? email;

  /// e.g. "kishore kishore (Admin)" or "you"; null when not converted.
  final String? convertedByLabel;
  final bool convertedByMe;

  final List<JourneyStep> journey;

  const LinkedItemData({
    required this.kind,
    required this.id,
    required this.title,
    required this.badge,
    required this.valueText,
    required this.phone,
    required this.whatsAppNumber,
    required this.email,
    required this.convertedByLabel,
    required this.convertedByMe,
    required this.journey,
  });
}

class LinkedItemsState {
  final String taskTitle;
  final LinkedTab tab;
  final List<LinkedItemData> deals;
  final List<LinkedItemData> leads;

  /// Index into [currentItems] of the item shown in detail; null = list.
  final int? openIndex;

  final bool reporting;

  /// Issue conversation per linked item id (oldest first).
  final Map<String, List<ItemIssue>> issuesByItem;

  const LinkedItemsState({
    required this.taskTitle,
    required this.tab,
    required this.deals,
    required this.leads,
    this.openIndex,
    this.reporting = false,
    this.issuesByItem = const {},
  });

  List<ItemIssue> issuesFor(LinkedItemData item) =>
      item.id == null ? const [] : issuesByItem[item.id] ?? const [];

  List<LinkedItemData> get currentItems =>
      tab == LinkedTab.deals ? deals : leads;

  LinkedItemData? get openItem {
    final i = openIndex;
    if (i == null || i < 0 || i >= currentItems.length) return null;
    return currentItems[i];
  }

  // openIndex is replaced on every copy (not kept), so pass it
  // explicitly to stay on a detail.
  LinkedItemsState copyWith({
    LinkedTab? tab,
    List<LinkedItemData>? deals,
    List<LinkedItemData>? leads,
    int? openIndex,
    bool? reporting,
    Map<String, List<ItemIssue>>? issuesByItem,
  }) {
    return LinkedItemsState(
      taskTitle: taskTitle,
      tab: tab ?? this.tab,
      deals: deals ?? this.deals,
      leads: leads ?? this.leads,
      openIndex: openIndex,
      reporting: reporting ?? this.reporting,
      issuesByItem: issuesByItem ?? this.issuesByItem,
    );
  }
}
