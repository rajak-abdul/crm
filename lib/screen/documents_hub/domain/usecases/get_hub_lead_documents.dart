// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            get_hub_lead_documents.dart        ║
// ║  USE CASE — load one page of lead files for the Lead tab.     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class GetHubLeadDocuments {
  final DocumentsHubRepository repository;

  const GetHubLeadDocuments(this.repository);

  Future<HubDocumentPage> call({int page = 1, int limit = 10}) {
    if (page < 1 || limit < 1) {
      throw const DocumentsHubFailure('Invalid page request');
    }
    return repository.getLeadDocuments(page: page, limit: limit);
  }
}
