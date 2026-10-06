import 'package:crm_app/screen/calendar/modal/calendar_model.dart';

abstract class CalendarState {}

class CalendarInitial extends CalendarState {}

class CalendarLoading extends CalendarState {}

class CalendarLoaded extends CalendarState {
  final List<CalendarEvent> events;

  CalendarLoaded(this.events);
}

class CalendarEmpty extends CalendarState {}

class CalendarNoteAdded extends CalendarState {
  final CalendarEvent note;

  CalendarNoteAdded(this.note);
}

class CalendarNoteUpdated extends CalendarState {
  final CalendarEvent note;

  CalendarNoteUpdated(this.note);
}

class CalendarNoteDeleted extends CalendarState {
  final String noteId;

  CalendarNoteDeleted(this.noteId);
}

class CalendarError extends CalendarState {
  final String message;

  CalendarError(this.message);
}