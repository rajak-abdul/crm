import 'package:crm_app/main.dart' show navigatorKey;
import 'package:crm_app/utils/data_sync.dart' show SessionCache;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Role permissions of the logged-in user.
///
/// The source of truth is `role.permissions` in GET /users/me: a key is
/// allowed only when the API says `true`. Login seeds it, [refresh]
/// replaces it with the live /users/me values, and the true keys are kept
/// in prefs 'permissions' so the app still knows them offline.
class PermissionHelper {
  static List<String> _perms = [];

  /// Load permissions from local storage
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Saved as a list (login / /users/me). Kept even when empty — every
    // permission false is a valid answer.
    final listPerms = _readList(prefs);
    if (listPerms != null) {
      _perms = listPerms;
    } else {
      // Fallback: older builds saved a comma-separated String.
      final stringPerms = _readString(prefs) ?? '';
      _perms = stringPerms
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    debugPrint('LOADED PERMISSIONS => $_perms');
  }

  static List<String>? _readList(SharedPreferences prefs) {
    try {
      return prefs.getStringList('permissions');
    } catch (_) {
      return null; // stored as a String
    }
  }

  static String? _readString(SharedPreferences prefs) {
    try {
      return prefs.getString('permissions');
    } catch (_) {
      return null;
    }
  }

  /// Check permission
  static bool can(String permission) {
    return _perms.contains(permission);
  }

  /// Saves a `role.permissions` map (true / false per key) as the current
  /// permissions. When anything changed, every mounted screen rebuilds so
  /// menus, bottom-nav tabs and detail tabs appear or disappear at once.
  static Future<void> apply(Map<dynamic, dynamic> permissions) async {
    final allowed = [
      for (final e in permissions.entries)
        if (e.value == true) e.key.toString(),
    ]..sort();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('permissions', allowed);

    final before = [..._perms]..sort();
    _perms = allowed;
    if (before.join(',') != allowed.join(',')) _rebuildAll();
  }

  /// Fetches /users/me and applies its `role.permissions`. Shares the
  /// 2-minute SessionCache with the drawer, dashboard and cubits, so
  /// calling it on resume / drawer open costs no extra request. Returns
  /// the role map from the response (null when it failed — the saved
  /// permissions are kept then).
  static Future<Map<String, dynamic>?> refresh() async {
    try {
      final role = roleFrom(await SessionCache.usersMe());
      final perms = role?['permissions'];
      if (perms is Map && perms.isNotEmpty) await apply(perms);
      return role;
    } catch (e) {
      debugPrint('Permission refresh failed: $e');
      return null;
    }
  }

  /// `role` from a /users/me body (at the root, or under data/user/result).
  static Map<String, dynamic>? roleFrom(dynamic body) {
    if (body is! Map) return null;
    for (final m in [body, body['data'], body['user'], body['result']]) {
      if (m is Map && m['role'] is Map) {
        return Map<String, dynamic>.from(m['role'] as Map);
      }
      if (m is Map && m['user'] is Map && (m['user'] as Map)['role'] is Map) {
        return Map<String, dynamic>.from((m['user'] as Map)['role'] as Map);
      }
    }
    return null;
  }

  /// Marks every element under the navigator dirty — permissions are read
  /// directly in build methods, so this redraws all of them. Only runs
  /// when a permission actually changed.
  static void _rebuildAll() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (ctx as Element).visitChildren(rebuild);
  }

  /// Debug
  static void printPermissions() {
    debugPrint('Permissions => $_perms');
  }

  static void clear() {
    _perms = [];
  }
}
