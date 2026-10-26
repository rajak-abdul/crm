// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/cubit/                  ║
// ║                            documents_hub_cubit.dart           ║
// ║  CUBIT — screen logic. Talks only to use cases; knows nothing ║
// ║  about Dio, JSON or where the documents come from.            ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'dart:math';

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/entities/hub_lead_group.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/delete_hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/download_hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/filter_hub_documents.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_current_user_id.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_deal_documents.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_documents.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_lead_assignments.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_lead_documents.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_recycle_bin.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/group_lead_documents.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/reply_to_hub_document.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:crm_app/screen/documents_hub/domain/entities/hub_lead_group.dart';
export 'package:crm_app/screen/documents_hub/domain/usecases/filter_hub_documents.dart'
    show HubSourceFilter;

part 'documents_hub_state.dart';

class DocumentsHubCubit extends Cubit<DocumentsHubState> {
  final GetHubDocuments getHubDocuments;
  final GetHubLeadDocuments getHubLeadDocuments;
  final GetHubDealDocuments getHubDealDocuments;
  final GetHubLeadAssignments getHubLeadAssignments;
  final DownloadHubDocument downloadHubDocument;
  final FilterHubDocuments filterHubDocuments;
  final GroupLeadDocuments groupLeadDocuments;
  final ReplyToHubDocument replyToHubDocument;
  final DeleteHubDocument deleteHubDocument;
  final GetHubCurrentUserId getHubCurrentUserId;
  final GetRecycleBin getRecycleBin;

  static const defaultPageSize = 10;
  static const pageSizeOptions = [10, 25, 50];

  /// Assigned tab's page size (each source feed keeps its own `limit`).
  int _assignedPageSize = defaultPageSize;

  /// Items in the recycle bin (header badge). Lives outside the state so
  /// it survives a reload; 0 until the first count comes back.
  int _recycleBinCount = 0;

  // Tab and search survive a reload / error.
  HubSourceFilter _source = HubSourceFilter.assigned;
  String _query = '';

  /// Logged-in user — their replies sit on the right in the sheet.
  String _currentUserId = '';

  /// Lead / Deal / Invoice / External tab feeds; live outside the state
  /// so an Assigned reload doesn't throw them away.
  final _feeds = <HubSourceFilter, HubFeed>{
    HubSourceFilter.lead: const HubFeed(),
    HubSourceFilter.deal: const HubFeed(),
    HubSourceFilter.invoice: const HubFeed(),
    HubSourceFilter.external: const HubFeed(),
  };

  /// Every hub assignment of a lead / deal file (sourceType=Lead|Deal,
  /// all pages) — where the Pending / Viewed / Replied pills come from.
  final _assignments = <HubSourceFilter, List<HubDocument>>{
    HubSourceFilter.lead: const [],
    HubSourceFilter.deal: const [],
  };

  DocumentsHubCubit({
    required this.getHubDocuments,
    required this.getHubLeadDocuments,
    required this.getHubDealDocuments,
    required this.getHubLeadAssignments,
    required this.downloadHubDocument,
    required this.replyToHubDocument,
    required this.deleteHubDocument,
    required this.getHubCurrentUserId,
    required this.getRecycleBin,
    this.filterHubDocuments = const FilterHubDocuments(),
    this.groupLeadDocuments = const GroupLeadDocuments(),
  }) : super(const DocumentsHubInitial());

  /// First page of assigned documents; replaces whatever is loaded.
  Future<void> load() async {
    emit(const DocumentsHubLoading());

    // Alongside the list; never fails or delays it.
    unawaited(refreshRecycleBinCount());

    try {
      _currentUserId = await getHubCurrentUserId();
      final result =
          await getHubDocuments(page: 1, limit: _assignedPageSize);

      emit(
        _loaded(
          documents: result.documents,
          page: result.page,
          totalPages: result.totalPages,
          total: result.total,
        ),
      );
    } catch (e) {
      emit(DocumentsHubError(e.toString()));
    }
  }

  /// Reloads the page showing on Assigned and on every source tab opened
  /// so far (e.g. after a restore from the recycle bin) without blanking
  /// the screen. On failure the current lists stay; pull-to-refresh can
  /// retry.
  Future<void> reloadAll() async {
    final current = state;
    if (current is! DocumentsHubLoaded) return load();

    await Future.wait<void>([
      refreshRecycleBinCount(),
      for (final source in _feeds.keys)
        if (_feeds[source]!.loaded)
          _loadSourceTab(source, page: _feeds[source]!.page),
      _loadAssignedPage(current.page),
    ]);
  }

