// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/view/                   ║
// ║                            documents_hub_screen.dart          ║
// ║  VIEW — header, search, Assigned/Lead/Deal tabs and document  ║
// ║  cards. Reads DocumentsHubState; actions go to the cubit.     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/documents_hub_injection.dart';
import 'package:crm_app/screen/documents_hub/presentation/cubit/documents_hub_cubit.dart';
import 'package:crm_app/screen/documents_hub/presentation/view/hub_lead_detail_screen.dart';
import 'package:crm_app/screen/documents_hub/presentation/view/recycle_bin_screen.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_document_card.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_document_sheet.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_lead_card.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_search_field.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_source_tabs.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_styles.dart';
import 'package:crm_app/shareWidgets/pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DocumentsHubScreen extends StatelessWidget {
  const DocumentsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => buildDocumentsHubCubit()..load(),
      child: const _DocumentsHubView(),
    );
  }
}

class _DocumentsHubView extends StatefulWidget {
  const _DocumentsHubView();

  @override
  State<_DocumentsHubView> createState() => _DocumentsHubViewState();
}

class _DocumentsHubViewState extends State<_DocumentsHubView> {
  static const _hPad = EdgeInsets.symmetric(horizontal: 18);

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Runs a cubit call that answers with an error, showing it in a
  /// snackbar.
  Future<void> _run(Future<String?> action) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await action;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// Page / page-size change: the new page starts at the top.
  Future<void> _changePage(Future<String?> action) async {
    await _run(action);
    if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DocumentsHubCubit>();

    return Scaffold(
      backgroundColor: HubPalette.background,
      body: SafeArea(
        child: BlocBuilder<DocumentsHubCubit, DocumentsHubState>(
          builder: (context, state) {
            final loaded = state is DocumentsHubLoaded ? state : null;

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: HubPalette.accent,
                    onRefresh: () => _run(cubit.refresh()),
                    child: ListView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 12, bottom: 28),
                      children: [
                        const Padding(padding: _hPad, child: _Header()),
                        const SizedBox(height: 18),
                        Padding(
                          padding: _hPad,
                          child: HubSearchField(
                            onChanged: cubit.search,
                            hint: switch (loaded?.source) {
                              HubSourceFilter.lead => 'Search leads',
                              HubSourceFilter.deal => 'Search deals',
                              HubSourceFilter.invoice => 'Search invoices',
                              HubSourceFilter.external =>
                                'Search external documents',
                              _ => 'Search documents',
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: _hPad,
                          child: HubSourceTabs(
                            selected:
                                loaded?.source ?? HubSourceFilter.assigned,
                            counts: loaded?.counts ?? const {},
                            onChanged: cubit.selectSource,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ..._body(context, state),
                      ],
                    ),
                  ),
                ),
                if (loaded != null && loaded.showsPager) ...[
                  SizedBox(
                    height: 2,
                    child: loaded.isPagingCurrent
                        ? const LinearProgressIndicator(
                            color: HubPalette.accent,
                            backgroundColor: Colors.transparent,
                          )
                        : null,
                  ),
                  PaginationWidget(
                    currentPage: loaded.currentPage,
                    totalItems: loaded.currentTotalItems,
                    pageSize: loaded.currentPageSize,
                    pageSizeOptions: DocumentsHubCubit.pageSizeOptions,
                    onPageChanged: (page) =>
                        _changePage(cubit.goToPage(page)),
                    onPageSizeChanged: (size) =>
                        _changePage(cubit.setPageSize(size)),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, DocumentsHubState state) {
    switch (state) {
      case DocumentsHubInitial():
      case DocumentsHubLoading():
        return const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: CircularProgressIndicator(color: HubPalette.accent),
            ),
          ),
        ];

      case DocumentsHubError(:final message):
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 60, 18, 0),
            child: _Message(
              icon: Icons.error_outline_rounded,
              text: message,
              actionLabel: 'Retry',
              onAction: context.read<DocumentsHubCubit>().load,
            ),
          ),
        ];

      case DocumentsHubLoaded() when state.sourceFeed != null:
        return _sourceBody(context, state);

      case DocumentsHubLoaded():
        return _documentList(context, state, emptyText: 'No documents yet');
    }
  }

