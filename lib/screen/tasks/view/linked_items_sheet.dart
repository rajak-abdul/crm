// ╔══════════════════════════════════════════════════════════════╗
// ║          lib/screen/tasks/view/linked_items_sheet.dart        ║
// ║  VIEW — "Linked items" bottom sheet (Deals / Leads tabs).     ║
// ║  Tapping an item swaps the sheet to LinkedItemDetail.         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/repository/task_repository.dart';
import 'package:crm_app/screen/tasks/view/issue_conversation.dart';
import 'package:crm_app/screen/tasks/view/linked_item_detail.dart';
import 'package:crm_app/screen/tasks/view/task_widgets.dart'
    show TaskPalette;
import 'package:crm_app/screen/tasks/viewmodel/linked_items_state.dart';
import 'package:crm_app/screen/tasks/viewmodel/linked_items_view_model.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the linked items sheet for [task]. [onReported] runs after an
/// issue is reported so the caller can refresh its task list.
Future<void> showLinkedItemsSheet(
  BuildContext context, {
  required TaskModel task,
  required TaskRepository repository,
  VoidCallback? onReported,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => BlocProvider(
      create: (_) =>
          LinkedItemsViewModel(task: task, repository: repository)..init(),
      // Own ScaffoldMessenger so snackbars show above the sheet.
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(sheetContext).pop(),
            child: GestureDetector(
              // Swallow taps on the sheet itself.
              onTap: () {},
              child: _LinkedItemsSheet(onReported: onReported),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Badge colours for a deal stage / lead status.
(Color, Color) linkedBadgeColors(LinkedItemData item) {
  if (item.kind == LinkedItemKind.deal) {
    return (const Color(0xFFE0F2FE), const Color(0xFF0369A1));
  }
  switch (item.badge.toLowerCase()) {
    case 'hot':
      return (AppColors.hotBg, AppColors.hot);
    case 'warm':
      return (AppColors.warmBg, const Color(0xFFB45309));
    case 'cold':
      return (AppColors.coldBg, AppColors.cold);
    case 'converted':
      return (AppColors.convertedBg, const Color(0xFF047857));
    case 'junk':
      return (AppColors.junkBg, AppColors.junk);
    default:
      return (const Color(0xFFF1F5F9), const Color(0xFF475569));
  }
}

class LinkedBadge extends StatelessWidget {
  final LinkedItemData item;

  const LinkedBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = linkedBadgeColors(item);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        item.badge,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHEET — list ↔ detail
// ══════════════════════════════════════════════════════════════
class _LinkedItemsSheet extends StatelessWidget {
  final VoidCallback? onReported;

  const _LinkedItemsSheet({this.onReported});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: BlocBuilder<LinkedItemsViewModel, LinkedItemsState>(
          builder: (context, state) {
            final vm = context.read<LinkedItemsViewModel>();
            final open = state.openItem;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: open == null
                  ? _LinkedList(
                      key: const ValueKey('list'),
                      state: state,
                      vm: vm,
                      controller: controller,
                    )
                  : LinkedItemDetail(
                      key: ValueKey('${state.tab}-${state.openIndex}'),
                      item: open,
                      position: state.openIndex! + 1,
                      total: state.currentItems.length,
                      reporting: state.reporting,
                      onBack: vm.closeItem,
                      onReportIssue: vm.reportIssue,
                      belowSummary: IssueConversation(
                        issues: state.issuesFor(open),
                      ),
                      controller: controller,
                      onReported: onReported,
                    ),
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LIST — header, Deals / Leads tabs, item cards
// ══════════════════════════════════════════════════════════════
class _LinkedList extends StatelessWidget {
  final LinkedItemsState state;
  final LinkedItemsViewModel vm;
  final ScrollController controller;

  const _LinkedList({
    super.key,
    required this.state,
    required this.vm,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final items = state.currentItems;

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
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Linked items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.taskTitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
              Row(
                children: [
                  _TabButton(
                    label: 'Deals',
                    count: state.deals.length,
                    selected: state.tab == LinkedTab.deals,
                    onTap: () => vm.selectTab(LinkedTab.deals),
                  ),
                  _TabButton(
                    label: 'Leads',
                    count: state.leads.length,
                    selected: state.tab == LinkedTab.leads,
                    onTap: () => vm.selectTab(LinkedTab.leads),
                  ),
                ],
              ),
              const Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? ListView(
                  controller: controller,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          state.tab == LinkedTab.deals
                              ? 'No deals linked to this task'
                              : 'No leads linked to this task',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) => LinkedItemCard(
                    item: items[i],
                    onTap: () => vm.openItem(i),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? TaskPalette.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFF0369A1)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LinkedItemCard extends StatelessWidget {
  final LinkedItemData item;
  final VoidCallback onTap;

  const LinkedItemCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDeal = item.kind == LinkedItemKind.deal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    LinkedBadge(item: item),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textHint),
                  ],
                ),
                if (item.convertedByMe) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Converted by you',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (isDeal && item.valueText != null)
                  _CardLine(
                    icon: Icons.payments_outlined,
                    text: item.valueText!,
                    strong: true,
                  ),
                if (item.phone != null)
                  _CardLine(icon: Icons.phone_outlined, text: item.phone!),
                if (item.email != null)
                  _CardLine(icon: Icons.mail_outline_rounded, text: item.email!),
                if (!isDeal && item.valueText != null)
                  _CardLine(
                    icon: Icons.business_outlined,
                    text: item.valueText!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool strong;

  const _CardLine({
    required this.icon,
    required this.text,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: strong ? 13 : 12,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: strong
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
