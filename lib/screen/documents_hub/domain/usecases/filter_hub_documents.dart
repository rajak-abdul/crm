// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            filter_hub_documents.dart          ║
// ║  USE CASE — narrow loaded documents by tab (source) and the   ║
// ║  search text. Pure: no I/O, so the cubit can call it on every ║
// ║  keystroke.                                                   ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';

/// Tabs on the hub. [assigned] = every document assigned to the user.
enum HubSourceFilter {
  assigned,
  lead,
  deal,
  invoice,
  external;

  /// Backend `sourceType` for this tab; null on Assigned (all sources).
  String? get sourceType => switch (this) {
        HubSourceFilter.assigned => null,
        HubSourceFilter.lead => 'Lead',
        HubSourceFilter.deal => 'Deal',
        HubSourceFilter.invoice => 'Invoice',
        HubSourceFilter.external => 'External',
      };

  /// Lead / Deal list one card per record; the others list files.
  bool get isGrouped =>
      this == HubSourceFilter.lead || this == HubSourceFilter.deal;
}

class FilterHubDocuments {
  const FilterHubDocuments();

  List<HubDocument> call(
    List<HubDocument> documents, {
    HubSourceFilter source = HubSourceFilter.assigned,
    String query = '',
  }) {
    final q = query.trim().toLowerCase();

    return [
      for (final d in documents)
        if (matchesSource(d, source) &&
            (q.isEmpty ||
                d.name.toLowerCase().contains(q) ||
                d.sourceName.toLowerCase().contains(q)))
          d,
    ];
  }

  /// Number of [documents] on the [source] tab (search ignored).
  int count(List<HubDocument> documents, HubSourceFilter source) =>
      documents.where((d) => matchesSource(d, source)).length;

  static bool matchesSource(HubDocument d, HubSourceFilter source) {
    final type = source.sourceType;
    return type == null || d.sourceType.toLowerCase() == type.toLowerCase();
  }
}
