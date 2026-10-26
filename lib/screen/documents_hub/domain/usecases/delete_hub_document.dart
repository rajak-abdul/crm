// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            delete_hub_document.dart           ║
// ║  USE CASE — move a hub assignment to the recycle bin.         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class DeleteHubDocument {
  final DocumentsHubRepository repository;

  const DeleteHubDocument(this.repository);

  /// Returns the backend's message ("Assignment moved to recycle bin").
  Future<String> call(HubDocument document) {
    // A raw lead / deal file has no hub assignment to delete.
    if (!document.isHubAssignment) {
      throw const DocumentsHubFailure(
        'Only assigned documents can be deleted',
      );
    }
    return repository.deleteDocument(document.id);
  }
}
