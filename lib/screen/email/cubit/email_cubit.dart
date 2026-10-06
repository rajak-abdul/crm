import 'package:crm_app/screen/email/cubit/email_state.dart';
import 'package:crm_app/screen/email/modal/email_modal.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailContactsCubit extends Cubit<EmailContactsState> {
  late final Dio dio;

  String _tenantSlug = '';

  EmailContactsCubit()
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
        super(const EmailContactsInitial());

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

    // Add only once
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
  // GET EMAIL CONTACTS
  // ============================================================

Future<void> getEmailContacts({
  int page = 1,
  int limit = 10,
}) async {
  if (isClosed) return;

  try {
    emit(const EmailContactsLoading());

    await initialize();

    if (isClosed) return;

    final response = await dio.get(
      '$_tenantSlug/api/email/contacts',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );

    if (isClosed) return;

    if (response.data is! Map<String, dynamic>) {
      emit(const EmailContactsError(
        'Invalid email contacts response',
      ));
      return;
    }

    final result = EmailContactsResponse.fromJson(
      Map<String, dynamic>.from(response.data),
      page: page,
      limit: limit,
    );

    emit(EmailContactsSuccess(result));
  } on DioException catch (e) {
    if (isClosed) return;

    emit(
      EmailContactsError(
        e.response?.data is Map
            ? e.response?.data['message']?.toString() ??
                'Failed to load email contacts'
            : 'Failed to load email contacts',
      ),
    );
  } catch (e) {
    if (isClosed) return;

    emit(EmailContactsError(e.toString()));
  }
}
}