import 'package:crm_app/screen/proposal/modal/proposal_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';

class ProposalCardDetailsSheet extends StatelessWidget {
  final Proposal proposal;

  const ProposalCardDetailsSheet({
    super.key,
    required this.proposal,
  });

  static Future<void> show(
    BuildContext context,
    Proposal proposal,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ProposalCardDetailsSheet(
          proposal: proposal,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.90,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xfff8f8f8),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // =====================================================
              // HANDLE
              // =====================================================

              const SizedBox(height: 8),

              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xffcfcfcf),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

             const SizedBox(height: 20),

Expanded(
  child: DefaultTabController(
    length: 4,
    child: Column(
      children: [
        // =========================================================
        // TABS
        // =========================================================
        const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              text: 'Proposal Details',
            ),
            Tab(
              text: 'Content',
            ),
            Tab(
              text: 'Attachments',
            ),
            Tab(
              text: 'Activity',
            ),
          ],
        ),

        // =========================================================
        // TAB CONTENT
        // =========================================================
        Expanded(
          child: TabBarView(
            children: [
              _DetailTab(
                proposal: proposal,
              ),
              _ContentTab(
                proposal: proposal,
              ),
              _AttachmentsTab(
                proposal: proposal,
              ),
              _ActivityTab(
                proposal: proposal,
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  final Proposal proposal;

  const _ActivityTab({
    required this.proposal,
  });

  @override
  Widget build(BuildContext context) {
    final activities = _buildActivities();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // =========================================================
          // HEADER
          // =========================================================

          const Text(
            'Activity timeline',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Recent activity and updates for this proposal',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 20),

          // =========================================================
          // TIMELINE
          // =========================================================

          ListView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity =
                  activities[index];

              final isLast =
                  index == activities.length - 1;

              return _ActivityTimelineItem(
                title: activity.title,
                time: activity.time,
                icon: activity.icon,
                iconColor: activity.iconColor,
                isLast: isLast,
              );
            },
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // BUILD ACTIVITIES
  // ===============================================================

  List<_ActivityData> _buildActivities() {
    final List<_ActivityData> activities = [];

    // ---------------------------------------------------------------
    // 1. PROPOSAL CREATED
    // ---------------------------------------------------------------

    if (proposal.createdAt != null) {
      activities.add(
        _ActivityData(
          title: 'Proposal created',
          time: _formatDateTime(
            proposal.createdAt!,
          ),
          icon: Icons.description_outlined,
          iconColor: Colors.blue,
        ),
      );
    }

    // ---------------------------------------------------------------
    // 2. FOLLOW-UP SCHEDULED
    // ---------------------------------------------------------------

    if (proposal.followUpDate != null) {
      activities.add(
        _ActivityData(
          title: 'Follow-up scheduled',
          time: _formatDateTime(
            proposal.followUpDate!,
          ),
          icon: Icons.schedule,
          iconColor: Colors.orange,
        ),
      );
    }

    // ---------------------------------------------------------------
    // 3. LATEST STATUS CHANGE
    // ---------------------------------------------------------------

    if (proposal.statusHistory.isNotEmpty) {
      final latestStatus =
          proposal.statusHistory.last;

      activities.add(
        _ActivityData(
          title:
              'Status changed to ${_displayStatus(latestStatus.status)}',
          time: latestStatus.changedAt == null
              ? '-'
              : _formatDateTime(
                  latestStatus.changedAt!,
                ),
          icon: Icons.mail_outline,
          iconColor: Colors.green,
        ),
      );
    }

    return activities;
  }

  // ===============================================================
  // DATE FORMAT
  // ===============================================================

  String _formatDateTime(DateTime date) {
    return DateFormat(
      'M/d/yyyy, h:mm:ss a',
    ).format(
      date.toLocal(),
    );
  }

  // ===============================================================
  // STATUS DISPLAY
  // ===============================================================

  String _displayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
        return 'Sent';

      case 'no reply':
        return 'No reply';

      case 'success':
        return 'Success';

      case 'draft':
        return 'Draft';

      case 'rejection':
        return 'Rejection';

      default:
        return status;
    }
  }
}
class _ActivityData {
  final String title;
  final String time;
  final IconData icon;
  final Color iconColor;

  const _ActivityData({
    required this.title,
    required this.time,
    required this.icon,
    required this.iconColor,
  });
}
class _ActivityTimelineItem extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final Color iconColor;
  final bool isLast;

  const _ActivityTimelineItem({
    required this.title,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // =========================================================
        // ICON + CONNECTING LINE
        // =========================================================

        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xfff8f8f8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 16,
                  color: iconColor,
                ),
              ),

              if (!isLast)
                Container(
                  width: 1.5,
                  height: 48,
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                  ),
                  color: const Color(0xffdddddd),
                ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // =========================================================
        // ACTIVITY TEXT
        // =========================================================

        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: 6,
              bottom: isLast ? 0 : 22,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
class _AttachmentsTab extends StatelessWidget {
  final Proposal proposal;

  const _AttachmentsTab({
    required this.proposal,
  });

  @override
  Widget build(BuildContext context) {
    final attachments = proposal.attachments;

    if (attachments.isEmpty) {
      return const Center(
        child: Text(
          'No attachments',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: attachments.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final attachment =
            attachments[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xffdddddd),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xfffff1f1),
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Colors.red,
                  size: 20,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _formatFileSize(
                        attachment.size,
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () {
                  // Open / preview attachment
                },
                icon: const Icon(
                  Icons.open_in_new,
                  size: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
class _ContentTab extends StatelessWidget {
  final Proposal proposal;

  const _ContentTab({
    required this.proposal,
  });

  @override
  Widget build(BuildContext context) {
    final content = proposal.content.trim();
    debugPrint('PROPOSAL CONTENT: $content');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xffdddddd),
          ),
        ),
        child: content.isEmpty
            ? const Text(
                'No content available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              )
            : HtmlWidget(
  content,
  textStyle: const TextStyle(
    fontSize: 14,
    height: 1.5,
  ),
  customStylesBuilder: (element) {
    if (element.localName == 'img') {
      return {
        'display': 'block',
        'max-width': '500px',
        'height': '200px',
      };
    }
    return null;
  },
),
      ),
    );
  }
}

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }


class _DetailTab extends StatelessWidget {
  final Proposal proposal;

  const _DetailTab({
    required this.proposal,
  });

  @override
  Widget build(BuildContext context) {
    final dealName = _getDealName();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          // =========================================================
          // CLIENT INFORMATION
          // =========================================================

          const Text(
            'Client Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xff17395f),
            ),
          ),

          const SizedBox(height: 18),

          _DetailItem(
            icon: Icons.person_outline,
            label: 'Client Name',
            value: dealName,
          ),

          const SizedBox(height: 20),

          _DetailItem(
            icon: Icons.business_outlined,
            label: 'Company',
            value: proposal.companyName,
          ),

          const SizedBox(height: 20),

          _DetailItem(
            icon: Icons.mail_outline,
            label: 'Email Address',
            value: proposal.email,
            valueColor: Colors.blue,
          ),

          const SizedBox(height: 16),

          const Divider(
            color: Color(0xffe5e7eb),
            thickness: 1.5,
          ),

          const SizedBox(height: 16),

          // =========================================================
          // PROPOSAL INFORMATION
          // =========================================================

          const Text(
            'Proposal Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xff17395f),
            ),
          ),

          const SizedBox(height: 18),

          _DetailItem(
            icon: Icons.attach_money,
            label: 'Proposed Value',
            value: proposal.value,
          ),

          const SizedBox(height: 20),

          _DetailItem(
            icon: Icons.calendar_today_outlined,
            label: 'Created Date',
            value: _formatDate(
              proposal.createdAt,
            ),
          ),

          const SizedBox(height: 20),

          _DetailItem(
            icon: Icons.access_time,
            label: 'Follow-up Date',
            value: _formatDate(
              proposal.followUpDate,
            ),
          ),
        ],
      ),
    );
  }

  String _getDealName() {
    if (proposal.deal is Map) {
      final deal =
          Map<String, dynamic>.from(
        proposal.deal as Map,
      );

      return deal['dealName']
              ?.toString() ??
          '';
    }

    return proposal.dealTitle;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    return DateFormat(
      'M/d/yyyy',
    ).format(
      date.toLocal(),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [

        // ICON
        SizedBox(
          width: 22,
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xff64748b),
          ),
        ),

        const SizedBox(width: 8),

        // LABEL + VALUE
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xff64748b),
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value.isEmpty ? '-' : value,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w500,
                  color: valueColor ??
                      const Color(0xff111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
}