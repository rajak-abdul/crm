// ╔══════════════════════════════════════════════════════════════╗
// ║     lib/screen/tasks/api_service/target_api_service.dart     ║
// ║  API SERVICE — backend communication only. The one place in   ║
// ║  the Target screen that uses Dio. Returns raw response data.  ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TargetApiException implements Exception {
  final String message;
  final int? statusCode;

  TargetApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class TargetApiService {
  final Dio dio;

  bool _initialized = false;

  TargetApiService(this.dio);

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
      throw TargetApiException('Tenant slug not found');
    }

    dio.options.baseUrl =
        'https://crm-backend-api.techzarinfo.cloud/'
        '$tenantSlug/api';

    final token = prefs.getString('token') ?? '';

    if (token.isNotEmpty) {
      dio.options.headers['Authorization'] =
          'Bearer $token';
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

  // ============================================================
  // ENDPOINTS
  // ============================================================

  /// GET /targets/my-dashboard-stats[?period=]
  /// Response: { monthly: { totalLeads, convertedLeads, leadToDealRate,
  /// totalDeals, wonDeals, lostDeals, calls, meetings },
  /// weekly: { calls, meetings } }.
  Future<dynamic> getMyDashboardStats({String? period}) => _send(
        () => dio.get(
          '/targets/my-dashboard-stats',
          queryParameters: period == null ? null : {'period': period},
        ),
        fallback: 'Failed to load dashboard stats',
      );

  /// GET /targets/my
  /// Response: [ target, ... ] — the logged-in user's targets.
  Future<dynamic> getMyTargets() => _send(
        () => dio.get('/targets/my'),
        fallback: 'Failed to load targets',
      );

  /// GET /targets/linked/:kind/:id — targets linked to one lead or deal
  /// (kind: 'lead' | 'deal'). Response: [ target, ... ].
  Future<dynamic> getLinkedTargets({
    required String kind,
    required String id,
  }) =>
      _send(
        () => dio.get('/targets/linked/$kind/$id'),
        fallback: 'Failed to load linked targets',
      );

  /// POST /targets/:targetId/reports/call (multipart)
  /// Fields: companyName, callSummary, companyUrl, recording (file).
  /// Response: { message, target: { ..., reportedCalls: [...] } }.
  Future<dynamic> reportCall({
    required String targetId,
    required FormData body,
  }) =>
      _send(
        () => dio.post('/targets/$targetId/reports/call', data: body),
        fallback: 'Failed to report call',
      );

  /// PUT /targets/:targetId
  /// Body e.g. { status: "In Hold", holdReason: "..." }.
  /// Response: { message, data: target }.
  Future<dynamic> updateTarget({
    required String targetId,
    required Map<String, dynamic> body,
  }) =>
      _send(
        () => dio.put('/targets/$targetId', data: body),
        fallback: 'Failed to update target',
      );

  /// GET /notifications/:userId?page=&limit=
  Future<dynamic> getNotifications({
    required String userId,
    int page = 1,
    int limit = 20,
  }) =>
      _send(
        () => dio.get(
          '/notifications/$userId',
          queryParameters: {'page': page, 'limit': limit},
        ),
        fallback: 'Failed to load notifications',
      );

  /// PATCH /notifications/read/:notificationId
  Future<dynamic> markNotificationRead(String notificationId) => _send(
        () => dio.patch('/notifications/read/$notificationId'),
        fallback: 'Failed to mark notification as read',
      );

  /// DELETE /notifications/:notificationId
  Future<dynamic> deleteNotification(String notificationId) => _send(
        () => dio.delete('/notifications/$notificationId'),
        fallback: 'Failed to delete notification',
      );

  /// POST /targets/:targetId/notes
  /// Body: { text }. Response: { message, notes: [...] }.
  Future<dynamic> addNote({
    required String targetId,
    required String text,
  }) =>
      _send(
        () => dio.post('/targets/$targetId/notes', data: {'text': text}),
        fallback: 'Failed to add note',
      );

  /// POST /targets/:targetId/reason-note
  /// Body: { note, itemType, itemId, itemName, companyName, phoneNumber,
  /// email, value, currency, stageOrStatus }.
  /// Response: { message, reasonNotes: [...] }.
  Future<dynamic> reportIssue({
    required String targetId,
    required Map<String, dynamic> body,
  }) =>
      _send(
        () => dio.post('/targets/$targetId/reason-note', data: body),
        fallback: 'Failed to report issue',
      );

  /// POST /targets/:targetId/reports/meeting (multipart)
  /// Fields: companyName, meetingSummary, companyUrl, screenshot (file).
  /// Response: { message, target: { ..., reportedMeetings: [...] } }.
  Future<dynamic> reportMeeting({
    required String targetId,
    required FormData body,
  }) =>
      _send(
        () => dio.post('/targets/$targetId/reports/meeting', data: body),
        fallback: 'Failed to report meeting',
      );

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
      throw TargetApiException(
        e.response?.data is Map<String, dynamic>
            ? e.response?.data['message']?.toString() ?? fallback
            : e.message ?? fallback,
        statusCode: e.response?.statusCode,
      );
    }
  }
}
