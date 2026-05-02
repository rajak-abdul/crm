import 'package:dio/dio.dart';
import 'package:crm_app/screen/LeaderBoard/modal/leaderBoard_modal.dart';

const String _baseUrl = 'https://sales.stagingzar.com/api';
const String _leaderboardEndpoint = '/streak/leaderboard';

class LeaderboardService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static Future<LeaderboardResponse> fetchLeaderboard({
    required String token,
    String? startDate,
    String? endDate,
    String? filterType,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (filterType != null) queryParams['filterType'] = filterType;

      final response = await _dio.get(
        _leaderboardEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return LeaderboardResponse.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
          throw Exception('Request timed out. Please try again.');
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          final message =
              e.response?.data?['message'] ?? 'Unknown server error';
          throw Exception('Server error ($statusCode): $message');
        case DioExceptionType.connectionError:
          throw Exception('No internet connection. Check your network.');
        default:
          throw Exception('Something went wrong: ${e.message}');
      }
    }
  }
}