  /// Re-reads how many items are in the recycle bin (GET
  /// /document-hub/recycle-bin — no paging, so it's the list length).
  /// On failure the last count stays.
  Future<void> refreshRecycleBinCount() async {
    try {
      final items = await getRecycleBin();
      _recycleBinCount = items.length;
    } catch (_) {
      return;
    }
    if (!isClosed) _refilter();
  }

  /// Pull-to-refresh reloads the page showing on the current tab (Lead /
  /// Deal together with their assignments). Returns the error for a
  /// snackbar when a list is already on screen.
  Future<String?> refresh() async {
    unawaited(refreshRecycleBinCount());

    if (_source != HubSourceFilter.assigned) {
      final feed = _feeds[_source]!;
      return _loadSourceTab(_source, page: feed.loaded ? feed.page : 1);
    }

    final current = state;
    if (current is DocumentsHubLoaded) return _loadAssignedPage(current.page);
    await load();
    return null;
  }

  /// Shows page [page] of whichever tab is showing. On failure the
  /// current page stays and the error is returned for a snackbar.
  Future<String?> goToPage(int page) => _source == HubSourceFilter.assigned
      ? _loadAssignedPage(page)
      : _loadSourceTab(_source, page: page, withAssignments: false);

  /// New page size for the tab that's showing; back to its first page.
  Future<String?> setPageSize(int size) {
    if (_source == HubSourceFilter.assigned) {
      _assignedPageSize = size;
    } else {
      _feeds[_source] = _feeds[_source]!.copyWith(limit: size);
    }
    return goToPage(1);
  }

  // ============================================================
  // SOURCE TABS — Lead / Deal: GET /leads/getAllLead | /deals/getAll
  // (?hasAttachments=true) plus their hub assignments.
  // Invoice / External: GET /document-hub/documents?sourceType=
  // ============================================================

  Future<HubDocumentPage> _fetchPage(HubSourceFilter source, int page) {
    final limit = _feeds[source]!.limit;
    return switch (source) {
      HubSourceFilter.lead => getHubLeadDocuments(page: page, limit: limit),
      HubSourceFilter.deal => getHubDealDocuments(page: page, limit: limit),
      _ => getHubDocuments(
          page: page,
          limit: limit,
          sourceType: source.sourceType,
        ),
    };
  }

  /// Page [page] of [source]'s files; replaces the tab's list. With
  /// [withAssignments] (first load / refresh) Lead / Deal also re-read
  /// every assignment of that source, for the file states — a page change
  /// reuses them. Returns the error for a snackbar when a list is already
  /// on screen; a first load shows it in place of the list.
  Future<String?> _loadSourceTab(
    HubSourceFilter source, {
    int page = 1,
    bool withAssignments = true,
  }) async {
    final feed = _feeds[source]!;
    if (feed.isLoading || feed.isPaging) return null;

    // A first load blanks the tab; later loads keep the list on screen.
    _feeds[source] = feed.loaded
        ? feed.copyWith(isPaging: true)
        : feed.copyWith(isLoading: true, error: () => null);
    _refilter();

    final loadAssignments = source.isGrouped && withAssignments;

    try {
      var (result, assignments) = await (
        _fetchPage(source, page),
        loadAssignments
            ? getHubLeadAssignments(sourceType: source.sourceType!)
            : Future.value(const <HubDocument>[]),
      ).wait;

      // The page emptied (deletes / restores elsewhere) — show the last
      // one instead.
      if (result.documents.isEmpty &&
          page > 1 &&
          result.total > 0 &&
          result.totalPages < page) {
        result = await _fetchPage(source, max(result.totalPages, 1));
      }

      // The deals list has no total, so its last page is a guess: an empty
      // page, or the backend ignoring page= and resending the one we have,
      // means the previous page was the last.
      final known = {for (final d in feed.documents) d.id};
      final pastEnd = feed.loaded &&
          page > feed.page &&
          result.total <= 0 &&
          (result.documents.isEmpty ||
              result.documents.every((d) => known.contains(d.id)));
      if (pastEnd) {
        _feeds[source] = feed.copyWith(totalPages: feed.page);
        _refilter();
        return 'No more pages';
      }

      if (loadAssignments) _assignments[source] = assignments;
      _feeds[source] = HubFeed(
        documents: result.documents,
        page: result.page,
        totalPages: result.totalPages,
        total: result.total,
        limit: feed.limit,
        loaded: true,
      );
      _refilter();
      return null;
    } on ParallelWaitError catch (e) {
      // Without both, the pills would be wrong — fail the tab as a whole.
      final (pageError, assignError) =
          e.errors as (AsyncError?, AsyncError?);
      return _sourceTabFailed(source, pageError?.error ?? assignError?.error ?? e);
    } catch (e) {
      return _sourceTabFailed(source, e);
    }
  }

