import 'dart:convert';

import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/email/cubit/email_history_cubit.dart';
import 'package:crm_app/screen/email/cubit/email_history_state.dart';
import 'package:crm_app/screen/email/cubit/email_template_cubit.dart';
import 'package:crm_app/screen/email/cubit/scheduled_email_cubit.dart';
import 'package:crm_app/screen/email/cubit/scheduled_email_state.dart';
import 'package:crm_app/screen/email/helper/alertbox.dart';
import 'package:crm_app/screen/email/modal/email_modal.dart';
import 'package:crm_app/screen/email/ui/create_email_screen.dart';
import 'package:crm_app/screen/email/ui/recipents_helper.dart';
import 'package:crm_app/shareWidgets/pagination.dart';
import 'package:flutter/material.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_app/screen/email/modal/scheduled_email_modal.dart';

class ViewEmailScreen extends StatefulWidget {
  final int initialTab;

  const ViewEmailScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<ViewEmailScreen> createState() =>
      _ViewEmailScreenState();
}

class _ViewEmailScreenState extends State<ViewEmailScreen> {
  final TextEditingController _attachmentSearchController = TextEditingController();
  late final DealsCubit _dealsCubit;
  late int _selectedTab = widget.initialTab;

  final List<int> _pageSizeOptions = [5, 10, 25];

  // Sent history is paginated server-side.
  int _historyPage = 1;
  int _historyPageSize = 10;

  // Scheduled emails come back as one list, so they're paginated locally.
  int _scheduledPage = 1;
  int _scheduledPageSize = 10;

  @override
  void initState() {
    super.initState();

    _dealsCubit = DealsCubit();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory(1);

      // Load deals separately for recipient name lookup.
      _dealsCubit.loadDeals();
    });
  }

  Future<void> _loadHistory(int page) {
    setState(() {
      _historyPage = page;
    });

    return context.read<EmailHistoryCubit>().getEmailHistory(
          page: page,
          limit: _historyPageSize,
        );
  }

  @override
  void dispose() {
    _dealsCubit.close();
    _attachmentSearchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

Expanded(
  child: _selectedTab == 0
      ? _buildScheduledTab()
      : _buildSentHistoryTab(),
),          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
  return Container(
    color: const Color(0xFFF5F6FA),
    padding: const EdgeInsets.fromLTRB(
      16,
      16,
      16,
      0,
    ),
    child: BlocBuilder<EmailHistoryCubit, EmailHistoryState>(
      builder: (context, state) {
        int total = 0;

        if (state is EmailHistorySuccess) {
          total = state.total;

          if (state.emails.isNotEmpty) {
            try {
              if (state.emails.isNotEmpty) {
                final contact = EmailContact.fromJson(
                  jsonDecode(state.emails.first.recipients.first),
                );

                
              }
            } catch (_) {}
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------
            // APP BAR (BACK BUTTON + TITLE)
            // ------------------------------------------
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.arrow_back_sharp,
                        size: 22,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  const Text(
                    'Email Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
              ),
            ),


            // ------------------------------------------
            // SUBTITLE
            // ------------------------------------------
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Text(
                '$total emails sent',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ------------------------------------------
            // TABS
            // ------------------------------------------
           BlocBuilder<ScheduledEmailCubit, ScheduledEmailState>(
  builder: (context, scheduledState) {
    int scheduledCount = 0;

    if (scheduledState is ScheduledEmailSuccess) {
      scheduledCount = scheduledState.emails.length;
    }

    return _buildHistoryTabs(
      scheduledCount,
      total,
    );
  },
),

            const SizedBox(height: 16),
          ],
        );
      },
    ),
  );
}

Widget _buildHistoryTabs(  int scheduledCount,
int total) {
  return Container(
    height: 44,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EAF3),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 85,
          child: _buildTab(
            title: 'Scheduled ($scheduledCount)',
            index: 0,
          ),
        ),

        Expanded(
          flex: 115,
          child: _buildTab(
            title: 'Sent history ($total)',
            index: 1,
          ),
        ),
      ],
    ),
  );
}

