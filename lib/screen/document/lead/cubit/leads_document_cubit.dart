import 'package:crm_app/modals/modals.dart';
import 'package:crm_app/screen/document/lead/cubit/lead_state.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeadsCubit extends Cubit<LeadsState> {
  late final Dio dio;

  LeadsCubit() : super(const LeadsState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token') ?? '';
final slug = prefs.getString('tenant_slug') ?? '';

if (slug.isEmpty) {
  throw Exception('Tenant slug not found');
}
    dio = Dio(
      BaseOptions(
        baseUrl:
            'https://crm-backend-api.techzarinfo.cloud/$slug/api',
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    dio.interceptors.add(AuthInterceptor());

    await fetchLeads(
      page: 1,
      limit: 10,
    );
  }

Future<void> fetchLeads({
  int page = 1,
  int limit = 10,
  bool loadMore = false,
  String searchQuery = '',
}) async {
  try {
    if (loadMore) {
      if (!state.hasMore) return;

      emit(
        state.copyWith(
          status: LeadsStatus.loadingMore,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: LeadsStatus.loading,
          errorMessage: null,
        ),
      );
    }

    final response = await dio.get(
      '/leads/getAllLead',
      queryParameters: {
        'page': page,
        'limit': limit,

        // IMPORTANT
        if (searchQuery.trim().isNotEmpty)
          'search': searchQuery.trim(),
      },
    );

    final data = response.data as Map<String, dynamic>;

    final List<dynamic> leadData =
        data['leads'] ?? [];

    final List<Lead> newLeads = leadData
        .map((json) => Lead.fromJson(json))
        .toList();

    emit(
      state.copyWith(
        status: LeadsStatus.loaded,
        leads: newLeads,
        currentPage: data['currentPage'] ?? page,
        totalPages: data['totalPages'] ?? 1,
        totalLeads: data['totalLeads'] ?? 0,
        searchQuery: searchQuery,
        errorMessage: null,
      ),
    );
  } catch (e) {
    emit(
      state.copyWith(
        status: LeadsStatus.error,
        errorMessage: e.toString(),
      ),
    );
  }
}

  Future<void> refreshLeads() async {
    await fetchLeads(
      page: 1,
      limit: 10,
    );
  }

  Future<void> loadNextPage() async {
  if (!state.hasMore) return;

  await fetchLeads(
    page: state.currentPage + 1,
    limit: 10,
    loadMore: true,
    searchQuery: state.searchQuery,
  );
}

 Future<void> search(String query) async {
  await fetchLeads(
    page: 1,
    limit: 10,
    searchQuery: query,
  );
}


}