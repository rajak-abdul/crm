// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/data/datasources/                    ║
// ║                     documents_hub_remote_data_source.dart     ║
// ║  DATA SOURCE — the one place in Documents Hub that uses Dio.  ║
// ║  Returns raw response data; throws DocumentsHubFailure.       ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/repositories/documents_hub_repository.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:crm_app/utils/attachment_downloader.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentsHubRemoteDataSource {
  final Dio dio;

  bool _initialized = false;

  DocumentsHubRemoteDataSource(this.dio);

  // ============================================================
  // INITIALIZE — tenant base URL, auth header, 401 handling
  // ============================================================

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    final tenantSlug = (
      prefs.getString('tenant_slug') ??
      prefs.getString('tenantSlug') ??
      ''
    ).trim();

    if (tenantSlug.isEmpty) {
      throw const DocumentsHubFailure('Tenant slug not found');
    }

    dio.options.baseUrl =
        'https://crm-backend-api.techzarinfo.cloud/'
        '$tenantSlug/api';

    final token = prefs.getString('token') ?? '';

    if (token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

    dio.options.headers['Accept'] = 'application/json';

    dio.options.connectTimeout = const Duration(seconds: 30);

    dio.options.receiveTimeout = const Duration(seconds: 30);

    if (!dio.interceptors.any(
      (interceptor) => interceptor is AuthInterceptor,
    )) {
      dio.interceptors.add(AuthInterceptor());
    }

    _initialized = true;
  }

  /// Logged-in user's id, saved at login ('' when missing).
  Future<String> currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('user_id') ?? '').trim();
  }

  // ============================================================
  // ENDPOINTS
  // ============================================================

  /// GET /document-hub/documents?page=&limit=[&sourceType=Lead|Deal]
  /// Response: { success, data: [ document, ... ],
  /// pagination: { page, limit, total, totalPages } }.
  Future<dynamic> getDocuments({
    required int page,
    required int limit,
    String? sourceType,
  }) =>
      _send(
        () => dio.get(
          '/document-hub/documents',
          queryParameters: {
            if (sourceType != null) 'sourceType': sourceType,
            'page': page,
            'limit': limit,
          },
        ),
        fallback: 'Failed to load documents',
      );

  /// GET /leads/getAllLead?page=&limit=&hasAttachments=true — only leads
  /// that carry files. Response: { leads: [ lead, ... ], currentPage,
  /// totalPages, totalLeads }.
  Future<dynamic> getLeadsWithAttachments({
    required int page,
    required int limit,
  }) =>
      _send(
        () => dio.get(
          '/leads/getAllLead',
          queryParameters: {
            'page': page,
            'limit': limit,
            'hasAttachments': true,
          },
        ),
        fallback: 'Failed to load lead documents',
      );

  /// GET /deals/getAll?page=&limit=&hasAttachments=true — only deals
  /// that carry files. Response: a bare list [ deal, ... ] (no paging
  /// info).
  Future<dynamic> getDealsWithAttachments({
    required int page,
    required int limit,
  }) =>
      _send(
        () => dio.get(
          '/deals/getAll',
          queryParameters: {
            'page': page,
            'limit': limit,
            'hasAttachments': true,
          },
        ),
        fallback: 'Failed to load deal documents',
      );

  /// POST /document-hub/documents/:id/activity — body { text }.
  /// Response: { success, message }.
  Future<dynamic> addActivity({
    required String documentId,
    required String text,
  }) =>
      _send(
        () => dio.post(
          '/document-hub/documents/$documentId/activity',
          data: {'text': text},
        ),
        fallback: 'Failed to send reply',
      );

  /// DELETE /document-hub/documents/:id — moves the assignment to the
  /// recycle bin. Response: { success, message }.
  Future<dynamic> deleteDocument(String documentId) => _send(
        () => dio.delete('/document-hub/documents/$documentId'),
        fallback: 'Failed to delete document',
      );

  /// POST /document-hub/documents/:id/restore — brings an assignment
  /// back from the recycle bin. Response: { success, message }.
  Future<dynamic> restoreDocument(String documentId) => _send(
        () => dio.post('/document-hub/documents/$documentId/restore'),
        fallback: 'Failed to restore document',
      );

  /// GET /document-hub/recycle-bin — deleted assignments.
  /// Response: { success, data: [ { id, name, path, sourceType,
  /// sourceId, sourceName, documentId, deletedAt }, ... ] }.
  Future<dynamic> getRecycleBin() => _send(
        () => dio.get('/document-hub/recycle-bin'),
        fallback: 'Failed to load recycle bin',
      );

  /// GET /files/download?filePath= — saves the file to the device's
  /// Downloads (same flow as lead / deal attachments). Returns the path.
  /// [toCache] saves to the app's temp folder instead and returns a real
  /// file path — Android's Downloads save hands back a content:// URI,
  /// which OpenFile can't open.
  Future<String> downloadFile({
    required String filePath,
    required String fileName,
    bool toCache = false,
  }) async {
    await _ensureInitialized();

    final clean = filePath.startsWith('/') ? filePath.substring(1) : filePath;
    final url = '${dio.options.baseUrl}/files/download'
        '?filePath=${Uri.encodeComponent(clean)}';

    try {
      if (toCache) {
        final dir = await getTemporaryDirectory();
        final savePath = '${dir.path}/document_hub/$fileName';
        await dio.download(url, savePath);
        return savePath;
      }
      return await AttachmentDownloader.saveToDownloads(
        dio: dio,
        url: url,
        fileName: fileName,
      );
    } on DioException catch (e) {
      throw DocumentsHubFailure(
        e.response?.statusCode == 404
            ? 'File not found on server'
            : e.message ?? 'Failed to download file',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw DocumentsHubFailure('Failed to download file: $e');
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Future<dynamic> _send(
    Future<Response<dynamic>> Function() request, {
    required String fallback,
  }) async {
    await _ensureInitialized();

    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw DocumentsHubFailure(
        e.response?.data is Map<String, dynamic>
            ? e.response?.data['message']?.toString() ?? fallback
            : e.message ?? fallback,
        statusCode: e.response?.statusCode,
      );
    }
  }
}
