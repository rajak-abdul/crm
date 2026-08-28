import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  UserCubit() : super(UserInitial());

  Future<void> loadUser() async {
    emit(UserLoading());

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token') ?? '';
      final tenant = prefs.getString('tenant_slug') ?? '';

      final dio = Dio()..interceptors.add(AuthInterceptor());

      final response = await dio.get(
        'https://crm-backend-api.techzarinfo.cloud/$tenant/api/users/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final user = UserProfile.fromJson(response.data);

      // Save locally
      await prefs.setString('currency', user.currency);
      await prefs.setString('user_name', user.name);
      await prefs.setString('email', user.email);

      emit(UserLoaded(user));
    } on DioException catch (e) {
      emit(UserError(
        e.response?.data['message']?.toString() ??
            'Failed to load user',
      ));
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }
}