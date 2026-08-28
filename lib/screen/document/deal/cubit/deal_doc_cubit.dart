import 'package:crm_app/modals/modals.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/screen/document/deal/cubit/deal_doc_state.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DealDocCubit extends Cubit<DealDocState> {
  final Dio dio;

  String _tenantSlug = '';

  // Stores all deals returned by API
  List<Deal> _allDeals = [];
  List<Deal> _filteredDeals = [];

  DealDocCubit(this.dio) : super(const DealDocState());

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _tenantSlug = (
      prefs.getString('tenant_slug') ??
      prefs.getString('tenantSlug') ??
      ''
    ).trim();

    if (_tenantSlug.isEmpty) {
      throw Exception('Tenant slug not found');
    }

    dio.options.baseUrl =
        'https://crm-backend-api.techzarinfo.cloud/'
        '$_tenantSlug/api';

    final token = prefs.getString('token') ?? '';

    if (token.isNotEmpty) {
      dio.options.headers['Authorization'] =
          'Bearer $token';
    }

    dio.options.headers['Accept'] =
        'application/json';

    dio.options.connectTimeout =
        const Duration(seconds: 30);

    dio.options.receiveTimeout =
        const Duration(seconds: 30);

    dio.interceptors.add(AuthInterceptor());
  }

  // ============================================================
  // FILE / IMAGE URL
  // ============================================================

  String previewUrl(String path) => _fileActionUrl(path, 'preview');

  String downloadUrl(String path) => _fileActionUrl(path, 'download');

  String _fileActionUrl(String path, String action) {
    if (path.trim().isEmpty) {
      return '';
    }

    if (path.startsWith('http://') ||
        path.startsWith('https://')) {
      return path;
    }

    String cleanPath = path.trim();

    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    return Uri.https(
      'crm-backend-api.techzarinfo.cloud',
      '/api/files/$action',
      {'filePath': cleanPath},
    ).toString();
  }

  // ============================================================
  // FETCH ALL DEALS
  // ============================================================

  Future<void> fetchDeals({
    int page = 1,
    int limit = 10,
    String searchQuery = '',
  }) async {
    try {
      emit(
        state.copyWith(
          status: DealDocStatus.loading,
          errorMessage: null,
        ),
      );

      await initialize();

      print('======================================');
      print('DEAL DOC FETCH');
      print('TENANT: $_tenantSlug');
      print('BASE URL: ${dio.options.baseUrl}');
      print('SEARCH: $searchQuery');
      print('======================================');

      // ----------------------------------------------------------
      // API
      // ----------------------------------------------------------
      //
      // Backend is currently returning all records.
      // Therefore page/limit are handled locally.
      //
      final response = await dio.get(
        '/deals/getAll',
        queryParameters: {
          if (searchQuery.trim().isNotEmpty)
            'search': searchQuery.trim(),
        },
      );

      print('======================================');
      print(
        'DEAL DOC REQUEST URL: '
        '${response.requestOptions.uri}',
      );
      print(
        'DEAL DOC STATUS: ${response.statusCode}',
      );
      print(
        'DEAL DOC RESPONSE TYPE: '
        '${response.data.runtimeType}',
      );
      print('======================================');

      // ==========================================================
      // RESPONSE
      // ==========================================================

      final responseData = response.data;

      Map<String, dynamic> data;

      if (responseData is Map) {
        data = Map<String, dynamic>.from(
          responseData,
        );
      } else if (responseData is List) {
        data = {
          'deals': responseData,
        };
      } else {
        throw Exception(
          'Invalid deals response: '
          '${responseData.runtimeType}',
        );
      }

      // ==========================================================
      // GET DEAL LIST
      // ==========================================================

      final rawDeals =
          data['deals'] ??
          data['data'] ??
          data['results'] ??
          [];

      final List<dynamic> dealData =
          rawDeals is List ? rawDeals : [];

      print(
        'DEAL DOC RECORDS RETURNED: '
        '${dealData.length}',
      );

      // ==========================================================
      // PARSE ALL DEALS
      // ==========================================================

      _allDeals = [];

      for (final json in dealData) {
        if (json is Map) {
          try {
            final deal = Deal.fromJson(
              Map<String, dynamic>.from(json),
            );

            _allDeals.add(deal);
          } catch (e) {
            print(
              'DEAL PARSE ERROR: $e',
            );
          }
        }
      }

print(
  'ALL DEALS STORED: '
  '${_allDeals.length}',
);

// ==========================================================
// INITIAL FILTERED LIST
// ==========================================================

_filteredDeals = List<Deal>.from(_allDeals);

print(
  'FILTERED DEALS INITIALIZED: '
  '${_filteredDeals.length}',
);

// ==========================================================
// SHOW REQUESTED LOCAL PAGE
// ==========================================================

_showPage(
  page: page,
  limit: limit,
  searchQuery: searchQuery,
);    } on DioException catch (e) {
      print('======================================');
      print('DEAL DOC DIO ERROR');
      print('MESSAGE: ${e.message}');
      print(
        'STATUS: ${e.response?.statusCode}',
      );
      print(
        'URL: ${e.requestOptions.uri}',
      );
      print(
        'RESPONSE: ${e.response?.data}',
      );
      print('======================================');

      String message =
          'Failed to fetch deals';

      if (e.response?.data is Map) {
        final responseData =
            Map<String, dynamic>.from(
          e.response!.data,
        );

        message =
            responseData['message']?.toString() ??
            responseData['error']?.toString() ??
            message;
      }

      if (e.response?.statusCode == 401) {
        message =
            'Session expired. Please login again.';
      } else if (e.response?.statusCode == 403) {
        message =
            'You do not have permission to view deals.';
      } else if (e.response?.statusCode == 404) {
        message =
            'Deals API endpoint not found.';
      } else if (e.response?.statusCode != null &&
          e.response!.statusCode! >= 500) {
        message =
            'Server error. Please try again later.';
      } else if (e.type ==
          DioExceptionType.connectionTimeout) {
        message =
            'Connection timeout.';
      } else if (e.type ==
          DioExceptionType.receiveTimeout) {
        message =
            'Server response timeout.';
      } else if (e.type ==
          DioExceptionType.connectionError) {
        message =
            'Unable to connect to server.';
      }

      emit(
        state.copyWith(
          status: DealDocStatus.error,
          errorMessage: message,
        ),
      );
    } catch (e) {
      print(
        'DEAL DOC ERROR: $e',
      );

      emit(
        state.copyWith(
          status: DealDocStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // LOCAL PAGINATION
  // ============================================================

  void _showPage({
  required int page,
  required int limit,
  String searchQuery = '',
}) {
  final totalDeals = _filteredDeals.length;

  final totalPages = totalDeals == 0
      ? 1
      : (totalDeals + limit - 1) ~/ limit;

  final safePage =
      page.clamp(1, totalPages);

  final start =
      (safePage - 1) * limit;

  final end =
      (start + limit > totalDeals)
          ? totalDeals
          : start + limit;

  final pageDeals = totalDeals == 0
      ? <Deal>[]
      : _filteredDeals.sublist(
          start,
          end,
        );

  emit(
    state.copyWith(
      status: DealDocStatus.loaded,
      deals: pageDeals,
      currentPage: safePage,
      totalPages: totalPages,
      totalDeals: totalDeals,
      searchQuery: searchQuery,
      errorMessage: null,
    ),
  );
}

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refreshDeals() async {
    await fetchDeals(
      page: 1,
      limit: 10,
      searchQuery: state.searchQuery,
    );
  }

  // ============================================================
  // NEXT PAGE
  // ============================================================

Future<void> nextPage() async {
  if (state.currentPage >= state.totalPages) {
    return;
  }

  _showPage(
    page: state.currentPage + 1,
    limit: 10,
    searchQuery: state.searchQuery,
  );
}

Future<void> previousPage() async {
  if (state.currentPage <= 1) {
    return;
  }

  _showPage(
    page: state.currentPage - 1,
    limit: 10,
    searchQuery: state.searchQuery,
  );
}

  // ============================================================
  // GO TO SPECIFIC PAGE
  // ============================================================

  void goToPage(int page) {
    if (page < 1 ||
        page > state.totalPages) {
      return;
    }

    _showPage(
      page: page,
      limit: 10,
      searchQuery: state.searchQuery,
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> search(String query) async {
  final searchQuery = query.trim().toLowerCase();

  if (searchQuery.isEmpty) {
    _filteredDeals =
        List<Deal>.from(_allDeals);

    _showPage(
      page: 1,
      limit: 10,
      searchQuery: '',
    );

    return;
  }

  _filteredDeals = _allDeals.where((deal) {
    return deal.name
            .toLowerCase()
            .contains(searchQuery) ||
        deal.assignTo
            .toLowerCase()
            .contains(searchQuery);
  }).toList();

  _showPage(
    page: 1,
    limit: 10,
    searchQuery: query,
  );
}

  // ============================================================
  // CLEAR SEARCH
  // ============================================================

  Future<void> clearSearch() async {
    await fetchDeals(
      page: 1,
      limit: 10,
      searchQuery: '',
    );
  }

  // ============================================================
  // INTEGER HELPER
  // ============================================================

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  
}