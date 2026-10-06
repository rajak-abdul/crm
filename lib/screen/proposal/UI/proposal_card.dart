import 'package:crm_app/screen/proposal/UI/proposal_card_details_sheet.dart' show ProposalCardDetailsSheet;
import 'package:crm_app/screen/proposal/cubit/proposal_cubit.dart';
import 'package:crm_app/screen/proposal/modal/proposal_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class ProposalCard extends StatefulWidget {
  final Proposal proposal;
  final VoidCallback onMorePressed;

  const ProposalCard({
    super.key,
    required this.proposal,
    required this.onMorePressed,
  });

  @override
  State<ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends State<ProposalCard> {
  late String selectedStatus;
  bool isUpdatingStatus = false;
  TextEditingController? _followUpCommentController;
  Proposal get proposal => widget.proposal;

  @override
  void initState() {
    super.initState();
  selectedStatus = proposal.status.toLowerCase();

  _followUpCommentController = TextEditingController(
    text: proposal.followUpComment ?? '',
  );
  }

  @override
void didUpdateWidget(covariant ProposalCard oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (oldWidget.proposal.id != widget.proposal.id ||
      oldWidget.proposal.status != widget.proposal.status) {
    setState(() {
      selectedStatus =
          widget.proposal.status.trim().toLowerCase();

      _followUpCommentController?.text =
          widget.proposal.followUpComment ?? '';
    });
  }
}

  @override
void dispose() {
  _followUpCommentController?.dispose();
  super.dispose();
}

  // ===============================================================
  // STATUS DISPLAY
  // ===============================================================

  String get displayStatus {
    switch (selectedStatus) {
      case 'sent':
        return 'Sent';

      case 'rejection':
        return 'Rejection';

      case 'draft':
        return 'Draft';

      case 'success':
        return 'Success';

      case 'no reply':
        return 'No reply';

      default:
        return selectedStatus.isEmpty
            ? '-'
            : selectedStatus;
    }
  }

  // ===============================================================
  // STATUS COLOR
  // ===============================================================

  Color get statusColor {
    switch (selectedStatus) {
      case 'no reply':
        return Colors.grey;

      case 'sent':
        return Colors.blue;

      case 'success':
        return Colors.green;

      case 'draft':
        return Colors.orange;

      case 'rejection':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // ===============================================================
  // STATUS ICON
  // ===============================================================

  IconData get statusIcon {
    switch (selectedStatus) {
      case 'no reply':
        return Icons.access_time;

      case 'sent':
        return Icons.send_outlined;

      case 'success':
        return Icons.check;

      case 'draft':
        return Icons.edit_document;

      case 'rejection':
        return Icons.close;

      default:
        return Icons.circle;
    }
  }

  // ===============================================================
  // INITIALS
  // ===============================================================

  String get initials {
    final title = proposal.title.trim();

    if (title.isEmpty) {
      return '?';
    }

    final parts = title
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first.toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ===============================================================
  // FOLLOW-UP DATE
  // ===============================================================

  String get formattedFollowUpDate {
    if (proposal.followUpDate == null) {
      return '-';
    }

    return DateFormat(
      'dd MMM',
    ).format(
      proposal.followUpDate!.toLocal(),
    );
  }

  // ===============================================================
  // OVERDUE
  // ===============================================================

  bool get isOverdue {
    final date = proposal.followUpDate;

    if (date == null) {
      return false;
    }

    return date.isBefore(DateTime.now());
  }

  // ===============================================================
  // UPDATE STATUS
  // ===============================================================

  Future<void> _updateStatus(String newStatus) async {
      if (selectedStatus.trim().toLowerCase() == 'draft') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Draft proposals cannot change status',
        ),
      ),
    );
    return;
  }

  if (newStatus == selectedStatus) {
    return;
  }


    final oldStatus = selectedStatus;

    setState(() {
      selectedStatus = newStatus;
      isUpdatingStatus = true;
    });

    try {
      await context.read<ProposalCubit>().updateProposalStatus(
            proposalId: proposal.id,
            status: newStatus,
          );

      if (!mounted) return;

      setState(() {
        isUpdatingStatus = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        selectedStatus = oldStatus;
        isUpdatingStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to update status',
          ),
        ),
      );
    }
  }

  // ===============================================================
  // STATUS DROPDOWN
  // ===============================================================

  Widget _buildStatusDropdown() {
  final isDraft =
      selectedStatus.trim().toLowerCase() == 'draft';

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 2,
    ),
    decoration: BoxDecoration(
      color: isDraft
          ? const Color(0xfff5f5f5)
          : const Color(0xfffafafa),
      borderRadius: BorderRadius.circular(12),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedStatus.isEmpty
            ? null
            : selectedStatus,

        isDense: true,

        icon: isUpdatingStatus
            ? const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                ),
              )
            : Icon(
                isDraft
                    ? Icons.lock_outline
                    : Icons.keyboard_arrow_down,
                size: 15,
                color: isDraft
                    ? Colors.grey
                    : statusColor,
              ),

        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDraft
              ? Colors.grey
              : statusColor,
        ),

        items: const [
  DropdownMenuItem<String>(
    value: 'draft',
    enabled: false,
    child: Text(
      'Draft',
      style: TextStyle(
        color: Colors.grey,
      ),
    ),
  ),
  DropdownMenuItem<String>(
    value: 'sent',
    child: Text('Sent'),
  ),
  DropdownMenuItem<String>(
    value: 'no reply',
    child: Text('No reply'),
  ),
  DropdownMenuItem<String>(
    value: 'success',
    child: Text('Success'),
  ),
  DropdownMenuItem<String>(
    value: 'rejection',
    child: Text('Rejection'),
  ),
],

