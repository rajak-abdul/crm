

import 'package:crm_app/screen/email/modal/scheduled_email_modal.dart';

abstract class ScheduledEmailState {
  const ScheduledEmailState();
}

// ============================================================
// INITIAL
// ============================================================

class ScheduledEmailInitial extends ScheduledEmailState {
  const ScheduledEmailInitial();
}

// ============================================================
// LOADING
// ============================================================

class ScheduledEmailLoading extends ScheduledEmailState {
  const ScheduledEmailLoading();
}

// ============================================================
// SUCCESS
// ============================================================

class ScheduledEmailSuccess extends ScheduledEmailState {
  final List<ScheduledEmail> emails;

  const ScheduledEmailSuccess(this.emails);

  int get count => emails.length;
}

// ============================================================
// ERROR
// ============================================================

class ScheduledEmailError extends ScheduledEmailState {
  final String message;

  const ScheduledEmailError(this.message);
}