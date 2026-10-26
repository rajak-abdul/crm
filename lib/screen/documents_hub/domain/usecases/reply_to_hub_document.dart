// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            reply_to_hub_document.dart         ║
// ║  USE CASE — post a reply on a hub document's activity trail.  ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class ReplyToHubDocument {
  final DocumentsHubRepository repository;

  const ReplyToHubDocument(this.repository);

  /// Sends the trimmed [text]; blank text is rejected before any call.
  Future<void> call(HubDocument document, String text) {
    // Lead / deal files have no hub activity trail to post to.
    if (!document.isHubAssignment) {
      throw const DocumentsHubFailure(
        'Replies are only available on assigned documents',
      );
    }
    final clean = text.trim();
    if (clean.isEmpty) {
      throw const DocumentsHubFailure('Reply cannot be empty');
    }
    return repository.addReply(documentId: document.id, text: clean);
  }
}
