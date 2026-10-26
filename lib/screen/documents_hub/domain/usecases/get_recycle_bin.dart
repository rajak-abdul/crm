// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/domain/usecases/get_recycle_bin.dart ║
// ║  USE CASE — the deleted assignments, soonest purge first.     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/recycled_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class GetRecycleBin {
  final DocumentsHubRepository repository;

  const GetRecycleBin(this.repository);

  Future<List<RecycledDocument>> call() async {
    final documents = await repository.getRecycleBin();
    final now = DateTime.now();

    return [
      for (final d in documents)
        // Without deletedAt there's no expiry to show — treat it as just
        // deleted.
        RecycledDocument(document: d, deletedAt: d.deletedAt ?? now),
    ]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }
}
