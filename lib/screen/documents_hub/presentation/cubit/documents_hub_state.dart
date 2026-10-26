// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/cubit/                  ║
// ║                            documents_hub_state.dart           ║
// ║  STATES — what the Documents Hub screen can be showing.       ║
// ╚══════════════════════════════════════════════════════════════╝

part of 'documents_hub_cubit.dart';

sealed class DocumentsHubState extends Equatable {
  const DocumentsHubState();

  @override
  List<Object?> get props => [];
}

final class DocumentsHubInitial extends DocumentsHubState {
  const DocumentsHubInitial();
}

final class DocumentsHubLoading extends DocumentsHubState {
  const DocumentsHubLoading();
}

final class DocumentsHubLoaded extends DocumentsHubState {
  /// Every page loaded so far, in backend order.
  final List<HubDocument> documents;

  /// [documents] narrowed by [source] and [query] — what the list shows.
  final List<HubDocument> visible;

  final HubSourceFilter source;
  final String query;

  /// Documents per tab. Assigned uses the backend total; Lead / Deal
  /// count the loaded pages (the API has no per-source totals yet).
  final Map<HubSourceFilter, int> counts;

  /// Assigned feed paging — [documents] is page [page] of [totalPages].
  final int page;
  final int totalPages;
  final int total;
  final int pageSize;

  /// True while another page is being fetched (list stays visible).
  final bool isPaging;

  /// Logged-in user's id ('' when unknown).
  final String currentUserId;

  /// Lead tab — its own API and paging, fetched on first open.
  final HubFeed leads;

  /// [leads] grouped per lead, searched and ordered by stage — what the
  /// Lead tab shows.
  final List<HubLeadGroup> leadGroups;

  /// Every lead-file assignment (GET ...?sourceType=Lead, all pages).
  final List<HubDocument> leadAssignments;

  /// Deal tab — GET /deals/getAll?hasAttachments=true, fetched on first
  /// open.
  final HubFeed deals;

  /// [deals] grouped per deal, like [leadGroups].
  final List<HubLeadGroup> dealGroups;

  /// Every deal-file assignment (GET ...?sourceType=Deal, all pages).
  final List<HubDocument> dealAssignments;

  /// Invoice tab — GET /document-hub/documents?sourceType=Invoice,
  /// fetched on first open.
  final HubFeed invoices;

  /// External tab — GET /document-hub/documents?sourceType=External,
  /// fetched on first open.
  final HubFeed externals;

  /// Items in the recycle bin — the badge on the header's trash icon.
  final int recycleBinCount;

  const DocumentsHubLoaded({
    required this.documents,
    required this.visible,
    required this.source,
    required this.query,
    required this.counts,
    required this.page,
    required this.totalPages,
    required this.total,
    this.pageSize = DocumentsHubCubit.defaultPageSize,
    this.isPaging = false,
    this.currentUserId = '',
    this.leads = const HubFeed(),
    this.leadGroups = const [],
    this.leadAssignments = const [],
    this.deals = const HubFeed(),
    this.dealGroups = const [],
    this.dealAssignments = const [],
    this.invoices = const HubFeed(),
    this.externals = const HubFeed(),
    this.recycleBinCount = 0,
  });

  /// Latest copy of the document with [id] from any loaded list — the
  /// sheet uses it so a reply shows up wherever the document came from.
  HubDocument? findDocument(String id) =>
      documents.where((d) => d.id == id).firstOrNull ??
      leadAssignments.where((d) => d.id == id).firstOrNull ??
      dealAssignments.where((d) => d.id == id).firstOrNull ??
      invoices.documents.where((d) => d.id == id).firstOrNull ??
      externals.documents.where((d) => d.id == id).firstOrNull;

  bool get onLeadTab => source == HubSourceFilter.lead;
  bool get onDealTab => source == HubSourceFilter.deal;

  /// The source tab's own feed; null on Assigned.
  HubFeed? get sourceFeed => switch (source) {
        HubSourceFilter.lead => leads,
        HubSourceFilter.deal => deals,
        HubSourceFilter.invoice => invoices,
        HubSourceFilter.external => externals,
        HubSourceFilter.assigned => null,
      };

  /// Groups the Lead / Deal tab shows (empty on the file-list tabs).
  List<HubLeadGroup> get sourceGroups => switch (source) {
        HubSourceFilter.lead => leadGroups,
        HubSourceFilter.deal => dealGroups,
        _ => const [],
      };

