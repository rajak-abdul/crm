// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            restore_hub_document.dart          ║
// ║  USE CASE — bring a deleted assignment back from the bin.     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/recycled_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class RestoreHubDocument {
  final DocumentsHubRepository repository;

  const RestoreHubDocument(this.repository);

  /// Returns the backend's message ("Assignment restored successfully").
  Future<String> call(RecycledDocument item) =>
      repository.restoreDocument(item.document.id);
}
