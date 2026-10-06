import 'package:crm_app/screen/email/modal/scheduled_email_modal.dart';
import 'package:flutter/material.dart';

class RecipientsBottomSheet extends StatefulWidget {
  final ScheduledEmail email;

  /// Maps recipient email -> CRM deal/contact name.
  final Map<String, String> recipientNames;

  const RecipientsBottomSheet({
    super.key,
    required this.email,
    this.recipientNames = const {},
  });

  @override
  State<RecipientsBottomSheet> createState() =>
      _RecipientsBottomSheetState();
}

class _RecipientsBottomSheetState
    extends State<RecipientsBottomSheet> {
  final TextEditingController searchController =
      TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<dynamic> get filteredRecipients {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.email.recipients;
    }

    return widget.email.recipients.where((recipient) {
      final name = _getRecipientName(recipient).toLowerCase();
      final email = _getRecipientEmail(recipient).toLowerCase();

      return name.contains(query) ||
          email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recipients = filteredRecipients;

    return Container(
        width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.85,
      constraints: const BoxConstraints(
        maxHeight: 600,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // =====================================================
          // DRAG HANDLE
          // =====================================================

          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(
              bottom: 20,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFD0D0D0),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // =====================================================
          // HEADER
          // =====================================================

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // USERS ICON
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people_outline,
                  size: 18,
                  color: Color(0xFF3974C6),
                ),
              ),

              const SizedBox(width: 12),

              // TITLE + COUNT + SUBTITLE
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Recipients',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF222222),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // COUNT BADGE
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E6FB),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.email.recipients.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4A2E7C),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 2),

                    const Text(
                      'People who received this update',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),

              // CLOSE BUTTON
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F7F7),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // =====================================================
          // SEARCH
          // =====================================================

          Container(
            height: 44,
            margin: const EdgeInsets.only(
              bottom: 20,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E2E2),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),

                const Icon(
                  Icons.search,
                  size: 16,
                  color: Color(0xFF888888),
                ),

                const SizedBox(width: 4),

                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) {
                      setState(() {});
                    },
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF333333),
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Search recipients by name or email...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF888888),
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),

                // FILTER BUTTON
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(
                    right: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.tune,
                    size: 16,
                    color: Color(0xFF555F6F),
                  ),
                ),
              ],
            ),
          ),

          // =====================================================
          // RECIPIENT LIST
          // =====================================================

          Flexible(
            child: recipients.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No recipients found',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: recipients.length,
                    separatorBuilder: (_, __) {
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      final recipient =
                          recipients[index];

                      return _buildRecipientItem(
                        recipient,
                        index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECIPIENT ITEM
  // ============================================================

  Widget _buildRecipientItem(
    dynamic recipient,
    int index,
  ) {
    final name = _getRecipientName(recipient);
    final email = _getRecipientEmail(recipient);

    final initials = _getInitials(name);

    final avatarColors = [
      const [
        Color(0xFFD6E7FB),
        Color(0xFF0C447C),
      ],
      const [
        Color(0xFFF0E6FB),
        Color(0xFF4A2E7C),
      ],
      const [
        Color(0xFFDCF3E3),
        Color(0xFF0E6B36),
      ],
      const [
        Color(0xFFFCEFCB),
        Color(0xFF8A6300),
      ],
      const [
        Color(0xFFFBDCE0),
        Color(0xFF9A2038),
      ],
      const [
        Color(0xFFD6EFFB),
        Color(0xFF0C5F7C),
      ],
    ];

    final colors =
        avatarColors[index % avatarColors.length];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE2E2E2),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // ==================================================
          // AVATAR
          // ==================================================

          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors[0],
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors[1],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ==================================================
          // NAME + EMAIL
          // ==================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty
                      ? name
                      : 'Unknown recipient',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222222),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECIPIENT NAME
  // ============================================================

  String _getRecipientName(dynamic recipient) {
  // Email history API returns recipients as plain email strings.
  if (recipient is String) {
    final email = recipient.trim().toLowerCase();

    return widget.recipientNames[email] ?? '';
  }

  // Keep support for object-based recipients as well.
  try {
    if (recipient.name != null) {
      return recipient.name.toString();
    }
  } catch (_) {}

  try {
    if (recipient.fullName != null) {
      return recipient.fullName.toString();
    }
  } catch (_) {}

  return '';
}
  // ============================================================
  // RECIPIENT EMAIL
  // ============================================================

  String _getRecipientEmail(dynamic recipient) {
  if (recipient is String) {
    return recipient.trim();
  }

  try {
    if (recipient.email != null) {
      return recipient.email.toString();
    }
  } catch (_) {}

  return '';
 }

  // ============================================================
  // INITIALS
  // ============================================================

  String _getInitials(String name) {
    final value = name.trim();

    if (value.isEmpty) {
      return 'U';
    }

    final parts = value
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'
          .toUpperCase();
    }

    return parts[0][0].toUpperCase();
  }
}