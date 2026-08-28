// ╔══════════════════════════════════════════════════════════════╗
// ║              lib/services/auth_guard.dart                    ║
// ║  Single source of truth for "the session is no longer valid" ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/main.dart' show navigatorKey;
import 'package:crm_app/utils/missed_followup_timer.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthGuard {
  AuthGuard._();

  static bool _handling = false;

  /// Call this from anywhere (interceptors, cubits, services) the moment
  /// a request proves the current token is no longer valid. Safe to call
  /// concurrently from multiple modules — only the first call acts.
  static Future<void> forceLogout({
    String reason = 'Session expired. Please log in again.',
  }) async {
    if (_handling) return;
    _handling = true;

    try {
      MissedFollowupTimer.instance.stop();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('email');
      await prefs.remove('role');
      await prefs.remove('permissions');
      await prefs.remove('profileImage');
      await prefs.remove('profile_image');
      await prefs.remove('tenant_slug');
      PermissionHelper.clear();

      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(reason)),
        );
      }
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (_) {
    } finally {
      _handling = false;
    }
  }
}