  String? _sourceTabFailed(HubSourceFilter source, Object cause) {
    final feed = _feeds[source]!;
    _feeds[source] = feed.loaded
        ? feed.copyWith(isLoading: false, isPaging: false)
        : feed.copyWith(isLoading: false, error: () => '$cause');
    _refilter();
    return feed.loaded ? '$cause' : null;
  }

  // ============================================================
  // ASSIGNED TAB — paging
  // ============================================================

  /// Page [page] of the assigned documents; replaces the list. On
  /// failure the current page stays and the error is returned.
  Future<String?> _loadAssignedPage(int page) async {
    final current = state;
    if (current is! DocumentsHubLoaded) {
      await load();
      return null;
    }
    if (current.isPaging) return null;

    emit(current.copyWith(isPaging: true));

    try {
      var result =
          await getHubDocuments(page: page, limit: _assignedPageSize);

      // The page emptied (deletes / restores elsewhere) — show the last
      // one instead.
      if (result.documents.isEmpty &&
          page > 1 &&
          result.total > 0 &&
          result.totalPages < page) {
        result = await getHubDocuments(
          page: max(result.totalPages, 1),
          limit: _assignedPageSize,
        );
      }

      emit(
        _loaded(
          documents: result.documents,
          page: result.page,
          totalPages: result.totalPages,
          total: result.total,
        ),
      );
      return null;
    } catch (e) {
      final latest = state;
      if (latest is DocumentsHubLoaded) emit(latest.copyWith(isPaging: false));
      return e.toString();
    }
  }

  // ============================================================
  // DOCUMENT ACTIONS
  // ============================================================

  /// Saves [document] to Downloads ([forPreview]: to the app's temp
  /// folder, ready to open). Doesn't touch screen state — the sheet
  /// shows its own spinner and a snackbar with the result.
  Future<({String? savedPath, String? error})> download(
    HubDocument document, {
    bool forPreview = false,
  }) async {
    try {
      return (
        savedPath: await downloadHubDocument(document, forPreview: forPreview),
        error: null,
      );
    } catch (e) {
      return (savedPath: null, error: e.toString());
    }
  }

  /// Posts [text] on [document]. The API only answers { success,
  /// message }, so on success the reply is appended locally and the
  /// document marked 'Replied'. Returns the error for a snackbar.
  Future<String?> reply(HubDocument document, String text) async {
    try {
      await replyToHubDocument(document, text);
    } catch (e) {
      return e.toString();
    }

    final current = state;
    if (current is! DocumentsHubLoaded) return null;

    final myId = current.myIdFor(document);
    final myRole = document.activity
        .where((a) => a.performedBy == myId && a.role.isNotEmpty)
        .map((a) => a.role)
        .lastOrNull;

    final now = DateTime.now();
    final reply = DocumentActivity(
      id: 'local-${now.microsecondsSinceEpoch}',
      action: 'Replied',
      performedBy: myId,
      role: myRole ?? 'You',
      note: text.trim(),
      createdAt: now,
    );

    HubDocument withReply(HubDocument d) => d.id == document.id
        ? d.copyWith(status: 'Replied', activity: [...d.activity, reply])
        : d;

    // The document may live in several lists (a lead / deal assignment
    // past the Assigned tab's loaded pages) — update all so the sheet and
    // the group card's pills agree.
    final documents = current.documents.map(withReply).toList();
    for (final source in _assignments.keys) {
      _assignments[source] = _assignments[source]!.map(withReply).toList();
    }
    // Invoice / External feeds hold hub documents directly.
    for (final source in _feeds.keys.where((s) => !s.isGrouped)) {
      final feed = _feeds[source]!;
      _feeds[source] = feed.copyWith(
        documents: feed.documents.map(withReply).toList(),
      );
    }

    emit(
      _loaded(
        documents: documents,
        page: current.page,
        totalPages: current.totalPages,
        total: current.total,
        isPaging: current.isPaging,
      ),
    );
    return null;
  }

