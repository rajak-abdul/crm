// ══════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════
import 'package:crm_app/screen/notification/model/notification_model.dart';
import 'package:equatable/equatable.dart';

abstract class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool hasMore;
  final int currentPage;

  const NotificationLoaded({
    required this.notifications,
    required this.unreadCount,
    this.hasMore = false,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [notifications, unreadCount, hasMore, currentPage];
}

class NotificationError extends NotificationState {
  final String message;
  const NotificationError(this.message);
  @override
  List<Object?> get props => [message];
}