Widget _buildTab({
  required String title,
  required int index,
}) {
  final selected = _selectedTab == index;

  return GestureDetector(
    onTap: () {
      setState(() {
        _selectedTab = index;
      });
    },
    child: Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? Colors.white
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight:
              selected ? FontWeight.w700 : FontWeight.w600,
          color: selected
              ? const Color(0xFF7C3AED)
              : const Color(0xFF6B7280),
        ),
      ),
    ),
  );
}

  // ============================================================
  // EMAIL LIST
  // ============================================================

  Widget _buildEmailList(
    List<ScheduledEmail> emails,
  ) {
    final sortedEmails = [...emails];

sortedEmails.sort((a, b) {
  final aDate = a.createdAt;
  final bDate = b.createdAt;

  if (aDate == null && bDate == null) {
    return 0;
  }

  if (aDate == null) {
    return 1;
  }

  if (bDate == null) {
    return -1;
  }

  return bDate.compareTo(aDate);
});
   

    return RefreshIndicator(
      onRefresh: () {
  return _loadHistory(_historyPage);
},
      child: ListView.builder(
         padding: const EdgeInsets.fromLTRB(
    6,
    8,
    6,
    20,
  ),
        itemCount: emails.length,
        itemBuilder: (context, index) {
           final email = emails[index];

  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () {
      showEmailTimingDetails(
        context,
        email,
      );
    },   child:    Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (_shouldShowDateHeader(
                sortedEmails,
                index,
              ))
                _buildDateHeader(email),

              _buildEmailCard(email),

              const SizedBox(height: 8),
            ],
    )
          );
        },
      ),
    );
  }

  // ============================================================
  // DATE HEADER
  // ============================================================

bool _shouldShowDateHeader(
  List<ScheduledEmail> emails,
  int index,
) {
  if (index == 0) {
    return true;
  }

  final current = emails[index].createdAt;
  final previous = emails[index - 1].createdAt;

  if (current == null || previous == null) {
    return false;
  }

  final currentDate = current.toLocal();
  final previousDate = previous.toLocal();

  return currentDate.year != previousDate.year ||
      currentDate.month != previousDate.month ||
      currentDate.day != previousDate.day;
}

 Widget _buildDateHeader(ScheduledEmail email) {
  final date = email.createdAt;

  String title = '';

  if (date != null) {
    final now = DateTime.now();
    final localDate = date.toLocal();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final emailDate = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final difference = today.difference(emailDate).inDays;

    if (difference == 0) {
      title = 'Today';
    } else if (difference == 1) {
      title = 'Yesterday';
    } else {
      title =
          '${_monthName(localDate.month)} ${localDate.day}';
    }
  }

  return Padding(
    padding: const EdgeInsets.only(
      left: 2,
      bottom: 7,
      top: 1,
    ),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w500,
        color: Color(0xFF777777),
      ),
    ),
  );
}

  // ============================================================
  // EMAIL CARD
  // ============================================================

Widget _buildEmailCard(ScheduledEmail email) {
  final category = _getCategory(email.templateTitle);
  final categoryColor = _getCategoryColor(category);

  final recipientCount = email.recipients.length;
  final attachmentCount = email.attachments.length;

  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,

      // EXACTLY LIKE HTML
      borderRadius: BorderRadius.circular(14),

      // LEFT ACCENT BORDER
      border: Border(
        left: BorderSide(
          color: categoryColor,
          width: 3,
        ),
      ),

      // HTML:
      // box-shadow: 0 1px 4px rgba(17,24,39,0.06)
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F111827),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    ),

    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // =====================================================
          // CATEGORY + DELETE
          // =====================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // CATEGORY PILL
              _buildCategoryBadge(
                category,
                categoryColor,
              ),

              const Spacer(),

              // DELETE
