// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/tasks/view/issue_conversation.dart        ║
// ║  VIEW — "Issues" chat card on a linked lead / deal detail     ║
// ║  page (Task Linked items and Target Records), plus the        ║
// ║  fixed-height scroll box it uses.                             ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/viewmodel/linked_items_state.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';

/// Notes and issue lists stop growing at this height and scroll inside
/// their card with a visible scrollbar.
const kScrollBoxHeight = 300.0;

/// Fixed-height scroll area with an always-visible scrollbar.
class IssueScrollBox extends StatefulWidget {
  final List<Widget> children;

  /// Start at the bottom (newest last, chat style).
  final bool startAtEnd;

  const IssueScrollBox({
    super.key,
    required this.children,
    this.startAtEnd = false,
  });

  @override
  State<IssueScrollBox> createState() => _IssueScrollBoxState();
}

class _IssueScrollBoxState extends State<IssueScrollBox> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.startAtEnd) _scrollToEnd();
  }

  @override
  void didUpdateWidget(covariant IssueScrollBox old) {
    super.didUpdateWidget(old);
    if (widget.startAtEnd && widget.children.length != old.children.length) {
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: kScrollBoxHeight),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: ListView(
          controller: _scroll,
          shrinkWrap: true,
          padding: const EdgeInsets.only(right: 10),
          children: widget.children,
        ),
      ),
    );
  }
}

/// "Issues" card: each note you sent (right) and the admin's answer
/// (left), oldest first, like a chat.
class IssueConversation extends StatelessWidget {
  final List<ItemIssue> issues;

  const IssueConversation({super.key, required this.issues});

  (Color, Color) _statusColors(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
      case 'pending':
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case 'reactivated':
        return (const Color(0xFFEEF2FF), const Color(0xFF3730A3));
      default:
        return (const Color(0xFFF1F5F9), const Color(0xFF475569));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Backend order is oldest first — keep it so it reads like a chat.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined,
                  size: 18, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Text(
                'Issues (${issues.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (issues.isEmpty)
            const Text(
              'No issues reported. Use Report above to message your admin.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          if (issues.isNotEmpty)
            IssueScrollBox(
              startAtEnd: true,
              children: [
                for (var i = 0; i < issues.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                  _buildThread(issues[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildThread(ItemIssue issue) {
    final (bg, fg) = _statusColors(issue.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // You
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    issue.note,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (issue.atText != null)
                      Text(
                        'You · ${issue.atText}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textHint,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        issue.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Admin
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: issue.adminReply != null
                        ? const Color(0xFFF1F5F9)
                        : Colors.transparent,
                    border: issue.adminReply != null
                        ? null
                        : Border.all(color: AppColors.border),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: Text(
                    issue.adminReply ?? 'Waiting for admin reply…',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontStyle: issue.adminReply != null
                          ? FontStyle.normal
                          : FontStyle.italic,
                      color: issue.adminReply != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Admin',
                  style: TextStyle(fontSize: 10.5, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
