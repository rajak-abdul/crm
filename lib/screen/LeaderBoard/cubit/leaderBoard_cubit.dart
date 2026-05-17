// ╔══════════════════════════════════════════════════════════════╗
// ║     lib/screen/LeaderBoard/service/leaderBoard_service.dart  ║
// ║                                                              ║
// ║  Strategy: network-first, cache fallback                     ║
// ║  1. Always try the API first                                 ║
// ║  2. Cache every successful response to SQLite                ║
// ║  3. On ANY error → fall back to SQLite cache                 ║
// ║  4. Only throw when BOTH API and cache fail                  ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/database/local_db.dart';
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

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<LeaderboardResponse> fetchLeaderboard({
    required String token,
    String? startDate,
    String? endDate,
    String? filterType,
    bool forceRefresh = false,
  }) async {
    final cacheKey = LocalDb.leaderboardCacheKey(
      filterType: filterType,
      startDate: startDate,
      endDate: endDate,
    );

    // ── 1. Try API ──────────────────────────────────────────────
    try {
      final json = await _fetchFromApi(
        token: token,
        startDate: startDate,
        endDate: endDate,
        filterType: filterType,
      );

      // ── 2. Cache the fresh response under the specific key ────
      try {
        await LocalDb.instance.cacheLeaderboard(
          cacheKey: cacheKey,
          responseJson: json,
        );
      } catch (_) {}

      return LeaderboardResponse.fromJson(json);
    } catch (apiError) {
      // ── 3. API failed — try cache with the exact filter key first,
      //       then fall back to the default (no-filter) cache key ──
      try {
        final db = LocalDb.instance;

        // Try exact filter key first
        Map<String, dynamic>? cached = await db.getCachedLeaderboard(cacheKey);

        // If no exact match and we had filters, fall back to default cache
        if (cached == null &&
            (filterType != null || startDate != null || endDate != null)) {
          final defaultKey = LocalDb.leaderboardCacheKey(
            filterType: null,
            startDate: null,
            endDate: null,
          );
          cached = await db.getCachedLeaderboard(defaultKey);
        }

        if (cached != null) {
          final data = cached['data'];
          if (data is List && data.isNotEmpty) {
            return LeaderboardResponse.fromJson(
                Map<String, dynamic>.from(cached));
          }
          if (cached['stats'] != null) {
            return LeaderboardResponse.fromJson(
                Map<String, dynamic>.from(cached));
          }
        }
      } catch (cacheError) {
        // Cache read failed — fall through
      }

      // ── 4. Both API and cache failed ─────────────────────────
      if (apiError is DioException &&
          apiError.type == DioExceptionType.connectionError) {
        throw Exception('No internet connection and no cached data available.');
      }
      rethrow;
    }
  }

  /// Wipes all leaderboard cache rows (call on logout or manual reset).
  static Future<void> clearCache() => LocalDb.instance.clearLeaderboardCache();

  // ── Private: raw API call (throws on any failure) ───────────────────────────

  static Future<Map<String, dynamic>> _fetchFromApi({
    required String token,
    String? startDate,
    String? endDate,
    String? filterType,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (filterType != null) queryParams['filterType'] = filterType;

    try {
      final response = await _dio.get(
        _leaderboardEndpoint,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException {
      // Re-throw as DioException so the caller can inspect the type
      // for the cache-vs-rethrow decision above.
      rethrow;
    }
  }
}
