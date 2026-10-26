// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            download_hub_document.dart         ║
// ║  USE CASE — save a hub document's file to the device.         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class DownloadHubDocument {
  final DocumentsHubRepository repository;

  const DownloadHubDocument(this.repository);

  /// Returns the saved file's path. [forPreview] keeps it in the app's
  /// temp folder (openable path) instead of Downloads.
  Future<String> call(HubDocument document, {bool forPreview = false}) {
    if (document.path.trim().isEmpty) {
      throw const DocumentsHubFailure('This document has no file');
    }
    return repository.downloadDocument(document, forPreview: forPreview);
  }
}
