import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/proposal/UI/create_proposal_screen.dart';
import 'package:crm_app/screen/proposal/cubit/draft_cubit.dart';
import 'package:crm_app/screen/proposal/cubit/proposal_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../cubit/draft_proposal_state.dart';
import '../modal/proposal_modal.dart';

class DraftProposalListScreen extends StatefulWidget {
  
  const DraftProposalListScreen({
    super.key,
  });

  @override
  State<DraftProposalListScreen> createState() =>
      _DraftProposalListScreenState();
}

class _DraftProposalListScreenState
    extends State<DraftProposalListScreen> {


  @override
  void initState() {
    super.initState();

    context
        .read<DraftProposalCubit>()
        .getDraftProposals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),

      // ============================================================
      // APP BAR
      // ============================================================

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xfff1f1f1),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,

        title: Row(
          children: [
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back,
                size: 19,
              ),
            ),

            Expanded(
              child: BlocBuilder<
                  DraftProposalCubit,
                  DraftProposalState>(
                builder: (context, state) {
                  final count = state is DraftProposalLoaded
                      ? state.drafts.length
                      : 0;

                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Draft proposals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      Text(
                        '$count unsent',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ============================================================
      // BODY
      // ============================================================

      body: BlocBuilder<
          DraftProposalCubit,
          DraftProposalState>(
        builder: (context, state) {

          // --------------------------------------------------------
          // LOADING
          // --------------------------------------------------------

          if (state is DraftProposalLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // --------------------------------------------------------
          // ERROR
          // --------------------------------------------------------

          if (state is DraftProposalError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 42,
                      color: Colors.grey.shade500,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 15),

                    ElevatedButton(
                      onPressed: () {
                        context
                            .read<DraftProposalCubit>()
                            .getDraftProposals();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // --------------------------------------------------------
          // LOADED
          // --------------------------------------------------------

          if (state is DraftProposalLoaded) {
            final drafts = state.drafts;

            // ------------------------------------------------------
            // EMPTY
            // ------------------------------------------------------

            if (drafts.isEmpty) {
              return RefreshIndicator(
                onRefresh: () {
                  return context
                      .read<DraftProposalCubit>()
                      .getDraftProposals();
                },
                child: ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 220),

                    Center(
                      child: Text(
                        'No draft proposals',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // ------------------------------------------------------
            // LIST
            // ------------------------------------------------------

            return RefreshIndicator(
              onRefresh: () {
                return context
                    .read<DraftProposalCubit>()
                    .getDraftProposals();
              },

              child: ListView.builder(
                physics:
                    const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(
                  12,
                  14,
                  12,
                  16,
                ),

                itemCount: drafts.length,

itemBuilder: (context, index) {
  final draft = drafts[index];

  final isSending =
      state is DraftProposalLoaded &&
      state.sendingProposalId == draft.id;

  return _DraftCard(
    draft: draft,
    isSending: isSending,
  );
},              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}

// ==================================================================
// DRAFT CARD
// ==================================================================

class _DraftCard extends StatelessWidget {
  final Proposal draft;
  final bool isSending;

  const _DraftCard({
    required this.draft,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(
      draft.dealTitle,
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,

        border: Border.all(
          color: const Color(0xffdddddd),
          width: .5,
        ),

        borderRadius: BorderRadius.circular(14),

        boxShadow: const [
          BoxShadow(
            blurRadius: 3,
            offset: Offset(0, 1),
            color: Color(0x08000000),
          ),
        ],
      ),

      child: Stack(
        children: [

          // ========================================================
          // AMBER LEFT STRIP
          // ========================================================

          Positioned(
            left: -14,
            top: -14,
            bottom: -14,

            child: Container(
              width: 3,

              decoration: const BoxDecoration(
                color: Color(0xffc58a22),
              ),
            ),
          ),

          // ========================================================
          // CONTENT
          // ========================================================

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // ====================================================
              // TITLE ROW
              // ====================================================

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // ------------------------------------------------
                  // INITIALS
                  // ------------------------------------------------

                  Container(
                    width: 38,
                    height: 38,

                    decoration: BoxDecoration(
                      color: const Color(0xfffff7e6),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),

                    alignment: Alignment.center,

                    child: Text(
                      initials,

                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xffa66d08),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ------------------------------------------------
                  // TITLE + DEAL
                  // ------------------------------------------------

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        Row(
                          children: [

                            Expanded(
                              child: Text(
                                draft.title.isEmpty
                                    ? 'Untitled proposal'
                                    : draft.title,

                                maxLines: 1,

                                overflow:
                                    TextOverflow.ellipsis,

                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // --------------------------------------
                            // DRAFT BADGE
                            // --------------------------------------

                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),

                              decoration: BoxDecoration(
                                color:
                                    const Color(0xfffff7e6),

                                borderRadius:
                                    BorderRadius.circular(8),
                              ),

                              child: const Text(
                                'DRAFT',

                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w600,
                                  color:
                                      Color(0xffa66d08),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 2),

                        Text(
                          draft.dealTitle.isEmpty
                              ? 'No deal'
                              : draft.dealTitle,

                          maxLines: 1,

                          overflow:
                              TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xff6f63b6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ====================================================
              // EMAIL
              // ====================================================

              Row(
                children: [
                  const Icon(
                    Icons.mail_outline,
                    size: 13,
                    color: Colors.grey,
                  ),

                  const SizedBox(width: 5),

                  Expanded(
                    child: Text(
                      draft.email.isEmpty
                          ? 'No email'
                          : draft.email,

                      maxLines: 1,

                      overflow:
                          TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ====================================================
              // DIVIDER
              // ====================================================

              Divider(
                height: 1,
                color: Colors.grey.shade300,
              ),

              const SizedBox(height: 10),

              Row(
                children: [

                  // ------------------------------------------------
                  // DATE
                  // ------------------------------------------------

                  Expanded(
                    child: Row(
                      children: [

                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Colors.grey,
                        ),

                        const SizedBox(width: 4),

                        Expanded(
                          child: Text(
                            _formatDate(
                              draft.createdAt,
                            ),

                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ------------------------------------------------
                  // EDIT BUTTON
                  // ------------------------------------------------

                  SizedBox(
                    height: 30,

                    child: ElevatedButton.icon(
onPressed: () async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<DealsCubit>(
            create: (_) => DealsCubit()..loadDeals(),
          ),
          BlocProvider<ProposalCubit>(
            create: (_) => ProposalCubit(),
          ),
        ],
        child: CreateProposalScreen(
          proposal: draft,
        ),
      ),
    ),
  );

  if (result == true && context.mounted) {
    context.read<DraftProposalCubit>().getDraftProposals();
  }
},
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 13,
                      ),

                      label: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12.5,
                        ),
                      ),

                      style:
                          ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),

                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ------------------------------------------------
// SEND BUTTON
// ------------------------------------------------



 // ------------------------------------------------
 // SEND BUTTON
 // ------------------------------------------------

SizedBox(
  height: 30,
  child: ElevatedButton.icon(
    onPressed: isSending
        ? null
        : () async {
            final success = await context
                .read<DraftProposalCubit>()
                .sendDraftProposal(draft.id);

            if (!context.mounted) return;

            ScaffoldMessenger.of(context)
                .showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Draft proposal sent successfully'
                      : 'Failed to send draft proposal',
                ),
                backgroundColor:
                    success ? Colors.green : Colors.red,
              ),
            );
          },
    icon: isSending
        ? const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(
            Icons.send_outlined,
            size: 13,
          ),
    label: Text(
      isSending ? 'Sending...' : 'Send',
      style: const TextStyle(fontSize: 12.5),
    ),
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      elevation: 0,
    ),
  ),
),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // GET INITIALS
  // ================================================================

  String _getInitials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return '--';
    }

    if (words.length == 1) {
      return words.first
          .substring(
            0,
            words.first.length >= 2
                ? 2
                : 1,
          )
          .toUpperCase();
    }

    return '${words[0][0]}${words[1][0]}'
        .toUpperCase();
  }

  // ================================================================
  // FORMAT DATE
  // ================================================================

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }

    try {
      return DateFormat(
        'MMM d, yyyy',
      ).format(
        value.toLocal(),
      );
    } catch (_) {
      return '';
    }
  }
}