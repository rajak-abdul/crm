import 'package:crm_app/screen/email/cubit/email_history_state.dart';
import 'package:crm_app/screen/email/modal/scheduled_email_modal.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailHistoryCubit extends Cubit<EmailHistoryState> {
  late final Dio dio;

  String _tenantSlug = '';

  EmailHistoryCubit()
      : dio = Dio(
          BaseOptions(
            baseUrl:
                'https://crm-backend-api.techzarinfo.cloud/',
            connectTimeout:
                const Duration(seconds: 30),
            receiveTimeout:
                const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ),
        super(
          const EmailHistoryInitial(),
        );

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    final prefs =
        await SharedPreferences.getInstance();

    _tenantSlug = (
      prefs.getString('tenant_slug') ??
      prefs.getString('tenantSlug') ??
      ''
    ).trim();

    if (_tenantSlug.isEmpty) {
      throw Exception(
        'Tenant slug not found',
      );
    }

    final token =
        prefs.getString('token') ?? '';

    if (token.isNotEmpty) {
      dio.options.headers[
          'Authorization'] =
          'Bearer $token';
    }

    dio.options.headers[
        'Accept'] = 'application/json';

    dio.options.connectTimeout =
        const Duration(seconds: 30);

    dio.options.receiveTimeout =
        const Duration(seconds: 30);

    // Add interceptor only once
    if (!dio.interceptors.any(
      (interceptor) =>
          interceptor is AuthInterceptor,
    )) {
      dio.interceptors.add(
        AuthInterceptor(),
      );
    }
  }

  // ============================================================
  // GET EMAIL HISTORY
  // ============================================================

  Future<void> getEmailHistory({
    required int page,
    required int limit,
  }) async {
    if (isClosed) return;

    try {
      emit(
        const EmailHistoryLoading(),
      );

      await initialize();

      if (isClosed) return;

      final response = await dio.get(
        '$_tenantSlug/api/email/history',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      debugPrint(
        '============================',
      );

      debugPrint(
        'Email History Response: '
        '${response.data}',
      );

      debugPrint(
        '============================',
      );

      if (isClosed) return;

      if (response.data
          is Map<String, dynamic>) {
        final data =
            Map<String, dynamic>.from(
          response.data,
        );

        // ========================================================
        // SUCCESS CHECK
        // ========================================================

        if (data['success'] != true) {
          emit(
            EmailHistoryError(
              data['message']?.toString() ??
                  'Failed to load email history',
            ),
          );
          return;
        }

        // ========================================================
        // DATA
        // ========================================================

        final List rawData =
            data['data'] as List? ?? [];

        final emails = rawData
            .map(
              (item) =>
                  ScheduledEmail.fromJson(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            )
            .toList();

        // ========================================================
        // PAGINATION RESPONSE
        // ========================================================

        final int total =
            data['total'] is int
                ? data['total']
                : int.tryParse(
                      data['total']
                              ?.toString() ??
                          '',
                    ) ??
                    0;

        final int currentPage =
            data['page'] is int
                ? data['page']
                : int.tryParse(
                      data['page']
                              ?.toString() ??
                          '',
                    ) ??
                    page;

        final int totalPages =
            data['totalPages'] is int
                ? data['totalPages']
                : int.tryParse(
                      data['totalPages']
                              ?.toString() ??
                          '',
                    ) ??
                    1;

        if (isClosed) return;

        emit(
          EmailHistorySuccess(
            emails: emails,
            total: total,
            page: currentPage,
            totalPages: totalPages,
          ),
        );
      } else {
        emit(
          const EmailHistoryError(
            'Invalid email history response',
          ),
        );
      }
    }

    // ==========================================================
    // DIO ERROR
    // ==========================================================

    on DioException catch (e) {
      if (isClosed) return;

      String message =
          'Failed to load email history';

      if (e.response?.data is Map) {
        final responseData =
            Map<String, dynamic>.from(
          e.response!.data,
        );

        message =
            responseData['message']
                    ?.toString() ??
                message;
      }

      emit(
        EmailHistoryError(message),
      );
    }

    // ==========================================================
    // OTHER ERROR
    // ==========================================================

    catch (e) {
      if (isClosed) return;

      emit(
        EmailHistoryError(
          e.toString(),
        ),
      );
    }
  }
}