// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/repositories/                 ║
// ║                         documents_hub_repository.dart         ║
// ║  CONTRACT — what the domain needs from the data layer. Use    ║
// ║  cases depend on this abstract class, never on the impl.      ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';

/// The only error type that leaves the data layer. Presentation shows
/// [message]; it never sees a DioException.
class DocumentsHubFailure implements Exception {
  final String message;
  final int? statusCode;

  const DocumentsHubFailure(this.message, {this.statusCode});

  @override
  String toString() => message;
}

abstract class DocumentsHubRepository {
  /// One page of documents assigned to the logged-in user, optionally
  /// only those from [sourceType] ('Lead' / 'Deal').
  /// Throws [DocumentsHubFailure].
  Future<HubDocumentPage> getDocuments({
    required int page,
    required int limit,
    String? sourceType,
  });

  /// One page of leads that have files, flattened to one document per
  /// attachment / image. Paging counts leads. Throws [DocumentsHubFailure].
  Future<HubDocumentPage> getLeadDocuments({
    required int page,
    required int limit,
  });

  /// One page of deals that have files, flattened the same way as
  /// [getLeadDocuments]. Paging counts deals. Throws [DocumentsHubFailure].
  Future<HubDocumentPage> getDealDocuments({
    required int page,
    required int limit,
  });

  /// Logged-in user's id ('' when unknown) — tells "my" replies apart.
  Future<String> currentUserId();

  /// Posts [text] to the document's Activity & Replies trail.
  /// Throws [DocumentsHubFailure].
  Future<void> addReply({
    required String documentId,
    required String text,
  });

  /// Moves the hub assignment [documentId] to the recycle bin and returns
  /// the backend's message. Throws [DocumentsHubFailure].
  Future<String> deleteDocument(String documentId);

  /// Brings the assignment [documentId] back from the recycle bin and
  /// returns the backend's message. Throws [DocumentsHubFailure].
  Future<String> restoreDocument(String documentId);

  /// Every deleted assignment still in the recycle bin.
  /// Throws [DocumentsHubFailure].
  Future<List<HubDocument>> getRecycleBin();

  /// Saves [document]'s file to the device's Downloads and returns the
  /// saved path. [forPreview] saves it to the app's temp folder instead,
  /// so the path can be opened in a viewer. Throws [DocumentsHubFailure].
  Future<String> downloadDocument(
    HubDocument document, {
    bool forPreview = false,
  });
}
