import 'package:crm_app/screen/proposal/cubit/draft_proposal_state.dart';
import 'package:crm_app/screen/proposal/cubit/proposal_state.dart';
import 'package:crm_app/screen/proposal/modal/proposal_modal.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProposalCubit extends Cubit<ProposalState> {
  late final Dio dio;

  String _tenantSlug = '';

  ProposalCubit()
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
        super( ProposalInitial());

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    final prefs =
        await SharedPreferences.getInstance();

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

    final token =
        prefs.getString('token') ?? '';

    if (token.isNotEmpty) {
      dio.options.headers['Authorization'] =
          'Bearer $token';
    }

    dio.options.headers['Accept'] =
        'application/json';

    dio.options.connectTimeout =
        const Duration(seconds: 30);

    dio.options.receiveTimeout =
        const Duration(seconds: 30);

    // Add only once
    if (!dio.interceptors
        .any((interceptor) =>
            interceptor is AuthInterceptor)) {
      dio.interceptors.add(
        AuthInterceptor(),
      );
    }
  }

  // ============================================================
  // GET ALL PROPOSALS
  // ============================================================

  Future<void> getProposals() async {
    try {
      emit( ProposalLoading());

      // Make sure tenant + token are initialized
      await initialize();

      debugPrint(
        'Proposal base URL: ${dio.options.baseUrl}',
      );

      debugPrint(
        'Proposal token exists: '
        '${dio.options.headers['Authorization'] != null}',
      );

      final response = await dio.get(
        '/proposal/getall',
      );

      debugPrint(
        'Proposal status: ${response.statusCode}',
      );

      debugPrint(
        'Proposal response: ${response.data}',
      );

      if (response.data is List) {
        final proposals =
            (response.data as List)
                .map(
                  (e) => Proposal.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList();

        emit(
          ProposalLoaded(proposals),
        );
      } else {
        emit(
          const ProposalError(
            'Invalid proposal response',
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint(
        'Proposal API error: '
        '${e.response?.statusCode}',
      );

      debugPrint(
        'Proposal API response: '
        '${e.response?.data}',
      );

      debugPrint(
        'Proposal API URL: '
        '${e.requestOptions.uri}',
      );

      emit(
        ProposalError(
          e.response?.data is Map
              ? e.response?.data['message']
                      ?.toString() ??
                  'Failed to load proposals'
              : 'Failed to load proposals',
        ),
      );
    } catch (e) {
      debugPrint(
        'Proposal error: $e',
      );

      emit(
        ProposalError(
          e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // UPDATE PROPOSAL STATUS
  // ============================================================

  Future<void> updateProposalStatus({
  required String proposalId,
  required String status,
}) async {
  try {
    await initialize();

    final response = await dio.put(
      '/proposal/updatestatus/$proposalId',
      data: {
        'status': status,
      },
    );

    debugPrint(
      'Update proposal status: ${response.statusCode}',
    );

    debugPrint(
      'Update proposal response: ${response.data}',
    );

    if (response.statusCode == 200) {
      // Refresh the proposal list so the card
      // always contains the latest API data.
      await getProposals();
    }
  } on DioException catch (e) {
    debugPrint(
      'Update proposal status error: '
      '${e.response?.statusCode}',
    );

    debugPrint(
      'Update proposal status response: '
      '${e.response?.data}',
    );

    emit(
      ProposalError(
        e.response?.data is Map
            ? e.response?.data['message']?.toString() ??
                'Failed to update status'
            : 'Failed to update status',
      ),
    );
  } catch (e) {
    debugPrint(
      'Update proposal status error: $e',
    );

    emit(
      ProposalError(
        e.toString(),
      ),
    );
  }
}

// ============================================================
// UPDATE PROPOSAL FOLLOW-UP DATE
// ============================================================
Future<void> updateProposalFollowUp({
  required String proposalId,
  required DateTime followUpDate,
  required String followUpComment,
}) async {
  try {
    await initialize();

    debugPrint(
      'Updating proposal follow-up: $proposalId',
    );

    final response = await dio.put(
      '/proposal/followup/$proposalId',
      data: {
        'followUpDate':
            followUpDate.toUtc().toIso8601String(),
        'followUpComment':
            followUpComment,
      },
    );

    debugPrint(
      'Follow-up status: ${response.statusCode}',
    );

    debugPrint(
      'Follow-up response: ${response.data}',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update follow-up',
      );
    }

    // ============================================================
    // GET UPDATED PROPOSAL FROM RESPONSE
    // ============================================================

    final responseData =
        Map<String, dynamic>.from(response.data);

    final proposalData = responseData['proposal'];

    if (proposalData is! Map) {
      throw Exception(
        'Updated proposal data not found',
      );
    }

    final updatedProposal = Proposal.fromJson(
      Map<String, dynamic>.from(proposalData),
    );

    // ============================================================
    // UPDATE CURRENT LIST
    // ============================================================

    final currentState = state;

    if (currentState is ProposalLoaded) {
      final updatedProposals =
          currentState.proposals.map((proposal) {
        if (proposal.id == updatedProposal.id) {
          return updatedProposal;
        }

        return proposal;
      }).toList();

      emit(
        ProposalLoaded(updatedProposals),
      );
    }

    debugPrint(
      'Proposal follow-up updated successfully',
    );
  } on DioException catch (e) {
    debugPrint(
      'Follow-up API error: '
      '${e.response?.statusCode}',
    );

    debugPrint(
      'Follow-up API response: '
      '${e.response?.data}',
    );

    throw Exception(
      e.response?.data is Map
          ? e.response?.data['message']?.toString() ??
              'Failed to update follow-up'
          : 'Failed to update follow-up',
    );
  } catch (e) {
    debugPrint(
      'Follow-up exception: $e',
    );

    rethrow;
  }
}

// ============================================================
// Delete Proposal
// ============================================================
Future<void> deleteProposal({
  required String proposalId,
}) async {
  try {
    await initialize();

    debugPrint(
      'Deleting proposal: $proposalId',
    );

    final response = await dio.delete(
      '/proposal/delete/$proposalId',
    );

    debugPrint(
      'Delete proposal status: ${response.statusCode}',
    );

    debugPrint(
      'Delete proposal response: ${response.data}',
    );

    if (response.statusCode == 200) {
      final currentState = state;

      // Remove deleted proposal immediately from current list
      if (currentState is ProposalLoaded) {
        final updatedProposals =
            currentState.proposals
                .where(
                  (proposal) =>
                      proposal.id != proposalId,
                )
                .toList();

        emit(
          ProposalLoaded(updatedProposals),
        );
      }
    } else {
      throw Exception(
        'Failed to delete proposal',
      );
    }
  } on DioException catch (e) {
    debugPrint(
      'Delete proposal error: '
      '${e.response?.statusCode}',
    );

    debugPrint(
      'Delete proposal response: '
      '${e.response?.data}',
    );

    throw Exception(
      e.response?.data is Map
          ? e.response?.data['message']?.toString() ??
              'Failed to delete proposal'
          : 'Failed to delete proposal',
    );
  } catch (e) {
    debugPrint(
      'Delete proposal exception: $e',
    );

    rethrow;
  }
}

// ============================================================
// CREATE PROPOSAL
// ============================================================

Future<void> createProposal({
  String? proposalId,
  required String title,
  required String selectedDealId,
  required String dealTitle,
  required String cc,
  required String content,
  required String emails,
  required bool isDraft,
  List<PlatformFile> attachments = const [],
}) async {
  try {
    await initialize();

    final formData = FormData();

    if (proposalId != null && proposalId.isNotEmpty) {
    formData.fields.add(
    MapEntry('id', proposalId),
   );
  }


    // Text fields
    formData.fields.add(
      MapEntry('title', title),
    );

    formData.fields.add(
      MapEntry('dealTitle', dealTitle),
    );

    formData.fields.add(
      MapEntry('selectedDealId', selectedDealId),
    );

    formData.fields.add(
      MapEntry('cc', cc),
    );

    formData.fields.add(
      MapEntry('content', content),
    );

    formData.fields.add(
      MapEntry('emails', emails),
    );

    formData.fields.add(
      MapEntry(
        'isDraft',
        isDraft.toString(),
      ),
    );

    // Binary attachments
    for (final file in attachments) {
      if (file.path == null) continue;

      formData.files.add(
        MapEntry(
          'attachments',
          await MultipartFile.fromFile(
            file.path!,
            filename: file.name,
          ),
        ),
      );
    }

    final response = await dio.post(
      '/proposal/mailsend',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      await getProposals();
    } else {
      throw Exception(
        'Failed to create proposal',
      );
    }
  } on DioException catch (e) {
    final message =
        e.response?.data is Map
            ? e.response?.data['message']?.toString() ??
                'Failed to create proposal'
            : 'Failed to create proposal';

    throw Exception(message);
  } catch (e) {
    rethrow;
  }
}

// ============================================================
// GET DRAFT PROPOSALS
// ============================================================

Future<void> getDraftProposals() async {
  try {
    emit(ProposalLoading());

    await initialize();

    debugPrint(
      'Draft Proposal base URL: ${dio.options.baseUrl}',
    );

    final response = await dio.get(
      '/proposal/drafts',
    );

    debugPrint(
      'Draft Proposal status: ${response.statusCode}',
    );

    debugPrint(
      'Draft Proposal response: ${response.data}',
    );

    if (response.data is List) {
      final drafts = (response.data as List)
          .map(
            (e) => Proposal.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();

      emit(
        ProposalLoaded(drafts),
      );
    } else {
      emit(
        const ProposalError(
          'Invalid draft proposal response',
        ),
      );
    }
  } on DioException catch (e) {
    debugPrint(
      'Draft Proposal API error: '
      '${e.response?.statusCode}',
    );

    debugPrint(
      'Draft Proposal API response: '
      '${e.response?.data}',
    );

    debugPrint(
      'Draft Proposal API URL: '
      '${e.requestOptions.uri}',
    );

    emit(
      ProposalError(
        e.response?.data is Map
            ? e.response?.data['message']?.toString() ??
                'Failed to load draft proposals'
            : 'Failed to load draft proposals',
      ),
    );
  } catch (e) {
    debugPrint(
      'Draft Proposal error: $e',
    );

    emit(
      ProposalError(
        e.toString(),
      ),
    );
  }
}

// ============================================================
// BULK DELETE PROPOSALS
// ============================================================

Future<void> bulkDeleteProposals({
  required List<String> proposalIds,
}) async {
  try {
    if (proposalIds.isEmpty) {
      throw Exception('Please select at least one proposal');
    }

    await initialize();

    debugPrint('Bulk deleting proposals: $proposalIds');

    final response = await dio.delete(
      '/proposal/bulk-delete',
      data: {
        'ids': proposalIds,
      },
    );

    debugPrint('Bulk delete status: ${response.statusCode}');
    debugPrint('Bulk delete response: ${response.data}');

    if (response.statusCode == 200 &&
        response.data is Map &&
        response.data['success'] == true) {
      final currentState = state;

      if (currentState is ProposalLoaded) {
        final updatedProposals =
            currentState.proposals.where((proposal) {
          return !proposalIds.contains(proposal.id);
        }).toList();

        emit(ProposalLoaded(updatedProposals));
      }

      debugPrint('Proposals deleted successfully');
    } else {
      throw Exception(
        response.data is Map
            ? response.data['message']?.toString() ??
                'Failed to delete proposals'
            : 'Failed to delete proposals',
      );
    }
  } on DioException catch (e) {
    debugPrint(
      'Bulk delete error: ${e.response?.statusCode}',
    );
    debugPrint('Bulk delete response: ${e.response?.data}');

    throw Exception(
      e.response?.data is Map
          ? e.response?.data['message']?.toString() ??
              'Failed to delete proposals'
          : 'Failed to delete proposals',
    );
  } catch (e) {
    debugPrint('Bulk delete exception: $e');
    rethrow;
  }
}

// ============================================================
// SEND DRAFT PROPOSAL
// ============================================================

Future<void> sendDraftProposal(
  String proposalId,
) async {
  try {
    emit(
      SendDraftProposalLoading(
        proposalId,
      ) as ProposalState,
    );

    await initialize();

    debugPrint(
      'Sending draft proposal: $proposalId',
    );

    debugPrint(
      'Send draft URL: '
      '${dio.options.baseUrl}/proposal/send-draft/$proposalId',
    );

    final response = await dio.post(
      '/proposal/send-draft/$proposalId',
    );

    debugPrint(
      'Send draft status: ${response.statusCode}',
    );

    debugPrint(
      'Send draft response: ${response.data}',
    );

    if (response.data is! Map) {
      emit(
        const SendDraftProposalError(
          'Invalid send draft response',
        ) as ProposalState,
      );
      return;
    }

    final data = Map<String, dynamic>.from(
      response.data,
    );

    final message =
        data['message']?.toString() ??
        'Proposal sent successfully!';

    final proposalData = data['proposal'];

    if (proposalData is! Map) {
      emit(
        const SendDraftProposalError(
          'Proposal data not found',
        ) as ProposalState,
      );
      return;
    }

    final sentProposal = Proposal.fromJson(
      Map<String, dynamic>.from(
        proposalData,
      ),
    );

    emit(
      SendDraftProposalSuccess(
        message: message,
        proposal: sentProposal,
      ) as ProposalState,
    );

    // Refresh draft list.
    // The sent proposal should no longer be a draft.
    await getDraftProposals();

  } on DioException catch (e) {
    debugPrint(
      'Send draft API error: '
      '${e.response?.statusCode}',
    );

    debugPrint(
      'Send draft API response: '
      '${e.response?.data}',
    );

    debugPrint(
      'Send draft API URL: '
      '${e.requestOptions.uri}',
    );

    String errorMessage =
        'Failed to send proposal';

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
      SendDraftProposalError(
        errorMessage,
      ) as ProposalState,
    );

  } catch (e) {
    debugPrint(
      'Send draft error: $e',
    );

    emit(
      SendDraftProposalError(
        e.toString(),
      ) as ProposalState,
    );
  }
}
}