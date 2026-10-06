// ╔══════════════════════════════════════════════════════════════╗
// ║       lib/screen/tasks/api_service/task_api_service.dart      ║
// ║  API SERVICE — backend communication only. The one place in   ║
// ║  the tasks module that uses Dio. Returns raw response data.   ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskApiException implements Exception {
  final String message;
  final int? statusCode;

  TaskApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class TaskApiService {
  final Dio dio;

  bool _initialized = false;

  TaskApiService(this.dio);

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
      throw TaskApiException('Tenant slug not found');
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

  /// GET /tasks
  Future<dynamic> getTasks() =>
      _get('/tasks', fallback: 'Failed to load tasks');

  /// GET /targets/my-dashboard-stats?period=
  Future<dynamic> getMyDashboardStats({String period = 'all'}) => _get(
        '/targets/my-dashboard-stats',
        queryParameters: {'period': period},
        fallback: 'Failed to load dashboard stats',
      );

  /// GET /notifications/:userId?page=&limit=
  Future<dynamic> getNotifications({
    required String userId,
    int page = 1,
    int limit = 20,
  }) =>
      _get(
        '/notifications/$userId',
        queryParameters: {'page': page, 'limit': limit},
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

  /// PUT /tasks/:taskId
  /// Body e.g. { status: "In Hold", holdReason: "..." }.
  /// Response: { message, data: task }.
  Future<dynamic> updateTask({
    required String taskId,
    required Map<String, dynamic> body,
  }) =>
      _send(
        () => dio.put('/tasks/$taskId', data: body),
        fallback: 'Failed to update task',
      );

  /// POST /tasks/:taskId/reason-note
  /// Body: { note, itemType, itemId, itemName }.
  /// Response: { message, reasonNotes: [...] }.
  Future<dynamic> reportTaskIssue({
    required String taskId,
    required Map<String, dynamic> body,
  }) =>
      _send(
        () => dio.post('/tasks/$taskId/reason-note', data: body),
        fallback: 'Failed to report issue',
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
      throw TaskApiException(
        e.response?.data is Map<String, dynamic>
            ? e.response?.data['message']?.toString() ?? fallback
            : e.message ?? fallback,
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    required String fallback,
  }) =>
      _send(
        () => dio.get(path, queryParameters: queryParameters),
        fallback: fallback,
      );
}
