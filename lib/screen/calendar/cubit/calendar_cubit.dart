
import 'package:crm_app/screen/calendar/modal/calendar_model.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_state.dart';

class CalendarCubit extends Cubit<CalendarState> {
  final Dio dio;

  String _tenantSlug = '';

  CalendarCubit(this.dio) : super(CalendarInitial());

  // The merged calendar feed (GET /calendar) prefixes note ids as
  // "note-<objectId>" to keep them unique alongside other event types,
  // but the notes API (POST/PUT /calendar/notes) works with the raw Mongo
  // ObjectId on both ends. Normalize to the prefixed form here so a note
  // added/updated in this session matches the id shape used elsewhere in
  // the loaded event list without requiring a full reload.
  CalendarEvent _parseNoteEvent(Map<String, dynamic> json) {
    final event = CalendarEvent.fromJson(json);
    if (event.id.startsWith('note-')) return event;

    return CalendarEvent(
      id: 'note-${event.id}',
      type: event.type,
      title: event.title,
      date: event.date,
      endDate: event.endDate,
      status: event.status,
      pending: event.pending,
      dealId: event.dealId,
      dealName: event.dealName,
      leadId: event.leadId,
      leadName: event.leadName,
      editable: event.editable,
      link: event.link,
    );
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _tenantSlug = (
      prefs.getString('tenant_slug') ??
      prefs.getString('tenantSlug') ??
      ''
    ).trim();

    if (_tenantSlug.isEmpty) {
      throw Exception('Tenant slug not found');
    }

    dio.options.baseUrl =
        'https://crm-backend-api.techzarinfo.cloud/'
        '$_tenantSlug/api';

    final token = prefs.getString('token') ?? '';

    if (token.isNotEmpty) {
      dio.options.headers['Authorization'] =
          'Bearer $token';
    }

    dio.options.headers['Accept'] = 'application/json';

    dio.options.connectTimeout = const Duration(seconds: 30);

    dio.options.receiveTimeout = const Duration(seconds: 30);

    if (!dio.interceptors.any(
      (interceptor) => interceptor is AuthInterceptor,
    )) {
      dio.interceptors.add(AuthInterceptor());
    }
  }

  Future<void> loadCalendar({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      emit(CalendarLoading());

      final response = await dio.get(
        '/calendar',
        queryParameters: {
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );

      final calendarResponse = CalendarResponse.fromJson(
        response.data as Map<String, dynamic>,
      );

      if (calendarResponse.events.isEmpty) {
        emit(CalendarEmpty());
      } else {
        emit(CalendarLoaded(calendarResponse.events));
      }
    } on DioException catch (e) {
      emit(
        CalendarError(
          e.response?.data is Map<String, dynamic>
              ? e.response?.data['message']?.toString() ??
                  'Failed to load calendar events'
              : e.message ?? 'Failed to load calendar events',
        ),
      );
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> addCalendarNote({
  required DateTime date,
  required String text,
}) async {
  try {
    emit(CalendarLoading());

    final response = await dio.post(
      '/calendar/notes',
      data: {
        'date': date.toUtc().toIso8601String(),
        'text': text,
      },
    );

    final note = _parseNoteEvent(
      response.data['note'] as Map<String, dynamic>,
    );

    emit(CalendarNoteAdded(note));

    // Optional: reload calendar from API after adding the note.
    // No local/offline storage is used.
  } on DioException catch (e) {
    emit(
      CalendarError(
        e.response?.data is Map<String, dynamic>
            ? e.response?.data['message']?.toString() ??
                'Failed to add note'
            : e.message ?? 'Failed to add note',
      ),
    );
  } catch (e) {
    emit(CalendarError(e.toString()));
  }
}

Future<void> updateCalendarNote({
  required String noteId,
  required DateTime date,
  required String text,
}) async {
  try {
    emit(CalendarLoading());

    // The merged calendar feed prefixes note ids as "note-<objectId>" to
    // keep them unique alongside other event types, but the notes API
    // expects the raw Mongo ObjectId in the route.
    final rawNoteId =
        noteId.startsWith('note-') ? noteId.substring(5) : noteId;

    final response = await dio.put(
      '/calendar/notes/$rawNoteId',
      data: {
        'text': text,
      },
    );

    final note = _parseNoteEvent(
      response.data['note'] as Map<String, dynamic>,
    );

    emit(CalendarNoteUpdated(note));
  } on DioException catch (e) {
    emit(
      CalendarError(
        e.response?.data is Map<String, dynamic>
            ? e.response?.data['message']?.toString() ??
                'Failed to update note'
            : e.message ?? 'Failed to update note',
      ),
    );
  } catch (e) {
    emit(CalendarError(e.toString()));
  }
}

Future<void> deleteCalendarNote({
  required String noteId,
}) async {
  try {
    emit(CalendarLoading());

    // Same "note-<objectId>" vs raw ObjectId mismatch handled in
    // updateCalendarNote — the notes API expects the raw id in the route.
    final rawNoteId =
        noteId.startsWith('note-') ? noteId.substring(5) : noteId;

    await dio.delete(
      '/calendar/notes/$rawNoteId',
    );

    emit(CalendarNoteDeleted(noteId));
  } on DioException catch (e) {
    emit(
      CalendarError(
        e.response?.data is Map<String, dynamic>
            ? e.response?.data['message']?.toString() ??
                'Failed to delete note'
            : e.message ?? 'Failed to delete note',
      ),
    );
  } catch (e) {
    emit(CalendarError(e.toString()));
  }
}
}