import 'package:crm_app/screen/meeting/modal/meeting.dart';


abstract class MeetingsState {
  const MeetingsState();
}

class MeetingsInitial extends MeetingsState {
  const MeetingsInitial();
}

class MeetingsLoading extends MeetingsState {
  const MeetingsLoading();
}

class MeetingsLoaded extends MeetingsState {
  final List<Meeting> meetings;
  final bool googleConnected;

  const MeetingsLoaded({
    required this.meetings,
    required this.googleConnected,
  });
}

class MeetingsCreating extends MeetingsState {
  final List<Meeting> meetings;
  final bool googleConnected;

  const MeetingsCreating({
    required this.meetings,
    required this.googleConnected,
  });
}

class MeetingsError extends MeetingsState {
  final String message;

  const MeetingsError(this.message);
}