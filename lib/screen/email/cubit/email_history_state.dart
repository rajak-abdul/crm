import 'package:crm_app/screen/email/modal/scheduled_email_modal.dart';

abstract class EmailHistoryState {
  const EmailHistoryState();
}

// ============================================================
// INITIAL
// ============================================================

class EmailHistoryInitial extends EmailHistoryState {
  const EmailHistoryInitial();
}

// ============================================================
// LOADING
// ============================================================

class EmailHistoryLoading extends EmailHistoryState {
  const EmailHistoryLoading();
}

// ============================================================
// SUCCESS
// ============================================================

class EmailHistorySuccess extends EmailHistoryState {
  final List<ScheduledEmail> emails;

  final int total;
  final int page;
  final int totalPages;

  const EmailHistorySuccess({
    required this.emails,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  int get count => emails.length;
}

// ============================================================
// ERROR
// ============================================================

class EmailHistoryError extends EmailHistoryState {
  final String message;

  const EmailHistoryError(this.message);
}