// ╔══════════════════════════════════════════════════════════════╗
// ║       lib/screen/tasks/repository/task_repository.dart        ║
// ║  REPOSITORY — data access between the ViewModel and the API   ║
// ║  Service. Returns models; the ViewModel never knows where     ║
// ║  the data came from (API today, cache/local DB later).        ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/api_service/task_api_service.dart';
import 'package:crm_app/screen/tasks/model/target/target_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/model/task/task_notification_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskRepository {
  final TaskApiService apiService;

  TaskRepository(this.apiService);

  Future<List<TaskModel>> getMyTasks() async {
    final data = await apiService.getTasks();

    return (data as List? ?? [])
        .map((e) => TaskModel.fromJson(e))
        .toList();
  }

  Future<MyDashboardStatsModel> getMyDashboardStats({
    String period = 'all',
  }) async {
    final data = await apiService.getMyDashboardStats(period: period);

    return MyDashboardStatsModel.fromJson(
      (data as Map<String, dynamic>?) ?? {},
    );
  }

  /// Notifications for the logged-in user (all types; newest first as
  /// returned by the backend). A page shorter than [limit] is the last.
  Future<List<TaskNotificationModel>> getMyNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final userId = await getCurrentUserId();
    if (userId.isEmpty) {
      throw TaskApiException('User not found — please log in again');
    }

    final data = await apiService.getNotifications(
      userId: userId,
      page: page,
      limit: limit,
    );

    return (data as List? ?? [])
        .map((e) => TaskNotificationModel.fromJson(e))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await apiService.markNotificationRead(notificationId);
  }

  /// Backend replies {"success": true}; anything else is a failure.
  Future<void> deleteNotification(String notificationId) async {
    final data = await apiService.deleteNotification(notificationId);
    if (data is Map && data['success'] == false) {
      throw TaskApiException(
        data['message']?.toString() ?? 'Failed to delete notification',
      );
    }
  }

  /// Logged-in user's id, saved locally at login.
  Future<String> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? '';
  }

  /// Moves a task to [status] ('Pending' | 'In Progress' | 'In Hold' |
  /// 'Completed' | 'Rejected'). In Hold sends [reason] as holdReason.
  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
    String? reason,
  }) async {
    final note = (reason ?? '').trim();
    final data = await apiService.updateTask(
      taskId: taskId,
      body: {
        'status': status,
        if (status == 'In Hold' && note.isNotEmpty) 'holdReason': note,
      },
    );

    if (data is Map && data['success'] == false) {
      throw TaskApiException(
        data['message']?.toString() ?? 'Failed to update task',
      );
    }
  }

  /// Reports an issue on a task, optionally about one linked lead/deal.
  Future<void> reportTaskIssue({
    required String taskId,
    required String note,
    required String itemType, // 'task' | 'lead' | 'deal'
    String? itemId,
    String? itemName,
  }) async {
    await apiService.reportTaskIssue(
      taskId: taskId,
      body: {
        'note': note,
        'itemType': itemType,
        'itemId': itemId,
        'itemName': itemName,
      },
    );
  }
}
