// ╔══════════════════════════════════════════════════════════════╗
// ║             lib/screen/tasks/view/task_screen.dart            ║
// ║  VIEW — My Tasks dashboard. Renders TaskViewModel state and   ║
// ║  forwards user actions to it. No Dio / JSON / calculations.   ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/deals/ui/deal_screen.dart' show DealsScreen;
import 'package:crm_app/screen/leads/ui/lead_screen.dart' show LeadsScreen;
import 'package:crm_app/screen/tasks/api_service/task_api_service.dart';
import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/repository/task_repository.dart';
import 'package:crm_app/screen/tasks/view/linked_items_sheet.dart';
import 'package:crm_app/screen/tasks/view/task_notifications_view.dart';
import 'package:crm_app/screen/tasks/view/task_pipeline_board.dart';
import 'package:crm_app/screen/tasks/view/task_widgets.dart';
import 'package:crm_app/screen/tasks/viewmodel/task_state.dart';
import 'package:crm_app/screen/tasks/viewmodel/task_view_model.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show EmptyState, LoadingState, ErrorState;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ══════════════════════════════════════════════════════════════
// ENTRY POINT — wires API Service → Repository → ViewModel
// ══════════════════════════════════════════════════════════════
class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskViewModel(
        TaskRepository(TaskApiService(Dio())),
      )..load(),
      child: const _TaskView(),
    );
  }
}

// Decorative trend shapes for the overview cards — the stats endpoint
// returns totals only, not a time series.
const _leadBars = [0.12, 0.16, 0.22, 0.3, 0.36, 0.45, 0.55, 0.64, 0.74, 0.95];
const _dealBars = [0.1, 0.14, 0.2, 0.26, 0.34, 0.42, 0.52, 0.62, 0.72, 0.95];
const _closedLine = [0.1, 0.25, 0.2, 0.42, 0.3, 0.52, 0.38, 0.6, 0.66, 0.85];
const _lostLine = [0.25, 0.18, 0.55, 0.3, 0.42, 0.62, 0.45, 0.9];

// ══════════════════════════════════════════════════════════════
// MY TASKS VIEW
// ══════════════════════════════════════════════════════════════
class _TaskView extends StatelessWidget {
  const _TaskView();

  static const _filterLabels = {
    TaskFilter.all: 'All',
    TaskFilter.newTask: 'New Task',
    TaskFilter.notifications: 'Notifications',
  };

  static Widget _pad(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: child,
      );

