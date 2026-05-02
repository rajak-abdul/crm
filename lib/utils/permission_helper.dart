import 'package:shared_preferences/shared_preferences.dart';

class PermissionHelper {
  static List<String> _perms = [];

  /// Load permissions from local storage
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _perms = prefs.getStringList('permissions') ?? [];
  }

  /// Check permission
 static bool can(String permission) {

  // ✅ Normal permission
  return _perms.contains(permission);
}

  /// Optional: debug
  static void printPermissions() {
    print('Permissions: $_perms');
  }
  static void clear() {
  _perms = [];
}
}