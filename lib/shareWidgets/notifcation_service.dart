import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: android,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        final path = response.payload;

        if (path != null && path.isNotEmpty) {
          await OpenFile.open(path);
        }
      },
    );
  }

  static Future<void> showDownloadNotification({
    required String fileName,
    required String filePath,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'downloads_channel',
      'Downloads',
      channelDescription: 'Download notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Download Complete',
      fileName,
      details,
      payload: filePath,
    );
  }
}