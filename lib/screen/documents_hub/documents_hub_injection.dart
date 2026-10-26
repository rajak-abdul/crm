// ╔══════════════════════════════════════════════════════════════╗
// ║  lib/screen/documents_hub/documents_hub_injection.dart        ║
// ║  COMPOSITION ROOT — the only file that knows every layer.     ║
// ║  Wires data source → repository impl → use case → cubit.      ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/data/datasources/documents_hub_remote_data_source.dart';
import 'package:crm_app/screen/documents_hub/data/repositories/documents_hub_repository_impl.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/delete_hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/download_hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_current_user_id.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_deal_documents.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_documents.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_lead_assignments.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_hub_lead_documents.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/get_recycle_bin.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/reply_to_hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/usecases/restore_hub_document.dart';
import 'package:crm_app/screen/documents_hub/presentation/cubit/documents_hub_cubit.dart';
import 'package:crm_app/screen/documents_hub/presentation/cubit/recycle_bin_cubit.dart';
import 'package:dio/dio.dart';

DocumentsHubRepositoryImpl _repository() => DocumentsHubRepositoryImpl(
      DocumentsHubRemoteDataSource(Dio()),
    );

DocumentsHubCubit buildDocumentsHubCubit() {
  final repository = _repository();

  return DocumentsHubCubit(
    getHubDocuments: GetHubDocuments(repository),
    getHubLeadDocuments: GetHubLeadDocuments(repository),
    getHubDealDocuments: GetHubDealDocuments(repository),
    getHubLeadAssignments: GetHubLeadAssignments(repository),
    downloadHubDocument: DownloadHubDocument(repository),
    replyToHubDocument: ReplyToHubDocument(repository),
    deleteHubDocument: DeleteHubDocument(repository),
    getHubCurrentUserId: GetHubCurrentUserId(repository),
    getRecycleBin: GetRecycleBin(repository),
  );
}

RecycleBinCubit buildRecycleBinCubit() {
  final repository = _repository();

  return RecycleBinCubit(
    getRecycleBin: GetRecycleBin(repository),
    restoreHubDocument: RestoreHubDocument(repository),
  );
}
