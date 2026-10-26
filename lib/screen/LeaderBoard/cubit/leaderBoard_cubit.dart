import 'package:dio/dio.dart';
import 'package:crm_app/screen/LeaderBoard/modal/leaderBoard_modal.dart';
import 'package:crm_app/services/auth_interceptor.dart';

const String _baseUrl =
    'https://crm-backend-api.techzarinfo.cloud/api';

const String _leaderboardEndpoint = '/streak/leaderboard';

class LeaderboardService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
      },
    ),
  )..interceptors.add(AuthInterceptor());

  static Future<LeaderboardResponse> fetchLeaderboard({
    required String token,
    String? startDate,
    String? endDate,
    String? filterType,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, dynamic>{};

    if (startDate != null && startDate.isNotEmpty) {
      queryParams['startDate'] = startDate;
    }

    if (endDate != null && endDate.isNotEmpty) {
      queryParams['endDate'] = endDate;
    }

    if (filterType != null && filterType.isNotEmpty) {
      queryParams['filterType'] = filterType;
    }

    try {
      final response = await _dio.get(
        _leaderboardEndpoint,
        queryParameters:
            queryParams.isEmpty ? null : queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is! Map) {
        throw Exception('Invalid leaderboard response.');
      }

      final json = Map<String, dynamic>.from(
        response.data as Map,
      );

      if (json['success'] != true) {
        throw Exception(
          'Failed to load leaderboard.',
        );
      }

      return LeaderboardResponse.fromJson(json);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw Exception(
          'Request timed out. Please try again.',
        );
      }

      if (error.type == DioExceptionType.connectionError) {
        throw Exception(
          'Unable to connect to the server. Check your internet connection.',
        );
      }

      if (statusCode == 401 || statusCode == 403) {
        throw Exception(
          'Session expired or access denied. Please log in again.',
        );
      }

      if (statusCode != null && statusCode >= 500) {
        throw Exception(
          'Server error. Please try again later.',
        );
      }

      final data = error.response?.data;

      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }

      throw Exception(
        error.message ?? 'Failed to load leaderboard.',
      );
    }
  }
}
