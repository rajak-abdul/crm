// ╔══════════════════════════════════════════════════════════════╗
// ║     lib/screen/tasks/viewmodel/linked_items_view_model.dart   ║
// ║  VIEWMODEL (Cubit) for the Linked items sheet and the linked  ║
// ║  deal/lead detail. Talks only to the Repository.              ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/repository/task_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'linked_item_presenter.dart';
import 'linked_items_state.dart';

class LinkedItemsViewModel extends Cubit<LinkedItemsState> {
  final TaskModel task;
  final TaskRepository repository;

  LinkedItemPresenter _presenter = const LinkedItemPresenter();

  LinkedItemsViewModel({required this.task, required this.repository})
      : super(LinkedItemsState(
          taskTitle: task.title ?? '-',
          tab: task.dealRefs.isNotEmpty ? LinkedTab.deals : LinkedTab.leads,
          deals: const [],
          leads: const [],
        )) {
    _rebuildItems();
  }

  /// Loads the current user so "Converted by you" can be shown.
  Future<void> init() async {
    final userId = await repository.getCurrentUserId();
    if (isClosed) return;
    _presenter = LinkedItemPresenter(currentUserId: userId);
    _rebuildItems();
  }

  // ============================================================
  // USER ACTIONS
  // ============================================================

  void selectTab(LinkedTab tab) {
    if (tab == state.tab) return;
    emit(state.copyWith(tab: tab));
  }

  void openItem(int index) => emit(state.copyWith(openIndex: index));

  void closeItem() => emit(state.copyWith());

  /// Reports an issue about the open item (or the task when none is open).
  /// Returns an error message on failure.
  Future<String?> reportIssue(String note) async {
    final item = state.openItem;
    final openIndex = state.openIndex;

    emit(state.copyWith(openIndex: openIndex, reporting: true));

    try {
      await repository.reportTaskIssue(
        taskId: task.id ?? '',
        note: note.trim(),
        itemType: item == null
            ? 'task'
            : item.kind == LinkedItemKind.deal
                ? 'deal'
                : 'lead',
        itemId: item?.id,
        itemName: item?.title ?? task.title,
      );

      // Show it in the item's conversation straight away; the task list
      // reloads separately (onReported).
      final itemId = item?.id;
      if (itemId != null && !isClosed) {
        final updated = {
          ...state.issuesByItem,
          itemId: [
            ...state.issuesFor(item!),
            ItemIssue(
              note: note.trim(),
              status: 'pending',
              atText: _formatDateTime(DateTime.now()),
            ),
          ],
        };
        emit(state.copyWith(openIndex: openIndex, issuesByItem: updated));
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      if (!isClosed) {
        emit(state.copyWith(openIndex: openIndex, reporting: false));
      }
    }
  }

  // ============================================================
  // PRESENTATION LOGIC
  // ============================================================

  void _rebuildItems() {
    emit(state.copyWith(
      openIndex: state.openIndex,
      deals: task.dealRefs.map(_presenter.deal).toList(),
      leads: task.leadRefs.map(_presenter.lead).toList(),
      issuesByItem: _issuesByItem(),
    ));
  }

  /// The task's reason notes grouped by the lead / deal they are about.
  Map<String, List<ItemIssue>> _issuesByItem() {
    final byItem = <String, List<ItemIssue>>{};
    for (final r in task.reasonNotes) {
      final itemId = (r.itemId ?? '').trim();
      if (itemId.isEmpty) continue;

      final reply = (r.adminReply ?? '').trim();
      byItem.putIfAbsent(itemId, () => []).add(ItemIssue(
            note: (r.note ?? '').trim().isEmpty ? '-' : r.note!.trim(),
            status: (r.status ?? '').trim().isEmpty ? '-' : r.status!.trim(),
            adminReply: reply.isEmpty ? null : reply,
            atText: _formatDateTime(r.addedAt),
          ));
    }
    return byItem;
  }

  String? _formatDateTime(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('d MMM yyyy, h:mm a')
        .format(dt.toLocal())
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');
  }
}
