// ╔══════════════════════════════════════════════════════════════╗
// ║           lib/services/auth_interceptor.dart                  ║
// ║  Add to ANY Dio instance to make it participate in the        ║
// ║  centralized force-logout flow. It does not touch headers or  ║
// ║  base URLs — each module keeps its own token/tenant setup —   ║
// ║  it only watches for a 401 and hands off to AuthGuard.        ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/services/auth_guard.dart';
import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      AuthGuard.forceLogout();
    }
    handler.next(err);
  }
}