  /// Assigned / Invoice / External: one card per document.
  List<Widget> _documentList(
    BuildContext context,
    DocumentsHubLoaded state, {
    required String emptyText,
  }) {
    final docs = state.visible;
    return [
      Padding(
        padding: _hPad,
        child: _ListHeader(count: docs.length),
      ),
      const SizedBox(height: 12),
      if (docs.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 48, 18, 0),
          child: _Message(
            icon: Icons.folder_open_outlined,
            text: state.query.trim().isEmpty
                ? emptyText
                : 'No documents match "${state.query.trim()}"',
          ),
        ),
      for (final (i, doc) in docs.indexed)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: HubDocumentCard(
            document: doc,
            onTap: () => showHubDocumentSheet(
              context,
              documents: docs,
              initialIndex: i,
            ),
          ),
        ),
    ];
  }

  /// A source tab with its own feed. Lead / Deal: one card per lead
  /// (deal), needs-action ones first. Invoice / External: one card per
  /// document.
  List<Widget> _sourceBody(BuildContext context, DocumentsHubLoaded state) {
    final feed = state.sourceFeed!;
    final grouped = state.source.isGrouped;
    final groups = state.sourceGroups;
    final cubit = context.read<DocumentsHubCubit>();
    final noun = switch (state.source) {
      HubSourceFilter.deal => 'deal',
      HubSourceFilter.invoice => 'invoice',
      HubSourceFilter.external => 'external',
      _ => 'lead',
    };
    final empty = grouped ? groups.isEmpty : feed.documents.isEmpty;

    if (empty && (feed.isLoading || !feed.loaded)) {
      if (feed.error == null) {
        return const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: CircularProgressIndicator(color: HubPalette.accent),
            ),
          ),
        ];
      }
    }

    if (empty && feed.error != null) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 60, 18, 0),
          child: _Message(
            icon: Icons.error_outline_rounded,
            text: feed.error!,
            actionLabel: 'Retry',
            // Reloads the tab that's showing.
            onAction: cubit.refresh,
          ),
        ),
      ];
    }

    if (!grouped) {
      return _documentList(
        context,
        state,
        emptyText: 'No $noun documents yet',
      );
    }

    if (groups.isEmpty) {
      final q = state.query.trim();
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 48, 18, 0),
          child: _Message(
            icon: state.onDealTab
                ? Icons.work_outline_rounded
                : Icons.person_search_outlined,
            text: q.isEmpty
                ? 'No $noun documents yet'
                : 'No ${noun}s match "$q"',
          ),
        ),
      ];
    }

    return [
      for (final group in groups)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: HubLeadCard(
            group: group,
            onTap: () => showHubLeadDetail(context, group: group),
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canPop)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: HubPalette.ink,
              visualDensity: VisualDensity.compact,
            ),
          ),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Document Hub',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: HubPalette.ink,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Linked and external documents',
                style: TextStyle(fontSize: 13, color: HubPalette.muted),
              ),
            ],
          ),
        ),
        BlocSelector<DocumentsHubCubit, DocumentsHubState, int>(
          selector: (state) =>
              state is DocumentsHubLoaded ? state.recycleBinCount : 0,
          builder: (context, binCount) => Badge(
            isLabelVisible: binCount > 0,
            label: Text(binCount > 99 ? '99+' : '$binCount'),
            offset: const Offset(2, -2),
            child: IconButton(
              onPressed: () async {
                final cubit = context.read<DocumentsHubCubit>();
                final restored = await showRecycleBin(context);
                if (!context.mounted) return;
                // A restored document is back in the hub's lists (the
                // reload re-reads the bin count too); otherwise just the
                // count, in case the bin changed.
                restored ? cubit.reloadAll() : cubit.refreshRecycleBinCount();
              },
              tooltip: 'Recycle bin',
              icon: const Icon(Icons.delete_outline_rounded),
              color: HubPalette.ink,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: HubPalette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  final int count;

  const _ListHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$count ',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: HubPalette.ink,
                ),
              ),
              TextSpan(text: count == 1 ? 'document' : 'documents'),
            ],
          ),
          style: const TextStyle(fontSize: 13, color: HubPalette.muted),
        ),
        const Spacer(),
        // Backend returns most recently updated first.
        const Icon(Icons.swap_vert_rounded, size: 16, color: HubPalette.ink),
        const SizedBox(width: 4),
        const Text(
          'Recently updated',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HubPalette.ink,
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 40, color: HubPalette.hint),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: HubPalette.muted),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}