InkWell(
  borderRadius: BorderRadius.circular(20),
  onTap: _isDeletingEmail
      ? null
      : () => _deleteSentEmail(email.id.toString()),
  child: const Padding(
    padding: EdgeInsets.all(3),
    child: Icon(
      Icons.delete_outline,
      size: 20,
      color: Color(0xFFDC2626),
    ),
  ),
),            ],
          ),

          // HTML:
          // margin: 10px 0 12px
          const SizedBox(height: 10),

          // =====================================================
          // SUBJECT
          // =====================================================
          Text(
            email.subject.isNotEmpty
                ? email.subject
                : 'No subject',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
              height: 1.25,
            ),
          ),

          const SizedBox(height: 12),

          // =====================================================
          // DIVIDER + BOTTOM INFORMATION
          // =====================================================
          Container(
            padding: const EdgeInsets.only(
              top: 10,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFFF0F1F5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [

                // =============================================
                // RECIPIENT
                // =============================================
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    _showRecipientsSheet(email);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),

                      const SizedBox(width: 4),

                      Text(
                        '$recipientCount '
                        '${recipientCount == 1 ? 'recipient' : 'recipients'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),

                      const SizedBox(width: 2),

                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // =============================================
                // ATTACHMENTS
                // =============================================
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: attachmentCount > 0
                      ? () {
                          _showAttachmentsSheet(email);
                        }
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.attach_file,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),

                      const SizedBox(width: 4),

                      Text(
                        '$attachmentCount '
                        '${attachmentCount == 1 ? 'file' : 'files'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),

                      // HTML only shows arrow when files > 0
                      if (attachmentCount > 0) ...[
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                // =============================================
                // SENT
                // =============================================
                _buildSentPill(email.status),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}


Widget _buildSentPill(String status) {
  final isSent = status.toLowerCase() == 'sent';

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 4,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFDDF3E4),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check,
          size: 13,
          color: Color(0xFF1E8A4C),
        ),

        SizedBox(width: 3),

        Text(
          'Sent',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E8A4C),
          ),
        ),
      ],
    ),
  );
}
  // ============================================================
  // CATEGORY BADGE
  // ============================================================
Widget _buildCategoryBadge(
  String category,
  Color color,
) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 11,
      vertical: 4,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.description_outlined,
          size: 13,
          color: color,
        ),

        const SizedBox(width: 6),

        Text(
          category,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 36,
              color: Color(0xFFCC7777),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
  onPressed: () {
    _loadHistory(_historyPage);
  },
  child: const Text('Retry'),
),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

