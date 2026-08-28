import 'package:crm_app/screen/meeting/cubit/meeting_state.dart';
import 'package:crm_app/screen/meeting/modal/meeting.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';


class MeetingsCubit extends Cubit<MeetingsState> {
   late final Dio dio;

  MeetingsCubit()
      : dio = Dio(
          BaseOptions(
            baseUrl:
                'https://crm-backend-api.techzarinfo.cloud/',
            connectTimeout:
                const Duration(seconds: 30),
            receiveTimeout:
                const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ),
        super(const MeetingsInitial()) {
    dio.interceptors.add(AuthInterceptor());
  }


  // ============================================================
  // CHECK GOOGLE CONNECTION
  // ============================================================

  Future<bool> checkGoogleConnection() async {
    try {
      final apiPrefix = await _getApiPrefix();

final response = await dio.get(
  '$apiPrefix/google-auth/auth/status',
);

      if (response.data['success'] == true &&
          response.data['connected'] == true) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // CHECK ZOOM CONNECTION
  // ============================================================

  Future<bool> checkZoomConnection() async {
    try {
      final apiPrefix = await _getApiPrefix();

      final response = await dio.get(
        '$apiPrefix/zoom-auth/auth/status',
      );

      if (response.data['success'] == true &&
          response.data['connected'] == true) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // LOAD MEETINGS
  // ============================================================

  Future<void> loadMeetings() async {
    if (isClosed) return;
    emit(const MeetingsLoading());

    try {
      // First check Google authentication
      final googleConnected = await checkGoogleConnection();

      // Then get meetings
      final apiPrefix = await _getApiPrefix();

final response = await dio.get(
  '$apiPrefix/meetings',
);

      if (isClosed) return;

      if (response.data['success'] != true) {
        emit(
          const MeetingsError(
            'Failed to load meetings.',
          ),
        );
        return;
      }

      final List<dynamic> data =
          response.data['meetings'] ?? [];

      final meetings = data
          .map(
            (json) => Meeting.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList();

      emit(
        MeetingsLoaded(
          meetings: meetings,
          googleConnected: googleConnected,
        ),
      );
    } on DioException catch (e) {
      // The bloc can be closed mid-flight if the sheet/screen that owns
      // it is torn down before this request resolves (e.g. the missed
      // follow-up flow's modal sheet). Emitting on a closed Cubit throws
      // an uncaught "Bad state" that Flutter's Navigator handles poorly.
      if (isClosed) return;
      emit(
        MeetingsError(
          _dioErrorMessage(e),
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        MeetingsError(
          e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // CREATE MEETING
  // ============================================================

  Future<bool> createMeeting({
    required String title,
    String description = '',
    String? dealId,
    String? leadId,
    required DateTime startDateTime,
    required DateTime endDateTime,
    List<String> attendees = const [],
    int reminderMinutes = 10,
    String provider = 'google_meet',
  }) async {
    try {
      // ALWAYS verify Google before creating
      final googleConnected = await checkGoogleConnection();

      if (!googleConnected) {
        final currentMeetings = _currentMeetings();

        emit(
          MeetingsLoaded(
            meetings: currentMeetings,
            googleConnected: false,
          ),
        );

        return false;
      }

      final currentMeetings = _currentMeetings();

      emit(
        MeetingsCreating(
          meetings: currentMeetings,
          googleConnected: true,
        ),
      );
      final apiPrefix = await _getApiPrefix();


      final response = await dio.post(
        '$apiPrefix/meetings',
        data: {
          'title': title,
          'description': description,
          'dealId': dealId,
          'leadId': leadId,
          'startDateTime':
              startDateTime.toUtc().toIso8601String(),
          'endDateTime':
              endDateTime.toUtc().toIso8601String(),
          'attendees': attendees,
          'provider': provider,
          'reminderMinutes': reminderMinutes,
        },
      );

      if (response.data['success'] != true) {
        emit(
          MeetingsLoaded(
            meetings: currentMeetings,
            googleConnected: true,
          ),
        );

        return false;
      }

      final meetingJson =
          Map<String, dynamic>.from(
        response.data['meeting'],
      );

      final newMeeting =
          Meeting.fromJson(meetingJson);

      final updatedMeetings = [
        newMeeting,
        ...currentMeetings,
      ];

      emit(
        MeetingsLoaded(
          meetings: updatedMeetings,
          googleConnected: true,
        ),
      );

      return true;
    } on DioException catch (e) {
      emit(
        MeetingsError(
          _dioErrorMessage(e),
        ),
      );

      return false;
    } catch (e) {
      emit(
        MeetingsError(
          e.toString(),
        ),
      );

      return false;
    }
  }

  // ============================================================
  // UPDATE MEETING
  // ============================================================
Future<bool> updateMeeting({
  required String meetingId,
  required String title,
  String description = '',
  String? dealId,
  String? leadId,
  required DateTime startDateTime,
  required DateTime endDateTime,
  List<String> attendees = const [],
  int reminderMinutes = 10,
  String provider = 'google_meet',
}) async {
  try {
    final googleConnected = await checkGoogleConnection();

    if (!googleConnected) {
      final currentMeetings = _currentMeetings();

      emit(
        MeetingsLoaded(
          meetings: currentMeetings,
          googleConnected: false,
        ),
      );

      return false;
    }

    final currentMeetings = _currentMeetings();

    emit(
      MeetingsCreating(
        meetings: currentMeetings,
        googleConnected: true,
      ),
    );

    final apiPrefix = await _getApiPrefix();

    final response = await dio.put(
      '$apiPrefix/meetings/$meetingId',
      data: {
        'title': title,
        'description': description,
        'dealId': dealId,
        'leadId': leadId,
        'startDateTime': startDateTime.toUtc().toIso8601String(),
        'endDateTime': endDateTime.toUtc().toIso8601String(),
        'attendees': attendees,
        'provider': provider,
        'reminderMinutes': reminderMinutes,
      },
    );

    debugPrint('UPDATE MEETING STATUS: ${response.statusCode}');
    debugPrint('UPDATE MEETING RESPONSE: ${response.data}');

    // Don't depend on response.data['meeting']
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      emit(
        MeetingsLoaded(
          meetings: currentMeetings,
          googleConnected: true,
        ),
      );

      return false;
    }

    // Build the updated meeting locally
    final updatedMeetings = currentMeetings.map((oldMeeting) {
      if (oldMeeting.id != meetingId) {
        return oldMeeting;
      }

      return Meeting(
        id: oldMeeting.id,
        title: title,
        description: description,
        leadId: leadId,
        dealId: dealId,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        attendees: attendees,
        reminderMinutes: reminderMinutes,
        provider: provider,
        status: oldMeeting.status,
      );
    }).toList();

    emit(
      MeetingsLoaded(
        meetings: updatedMeetings,
        googleConnected: true,
      ),
    );

    return true;
  } on DioException catch (e) {
    debugPrint('UPDATE MEETING DIO ERROR: ${e.response?.data}');
    debugPrint('UPDATE MEETING STATUS: ${e.response?.statusCode}');

    emit(
      MeetingsError(
        _dioErrorMessage(e),
      ),
    );

    return false;
  } catch (e) {
    debugPrint('UPDATE MEETING ERROR: $e');

    emit(
      MeetingsError(
        e.toString(),
      ),
    );

    return false;
  }
}
  // ============================================================
  // CANCEL MEETING
  // ============================================================
  Future<bool> cancelMeeting({
  required String meetingId,
}) async {
  try {
    final currentMeetings = _currentMeetings();

    final apiPrefix = await _getApiPrefix();

    final response = await dio.put(
      '$apiPrefix/meetings/$meetingId',
      data: {
        'status': 'cancelled',
      },
    );

    if (response.data['success'] != true) {
      emit(
        MeetingsLoaded(
          meetings: currentMeetings,
          googleConnected: true,
        ),
      );

      return false;
    }

    final meetingJson =
        Map<String, dynamic>.from(
      response.data['meeting'],
    );

    final updatedMeeting =
        Meeting.fromJson(meetingJson);

    final updatedMeetings = currentMeetings.map((meeting) {
      if (meeting.id == meetingId) {
        return updatedMeeting;
      }

      return meeting;
    }).toList();

    final googleConnected =
        await checkGoogleConnection();

    emit(
      MeetingsLoaded(
        meetings: updatedMeetings,
        googleConnected: googleConnected,
      ),
    );

    return true;
  } on DioException catch (e) {
    emit(
      MeetingsError(
        _dioErrorMessage(e),
      ),
    );

    return false;
  } catch (e) {
    emit(
      MeetingsError(
        e.toString(),
      ),
    );

    return false;
  }
}
  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refreshMeetings() async {
    await loadMeetings();
  }

  // ============================================================
  // GET CURRENT MEETINGS
  // ============================================================

  List<Meeting> _currentMeetings() {
    final currentState = state;

    if (currentState is MeetingsLoaded) {
      return currentState.meetings;
    }

    if (currentState is MeetingsCreating) {
      return currentState.meetings;
    }

    return [];
  }
// ============================================================
// CONNECT TO THE GOOGLE
// ============================================================

  Future<bool> connectGoogle() async {
  try {
    final apiPrefix = await _getApiPrefix();

    final response = await dio.get(
      '$apiPrefix/google-auth/auth/google',
    );

    if (response.data['success'] != true) {
      return false;
    }

    final authUrl = response.data['authUrl']?.toString();

    if (authUrl == null || authUrl.isEmpty) {
      return false;
    }

    final uri = Uri.parse(authUrl);

    if (!await canLaunchUrl(uri)) {
      return false;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    return true;
  } catch (e) {
    return false;
  }
}

  // ============================================================
  // DIO ERROR
  // ============================================================

  String _dioErrorMessage(DioException e) {
    if (e.response?.data is Map) {
      final data = e.response?.data;

      if (data['message'] != null) {
        return data['message'].toString();
      }
    }

    if (e.response?.statusCode == 401) {
      return 'Session expired. Please login again.';
    }

    if (e.response?.statusCode == 403) {
      return 'You do not have permission to perform this action.';
    }

    return e.message ?? 'Something went wrong.';
  }
  //====================================================
  // helper
  Future<String> _getApiPrefix() async {
  final prefs = await SharedPreferences.getInstance();

  final tenant = prefs.getString('tenant_slug');
  final token = prefs.getString('token');

  if (tenant == null || tenant.trim().isEmpty) {
    throw Exception('Tenant information not found.');
  }

  if (token == null || token.trim().isEmpty) {
    throw Exception('Authentication token not found.');
  }

  dio.options.headers['Authorization'] =
      'Bearer ${token.trim()}';

  return '${tenant.trim()}/api';
}
}