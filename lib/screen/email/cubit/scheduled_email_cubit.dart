import 'package:crm_app/screen/email/cubit/scheduled_email_state.dart';
import 'package:crm_app/screen/email/modal/scheduled_email_modal.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduledEmailCubit
    extends Cubit<ScheduledEmailState> {

  late final Dio dio;

  String _tenantSlug = '';

  ScheduledEmailCubit()
      : dio = Dio(
          BaseOptions(
            baseUrl:
                'https://crm-backend-api.techzarinfo.cloud/',
            connectTimeout:
                const Duration(seconds: 30),
            receiveTimeout:
                const Duration(seconds: 30),
            headers: {
              'Content-Type':
                  'application/json',
              'Accept':
                  'application/json',
            },
          ),
        ),
        super(
          const ScheduledEmailInitial(),
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
  // GET SCHEDULED EMAILS
  // ============================================================

  Future<void> getScheduledEmails() async {
    if (isClosed) return;

    try {
      emit(
        const ScheduledEmailLoading(),
      );

      await initialize();

      if (isClosed) return;

      final response = await dio.get(
        '$_tenantSlug/api/email/scheduled',
      );

      if (isClosed) return;

      if (response.data
          is Map<String, dynamic>) {

        final data =
            Map<String, dynamic>.from(
          response.data,
        );

        if (data['success'] != true) {
          emit(
            ScheduledEmailError(
              data['message']?.toString() ??
                  'Failed to load scheduled emails',
            ),
          );
          return;
        }

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

        if (isClosed) return;

        emit(
          ScheduledEmailSuccess(emails),
        );
      } else {
        emit(
          const ScheduledEmailError(
            'Invalid scheduled emails response',
          ),
        );
      }
    } on DioException catch (e) {
      if (isClosed) return;

      String message =
          'Failed to load scheduled emails';

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
        ScheduledEmailError(message),
      );
    } catch (e) {
      if (isClosed) return;

      emit(
        ScheduledEmailError(
          e.toString(),
        ),
      );
    }
  }

// ============================================================
// UPDATE SCHEDULED EMAIL
// ============================================================

Future<void> updateScheduledEmail({
  required String id,
  required List<String> recipients,
  required String subject,
  required String content,
  required String templateTitle,
  required DateTime scheduledFor,
}) async {
  try {
    await initialize();

    final response = await dio.put(
      '$_tenantSlug/api/email/update/$id',
      data: {
        'recipients': recipients,
        'subject': subject,
        'content': content,
        'templateTitle': templateTitle,
        'scheduledFor':
            scheduledFor.toUtc().toIso8601String(),
      },
    );

    debugPrint(
      'Update Scheduled Email Response: ${response.data}',
    );

    if (response.data is! Map) {
      throw Exception(
        'Invalid update response',
      );
    }

    final data = Map<String, dynamic>.from(
      response.data,
    );

    if (data['success'] != true) {
      throw Exception(
        data['message']?.toString() ??
            'Failed to update scheduled email',
      );
    }

    debugPrint(
      'Scheduled email updated successfully',
    );
  } on DioException catch (e) {
    debugPrint(
      'Update Scheduled Email Dio Error: '
      '${e.response?.data}',
    );

    String message =
        'Failed to update scheduled email';

    if (e.response?.data is Map) {
      final data = Map<String, dynamic>.from(
        e.response!.data,
      );

      message =
          data['message']?.toString() ??
              message;
    }

    throw Exception(message);
  } catch (e) {
    debugPrint(
      'Update Scheduled Email Error: $e',
    );

    rethrow;
  }
}

// ============================================================
// GET SCHEDULED EMAIL BY ID
// ============================================================

Future<ScheduledEmail?> getScheduledEmailById(
  String id,
) async {
  try {
    await initialize();

    final response = await dio.get(
      '$_tenantSlug/api/email/$id',
    );

    debugPrint(
      'Scheduled Email Detail Response: ${response.data}',
    );

    if (response.data is! Map) {
      throw Exception(
        'Invalid scheduled email response',
      );
    }

    final data = Map<String, dynamic>.from(
      response.data,
    );

    if (data['success'] != true) {
      throw Exception(
        data['message']?.toString() ??
            'Failed to fetch scheduled email',
      );
    }

    final emailData = data['data'];

    if (emailData is Map) {
      return ScheduledEmail.fromJson(
        Map<String, dynamic>.from(emailData),
      );
    }

    throw Exception(
      'Scheduled email data not found',
    );
  } on DioException catch (e) {
    debugPrint(
      'Get Scheduled Email Dio Error: '
      '${e.response?.data}',
    );

    String message =
        'Failed to fetch scheduled email';

    if (e.response?.data is Map) {
      final data = Map<String, dynamic>.from(
        e.response!.data,
      );

      message =
          data['message']?.toString() ??
              message;
    }

    throw Exception(message);
  } catch (e) {
    debugPrint(
      'Get Scheduled Email Error: $e',
    );

    rethrow;
  }
}

// ============================================================
// CANCEL SCHEDULED EMAIL
// ============================================================
Future<void> cancelScheduledEmail({
  required String id,
}) async {
  try {
    await initialize();

    final response = await dio.patch(
      '$_tenantSlug/api/email/cancel/$id',
    );

    debugPrint(
      'Cancel Scheduled Email Response: ${response.data}',
    );

    if (response.data is! Map) {
      throw Exception(
        'Invalid cancel response',
      );
    }

    final data = Map<String, dynamic>.from(
      response.data,
    );

    if (data['success'] != true) {
      throw Exception(
        data['message']?.toString() ??
            'Failed to cancel scheduled email',
      );
    }

    debugPrint(
      'Scheduled email cancelled successfully',
    );

    // Refresh scheduled email list
    await getScheduledEmails();
  } on DioException catch (e) {
    debugPrint(
      'Cancel Scheduled Email Dio Error: '
      '${e.response?.data}',
    );

    String message =
        'Failed to cancel scheduled email';

    if (e.response?.data is Map) {
      final data = Map<String, dynamic>.from(
        e.response!.data,
      );

      message =
          data['message']?.toString() ??
              message;
    }

    throw Exception(message);
  } catch (e) {
    debugPrint(
      'Cancel Scheduled Email Error: $e',
    );

    rethrow;
  }
}
    }