Widget _buildEmpty({String message = 'No email history'}) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.email_outlined,
          size: 42,
          color: Color(0xFFBBBBBB),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF777777),
          ),
        ),
      ],
    ),
  );
}
  // ============================================================
  // HELPERS
  // ============================================================


  String _getCategory(String templateTitle) {
  return templateTitle.isNotEmpty
      ? templateTitle
      : 'Email';
}
Color _getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'qualification':
      return const Color(0xFF7C3AED);

    case 'holiday notice':
      return const Color(0xFF1D74C9);

    case 'deal won':
      return const Color(0xFF22B573);

    case 'services':
      return const Color(0xFF1D74C9);

    case 'follow up':
      return const Color(0xFFE29A3E);

    default:
      return const Color(0xFF7C3AED);
  }
}
  String _getInitials(
    ScheduledCreatedBy? createdBy,
  ) {
    if (createdBy == null) {
      return 'U';
    }

    final first =
        createdBy.firstName.trim();

    final last =
        createdBy.lastName.trim();

    if (first.isNotEmpty &&
        last.isNotEmpty) {
      return '${first[0]}${last[0]}'
          .toUpperCase();
    }

    if (first.isNotEmpty) {
      return first[0].toUpperCase();
    }

    return 'U';
  }


  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  void _showAttachmentsSheet(ScheduledEmail email) {
  if (email.attachments.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No attachments'),
      ),
    );
    return;
  }

  _attachmentSearchController.clear();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final query =
              _attachmentSearchController.text.trim().toLowerCase();

          final filteredAttachments =
              email.attachments.where((attachment) {
            final filename =
                attachment.filename?.toString().toLowerCase() ??
                    'attachment';

            return filename.contains(query);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // --------------------------------------------
                // HANDLE
                // --------------------------------------------
                const SizedBox(height: 10),

                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D5D5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 16),

                // --------------------------------------------
                // HEADER
                // --------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.attach_file,
                          size: 19,
                          color: Color(0xFF3974C6),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Attachments',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF222222),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${email.attachments.length} file'
                              '${email.attachments.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF777777),
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                const Divider(
                  height: 1,
                  color: Color(0xFFEAEAEA),
                ),

                // --------------------------------------------
                // SEARCH BOX
                // --------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    10,
                  ),
                  child: TextField(
                    controller: _attachmentSearchController,
                    onChanged: (_) {
                      setSheetState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Search attachments',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: Color(0xFF777777),
                      ),
                      suffixIcon:
                          _attachmentSearchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _attachmentSearchController.clear();
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.clear,
                                    size: 18,
                                  ),
                                )
                              : null,
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF3974C6),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                // --------------------------------------------
                // ATTACHMENT LIST
                // --------------------------------------------
                Expanded(
                  child: filteredAttachments.isEmpty
                      ? const Center(
                          child: Text(
                            'No attachments found',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF888888),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            24,
                          ),
                          itemCount: filteredAttachments.length,
                          separatorBuilder: (_, __) {
                            return const SizedBox(height: 8);
                          },
                          itemBuilder: (context, index) {
                            final attachment =
                                filteredAttachments[index];

                            return _buildAttachmentItem(
                              attachment,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  Widget _buildAttachmentItem(dynamic attachment) {
  final filename =
      attachment.filename?.toString() ?? 'Attachment';

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: const Color(0xFFE5E7EB),
      ),
    ),
    child: Row(
      children: [
        // --------------------------------------------
        // FILE ICON
        // --------------------------------------------
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEEE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            size: 20,
            color: Color(0xFFD66A6A),
          ),
        ),

        const SizedBox(width: 10),

        // --------------------------------------------
        // FILE NAME
        // --------------------------------------------
        Expanded(
          child: Text(
            filename,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // --------------------------------------------
        // DOWNLOAD BUTTON
        // --------------------------------------------
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _downloadAttachment(attachment);
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.download_outlined,
              size: 20,
              color: Color(0xFF3974C6),
            ),
          ),
        ),
      ],
    ),
  );
}
Future<void> _downloadAttachment(dynamic attachment) async {
  try {
    final filename =
        attachment.filename?.toString() ?? 'Attachment';

    // Replace this with your actual attachment URL field.
    final url = attachment.url?.toString();

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachment URL not available'),
        ),
      );
      return;
    }

    debugPrint('Downloading: $filename');
    debugPrint('URL: $url');

    // Add your download implementation here.
  } catch (e) {
    debugPrint('Download error: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to download attachment'),
      ),
    );
  }
}
Map<String, String> _buildRecipientNamesMap() {
  final Map<String, String> recipientNames = {};

  final dealsState = _dealsCubit.state;

  if (dealsState is DealsLoaded) {
    for (final deal in dealsState.allDeals) {
      final dealEmail = deal.email.trim().toLowerCase();
      final dealName = deal.name.trim();

      if (dealEmail.isNotEmpty && dealName.isNotEmpty) {
        recipientNames[dealEmail] = dealName;
      }
    }
  }

  return recipientNames;
}

