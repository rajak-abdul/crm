import 'package:crm_app/utils/data_sync.dart';
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

      // GET /{tenant}/api/users/me — shared with the drawer and the
      // dashboard for 2 min instead of each requesting it at startup.
      final data = await SessionCache.usersMe();

      final user = UserProfile.fromJson(data);

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