// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/data/repositories/                   ║
// ║                     documents_hub_repository_impl.dart        ║
// ║  REPOSITORY IMPL — fulfils the domain contract: calls the     ║
// ║  data source, checks the envelope, returns entities.          ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/data/datasources/documents_hub_remote_data_source.dart';
import 'package:crm_app/screen/documents_hub/data/models/hub_document_model.dart';
import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';

class DocumentsHubRepositoryImpl implements DocumentsHubRepository {
  final DocumentsHubRemoteDataSource remoteDataSource;

  const DocumentsHubRepositoryImpl(this.remoteDataSource);

  @override
  Future<HubDocumentPage> getDocuments({
    required int page,
    required int limit,
    String? sourceType,
  }) async {
    final data = await remoteDataSource.getDocuments(
      page: page,
      limit: limit,
      sourceType: sourceType,
    );

    if (data is! Map<String, dynamic>) {
      throw const DocumentsHubFailure('Unexpected documents response');
    }

    if (data['success'] == false) {
      throw DocumentsHubFailure(
        data['message']?.toString() ?? 'Failed to load documents',
      );
    }

    return HubDocumentPageModel.fromJson(data, page: page, limit: limit);
  }

  @override
  Future<HubDocumentPage> getLeadDocuments({
    required int page,
    required int limit,
  }) async {
    final data = await remoteDataSource.getLeadsWithAttachments(
      page: page,
      limit: limit,
    );

    if (data is! Map<String, dynamic>) {
      throw const DocumentsHubFailure('Unexpected leads response');
    }

    if (data['success'] == false) {
      throw DocumentsHubFailure(
        data['message']?.toString() ?? 'Failed to load lead documents',
      );
    }

    return HubDocumentPageModel.fromLeadsJson(data, page: page, limit: limit);
  }

  @override
  Future<HubDocumentPage> getDealDocuments({
    required int page,
    required int limit,
  }) async {
    final data = await remoteDataSource.getDealsWithAttachments(
      page: page,
      limit: limit,
    );

    // The deals API answers with a bare list; accept an envelope too.
    if (data is List) {
      return HubDocumentPageModel.fromDealsJson(
        {'deals': data},
        page: page,
        limit: limit,
      );
    }

    if (data is! Map<String, dynamic>) {
      throw const DocumentsHubFailure('Unexpected deals response');
    }

    if (data['success'] == false) {
      throw DocumentsHubFailure(
        data['message']?.toString() ?? 'Failed to load deal documents',
      );
    }

    return HubDocumentPageModel.fromDealsJson(data, page: page, limit: limit);
  }

  @override
  Future<String> currentUserId() => remoteDataSource.currentUserId();

  @override
  Future<void> addReply({
    required String documentId,
    required String text,
  }) async {
    final data = await remoteDataSource.addActivity(
      documentId: documentId,
      text: text,
    );

    if (data is Map<String, dynamic> && data['success'] == false) {
      throw DocumentsHubFailure(
        data['message']?.toString() ?? 'Failed to send reply',
      );
    }
  }

  @override
  Future<String> deleteDocument(String documentId) async {
    final data = await remoteDataSource.deleteDocument(documentId);

    if (data is Map<String, dynamic> && data['success'] == false) {
      throw DocumentsHubFailure(
        data['message']?.toString() ?? 'Failed to delete document',
      );
    }

    final message = data is Map<String, dynamic> ? data['message'] : null;
    return message?.toString() ?? 'Moved to recycle bin';
  }

  @override
  Future<String> restoreDocument(String documentId) async {
    final data = await remoteDataSource.restoreDocument(documentId);

    if (data is Map<String, dynamic> && data['success'] == false) {
      throw DocumentsHubFailure(
        data['message']?.toString() ?? 'Failed to restore document',
      );
    }

    final message = data is Map<String, dynamic> ? data['message'] : null;
    return message?.toString() ?? 'Document restored';
  }

  @override
  Future<List<HubDocument>> getRecycleBin() async {
    final data = await remoteDataSource.getRecycleBin();

    if (data is! Map<String, dynamic>) {
      throw const DocumentsHubFailure('Unexpected recycle bin response');
    }

    if (data['success'] == false) {
      throw DocumentsHubFailure(
        data['message']?.toString() ?? 'Failed to load recycle bin',
      );
    }

    final rawData = data['data'];
    return [
      if (rawData is List)
        for (final d in rawData)
          if (d is Map<String, dynamic>) HubDocumentModel.fromJson(d),
    ];
  }

  @override
  Future<String> downloadDocument(
    HubDocument document, {
    bool forPreview = false,
  }) {
    return remoteDataSource.downloadFile(
      filePath: document.path,
      fileName: document.fileName,
      toCache: forPreview,
    );
  }
}