void _showRecipientsSheet(ScheduledEmail email) {
  final recipientNames = _buildRecipientNamesMap();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    useSafeArea: true,
    builder: (sheetContext) {
      return RecipientsBottomSheet(
        email: email,
        recipientNames: recipientNames,
      );
    },
  );
}

  Widget _buildScheduledEmailList(
  List<ScheduledEmail> emails,
) {
  final sortedEmails = [...emails];

  sortedEmails.sort((a, b) {
    final aDate = a.scheduledFor;
    final bDate = b.scheduledFor;

    if (aDate == null && bDate == null) {
      return 0;
    }

    if (aDate == null) {
      return 1;
    }

    if (bDate == null) {
      return -1;
    }

    return aDate.compareTo(bDate);
  });

  return RefreshIndicator(
    onRefresh: () {
      return context
                .read<ScheduledEmailCubit>()

          .getScheduledEmails(
          );
    },
    child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        6,
        8,
        6,
        20,
      ),
      itemCount: sortedEmails.length,
      itemBuilder: (context, index) {
        final email = sortedEmails[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _showScheduledEmailDetailSheet(email);
            },
            child: _buildScheduledEmailCard(email),
          ),
        );
      },
    ),
  );
}
Widget _buildScheduledEmailCard(
  ScheduledEmail email,
) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: const Border(
        left: BorderSide(
          color: Color(0xFFF0AA2E),
          width: 3,
        ),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A14161A),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------------
        // SCHEDULED + MENU
        // ---------------------------------------------------------
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFAEEDA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Color(0xFF854F0B),
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Scheduled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF854F0B),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            _buildScheduledMenu(email),
          ],
        ),

        const SizedBox(height: 12),

        // ---------------------------------------------------------
        // SUBJECT
        // ---------------------------------------------------------
        Text(
          email.subject.isNotEmpty
              ? email.subject
              : 'No subject',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF14161A),
            height: 1.4,
          ),
        ),

        const SizedBox(height: 14),

        // ---------------------------------------------------------
        // INFORMATION BOX
        // ---------------------------------------------------------
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFD),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Scheduled send
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAEEDA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xFFBA7517),
                    ),
                  ),

                  const SizedBox(width: 9),

                  const Expanded(
                    child: Text(
                      'Scheduled send',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),

                  Text(
                    _formatScheduledDateTime(
                      email.scheduledFor,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF14161A),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Recipient
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _showRecipientsSheet(email);
                },
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F1FB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Color(0xFF185FA5),
                      ),
                    ),

                    const SizedBox(width: 9),

                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        'Recipient',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        email.recipients.isEmpty
                            ? '-'
                            : email.recipients.first,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF14161A),
                          height: 1.5,
                        ),
                      ),
                    ),

                    if (email.recipients.length > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EEFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+${email.recipients.length - 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF625DCE),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 2),

                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _buildScheduledMenu(
  ScheduledEmail email,
) {
  return PopupMenuButton<String>(
    padding: EdgeInsets.zero,
    offset: const Offset(-5, 38),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 6,
    color: Colors.white,
    onSelected: (value) {
      if (value == 'edit') {
        _editScheduledEmail(email);
      } else if (value == 'cancel') {
        _cancelScheduledEmail(email);
      }
    },
    itemBuilder: (context) {
      return [
        const PopupMenuItem<String>(
          value: 'edit',
          height: 42,
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: Color(0xFF14161A),
              ),
              SizedBox(width: 10),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF14161A),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(
          height: 1,
        ),
        const PopupMenuItem<String>(
          value: 'cancel',
          height: 42,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 16,
                color: Color(0xFFA32D2D),
              ),
              SizedBox(width: 10),
              Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFA32D2D),
                ),
              ),
            ],
          ),
        ),
      ];
    },
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(
        Icons.more_vert,
        size: 17,
        color: Color(0xFF6B7280),
      ),
    ),
  );
}
String _formatScheduledDateTime(
  DateTime? date,
) {
  if (date == null) {
    return '-';
  }

  final local = date.toLocal();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  int hour = local.hour;

  final period = hour >= 12 ? 'PM' : 'AM';

  hour = hour % 12;

  if (hour == 0) {
    hour = 12;
  }

  final minute =
      local.minute.toString().padLeft(2, '0');

  return '${months[local.month - 1]} '
      '${local.day}, '
      '$hour:$minute $period';
}
// ============================================================
// SCHEDULED EMAIL DETAIL SHEET
// ============================================================

void _showScheduledEmailDetailSheet(ScheduledEmail email) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    useSafeArea: true,
    builder: (sheetContext) {
      return _buildScheduledDetailSheet(email);
    },
  );
}