  /// Moves [document] to the recycle bin, then drops it from every
  /// loaded list. A lead / deal file it was assigned from goes back to
  /// "Not assigned". A page it left re-reads itself in the background so
  /// the next page's items move up (or steps back when it emptied).
  /// Returns the backend message or the error.
  Future<({String? message, String? error})> delete(
    HubDocument document,
  ) async {
    final String message;
    try {
      message = await deleteHubDocument(document);
    } catch (e) {
      return (message: null, error: e.toString());
    }

    // It's in the bin now — the badge goes up without another call.
    _recycleBinCount++;

    final current = state;
    if (current is! DocumentsHubLoaded) return (message: message, error: null);

    bool keep(HubDocument d) => d.id != document.id;

    final documents = current.documents.where(keep).toList();
    final removed = current.documents.length - documents.length;

    for (final source in _assignments.keys) {
      _assignments[source] = _assignments[source]!.where(keep).toList();
    }
    // Invoice / External feeds hold hub documents directly.
    final refill = <HubSourceFilter, int>{};
    for (final source in _feeds.keys.where((s) => !s.isGrouped)) {
      final feed = _feeds[source]!;
      final left = feed.documents.where(keep).toList();
      final gone = feed.documents.length - left.length;
      if (gone == 0) continue;
      final total = feed.total > 0 ? feed.total - gone : 0;
      final totalPages = _pageCount(total, feed.limit);
      _feeds[source] = feed.copyWith(
        documents: left,
        total: total,
        totalPages: totalPages,
      );
      if (total > 0) refill[source] = min(feed.page, totalPages);
    }

    final total = current.total - removed;
    final totalPages = _pageCount(total, _assignedPageSize);
    emit(
      _loaded(
        documents: documents,
        page: current.page,
        totalPages: totalPages,
        total: total,
        isPaging: current.isPaging,
      ),
    );

    if (removed > 0 && total > 0) {
      unawaited(_loadAssignedPage(min(current.page, totalPages)));
    }
    for (final MapEntry(key: source, value: page) in refill.entries) {
      unawaited(_loadSourceTab(source, page: page, withAssignments: false));
    }
    return (message: message, error: null);
  }

  // ============================================================
  // TABS & SEARCH
  // ============================================================

  /// Switches tab; the Lead / Deal tab fetches its first page on first
  /// open.
  void selectSource(HubSourceFilter source) {
    _source = source;
    _refilter();

    final feed = _feeds[source];
    if (feed != null && !feed.loaded && !feed.isLoading) {
      _loadSourceTab(source);
    }
  }

  void search(String query) {
    _query = query;
    _refilter();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _refilter() {
    final current = state;
    if (current is! DocumentsHubLoaded) return;

    emit(
      _loaded(
        documents: current.documents,
        page: current.page,
        totalPages: current.totalPages,
        total: current.total,
        isPaging: current.isPaging,
      ),
    );
  }

  static int _pageCount(int total, int limit) =>
      max(1, (total / limit).ceil());

  List<HubLeadGroup> _groups(HubSourceFilter source) => groupLeadDocuments(
        _feeds[source]!.documents,
        assigned: _assignments[source]!,
        query: _query,
      );

  /// Count on a source tab: the backend total, or — when none is sent
  /// (the deals list) — the pages before this one plus what's on it:
  /// records on Lead / Deal, files on Invoice / External.
  int _recordCount(HubSourceFilter source) {
    final feed = _feeds[source]!;
    if (feed.total > 0) return feed.total;
    final onPage = source.isGrouped
        ? {for (final d in feed.documents) d.sourceId}.length
        : feed.documents.length;
    return max(feed.page - 1, 0) * feed.limit + onPage;
  }

  DocumentsHubLoaded _loaded({
    required List<HubDocument> documents,
    required int page,
    required int totalPages,
    required int total,
    bool isPaging = false,
  }) {
    // Lead / Deal tabs read their own feed; Assigned reads assigned docs.
    final visible = filterHubDocuments(
      _feeds[_source]?.documents ?? documents,
      source: _source,
      query: _query,
    );

    return DocumentsHubLoaded(
      documents: documents,
      visible: visible,
      source: _source,
      query: _query,
      counts: {
        HubSourceFilter.assigned: total,
        for (final source in _feeds.keys) source: _recordCount(source),
      },
      page: page,
      totalPages: totalPages,
      total: total,
      pageSize: _assignedPageSize,
      isPaging: isPaging,
      currentUserId: _currentUserId,
      leads: _feeds[HubSourceFilter.lead]!,
      leadGroups: _groups(HubSourceFilter.lead),
      leadAssignments: _assignments[HubSourceFilter.lead]!,
      deals: _feeds[HubSourceFilter.deal]!,
      dealGroups: _groups(HubSourceFilter.deal),
      dealAssignments: _assignments[HubSourceFilter.deal]!,
      invoices: _feeds[HubSourceFilter.invoice]!,
      externals: _feeds[HubSourceFilter.external]!,
      recycleBinCount: _recycleBinCount,
    );
  }
}
