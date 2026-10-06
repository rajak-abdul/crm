import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modal/proposal_modal.dart';
import 'draft_proposal_state.dart';

class DraftProposalCubit extends Cubit<DraftProposalState> {
  DraftProposalCubit() : super(const DraftProposalInitial());

  final Dio dio = Dio();

  String _tenantSlug = '';

  // ----------------------------------------------------------
  // INITIALIZE DIO
  // ----------------------------------------------------------

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
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

    dio.options.headers['Accept'] = 'application/json';

    dio.options.connectTimeout =
        const Duration(seconds: 30);

    dio.options.receiveTimeout =
        const Duration(seconds: 30);

    if (!dio.interceptors.any(
      (interceptor) => interceptor is AuthInterceptor,
    )) {
      dio.interceptors.add(AuthInterceptor());
    }
  }

  // ----------------------------------------------------------
  // GET DRAFT PROPOSALS
  // ----------------------------------------------------------

  Future<void> getDraftProposals() async {
    try {
      emit(const DraftProposalLoading());

      await initialize();

      debugPrint(
        'Get drafts URL: '
        '${dio.options.baseUrl}/proposal/drafts',
      );

      final response = await dio.get(
        '/proposal/drafts',
      );

      debugPrint(
        'Get drafts status: ${response.statusCode}',
      );

      debugPrint(
        'Get drafts response: ${response.data}',
      );

      if (response.data is List) {
        final drafts = (response.data as List)
            .whereType<Map>()
            .map(
              (e) => Proposal.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList();

        emit(
          DraftProposalLoaded(drafts),
        );
      } else {
        emit(
          const DraftProposalError(
            'Invalid draft proposal response',
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint(
        'Get drafts error: ${e.response?.statusCode}',
      );

      debugPrint(
        'Get drafts response: ${e.response?.data}',
      );

      String errorMessage =
          'Failed to load draft proposals';

      if (e.response?.data is Map) {
        final data = Map<String, dynamic>.from(
          e.response!.data,
        );

        errorMessage =
            data['message']?.toString() ??
            errorMessage;
      } else if (e.message != null &&
          e.message!.isNotEmpty) {
        errorMessage = e.message!;
      }

      emit(
        DraftProposalError(errorMessage),
      );
    } catch (e) {
      debugPrint(
        'Get drafts exception: $e',
      );

      emit(
        DraftProposalError(
          e.toString(),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // SEND DRAFT PROPOSAL
  // ----------------------------------------------------------

Future<void> sendDraftProposal(String proposalId) async {
  try {
    final currentState = state;

    if (currentState is DraftProposalLoaded) {
      emit(
        DraftProposalLoaded(
          currentState.drafts,
          sendingProposalId: proposalId,
        ),
      );
    }

    await initialize();

    final response = await dio.post(
      '/proposal/send-draft/$proposalId',
    );

    if (response.data is! Map) {
      if (currentState is DraftProposalLoaded) {
        emit(
          DraftProposalLoaded(
            currentState.drafts,
          ),
        );
      }
      return;
    }

    final data = Map<String, dynamic>.from(response.data);

    final proposalData = data['proposal'];

    if (proposalData is! Map) {
      if (currentState is DraftProposalLoaded) {
        emit(
          DraftProposalLoaded(
            currentState.drafts,
          ),
        );
      }
      return;
    }

    // Reload the drafts.
    await getDraftProposals();
  } on DioException catch (e) {
    debugPrint(
      'Send draft error: ${e.response?.data}',
    );

    await getDraftProposals();
  } catch (e) {
    debugPrint('Send draft error: $e');

    await getDraftProposals();
  }
}
}