Widget _buildScheduledDetailSheet(ScheduledEmail email) {
  final templateTitle = email.templateTitle.trim();

  final createdByName = email.createdBy?.fullName.isNotEmpty == true
      ? email.createdBy!.fullName
      : 'Unknown';

  final createdByEmail = email.createdBy?.email.trim() ?? '';

  final scheduledLines = _splitDateTimeLines(email.scheduledFor);
  final createdLines = _splitDateTimeLines(email.createdAt);

  return Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(22),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------
            // DRAG HANDLE
            // --------------------------------------------
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // --------------------------------------------
            // STATUS + MENU
            // --------------------------------------------
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 6,
                        height: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF854F0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Scheduled',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF854F0B),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                _buildScheduledMenu(email),
              ],
            ),

            const SizedBox(height: 14),

            // --------------------------------------------
            // SUBJECT
            // --------------------------------------------
            Text(
              email.subject.isNotEmpty
                  ? email.subject
                  : 'No subject',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w500,
                color: Color(0xFF14161A),
                height: 1.3,
              ),
            ),

            // --------------------------------------------
            // TEMPLATE CHIP
            // --------------------------------------------
            if (templateTitle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFD),
                  border: Border.all(
                    color: const Color(0xFFE5E5E7),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 13,
                      color: Color(0xFF625DCE),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      templateTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(
                height: 0.5,
                color: Color(0xFFE5E5E7),
              ),
            ),

            // --------------------------------------------
            // SCHEDULED BY
            // --------------------------------------------
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0EEFF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getInitials(email.createdBy),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF625DCE),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scheduled by',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        createdByName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF14161A),
                        ),
                      ),
                      if (createdByEmail.isNotEmpty)
                        Text(
                          createdByEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(
                height: 0.5,
                color: Color(0xFFE5E5E7),
              ),
            ),

            // --------------------------------------------
            // INFO BOXES
            // --------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDetailInfoBox(
                    icon: Icons.calendar_today_outlined,
                    label: 'Scheduled for',
                    lines: scheduledLines,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailInfoBox(
                    icon: Icons.people_outline,
                    label: 'Recipients',
                    lines: [
                      '${email.recipients.length}',
                      email.recipients.length == 1
                          ? 'person'
                          : 'people',
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailInfoBox(
                    icon: Icons.history,
                    label: 'Created',
                    lines: createdLines,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildDetailInfoBox({
  required IconData icon,
  required String label,
  required List<String> lines,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFBFD),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF625DCE),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          lines.join('\n'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF14161A),
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

List<String> _splitDateTimeLines(DateTime? date) {
  if (date == null) {
    return const ['-', ''];
  }

  final local = date.toLocal();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  int hour = local.hour;

  final period = hour >= 12 ? 'PM' : 'AM';

  hour = hour % 12;

  if (hour == 0) {
    hour = 12;
  }

  final minute = local.minute.toString().padLeft(2, '0');

  return [
    '${months[local.month - 1]} ${local.day}',
    '$hour:$minute $period',
  ];
}
Future<void> _editScheduledEmail(
  ScheduledEmail email,
) async {
  try {
    final scheduledEmail =
        await context
            .read<ScheduledEmailCubit>()
            .getScheduledEmailById(email.id);

    if (!mounted || scheduledEmail == null) {
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: context.read<ScheduledEmailCubit>(),
            ),
            BlocProvider<EmailTemplateCubit>(
              create: (_) => EmailTemplateCubit()
                ..getEmailTemplates(),
            ),
          ],
          child: CreateEmailScreen(
            isEdit: true,
            scheduledEmail: scheduledEmail,
            recipients: const [],
            recipientNames: _buildRecipientNamesMap(),
          ),
        ),
      ),
    );

    // Refresh scheduled list after update
    if (result == true && mounted) {
      context
          .read<ScheduledEmailCubit>()
          .getScheduledEmails();
    }
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst('Exception: ', ''),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// =============================
// Delete functionality
// =============================

bool _isDeletingEmail = false;

Future<void> _deleteSentEmail(String emailId) async {
  if (_isDeletingEmail) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete sent email?'),
      content: const Text(
        'Are you sure you want to delete this email from history?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirm != true || !mounted) return;

  setState(() => _isDeletingEmail = true);

  try {
    final success = await EmailHistoryCubit().deleteSentEmail(emailId);

    if (!mounted) return;

    if (success) {
  // If the deleted email was the only item on this page,
  // go back one page when possible.
  final historyState = context.read<EmailHistoryCubit>().state;

  var page = _historyPage;

  if (historyState is EmailHistorySuccess &&
      historyState.emails.length == 1 &&
      page > 1) {
    page--;
  }

  await _loadHistory(page);

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Email deleted successfully'),
    ),
  );
} else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete email'),
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to delete email: $e'),
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _isDeletingEmail = false);
    }
  }
}
Future<void> _cancelScheduledEmail(
  ScheduledEmail email,
) async {
  try {
    await context
        .read<ScheduledEmailCubit>()
        .cancelScheduledEmail(
          id: email.id,
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Scheduled email cancelled successfully',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
        ),
      ),
    );
  }
}

 Widget _buildScheduledTab() {
  return BlocBuilder<ScheduledEmailCubit, ScheduledEmailState>(
    builder: (context, state) {
      if (state is ScheduledEmailInitial ||
          state is ScheduledEmailLoading) {
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        );
      }

      if (state is ScheduledEmailError) {
        return _buildScheduledError(state.message);
      }

      if (state is ScheduledEmailSuccess) {
        if (state.emails.isEmpty) {
          return _buildEmpty(
            message: 'No scheduled emails',
          );
        }

        // Sort before slicing so pages follow the scheduled order.
        final sortedEmails = [...state.emails]..sort((a, b) {
            final aDate = a.scheduledFor;
            final bDate = b.scheduledFor;

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            return aDate.compareTo(bDate);
          });

        final total = sortedEmails.length;
        final totalPages = (total / _scheduledPageSize).ceil();

        // A cancel can empty the last page — fall back to the new last one.
        final page = _scheduledPage.clamp(1, totalPages);

        final start = (page - 1) * _scheduledPageSize;
        final end = (start + _scheduledPageSize).clamp(0, total);

        return Column(
          children: [
            Expanded(
              child: _buildScheduledEmailList(
                sortedEmails.sublist(start, end),
              ),
            ),
            PaginationWidget(
              currentPage: page,
              totalItems: total,
              pageSize: _scheduledPageSize,
              pageSizeOptions: _pageSizeOptions,
              onPageChanged: (newPage) {
                setState(() {
                  _scheduledPage = newPage;
                });
              },
              onPageSizeChanged: (size) {
                setState(() {
                  _scheduledPageSize = size;
                  _scheduledPage = 1;
                });
              },
            ),
          ],
        );
      }

      return const SizedBox();
    },
  );
}

  Widget _buildSentHistoryTab() {
  return BlocBuilder<EmailHistoryCubit, EmailHistoryState>(
    builder: (context, state) {
      if (state is EmailHistoryLoading) {
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        );
      }

      if (state is EmailHistoryError) {
        return _buildError(state.message);
      }

      if (state is EmailHistorySuccess) {
        final sentEmails = state.emails.where((email) {
          return email.status.toLowerCase() != 'scheduled';
        }).toList();

        if (state.total == 0) {
          return _buildEmpty(
            message: 'No sent emails',
          );
        }

        return Column(
          children: [
            Expanded(
              child: sentEmails.isEmpty
                  ? _buildEmpty(
                      message: 'No sent emails on this page',
                    )
                  : _buildEmailList(sentEmails),
            ),
            PaginationWidget(
              currentPage: state.page,
              totalItems: state.total,
              pageSize: _historyPageSize,
              pageSizeOptions: _pageSizeOptions,
              onPageChanged: _loadHistory,
              onPageSizeChanged: (size) {
                setState(() {
                  _historyPageSize = size;
                });
                _loadHistory(1);
              },
            ),
          ],
        );
      }

      return const SizedBox();
    },
  );
}

  Widget _buildScheduledError(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 36,
            color: Color(0xFFCC7777),
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () {
              context
                  .read<ScheduledEmailCubit>()
                  .getScheduledEmails();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
}