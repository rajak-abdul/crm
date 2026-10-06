import 'package:crm_app/screen/email/cubit/email_template_state.dart';
import 'package:crm_app/screen/email/modal/email_modal.dart';
import 'package:crm_app/screen/email/modal/email_template_modal.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailTemplateCubit extends Cubit<EmailTemplateState> {
  late final Dio dio;

  String _tenantSlug = '';

  EmailTemplateCubit()
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
        super(const EmailTemplateInitial());

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
      throw Exception('Tenant slug not found');
    }

    final token =
        prefs.getString('token') ?? '';

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
  // GET EMAIL TEMPLATES
  // ============================================================

Future<void> getEmailTemplates() async {
  if (isClosed) return;

  try {
    emit(const EmailTemplateLoading());

    await initialize();

    if (isClosed) return;

    final response = await dio.get(
      '$_tenantSlug/api/email-templates',
    );

    if (isClosed) return;

    if (response.data is Map<String, dynamic>) {
      final result = EmailTemplatesResponse.fromJson(
        Map<String, dynamic>.from(response.data),
      );

      if (isClosed) return;

      emit(EmailTemplateSuccess(result));
    } else {
      if (isClosed) return;

      emit(const EmailTemplateError(
        'Invalid email templates response',
      ));
    }
  } on DioException catch (e) {
    if (isClosed) return;

    emit(
      EmailTemplateError(
        e.response?.data is Map
            ? e.response?.data['message']?.toString() ??
                'Failed to load email templates'
            : 'Failed to load email templates',
      ),
    );
  } catch (e) {
    if (isClosed) return;

    emit(EmailTemplateError(e.toString()));
  }
}

Future<void> sendBulkEmail({
  required List<EmailContact> recipients,
  required String subject,
  required String content,
  required String templateTitle,
  DateTime? scheduledFor,
}) async {
  if (isClosed) return;

  try {
    emit(const BulkEmailLoading());

    await initialize();

    if (isClosed) return;

    final Map<String, dynamic> data = {
      'subject': subject,
      'content': content,
      'templateTitle': templateTitle,
      'recipients': recipients
          .map((contact) => contact.email.trim())
          .where((email) => email.isNotEmpty)
          .toList(),
    };

    // Only include scheduledFor when the user actually picked a
    // schedule date/time; omit it entirely for a normal send.
    if (scheduledFor != null) {
      data['scheduledFor'] =
          scheduledFor.toUtc().toIso8601String();
    }

    final response = await dio.post(
      '$_tenantSlug/api/email/send-bulk',
      data: data,
    );

    if (isClosed) return;

    if (response.data is Map<String, dynamic>) {
      final data = Map<String, dynamic>.from(response.data);

      if (data['success'] == true) {
        emit(
          BulkEmailSuccess(
            data['message']?.toString() ??
                'Email sent successfully',
          ),
        );
      } else {
        emit(
          BulkEmailError(
            data['message']?.toString() ??
                'Failed to send bulk email',
          ),
        );
      }
    } else {
      emit(
        const BulkEmailError(
          'Invalid bulk email response',
        ),
      );
    }
  } on DioException catch (e) {
    if (isClosed) return;

    String message = 'Failed to send bulk email';

    if (e.response?.data is Map) {
      final responseData =
          Map<String, dynamic>.from(e.response!.data);

      message =
          responseData['message']?.toString() ?? message;
    }

    emit(BulkEmailError(message));
  } catch (e) {
    if (isClosed) return;

    emit(
      BulkEmailError(
        e.toString(),
      ),
    );
  }
}
}