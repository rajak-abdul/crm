// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/get_hub_documents.dart║
// ║  USE CASE — load one page of the user's hub documents. The    ║
// ║  cubit calls this; it never touches the repository directly.  ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class GetHubDocuments {
  final DocumentsHubRepository repository;

  const GetHubDocuments(this.repository);

  /// [sourceType] ('Invoice', 'External' …) narrows to one source; null
  /// loads every source.
  Future<HubDocumentPage> call({
    int page = 1,
    int limit = 10,
    String? sourceType,
  }) {
    if (page < 1 || limit < 1) {
      throw const DocumentsHubFailure('Invalid page request');
    }
    return repository.getDocuments(
      page: page,
      limit: limit,
      sourceType: sourceType,
    );
  }
}