  /// Runs a ViewModel action that returns an error message (or null)
  /// and shows the error as a snackbar.
  Future<void> _runAction(
    BuildContext context,
    Future<String?> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await action();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _showWorkflowInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How tasks work'),
        content: const Text(
          '1. Start Task — begin working on a task your admin assigned.\n\n'
          '2. Mark as Done — once the linked leads and deals are handled.\n\n'
          '3. Admin Approves — your admin reviews and closes the task.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<TaskViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<TaskViewModel, TaskState>(
          builder: (context, state) {
            final showNotifications =
                state.filter == TaskFilter.notifications;

            return RefreshIndicator(
              color: TaskPalette.accent,
              onRefresh: () => _runAction(context, vm.refresh),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 28),
                children: [
                  _pad(TaskHeader(
                    onInfoTap: () => _showWorkflowInfo(context),
                    onBellTap: () =>
                        vm.selectFilter(TaskFilter.notifications),
                  )),
                  if (showNotifications) ...[
                    // Dashboard hides; notifications start at the top.
                    const SizedBox(height: 14),
                    _buildFilters(vm, state),
                    const SizedBox(height: 8),
                    TaskNotificationsView(
                      status: state.notificationStatus,
                      errorMessage: state.notificationError,
                      groups: state.notificationGroups,
                      total: state.notifications.length,
                      unread: state.unreadCount,
                      onRetry: vm.reloadNotifications,
                      onReadAll: () =>
                          _runAction(context, vm.markAllNotificationsRead),
                      onTapNotification: vm.markNotificationRead,
                      onDelete: vm.deleteNotification,
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    _pad(const TaskFlowBanner()),
                    const SizedBox(height: 24),
                    ..._buildBody(context, vm, state),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    TaskViewModel vm,
    TaskState state,
  ) {
    switch (state.status) {
      case TaskViewStatus.initial:
      case TaskViewStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: LoadingState(message: 'Loading tasks...'),
          ),
        ];

      case TaskViewStatus.error:
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 40, 18, 0),
            child: ErrorState(
              message: state.errorMessage ?? 'Something went wrong',
              onRetry: vm.load,
            ),
          ),
        ];

      case TaskViewStatus.success:
      case TaskViewStatus.empty:
        return [
          _pad(_buildOverview(context, vm, state)),
          const SizedBox(height: 22),
          _buildFilters(vm, state),
          const SizedBox(height: 16),
          _pad(Row(
            children: [
              Expanded(
                child: Text(
                  '${state.visibleTasks.length} '
                  '${state.visibleTasks.length == 1 ? 'task' : 'tasks'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TaskViewToggle(
                value: state.viewMode,
                onChanged: vm.setViewMode,
              ),
            ],
          )),
          const SizedBox(height: 16),
          // The board pads itself so columns can swipe edge to edge.
          if (state.viewMode == TaskViewMode.pipeline)
            PipelineBoard<TaskCardData>(
              columns: state.pipeline,
              emptyText: 'No tasks',
              cardBuilder: (data) => TaskPipelineCard(
                data: data,
                onTap: () => showMoveTaskSheet(
                  context,
                  data: data,
                  viewModel: vm,
                ),
              ),
            )
          else
            ..._buildTaskList(context, state).map(_pad),
        ];
    }
  }

  Widget _buildOverview(
    BuildContext context,
    TaskViewModel vm,
    TaskState state,
  ) {
    final stats = state.stats;

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'My Dashboard Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OverviewPeriodDropdown(
              value: state.period,
              onChanged: (period) =>
                  _runAction(context, () => vm.changePeriod(period)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OverviewStatCard(
                label: 'Total Leads',
                value: stats.totalLeads,
                icon: Icons.people_outline_rounded,
                color: const Color(0xFF1D4ED8),
                lightColor: const Color(0xFFBFDBFE),
                bgStart: const Color(0xFFEFF4FF),
                bgEnd: const Color(0xFFF8FAFF),
                borderColor: const Color(0xFFD6E4FF),
                chart: OverviewChart.bars,
                chartValues: _leadBars,
                onTap: () => _push(
                  context,
                  const LeadsScreen(showBackButton: true),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OverviewStatCard(
                label: 'Total Deals',
                value: stats.totalDeals,
                icon: Icons.work_outline_rounded,
                color: const Color(0xFF047857),
                lightColor: const Color(0xFFA7F3D0),
                bgStart: const Color(0xFFECFDF5),
                bgEnd: const Color(0xFFF5FFFA),
                borderColor: const Color(0xFFC9F0DD),
                chart: OverviewChart.bars,
                chartValues: _dealBars,
                onTap: () => _push(context, const DealsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OverviewStatCard(
                label: 'Deal Closed',
                value: stats.wonDeals,
                icon: Icons.workspace_premium_outlined,
                color: const Color(0xFF6D28D9),
                lightColor: const Color(0xFFDDD6FE),
                bgStart: const Color(0xFFF5F3FF),
                bgEnd: const Color(0xFFFBFAFF),
                borderColor: const Color(0xFFE4DCFD),
                chart: OverviewChart.line,
                chartValues: _closedLine,
                onTap: () => _push(
                  context,
                  const DealsScreen(initialStageFilter: 'Closed Won'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OverviewStatCard(
                label: 'Deal Lost',
                value: stats.lostDeals,
                icon: Icons.cancel_outlined,
                color: const Color(0xFFDC2626),
                lightColor: const Color(0xFFFECACA),
                bgStart: const Color(0xFFFEF2F2),
                bgEnd: const Color(0xFFFFF9F9),
                borderColor: const Color(0xFFFBD5D5),
                chart: OverviewChart.line,
                chartValues: _lostLine,
                onTap: () => _push(
                  context,
                  const DealsScreen(initialStageFilter: 'Closed Lost'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters(TaskViewModel vm, TaskState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          for (final f in TaskFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TaskFilterChip(
                label: _filterLabels[f]!,
                icon: f == TaskFilter.notifications
                    ? Icons.notifications_none_rounded
                    : null,
                badgeCount:
                    f == TaskFilter.notifications ? state.unreadCount : 0,
                selected: state.filter == f,
                onTap: () => vm.selectFilter(f),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTaskList(BuildContext context, TaskState state) {
    if (state.visibleTasks.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: EmptyState(
            message: state.status == TaskViewStatus.empty
                ? 'No tasks assigned yet'
                : 'No tasks match this filter',
            icon: Icons.task_alt_outlined,
          ),
        ),
      ];
    }

    return [
      for (final data in state.visibleTasks)
        state.viewMode == TaskViewMode.grid
            ? TaskCard(
                data: data,
                onViewLinked: () => _openLinkedItems(context, data.task),
              )
            : TaskListRow(
                data: data,
                onTap: () => _openLinkedItems(context, data.task),
              ),
    ];
  }

  void _openLinkedItems(BuildContext context, TaskModel task) {
    final vm = context.read<TaskViewModel>();

    showLinkedItemsSheet(
      context,
      task: task,
      repository: vm.repository,
      // A reported issue adds "Pending admin review" — reload the list.
      onReported: vm.refresh,
    );
  }
}
