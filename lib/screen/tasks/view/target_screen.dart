// ╔══════════════════════════════════════════════════════════════╗
// ║           lib/screen/tasks/view/target_screen.dart           ║
// ║  VIEW — My Targets. Renders TargetViewModel state and         ║
// ║  forwards user actions to it. No Dio / JSON / calculations.   ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/deals/ui/deal_screen.dart' show DealsScreen;
import 'package:crm_app/screen/leads/ui/lead_screen.dart' show LeadsScreen;
import 'package:crm_app/screen/tasks/api_service/target_api_service.dart';
import 'package:crm_app/screen/tasks/repository/target_repository.dart';
import 'package:crm_app/screen/tasks/view/report_activity_sheet.dart';
import 'package:crm_app/screen/tasks/view/reported_activity_list_sheet.dart';
import 'package:crm_app/screen/tasks/view/target_details_sheet.dart';
import 'package:crm_app/screen/tasks/view/target_widgets.dart';
import 'package:crm_app/screen/tasks/view/task_notifications_view.dart';
import 'package:crm_app/screen/tasks/viewmodel/target_state.dart';
import 'package:crm_app/screen/tasks/viewmodel/target_view_model.dart';
import 'package:crm_app/screen/tasks/view/task_widgets.dart'
    show OverviewPeriodDropdown, TaskFilterChip;
import 'package:crm_app/screen/tasks/view/task_pipeline_board.dart'
    show PipelineBoard, showMoveStageSheet;
import 'package:crm_app/screen/tasks/viewmodel/task_state.dart'
    show TaskStage;
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show EmptyState, LoadingState, ErrorState;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ══════════════════════════════════════════════════════════════
// ENTRY POINT — wires API Service → Repository → ViewModel
// ══════════════════════════════════════════════════════════════
class TargetScreen extends StatelessWidget {
  /// Opens the app's notifications; the bell is hidden when null.
  final VoidCallback? onOpenNotifications;

  /// Defaults to the live API; pass one to use other data (e.g. tests).
  final TargetRepository? repository;

  const TargetScreen({super.key, this.onOpenNotifications, this.repository});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TargetViewModel(
        repository ?? TargetRepository(TargetApiService(Dio())),
      )..load(),
      child: _TargetView(onOpenNotifications: onOpenNotifications),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MY TARGETS VIEW
// ══════════════════════════════════════════════════════════════
class _TargetView extends StatelessWidget {
  final VoidCallback? onOpenNotifications;

  const _TargetView({this.onOpenNotifications});

  static const _filterLabels = {
    TargetFilter.all: 'All',
    TargetFilter.weekly: 'Weekly',
    TargetFilter.monthly: 'Monthly',
    TargetFilter.notifications: 'Notifications & Reminders',
  };

