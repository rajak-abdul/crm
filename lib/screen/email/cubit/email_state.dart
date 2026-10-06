import 'package:crm_app/screen/email/modal/email_modal.dart';

abstract class EmailContactsState {
  const EmailContactsState();
}

class EmailContactsInitial extends EmailContactsState {
  const EmailContactsInitial();
}

class EmailContactsLoading extends EmailContactsState {
  const EmailContactsLoading();
}

class EmailContactsSuccess extends EmailContactsState {
  final EmailContactsResponse response;

  const EmailContactsSuccess(this.response);

  List<EmailContact> get contacts => response.contacts;

  int get total => response.total;

  int get page => response.page;

  int get limit => response.limit;

  int get leadCount => response.leadCount;

  int get dealCount => response.dealCount;
}

class EmailContactsError extends EmailContactsState {
  final String message;

  const EmailContactsError(this.message);
}