onChanged: isUpdatingStatus
    ? null
    : (value) {
        if (value == null) return;

        _updateStatus(value);
      },
      ),
    ),
  );
}


  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xfff1f1f1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF0F9FF),
          width: .5,
        ),
      ),
      child: Stack(
        children: [

          // =========================================================
          // LEFT STATUS LINE
          // =========================================================

          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              color: statusColor,
            ),
          ),

          // =========================================================
          // CARD CONTENT
          // =========================================================

Padding(
  padding: const EdgeInsets.fromLTRB(
    18,
    14,
    14,
    14,
  ),
  child: Column(
    children: [
      // =========================================================
      // TOP ROW
      // =========================================================

      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // =======================================================
          // CLICKABLE PROPOSAL CONTENT
          // =======================================================

          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                ProposalCardDetailsSheet.show(
                  context,
                  proposal,
                );
              },
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  // =================================================
                  // INITIALS
                  // =================================================

                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                        const BoxDecoration(
                      color: Color(0xfffafafa),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // =================================================
                  // TITLE + DEAL + EMAIL
                  // =================================================

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Text(
                          proposal.title,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          proposal.dealTitle,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),

                        const SizedBox(height: 7),

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
                                proposal.email,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =========================================================
          // VERTICAL ELLIPSIS
          // =========================================================

          SizedBox(
            width: 28,
            height: 28,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,

              icon: const Icon(
                Icons.more_vert,
                size: 17,
              ),

              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    _deleteProposal(
                      context,
                      proposal,
                    );
                    break;
                }
              },

              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      const SizedBox(height: 10),

      // =========================================================
      // DIVIDER
      // =========================================================

      Container(
        height: .5,
        color: const Color(0xffdddddd),
      ),

      const SizedBox(height: 10),

      // =========================================================
      // STATUS + FOLLOW-UP
      // =========================================================

      Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [

          // STATUS
          _buildStatusDropdown(),

          // FOLLOW-UP
          InkWell(
            borderRadius:
                BorderRadius.circular(6),
            onTap: () {
              _showFollowUpDetails(
                context,
              );
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [

                  Icon(
                    Icons
                        .calendar_month_outlined,
                    size: 13,
                    color: isOverdue
                        ? Colors.red
                        : Colors.grey,
                  ),

                  const SizedBox(width: 4),

                  Text(
                    formattedFollowUpDate,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isOverdue
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isOverdue
                          ? Colors.red
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  ),
)

        ],
      ),
    );
  }
Future<void> _showFollowUpDetails(
  BuildContext context,
) async {
    final proposalCubit = context.read<ProposalCubit>();

  DateTime selectedDate =
      proposal.followUpDate ?? DateTime.now();


  bool editMode = false;
  bool isSaving = false;
  final commentController =
      _followUpCommentController!;


  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16),
      ),
    ),
    builder: (sheetContext) {
      return BlocProvider.value(
      value: proposalCubit,
        child: StatefulBuilder(
        builder: (
          context,
          setSheetState,
        ) {
          return SafeArea(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xfff1f1f1),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    // =============================================
                    // HANDLE
                    // =============================================

                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xffcccccc),
                          borderRadius:
                              BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // =============================================
                    // HEADER
                    // =============================================

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [

                        const Text(
                          'Follow-up details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                            );
                          },
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // =============================================
                    // VIEW MODE
                    // =============================================

                    if (!editMode) ...[
                      _followUpViewMode(
                        selectedDate,
                        commentController.text.trim(),

                        () {
                          setSheetState(() {
                            editMode = true;
                          });
                        },
                      ),
                    ]

                    // =============================================
                    // EDIT MODE
                    // =============================================

                    else ...[
                      _followUpEditMode(
                        context: context,
                        selectedDate: selectedDate,
                        commentController:
                            commentController,
                        isSaving: isSaving,

                        onDateChanged: (
                          newDate,
                        ) {
                          setSheetState(() {
                            selectedDate = newDate;
                          });
                        },

                        onCancel: () {
                          setSheetState(() {
                            editMode = false;
                          });
                        },

                        onSave: () async {
                          setSheetState(() {
                            isSaving = true;
                          });

                          try {
                            await context
                                .read<ProposalCubit>()
                                .updateProposalFollowUp(
                                  proposalId:
                                      proposal.id,
                                  followUpDate:
                                      selectedDate,
                                  followUpComment:
                                      commentController
                                          .text
                                          .trim(),
                                );

                            if (!sheetContext.mounted) {
                              return;
                            }

                            Navigator.pop(
                              sheetContext,
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Follow-up updated',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setSheetState(() {
                              isSaving = false;
                            });

                            if (!sheetContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(
                              sheetContext,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString(),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      )
      );
    },
  );

}
Widget _followUpViewMode(
  DateTime selectedDate,
  String comment,
  VoidCallback onEdit,
) {
  return Padding(
    padding: const EdgeInsets.only(
      top: 8,
      bottom: 4,
    ),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [

        // ===========================================
        // FOLLOW-UP DATE
        // ===========================================

        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            const Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 13,
                  color: Colors.grey,
                ),
                SizedBox(width: 5),
                Text(
                  'Follow-up date',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              DateFormat(
                'MM/dd/yyyy, hh:mm a',
              ).format(
                selectedDate.toLocal(),
              ),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ===========================================
        // COMMENT
        // ===========================================

        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            const Row(
              children: [
                Icon(
                  Icons.message_outlined,
                  size: 13,
                  color: Colors.grey,
                ),
                SizedBox(width: 5),
                Text(
                  'Comment',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              comment.trim().isEmpty
                  ? 'No comment added'
                  : comment,
              style: TextStyle(
                fontSize: 14,
                color: comment.trim().isEmpty
                    ? Colors.grey
                    : Colors.black87,
                fontStyle: comment.trim().isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ===========================================
        // EDIT BUTTON
        // ===========================================

        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: onEdit,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _followUpEditMode({
  required BuildContext context,
  required DateTime selectedDate,
  required TextEditingController commentController,
  required bool isSaving,
  required ValueChanged<DateTime> onDateChanged,
  required VoidCallback onCancel,
  required VoidCallback onSave,
}) {
  return Padding(
    padding: const EdgeInsets.only(
      top: 8,
      bottom: 4,
    ),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [

        // ===========================================
        // FOLLOW-UP DATE
        // ===========================================

        const Text(
          'Follow-up date',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 6),

        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );

            if (date == null) {
              return;
            }

            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(
                selectedDate,
              ),
            );

            if (time == null) {
              return;
            }

            final newDate = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );

            onDateChanged(newDate);
          },
          child: Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xffdddddd),
              ),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: Row(
              children: [

                const Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: Colors.grey,
                ),

                const SizedBox(width: 8),

                Text(
                  DateFormat(
                    'MM/dd/yyyy, hh:mm a',
                  ).format(
                    selectedDate.toLocal(),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ===========================================
        // COMMENT
        // ===========================================

        const Text(
          'Comment',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 6),

        TextField(
          controller: commentController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'Add a follow-up comment',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xffdddddd),
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xffdddddd),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ===========================================
        // CANCEL + SAVE
        // ===========================================

        Row(
          children: [

            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed:
                      isSaving
                          ? null
                          : onCancel,
                  child: const Text(
                    'Cancel',
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed:
                      isSaving
                          ? null
                          : onSave,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save',
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Future<void> _deleteProposal(
  BuildContext context,
  Proposal proposal,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete Proposal'),
        content: const Text(
          'Are you sure you want to delete this proposal?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    await context.read<ProposalCubit>().deleteProposal(
      proposalId: proposal.id,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Proposal deleted'),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
      ),
    );
  }
}
}