  static const _overviewTitles = {
    'all': 'My Overview',
    'monthly': 'My Monthly Overview',
    'weekly': 'My Weekly Overview',
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
        title: const Text('How targets work'),
        content: const Text(
          '1. Admin sets target — leads, deals, calls and meetings to reach '
          'by the end date.\n\n'
          '2. You work towards it — convert leads and close deals as usual.\n\n'
          '3. Progress is tracked automatically from your leads and deals.\n\n'
          '4. Add notes if delayed — tell your admin what is holding you up.',
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
    final vm = context.read<TargetViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<TargetViewModel, TargetState>(
          builder: (context, state) {
            final showNotifications =
                state.filter == TargetFilter.notifications;

            return RefreshIndicator(
              color: TargetPalette.accent,
              onRefresh: () => _runAction(context, vm.refresh),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 28),
                children: [
                  _pad(TargetHeader(
                    onInfoTap: () => _showWorkflowInfo(context),
                    // Same as the Task screen: the bell opens the
                    // notifications tab (target notifications only).
                    onBellTap: () =>
                        vm.selectFilter(TargetFilter.notifications),
                  )),
                  if (showNotifications) ...[
                    // Overview hides; notifications start at the top.
                    const SizedBox(height: 14),
                    _buildFilters(vm, state),
                    const SizedBox(height: 8),
                    TaskNotificationsView(
                      status: state.notificationStatus,
                      errorMessage: state.notificationError,
                      groups: state.notificationGroups,
                      total: state.notifications.length,
                      unread: state.unreadCount,
                      emptyMessage: 'No target notifications yet',
                      onRetry: vm.reloadNotifications,
                      onReadAll: () =>
                          _runAction(context, vm.markAllNotificationsRead),
                      onTapNotification: vm.markNotificationRead,
                      onDelete: vm.deleteNotification,
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    _pad(const TargetStepsBanner()),
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
    TargetViewModel vm,
    TargetState state,
  ) {
    switch (state.status) {
      case TargetViewStatus.initial:
      case TargetViewStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: LoadingState(message: 'Loading targets...'),
          ),
        ];

      case TargetViewStatus.error:
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 40, 18, 0),
            child: ErrorState(
              message: state.errorMessage ?? 'Something went wrong',
              onRetry: vm.load,
            ),
          ),
        ];

      case TargetViewStatus.success:
      case TargetViewStatus.empty:
        return [
          _pad(_buildOverview(context, vm, state)),
          const SizedBox(height: 26),
          _pad(const Text(
            'Your Targets',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          )),
          const SizedBox(height: 12),
          if (state.status == TargetViewStatus.empty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: EmptyState(
                message: 'No targets assigned yet',
                icon: Icons.track_changes_rounded,
              ),
            )
          else ...[
            _pad(TargetSummaryCard(summary: state.summary)),
            const SizedBox(height: 16),
            _buildFilters(vm, state),
            const SizedBox(height: 16),
            // The board pads itself so columns can swipe edge to edge.
            if (state.viewMode == TargetViewMode.pipeline)
              PipelineBoard<TargetCardData>(
                columns: state.pipeline,
                emptyText: 'No targets',
                cardBuilder: (data) => TargetPipelineCard(
                  data: data,
                  onTap: () => showMoveStageSheet(
                    context,
                    title: data.title,
                    current: TaskStage.fromTargetStatus(data.target.status),
                    onMove: (stage, reason) =>
                        vm.moveTarget(data.target, stage, reason: reason),
                  ),
                ),
              )
            else
              ..._buildTargetList(context, state).map(_pad),
          ],
        ];
    }
  }

  Widget _buildOverview(
    BuildContext context,
    TargetViewModel vm,
    TargetState state,
  ) {
    final stats = state.stats;

    Widget card(
      int value,
      String unit,
      String label,
      OverviewChartStyle chart,
      Widget page,
    ) =>
        Expanded(
          child: OverviewMetricCard(
            value: value,
            unit: unit,
            label: label,
            chart: chart,
            onTap: () => _push(context, page),
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _overviewTitles[state.period] ?? 'My Overview',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
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
            card(stats.totalLeads, 'leads', 'Total leads',
                OverviewChartStyle.statusBars,
                const LeadsScreen(showBackButton: true)),
            const SizedBox(width: 12),
            card(stats.totalDeals, 'deals', 'Total deals',
                OverviewChartStyle.trendLine, const DealsScreen()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            card(stats.wonDeals, 'won', 'Deals closed',
                OverviewChartStyle.dotPlot,
                const DealsScreen(initialStageFilter: 'Closed Won')),
            const SizedBox(width: 12),
            card(stats.lostDeals, 'lost', 'Deals lost',
                OverviewChartStyle.lollipop,
                const DealsScreen(initialStageFilter: 'Closed Lost')),
          ],
        ),
        const SizedBox(height: 10),
        const OverviewLegend(),
      ],
    );
  }

  /// Filter chips, plus the Card | Pipeline toggle on the right (hidden on
  /// the notifications tab, where it doesn't apply).
  Widget _buildFilters(TargetViewModel vm, TargetState state) {
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 18, right: 10),
      child: Row(
        children: [
          for (final f in TargetFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TaskFilterChip(
                label: _filterLabels[f]!,
                icon: f == TargetFilter.notifications
                    ? Icons.notifications_none_rounded
                    : null,
                badgeCount:
                    f == TargetFilter.notifications ? state.unreadCount : 0,
                selected: state.filter == f,
                onTap: () => vm.selectFilter(f),
              ),
            ),
        ],
      ),
    );

    if (state.filter == TargetFilter.notifications) return chips;

    return Row(
      children: [
        Expanded(child: chips),
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: TargetViewToggle(
            value: state.viewMode,
            onChanged: vm.setViewMode,
          ),
        ),
      ],
    );
  }

  Future<void> _report(
    BuildContext context,
    TargetCardData data,
    TargetMetricKind kind,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final targetId = data.target.id;

    if (targetId == null) return;

    final vm = context.read<TargetViewModel>();
    final isCall = kind == TargetMetricKind.calls;

    final open = isCall ? showReportCallSheet : showReportMeetingSheet;
    final reported = await open(context, viewModel: vm, targetId: targetId);

    if (reported) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(isCall
              ? 'Call report added successfully'
              : 'Meeting report added successfully'),
          backgroundColor: AppColors.success,
        ));
    }
  }

  void _viewReports(
    BuildContext context,
    TargetCardData data,
    TargetMetricKind kind,
  ) {
    final vm = context.read<TargetViewModel>();
    if (kind == TargetMetricKind.calls) {
      showReportedCallsSheet(context, viewModel: vm, rows: data.reportedCalls);
    } else {
      showReportedMeetingsSheet(context,
          viewModel: vm, rows: data.reportedMeetings);
    }
  }

  List<Widget> _buildTargetList(BuildContext context, TargetState state) {
    if (state.visibleTargets.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 30),
          child: EmptyState(
            message: 'No targets match this filter',
            icon: Icons.track_changes_rounded,
          ),
        ),
      ];
    }

    return [
      for (final data in state.visibleTargets)
        TargetCard(
          data: data,
          onDetails: () => showTargetDetailsSheet(
            context,
            data: data,
            viewModel: context.read<TargetViewModel>(),
          ),
          onReport: (kind) => _report(context, data, kind),
          onView: (kind) => _viewReports(context, data, kind),
        ),
    ];
  }
}
