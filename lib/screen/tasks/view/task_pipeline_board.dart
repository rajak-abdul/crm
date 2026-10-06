// ╔══════════════════════════════════════════════════════════════╗
// ║        lib/screen/tasks/view/task_pipeline_board.dart        ║
// ║  VIEW — My Tasks "Pipeline": swipeable stage columns (New →   ║
// ║  Rejected) and the "Move card" sheet that changes a task's    ║
// ║  status via TaskViewModel.moveTask.                           ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/viewmodel/task_state.dart';
import 'package:crm_app/screen/tasks/viewmodel/task_view_model.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';

Color taskStageColor(TaskStage stage) {
  switch (stage) {
    case TaskStage.newTask:
      return const Color(0xFF2563EB);
    case TaskStage.inProgress:
      return const Color(0xFFD97706);
    case TaskStage.inHold:
      return const Color(0xFF9333EA);
    case TaskStage.completed:
      return const Color(0xFF16A34A);
    case TaskStage.rejected:
      return const Color(0xFFDC2626);
  }
}

// ══════════════════════════════════════════════════════════════
// BOARD
// ══════════════════════════════════════════════════════════════
/// Swipeable stage board shared by My Tasks ([T] = TaskCardData) and My
/// Targets ([T] = TargetCardData); [cardBuilder] draws one card.
class PipelineBoard<T> extends StatefulWidget {
  final List<TaskPipelineColumn<T>> columns;
  final Widget Function(T item) cardBuilder;

  /// e.g. "No tasks" / "No targets" for an empty column.
  final String emptyText;

  const PipelineBoard({
    super.key,
    required this.columns,
    required this.cardBuilder,
    this.emptyText = 'No items',
  });

  @override
  State<PipelineBoard<T>> createState() => _PipelineBoardState<T>();
}

class _PipelineBoardState<T> extends State<PipelineBoard<T>> {
  static const _columnHeight = 470.0;

  final _pages = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.columns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stage chips — tap to jump to a column.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _StageChip(
                    column: columns[i],
                    selected: i == _page,
                    onTap: () => _goTo(i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _columnHeight,
          child: PageView.builder(
            controller: _pages,
            padEnds: false,
            itemCount: columns.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 18 : 6,
                right: i == columns.length - 1 ? 18 : 6,
              ),
              child: _StageColumn<T>(
                column: columns[i],
                cardBuilder: widget.cardBuilder,
                emptyText: widget.emptyText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Swipe left / right to browse stages · Tap a card to move it',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  final TaskPipelineColumn<Object?> column;
  final bool selected;
  final VoidCallback onTap;

  const _StageChip({
    required this.column,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = taskStageColor(column.stage);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '${column.stage.label} ${column.items.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageColumn<T> extends StatelessWidget {
  final TaskPipelineColumn<T> column;
  final Widget Function(T item) cardBuilder;
  final String emptyText;

  const _StageColumn({
    required this.column,
    required this.cardBuilder,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final color = taskStageColor(column.stage);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  column.stage.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${column.items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: column.items.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint),
                    ),
                  )
                : Scrollbar(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 10),
                      itemCount: column.items.length,
                      itemBuilder: (_, i) => cardBuilder(column.items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Task card on the pipeline board.
class TaskPipelineCard extends StatelessWidget {
  final TaskCardData data;
  final VoidCallback onTap;

  const TaskPipelineCard({super.key, required this.data, required this.onTap});

  Color get _dueColor {
    switch (data.dueTone) {
      case DueTone.overdue:
        return const Color(0xFFDC2626);
      case DueTone.soon:
        return const Color(0xFFD97706);
      case DueTone.normal:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = data.task;
    final pills = [
      if (task.holdRequested == true) 'Hold requested',
      if (task.rejectionRequested == true) 'Rejection requested',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (data.assignedBy.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'By ${data.assignedBy}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in pills)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            p,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      data.linkedSummary,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (data.dueLabel != null)
                      Text(
                        [data.dueLabel, data.dueSuffix]
                            .whereType<String>()
                            .join(' · '),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _dueColor,
                        ),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Tap to change status →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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

// ══════════════════════════════════════════════════════════════
// MOVE CARD SHEET
// ══════════════════════════════════════════════════════════════

/// Opens "Move card" for a task.
Future<void> showMoveTaskSheet(
  BuildContext context, {
  required TaskCardData data,
  required TaskViewModel viewModel,
}) =>
    showMoveStageSheet(
      context,
      title: data.task.title ?? 'Task',
      current: TaskStage.fromStatus(data.task.status),
      onMove: (stage, reason) =>
          viewModel.moveTask(data.task, stage, reason: reason),
    );

/// Opens "Move card" for any pipeline item (task or target). [onMove]
/// saves the move and returns an error message or null; In Hold always
/// asks for a reason first.
Future<void> showMoveStageSheet(
  BuildContext context, {
  required String title,
  required TaskStage current,
  required Future<String?> Function(TaskStage stage, String? reason) onMove,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _MoveStageSheet(title: title, current: current, onMove: onMove),
  );
}

class _MoveStageSheet extends StatefulWidget {
  final String title;
  final TaskStage current;
  final Future<String?> Function(TaskStage stage, String? reason) onMove;

  const _MoveStageSheet({
    required this.title,
    required this.current,
    required this.onMove,
  });

  @override
  State<_MoveStageSheet> createState() => _MoveStageSheetState();
}

class _MoveStageSheetState extends State<_MoveStageSheet> {
  late final TaskStage _current = widget.current;
  late TaskStage _selected = _current;

  final _reason = TextEditingController();
  bool _moving = false;

  bool get _needsReason => _selected == TaskStage.inHold;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _move() async {
    if (_selected == _current) {
      Navigator.of(context).pop();
      return;
    }
    if (_needsReason && _reason.text.trim().isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _moving = true);
    final error = await widget.onMove(
      _selected,
      _needsReason ? _reason.text : null,
    );
    if (!mounted) return;

    if (error != null) {
      setState(() => _moving = false);
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text(_selected == TaskStage.inHold
            ? 'Hold requested — waiting for admin approval'
            : '${widget.title} moved to '
                '${_selected.label}'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final canMove = !_moving &&
        (_selected == _current ||
            !_needsReason ||
            _reason.text.trim().isNotEmpty);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Move card',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.title} · Current: ${_current.label}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'SELECT STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 2.6,
                children: [
                  for (final stage in TaskStage.values)
                    _StageOption(
                      stage: stage,
                      isCurrent: stage == _current,
                      selected: stage == _selected,
                      onTap: _moving
                          ? null
                          : () => setState(() => _selected = stage),
                    ),
                ],
              ),
              if (_needsReason && _selected != _current) ...[
                const SizedBox(height: 14),
                const Text(
                  'Reason for hold *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reason,
                  enabled: !_moving,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Why should this be on hold?',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textHint,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your admin approves hold requests.',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: canMove ? _move : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF2563EB).withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: _moving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _selected == _current ? 'Close' : 'Move Card',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
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

class _StageOption extends StatelessWidget {
  final TaskStage stage;
  final bool isCurrent;
  final bool selected;
  final VoidCallback? onTap;

  const _StageOption({
    required this.stage,
    required this.isCurrent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = taskStageColor(stage);

    return Material(
      color: selected ? color.withValues(alpha: 0.08) : AppColors.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      stage.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                isCurrent ? 'Current status' : 'Move here',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
