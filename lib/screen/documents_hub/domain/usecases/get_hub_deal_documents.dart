// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            get_hub_deal_documents.dart        ║
// ║  USE CASE — load one page of deal files for the Deal tab.     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class GetHubDealDocuments {
  final DocumentsHubRepository repository;

  const GetHubDealDocuments(this.repository);

  Future<HubDocumentPage> call({int page = 1, int limit = 10}) {
    if (page < 1 || limit < 1) {
      throw const DocumentsHubFailure('Invalid page request');
    }
    return repository.getDealDocuments(page: page, limit: limit);
  }
}
