import 'package:shared_preferences/shared_preferences.dart';

class PermissionHelper {
  static List<String> _perms = [];

  /// Load permissions from local storage
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // First try StringList
    final listPerms = prefs.getStringList('permissions');

    if (listPerms != null && listPerms.isNotEmpty) {
      _perms = listPerms;
    } else {
      // Fallback: try normal String
      final stringPerms = prefs.getString('permissions') ?? '';

      if (stringPerms.isNotEmpty) {
        _perms = stringPerms
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        _perms = [];
      }
    }

    print('LOADED PERMISSIONS => $_perms');
  }

  /// Check permission
  static bool can(String permission) {
    return _perms.contains(permission);
  }

  /// Debug
  static void printPermissions() {
    print('Permissions => $_perms');
  }

  static void clear() {
    _perms = [];
  }
}
