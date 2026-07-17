import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    String? deviceId = prefs.getString('device_id');

    if (deviceId != null && deviceId.isNotEmpty) {
      return deviceId;
    }

    if (Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;

      deviceId = android.id; // Android ID
    } else if (Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;

      deviceId = ios.identifierForVendor;
    } else {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    await prefs.setString('device_id', deviceId!);

    return deviceId;
  }

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