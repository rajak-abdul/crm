// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/                     ║
// ║                            get_hub_current_user_id.dart       ║
// ║  USE CASE — who is logged in, so the sheet can put the user's ║
// ║  own replies on the right.                                    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class GetHubCurrentUserId {
  final DocumentsHubRepository repository;

  const GetHubCurrentUserId(this.repository);

  /// '' when no user id is saved.
  Future<String> call() => repository.currentUserId();
}
