import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Returns a stable ID for this app installation.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

  /// Returns a readable device name.
  static Future<String> getDeviceLabel() async {
    try {
      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        return "${android.brand} ${android.model}";
      }

      if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        return "${ios.name} ${ios.model}";
      }

      return "Unknown Device";
    } catch (_) {
      return "Unknown Device";
    }
  }
}