  // ── Pager for whichever tab is showing ──────────────────────────

  int get currentPage => sourceFeed?.page ?? page;

  int get currentPageSize => sourceFeed?.limit ?? pageSize;

  bool get isPagingCurrent => sourceFeed?.isPaging ?? isPaging;

  /// Records behind the pager (leads / deals on the grouped tabs). The
  /// deals list sends no total, so there it's what's known so far — plus
  /// one while another page may follow, so "next" stays enabled.
  int get currentTotalItems {
    final feed = sourceFeed;
    if (feed == null) return total;
    final known = counts[source] ?? 0;
    if (feed.total > 0 || !feed.hasMore) return known;
    return max(known, feed.page * feed.limit + 1);
  }

  /// Hidden until the tab's first page is in, and when it has nothing.
  bool get showsPager =>
      (sourceFeed?.loaded ?? true) && currentTotalItems > 0;

  /// Whose activity counts as "mine" on [document] — the logged-in
  /// user, or the assignee when no user id was saved.
  String myIdFor(HubDocument document) => currentUserId.isNotEmpty
      ? currentUserId
      : document.assignedTo?.id ?? '';

  DocumentsHubLoaded copyWith({
    List<HubDocument>? documents,
    List<HubDocument>? visible,
    HubSourceFilter? source,
    String? query,
    Map<HubSourceFilter, int>? counts,
    int? page,
    int? totalPages,
    int? total,
    int? pageSize,
    bool? isPaging,
    HubFeed? leads,
    HubFeed? deals,
  }) {
    return DocumentsHubLoaded(
      documents: documents ?? this.documents,
      visible: visible ?? this.visible,
      source: source ?? this.source,
      query: query ?? this.query,
      counts: counts ?? this.counts,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      pageSize: pageSize ?? this.pageSize,
      isPaging: isPaging ?? this.isPaging,
      currentUserId: currentUserId,
      leads: leads ?? this.leads,
      leadGroups: leadGroups,
      leadAssignments: leadAssignments,
      deals: deals ?? this.deals,
      dealGroups: dealGroups,
      dealAssignments: dealAssignments,
      invoices: invoices,
      externals: externals,
      recycleBinCount: recycleBinCount,
    );
  }

  @override
  List<Object?> get props => [
        documents,
        visible,
        source,
        query,
        counts,
        page,
        totalPages,
        total,
        pageSize,
        isPaging,
        currentUserId,
        leads,
        leadGroups,
        leadAssignments,
        deals,
        dealGroups,
        dealAssignments,
        invoices,
        externals,
        recycleBinCount,
      ];
}

/// One tab's independently paged list (Lead / Deal / Invoice /
/// External). Loading and errors stay inside the tab, so the rest of the
/// hub keeps working.
class HubFeed extends Equatable {
  /// Files of page [page] only.
  final List<HubDocument> documents;
  final int page;
  final int totalPages;

  /// Backend total of records (leads / deals, not files); 0 when the
  /// backend sends none (the deals list).
  final int total;

  /// Records per page — the tab's own page size.
  final int limit;

  /// False until the first page has come back.
  final bool loaded;
  final bool isLoading;

  /// True while another page is being fetched (list stays visible).
  final bool isPaging;

  /// First-page failure, shown in place of the list.
  final String? error;

  const HubFeed({
    this.documents = const [],
    this.page = 0,
    this.totalPages = 0,
    this.total = 0,
    this.limit = DocumentsHubCubit.defaultPageSize,
    this.loaded = false,
    this.isLoading = false,
    this.isPaging = false,
    this.error,
  });

  bool get hasMore => page < totalPages;

  HubFeed copyWith({
    List<HubDocument>? documents,
    int? page,
    int? totalPages,
    int? total,
    int? limit,
    bool? loaded,
    bool? isLoading,
    bool? isPaging,
    String? Function()? error,
  }) {
    return HubFeed(
      documents: documents ?? this.documents,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      limit: limit ?? this.limit,
      loaded: loaded ?? this.loaded,
      isLoading: isLoading ?? this.isLoading,
      isPaging: isPaging ?? this.isPaging,
      error: error != null ? error() : this.error,
    );
  }

  @override
  List<Object?> get props => [
        documents,
        page,
        totalPages,
        total,
        limit,
        loaded,
        isLoading,
        isPaging,
        error,
      ];
}

final class DocumentsHubError extends DocumentsHubState {
  final String message;

  const DocumentsHubError(this.message);

  @override
  List<Object?> get props => [message];
}
