// ╔══════════════════════════════════════════════════════════════╗
// ║      lib/screen/tasks/repository/target_repository.dart      ║
// ║  REPOSITORY — data access between the ViewModel and the API   ║
// ║  Service. Returns models; the ViewModel never knows where     ║
// ║  the data came from (API today, cache/local DB later).        ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/api_service/target_api_service.dart';
import 'package:crm_app/screen/tasks/model/target/target_modal.dart';
import 'package:crm_app/screen/tasks/model/task/target_call_response.dart';
import 'package:crm_app/screen/tasks/model/task/task_notification_modal.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TargetRepository {
  final TargetApiService apiService;

  TargetRepository(this.apiService);

  /// Monthly lead/deal totals plus monthly and weekly calls/meetings.
  Future<MyDashboardStatsModel> getMyDashboardStats({String? period}) async {
    final data = await apiService.getMyDashboardStats(period: period);

    if (data is! Map<String, dynamic>) {
      throw TargetApiException('Unexpected dashboard stats response');
    }

    return MyDashboardStatsModel.fromJson(data);
  }

  /// The logged-in user's targets, in the order the backend returns them.
  Future<List<TargetModel>> getMyTargets() async {
    final data = await apiService.getMyTargets();

    if (data is! List) {
      throw TargetApiException('Unexpected targets response');
    }

    return [
      for (final e in data)
        if (e is Map<String, dynamic>) TargetModel.fromJson(e),
    ];
  }

  /// Logs a call against a target. The recording is optional; pass its
  /// [recordingPath] (mobile/desktop) or [recordingBytes] (web).
  Future<CallReportResponseModel> reportCall({
    required String targetId,
    required String companyName,
    required String callSummary,
    String? companyUrl,
    String? recordingPath,
    List<int>? recordingBytes,
    String? recordingName,
  }) async {
    final recording = await _multipartFile(
      path: recordingPath,
      bytes: recordingBytes,
      name: recordingName ?? 'recording',
    );

    final data = await apiService.reportCall(
      targetId: targetId,
      body: FormData.fromMap({
        'companyName': companyName,
        'callSummary': callSummary,
        'companyUrl': companyUrl ?? '',
        if (recording != null) 'recording': recording,
      }),
    );

    if (data is! Map<String, dynamic>) {
      throw TargetApiException('Unexpected call report response');
    }

    return CallReportResponseModel.fromJson(data);
  }

  /// Logs a meeting against a target. The screenshot is optional; pass
  /// its [screenshotPath] (mobile/desktop) or [screenshotBytes] (web).
  Future<MeetingReportResponseModel> reportMeeting({
    required String targetId,
    required String companyName,
    required String meetingSummary,
    String? companyUrl,
    String? screenshotPath,
    List<int>? screenshotBytes,
    String? screenshotName,
  }) async {
    final screenshot = await _multipartFile(
      path: screenshotPath,
      bytes: screenshotBytes,
      name: screenshotName ?? 'screenshot',
    );

    final data = await apiService.reportMeeting(
      targetId: targetId,
      body: FormData.fromMap({
        'companyName': companyName,
        'meetingSummary': meetingSummary,
        'companyUrl': companyUrl ?? '',
        if (screenshot != null) 'screenshot': screenshot,
      }),
    );

    if (data is! Map<String, dynamic>) {
      throw TargetApiException('Unexpected meeting report response');
    }

    return MeetingReportResponseModel.fromJson(data);
  }

  /// Notifications for the logged-in user (all types; the ViewModel keeps
  /// the target ones).
  Future<List<TaskNotificationModel>> getMyNotifications({
    int page = 1,
    int limit = 100,
  }) async {
    final userId = await getCurrentUserId();
    if (userId.isEmpty) {
      throw TargetApiException('User not found — please log in again');
    }

    final data = await apiService.getNotifications(
      userId: userId,
      page: page,
      limit: limit,
    );

    return [
      for (final e in (data as List? ?? const []))
        if (e is Map<String, dynamic>) TaskNotificationModel.fromJson(e),
    ];
  }

  Future<void> markNotificationRead(String notificationId) async {
    await apiService.markNotificationRead(notificationId);
  }

  /// Backend replies {"success": true}; anything else is a failure.
  Future<void> deleteNotification(String notificationId) async {
    final data = await apiService.deleteNotification(notificationId);
    if (data is Map && data['success'] == false) {
      throw TargetApiException(
        data['message']?.toString() ?? 'Failed to delete notification',
      );
    }
  }

  /// Moves a target to [status] ('New' | 'In Progress' | 'In Hold' |
  /// 'Completed' | 'Rejected'). In Hold sends [reason] as holdReason.
  Future<void> updateTargetStatus({
    required String targetId,
    required String status,
    String? reason,
  }) async {
    final note = (reason ?? '').trim();
    final data = await apiService.updateTarget(
      targetId: targetId,
      body: {
        'status': status,
        if (status == 'In Hold' && note.isNotEmpty) 'holdReason': note,
      },
    );

    if (data is Map && data['success'] == false) {
      throw TargetApiException(
        data['message']?.toString() ?? 'Failed to update target',
      );
    }
  }

  /// Adds a note to a target (e.g. why it is delayed).
  Future<void> addNote({
    required String targetId,
    required String text,
  }) async {
    final data = await apiService.addNote(targetId: targetId, text: text);

    if (data is Map && data['success'] == false) {
      throw TargetApiException(
        data['message']?.toString() ?? 'Failed to add note',
      );
    }
  }

  /// Sends an issue about one linked lead / deal to the admin. The item's
  /// details are copied into the note so the admin sees them as they were.
  Future<void> reportIssue({
    required String targetId,
    required String note,
    required String itemType, // 'lead' | 'deal'
    String? itemId,
    String? itemName,
    String? companyName,
    String? phoneNumber,
    String? email,
    String? value,
    String? currency,
    String? stageOrStatus,
  }) async {
    final data = await apiService.reportIssue(
      targetId: targetId,
      body: {
        'note': note,
        'itemType': itemType,
        'itemId': itemId,
        'itemName': itemName,
        'companyName': companyName ?? '',
        'phoneNumber': phoneNumber ?? '',
        'email': email ?? '',
        'value': value ?? '',
        'currency': currency ?? '',
        'stageOrStatus': stageOrStatus ?? '',
      },
    );

    if (data is Map && data['success'] == false) {
      throw TargetApiException(
        data['message']?.toString() ?? 'Failed to report issue',
      );
    }
  }

  /// Logged-in user's id, saved locally at login.
  Future<String> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? '';
  }

  /// Where to load an uploaded recording / screenshot from. Files are
  /// served by GET /files/preview?filePath= and need the bearer token.
  Future<({String url, Map<String, String> headers})> mediaSource(
    String filePath,
  ) async {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return (url: filePath, headers: const <String, String>{});
    }

    final prefs = await SharedPreferences.getInstance();
    final tenantSlug =
        (prefs.getString('tenant_slug') ?? prefs.getString('tenantSlug') ?? '')
            .trim();
    final token = prefs.getString('token') ?? '';

    return (
      url: 'https://crm-backend-api.techzarinfo.cloud/$tenantSlug/api'
          '/files/preview?filePath=${Uri.encodeComponent(filePath)}',
      headers: {if (token.isNotEmpty) 'Authorization': 'Bearer $token'},
    );
  }

  Future<MultipartFile?> _multipartFile({
    String? path,
    List<int>? bytes,
    required String name,
  }) async {
    final contentType = _mediaType(name);
    if (path != null) {
      return MultipartFile.fromFile(
        path,
        filename: name,
        contentType: contentType,
      );
    }
    if (bytes != null) {
      return MultipartFile.fromBytes(
        bytes,
        filename: name,
        contentType: contentType,
      );
    }
    return null;
  }

  static const _mimeTypes = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'amr': 'audio/amr',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'mkv': 'video/x-matroska',
    '3gp': 'video/3gpp',
  };

  DioMediaType? _mediaType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final mime = _mimeTypes[ext];
    return mime == null ? null : DioMediaType.parse(mime);
  }
}
