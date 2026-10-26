// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            group_lead_documents.dart          ║
// ║  USE CASE — turn the flat lead (or deal) files into one group ║
// ║  per record, give each file its hub state and order the       ║
// ║  groups by stage.                                             ║
// ║  Pure: no I/O, safe to run on every keystroke.                ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/entities/hub_lead_group.dart';

class GroupLeadDocuments {
  const GroupLeadDocuments();

  /// [leadFiles] — files from GET /leads/getAllLead (or /deals/getAll),
  /// in API order.
  /// [assigned] — hub assignments loaded so far; a lead file with a
  /// matching assignment takes that assignment's status (and is swapped
  /// for it, so the sheet gets its activity trail).
  /// [query] matches the lead name or any of its file names.
  List<HubLeadGroup> call(
    List<HubDocument> leadFiles, {
    List<HubDocument> assigned = const [],
    String query = '',
  }) {
    final q = query.trim().toLowerCase();

    // Keep first-seen lead order from the API.
    final order = <String>[];
    final byLead = <String, List<HubDocument>>{};
    for (final f in leadFiles) {
      if (!byLead.containsKey(f.sourceId)) order.add(f.sourceId);
      (byLead[f.sourceId] ??= []).add(f);
    }

    final groups = <HubLeadGroup>[];
    for (final leadId in order) {
      final files = byLead[leadId]!;
      final first = files.first;

      final matches = q.isEmpty ||
          first.sourceName.toLowerCase().contains(q) ||
          files.any((f) => f.name.toLowerCase().contains(q));
      if (!matches) continue;

      groups.add(
        HubLeadGroup(
          leadId: leadId,
          leadName: first.sourceName,
          sourceType: first.sourceType,
          assignee: first.assignedTo,
          files: [for (final f in files) _withState(f, assigned)],
        ),
      );
    }

    // Stable sort: needs action → in progress → done, API order within.
    final indexed = groups.indexed.toList()
      ..sort((a, b) {
        final byStage = a.$2.stage.index.compareTo(b.$2.stage.index);
        return byStage != 0 ? byStage : a.$1.compareTo(b.$1);
      });
    return [for (final (_, g) in indexed) g];
  }

  HubLeadFile _withState(HubDocument file, List<HubDocument> assigned) {
    // The file's _id is unique on its own; a path match also needs the
    // same lead / deal, since one upload can be copied to several.
    final hub = assigned
            .where((a) => a.documentId.isNotEmpty && a.documentId == file.id)
            .firstOrNull ??
        assigned
            .where(
              (a) =>
                  a.sourceType.toLowerCase() ==
                      file.sourceType.toLowerCase() &&
                  a.sourceId == file.sourceId &&
                  _cleanPath(a.path) == _cleanPath(file.path),
            )
            .firstOrNull;

    if (hub == null) {
      return HubLeadFile(document: file, state: HubFileState.notAssigned);
    }
    return HubLeadFile(document: hub, state: _stateOf(hub.status));
  }

  /// Records store paths both as "/uploads/…" and "uploads/…".
  static String _cleanPath(String path) =>
      path.startsWith('/') ? path.substring(1) : path;

  static HubFileState _stateOf(String status) {
    switch (status.toLowerCase()) {
      case 'replied':
        return HubFileState.replied;
      case 'viewed':
        return HubFileState.viewed;
      default: // Assigned
        return HubFileState.pending;
    }
  }
}
