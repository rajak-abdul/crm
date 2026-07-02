// ── 🌐 POST /leads/call ──────────────────────────────────

import 'package:crm_app/screen/leads/cubit/lead_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class CallCubit extends Cubit<CallState> {
  CallCubit() : super(CallInitial());

  Future<void> makeCall(String phoneNumber) async {
    emit(CallLoading());

    try {
      final Uri uri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );

      final launched = await launchUrl(uri);

      if (!launched) {
        emit(const CallError('Unable to launch phone app'));
        return;
      }

      emit(CallSuccess());
    } catch (e) {
      emit(CallError(e.toString()));
    }
  }
}
