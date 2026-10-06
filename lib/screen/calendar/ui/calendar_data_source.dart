import 'package:crm_app/screen/calendar/UI/calendar_category.dart';
import 'package:crm_app/screen/calendar/modal/calendar_model.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

/// Wraps [CalendarEvent]s so they can be rendered by [SfCalendar].
class CalendarEventDataSource extends CalendarDataSource {
  CalendarEventDataSource(List<CalendarEvent> events) {
    appointments = events;
  }

  CalendarEvent _eventAt(int index) => appointments![index] as CalendarEvent;

  // SfCalendar renders appointments at these DateTime's own field values, so
  // an event's UTC timestamp from the API must be converted to local wall
  // clock time first, or it plots at the wrong cell for any timezone with
  // a non-zero UTC offset.
  @override
  DateTime getStartTime(int index) => _eventAt(index).date.toLocal();

  @override
  DateTime getEndTime(int index) {
    final event = _eventAt(index);
    return (event.endDate ?? event.date.add(const Duration(hours: 1)))
        .toLocal();
  }

  @override
  String getSubject(int index) => _eventAt(index).title;

  @override
  Color getColor(int index) => categoryInfoOf(_eventAt(index).type).color;

  @override
  bool isAllDay(int index) => false;
}
