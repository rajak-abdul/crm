import 'package:crm_app/screen/email/modal/email_template_modal.dart';

abstract class EmailTemplateState {
  const EmailTemplateState();
}

class EmailTemplateInitial extends EmailTemplateState {
  const EmailTemplateInitial();
}

class EmailTemplateLoading extends EmailTemplateState {
  const EmailTemplateLoading();
}

class EmailTemplateSuccess extends EmailTemplateState {
  final EmailTemplatesResponse response;

  const EmailTemplateSuccess(this.response);

  List<EmailTemplate> get templates =>
      response.templates;

  // NEW
  int get total =>
      response.total;
}

class EmailTemplateError extends EmailTemplateState {
  final String message;

  const EmailTemplateError(this.message);
}

class BulkEmailInitial extends EmailTemplateState {
  const BulkEmailInitial();
}

class BulkEmailLoading extends EmailTemplateState {
  const BulkEmailLoading();
}

class BulkEmailSuccess extends EmailTemplateState {
  final String message;

  const BulkEmailSuccess(this.message);
}

class BulkEmailError extends EmailTemplateState {
  final String message;

  const BulkEmailError(this.message);
}