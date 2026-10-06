// ╔══════════════════════════════════════════════════════════════╗
// ║          lib/screen/tasks/view/linked_item_detail.dart        ║
// ║  VIEW — detail of one linked deal/lead inside the Linked      ║
// ║  items sheet: value card, Call / WhatsApp / Report, journey.  ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/view/linked_items_sheet.dart'
    show LinkedBadge, SheetHandle;
import 'package:crm_app/screen/tasks/view/task_widgets.dart'
    show TaskPalette;
import 'package:crm_app/screen/tasks/viewmodel/linked_items_state.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkedItemDetail extends StatelessWidget {
  final LinkedItemData item;
  final int position;
  final int total;
  final bool reporting;
  final ScrollController controller;

  /// Back to the list.
  final VoidCallback onBack;

  /// Sends an issue note; returns an error message or null. When null the
  /// Report button is shown disabled.
  final Future<String?> Function(String note)? onReportIssue;

  final VoidCallback? onReported;

  /// Optional extra content shown right under the summary card (e.g. the
  /// issue conversation on the Target screen).
  final Widget? belowSummary;

  const LinkedItemDetail({
    super.key,
    required this.item,
    required this.position,
    required this.total,
    required this.controller,
    required this.onBack,
    this.reporting = false,
    this.onReportIssue,
    this.onReported,
    this.belowSummary,
  });

  bool get _isDeal => item.kind == LinkedItemKind.deal;

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _launch(BuildContext context, Uri uri, String error) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) messenger.showSnackBar(SnackBar(content: Text(error)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _call(BuildContext context) => _launch(
        context,
        Uri(scheme: 'tel', path: item.phone),
        'Unable to place call.',
      );

  void _whatsApp(BuildContext context) => _launch(
        context,
        Uri.parse('https://wa.me/${item.whatsAppNumber}'),
        'Unable to open WhatsApp.',
      );

  Future<void> _report(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReportDialog(itemTitle: item.title),
    );
    if (note == null || note.trim().isEmpty) return;

    final error = await onReportIssue!(note);

    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Issue reported to your admin'),
    ));
    if (error == null) onReported?.call();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded,
                          size: 22, color: AppColors.textPrimary),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_isDeal ? 'Deal' : 'Lead'} $position of $total',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          size: 22, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _buildSummaryCard(context),
              const SizedBox(height: 12),
              if (belowSummary != null) ...[
                belowSummary!,
                const SizedBox(height: 12),
              ],
              _JourneyCard(
                title: _isDeal ? 'Stage journey' : 'Status journey',
                steps: item.journey,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final hasPhone = item.phone != null;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDeal ? 'Deal value' : 'Company',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.valueText ?? '-',
                      style: TextStyle(
                        fontSize: _isDeal ? 20 : 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LinkedBadge(item: item),
            ],
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.phone_outlined,
            text: item.phone ?? 'No phone added',
            color: hasPhone ? TaskPalette.link : AppColors.textHint,
            onTap: hasPhone ? () => _call(context) : null,
          ),
          _InfoLine(
            icon: Icons.mail_outline_rounded,
            text: item.email ?? 'No email added',
            color: item.email != null
                ? AppColors.textSecondary
                : AppColors.textHint,
          ),
          if (item.convertedByLabel != null)
            _InfoLine(
              icon: Icons.sync_alt_rounded,
              text: 'Converted by ${item.convertedByLabel}',
              color: AppColors.textSecondary,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.phone_outlined,
                  label: 'Call',
                  fg: TaskPalette.link,
                  bg: TaskPalette.linkBg,
                  border: TaskPalette.linkBorder,
                  onTap: hasPhone ? () => _call(context) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'WhatsApp',
                  fg: const Color(0xFF059669),
                  bg: AppColors.successLight,
                  border: const Color(0xFFA7F3D0),
                  onTap: item.whatsAppNumber != null
                      ? () => _whatsApp(context)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.outlined_flag_rounded,
                  label: 'Report',
                  fg: const Color(0xFFDC2626),
                  bg: AppColors.dangerLight,
                  border: const Color(0xFFFECACA),
                  loading: reporting,
                  onTap: reporting || onReportIssue == null
                      ? null
                      : () => _report(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SUMMARY CARD PARTS
// ══════════════════════════════════════════════════════════════
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const _InfoLine({
    required this.icon,
    required this.text,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12.5, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final Color border;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled || loading ? 1 : 0.45,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                loading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: fg),
                      )
                    : Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  final String itemTitle;

  const _ReportDialog({required this.itemTitle});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report an issue', style: TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.itemTitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'What is the problem?',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, value, __) => FilledButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, value.text),
            child: const Text('Submit'),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// JOURNEY TIMELINE
// ══════════════════════════════════════════════════════════════
class _JourneyCard extends StatelessWidget {
  final String title;
  final List<JourneyStep> steps;

  const _JourneyCard({required this.title, required this.steps});

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.schedule_rounded,
                  size: 18, color: AppColors.purple),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (steps.isEmpty)
            const Text(
              'No history yet',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else
            for (var i = 0; i < steps.length; i++)
              _JourneyRow(step: steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _JourneyRow extends StatelessWidget {
  final JourneyStep step;
  final bool isLast;

  const _JourneyRow({required this.step, required this.isLast});

  (IconData, Color) get _icon {
    switch (step.kind) {
      case JourneyKind.dealStage:
        return (Icons.assignment_turned_in_outlined, AppColors.primary);
      case JourneyKind.converted:
        return (Icons.sync_alt_rounded, const Color(0xFF059669));
      case JourneyKind.leadCreated:
        return (Icons.person_add_alt_outlined, AppColors.textSecondary);
      case JourneyKind.leadStatus:
        switch (step.title.toLowerCase()) {
          case 'hot':
            return (Icons.local_fire_department_outlined, AppColors.hot);
          case 'warm':
            return (Icons.wb_sunny_outlined, AppColors.warm);
          case 'cold':
            return (Icons.ac_unit_rounded, AppColors.cold);
          case 'junk':
            return (Icons.delete_outline_rounded, AppColors.junk);
          case 'new':
            return (Icons.fiber_new_outlined, AppColors.primary);
          default:
            return (Icons.radio_button_unchecked, AppColors.textSecondary);
        }
    }
  }

  Color get _dotColor {
    if (step.isCurrent) return AppColors.primary;
    if (step.kind == JourneyKind.converted) return const Color(0xFF059669);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = _icon;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                    border: step.isCurrent
                        ? Border.all(color: const Color(0xFFBFDBFE), width: 2)
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: step.isCurrent
                    ? AppColors.primaryLight
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: step.isCurrent
                      ? const Color(0xFFBFDBFE)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                step.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (step.isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (step.atText != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            step.atText!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 15, color: iconColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
