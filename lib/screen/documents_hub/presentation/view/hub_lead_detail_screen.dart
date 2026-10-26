// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/view/                   ║
// ║                            hub_lead_detail_screen.dart        ║
// ║  LEAD DETAIL — opened from a Lead / Deal card: the record's   ║
// ║  name, a document count, then its files as document cards. A  ║
// ║  file opens the document sheet.                               ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/presentation/cubit/documents_hub_cubit.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_document_card.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_document_sheet.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pushes the detail page, sharing the hub's cubit so replies made from
/// here update the Lead tab too.
Future<void> showHubLeadDetail(
  BuildContext context, {
  required HubLeadGroup group,
}) {
  final cubit = context.read<DocumentsHubCubit>();

  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: HubLeadDetailScreen(group: group),
      ),
    ),
  );
}

class HubLeadDetailScreen extends StatelessWidget {
  /// Snapshot from the tapped card; the live copy is read from the cubit.
  final HubLeadGroup group;

  const HubLeadDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    // Live group, so a reply in the sheet updates pills and stage here.
    // Falls back to the snapshot (e.g. the search now hides this lead).
    final live = context.select<DocumentsHubCubit, HubLeadGroup>((c) {
      final state = c.state;
      if (state is! DocumentsHubLoaded) return group;
      final groups = group.isDeal ? state.dealGroups : state.leadGroups;
      return groups.where((g) => g.leadId == group.leadId).firstOrNull ??
          group;
    });
    final docs = live.documents;

    return Scaffold(
      backgroundColor: HubPalette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            _Header(group: live),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${docs.length} ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: HubPalette.ink,
                    ),
                  ),
                  TextSpan(text: docs.length == 1 ? 'document' : 'documents'),
                ],
              ),
              style: const TextStyle(fontSize: 13, color: HubPalette.muted),
            ),
            const SizedBox(height: 12),
            for (final (i, doc) in docs.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HubDocumentCard(
                  document: doc,
                  onTap: () => showHubDocumentSheet(
                    context,
                    documents: docs,
                    initialIndex: i,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final HubLeadGroup group;

  const _Header({required this.group});

  @override
  Widget build(BuildContext context) {
    final name = group.leadName.trim();

    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: HubPalette.ink,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name.isEmpty
                ? (group.isDeal ? 'Unnamed deal' : 'Unnamed lead')
                : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: HubPalette.ink,
            ),
          ),
        ),
      ],
    );
  }
}
