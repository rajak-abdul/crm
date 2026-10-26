// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            get_hub_lead_assignments.dart      ║
// ║  USE CASE — every hub assignment made from a lead (or deal)   ║
// ║  file (GET /document-hub/documents?sourceType=, all pages).   ║
// ║  The Lead / Deal tab reads each file's Pending / Viewed /     ║
// ║  Replied state from these; a file with none is "Not assigned".║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class GetHubLeadAssignments {
  final DocumentsHubRepository repository;

  const GetHubLeadAssignments(this.repository);

  static const _pageSize = 10;

  /// Safety stop in case the backend's paging never ends.
  static const _maxPages = 50;

  /// Walks the pages until the backend's totalPages; a pill must not
  /// read "Not assigned" just because its assignment is on page 3.
  /// [sourceType] is 'Lead' or 'Deal'.
  Future<List<HubDocument>> call({String sourceType = 'Lead'}) async {
    final all = <HubDocument>[];
    var page = 1;

    while (true) {
      final result = await repository.getDocuments(
        page: page,
        limit: _pageSize,
        sourceType: sourceType,
      );
      all.addAll(result.documents);

      if (!result.hasMore || result.documents.isEmpty || page >= _maxPages) {
        return all;
      }
      page++;
    }
  }
}
