// ╔══════════════════════════════════════════════════════════════╗
// ║              lib/screen/deals/ui/deal_screen.dart            ║
// ║  Pure UI — all API calls live in deals_cubit.dart            ║
// ╚══════════════════════════════════════════════════════════════╝

// ignore_for_file: curly_braces_in_flow_control_structures


import 'package:crm_app/screen/deals/cubit/attachment_deals_cubit.dart';
import 'package:crm_app/screen/deals/cubit/deals_sheet.dart';
import 'package:crm_app/screen/deals/cubit/deals_sheet_state.dart';
import 'package:crm_app/screen/deals/cubit/followup_deal_cubit.dart';
import 'package:crm_app/screen/deals/ui/deal_detail_sheet.dart';
import 'package:crm_app/screen/deals/ui/deal_form_modal.dart';
import 'package:crm_app/screen/deals/ui/deals_shared_widget.dart';
import 'package:crm_app/screen/deals/ui/rejected_deals.dart';
import 'package:crm_app/screen/invoice/cubit/invoice_cubit.dart';
import 'package:crm_app/screen/meeting/cubit/meeting_cubit.dart';
import 'package:crm_app/shareWidgets/date_time.dart';
import 'package:crm_app/shareWidgets/missed_followup.dart';
import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show showApiSnack, ErrorState, LoadingState;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:crm_app/utils/permission_helper.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── UI-only helpers ───────────────────────────────────────────
Color stageColor(String s) => switch (DealConstants.canonicalStage(s)) {
      'Qualification' => const Color(0xFF0EA5E9),
      'Proposal Sent-Negotiation' => AppColors.purple,
      'Invoice Sent' => const Color(0xFFF59E0B),
      'Closed Won' => const Color(0xFF10B981),
      'Closed Lost' => const Color(0xFFEF4444),
      _ => AppColors.primary,
    };

IconData _stageIcon(String s) => switch (DealConstants.canonicalStage(s)) {
      'Qualification' => Icons.checklist_outlined,
      'Proposal Sent-Negotiation' => Icons.handshake_outlined,
      'Invoice Sent' => Icons.receipt_long_outlined,
      'Closed Won' => Icons.emoji_events_outlined,
      'Closed Lost' => Icons.cancel_outlined,
      _ => Icons.circle_outlined,
    };


String userName(String raw) => raw.split('||').first;
String userId(String raw) =>
    raw.split('||').length > 1 ? raw.split('||')[1] : raw;

// ══════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════
class DealsScreen extends StatefulWidget {
  final int initialTab;
  final String? initialStageFilter;
  final bool showBackButton;

  // Dashboard period filter
  final String filterRange;
  final int? filterMonth;
  final int? filterYear;

  const DealsScreen({
    super.key,
    this.initialTab = 0,
    this.initialStageFilter,
    this.showBackButton = true,
    this.filterRange = 'all',
    this.filterMonth,
    this.filterYear,
  });
  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  late final DealsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = DealsCubit()..loadDeals();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
Widget build(BuildContext context) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider(create: (_) => DealsTemplateCubit(_cubit)),
        BlocProvider(create: (_) => FollowUpsTemplateCubit()),
      ],
child: _DealsShell(
  initialTab: widget.initialTab,
  initialStageFilter: widget.initialStageFilter,
  showBackButton: widget.showBackButton,
  filterRange: widget.filterRange,
  filterMonth: widget.filterMonth,
  filterYear: widget.filterYear,
),    );
}

class _DealsShell extends StatefulWidget {
  final int initialTab;
  final String? initialStageFilter;
  final bool showBackButton;
  final String filterRange;
  final int? filterMonth;
  final int? filterYear;
const _DealsShell({
  required this.initialTab,
  this.initialStageFilter,
  this.showBackButton = true,
  this.filterRange = 'all',
  this.filterMonth,
  this.filterYear,
});  @override
  State<_DealsShell> createState() => _DealsShellState();
}

class _DealsShellState extends State<_DealsShell> {
  late String _view;
  DealsLoaded? _lastLoaded;

  static const _viewOptions = [
    ('stages', 'Deal Stages'),
    ('alldeals', 'All Deals'),
  ];
DateTimeRange? _dashboardDateRange() {
  final now = DateTime.now();

  switch (widget.filterRange) {
    case 'today':
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final end = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
        999,
      );

      return DateTimeRange(
        start: start,
        end: end,
      );

    case 'last7':
      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final start = today.subtract(
        const Duration(days: 6),
      );

      final end = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
        999,
      );

      return DateTimeRange(
        start: start,
        end: end,
      );

    case 'month':
      if (widget.filterMonth == null ||
          widget.filterYear == null) {
        return null;
      }

      final start = DateTime(
        widget.filterYear!,
        widget.filterMonth!,
        1,
      );

      final end = DateTime(
        widget.filterYear!,
        widget.filterMonth! + 1,
        0,
        23,
        59,
        59,
        999,
      );

      return DateTimeRange(
        start: start,
        end: end,
      );

    case 'year':
      if (widget.filterYear == null) {
        return null;
      }

      return DateTimeRange(
        start: DateTime(
          widget.filterYear!,
          1,
          1,
        ),
        end: DateTime(
          widget.filterYear!,
          12,
          31,
          23,
          59,
          59,
          999,
        ),
      );

    case 'all':
    default:
      return null;
  }
}
  @override
  void initState() {
    super.initState();
      _view = widget.initialStageFilter != null
        ? 'alldeals'
        : (widget.initialTab == 1 ? 'stages' : 'alldeals');
      
        

  }

  @override
void dispose() {
  
  super.dispose();
}

  

  void _openCreate(List<String> users) async {
    final message = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => BlocProvider.value(
            value: context.read<DealsCubit>(),
            child: DealFormModal(users: users)));
    if (message != null && mounted) showApiSnack(context, message);
  }

  void _openEdit(Deal deal, List<String> users) async {
    final message = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => BlocProvider.value(
            value: context.read<DealsCubit>(),
            child: DealFormModal(users: users, editDeal: deal)));
    if (message != null && mounted) showApiSnack(context, message);
  }

  void openDetail(Deal deal) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: context.read<DealsCubit>(),
          ),

          BlocProvider(
            create: (_) => DealsAttachmentCubit(),
          ),

          BlocProvider(
            create: (_) => InvoiceCubit()..load(),
          ),
        ],
        child: BlocProvider(
  create: (_) => MeetingsCubit()..loadMeetings(),
  child: DealDetailSheet(
    deal: deal,
  ),
)
      ),
    );
      
  Widget _buildLoaded(BuildContext ctx, DealsLoaded loaded) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _view == 'stages'
          ? _StagesView(
              key: const ValueKey('stages'),
              deals: loaded.allDeals,
              pendingDeals: loaded.pendingDeals,
              lostDeals: loaded.lostDeals,
              initialDateRange: _dashboardDateRange(),
              onCreateDeal: () => _openCreate(loaded.salesUsers),
              onViewDeal: (d) => openDetail(d),
              onEditDeal: (d) => _openEdit(d, loaded.salesUsers),
              onDeleteDeal: (id) => ctx.read<DealsCubit>().deleteDeal(id))
          : _AllDealsView(
    key: const ValueKey('alldeals'),
    deals: loaded.allDeals,
    salesUsers: loaded.salesUsers,
    initialStageFilter: widget.initialStageFilter,
    initialDateRange: _dashboardDateRange(),
    onCreateDeal: () => _openCreate(loaded.salesUsers),
    onViewDeal: (d) => openDetail(d),
    onEditDeal: (d) => _openEdit(d, loaded.salesUsers),
    onDeleteDeal: (id) => ctx.read<DealsCubit>().deleteDeal(id)));

  @override
  Widget build(BuildContext context) =>BlocListener<
    DealsTemplateCubit,
    DealsTemplateState>(
  listener: (context, state) {
    if (state is DealsTemplateSuccess) {
      showApiSnack(context, state.message);
    } else if (state is DealsTemplateError) {
      showApiSnack(
        context,
        state.message,
        isError: true,
      );
    }
  }, 
  
  child:Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Deals'),
          backgroundColor: AppColors.surface,
            automaticallyImplyLeading: false,
          leading: widget.showBackButton
      ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop())
      : null,
          actions: [
            Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _ViewDropdown(
                    value: _view,
                    options: _viewOptions,
                    onChanged: (v) => setState(() => _view = v))),
          ],
        ),
        body: BlocConsumer<DealsCubit, DealsState>(
          listener: (ctx, state) {
            final route = ModalRoute.of(ctx);
            if (route != null && !route.isCurrent) return;
            if (state is DealsActionSuccess) showApiSnack(ctx, state.message);
            if (state is DealsError) {
              showApiSnack(ctx, state.message, isError: true);
            }
          },
          builder: (ctx, state) {
            if (state is DealsLoaded ) {
  _lastLoaded = state;

    if (!PermissionHelper.can('users_roles')) {
      
    }
}
            if (state is DealsLoading && _lastLoaded == null)
              return const LoadingState(message: 'Loading deals…');
            if (state is DealsError && _lastLoaded == null)
              return ErrorState(
                  message: state.message,
                  onRetry: () => ctx.read<DealsCubit>().loadDeals());
            if (_lastLoaded != null)
              return _buildLoaded(
                  ctx, state is DealsLoaded ? state : _lastLoaded!);
            return const SizedBox.shrink();
          },
        ),
              floatingActionButton: Padding(
  padding: const EdgeInsets.only(bottom: 60),
  child: FloatingActionButton(
    heroTag: 'dealsFab',
    onPressed: () {
      if (_lastLoaded != null) {
        _openCreate(_lastLoaded!.salesUsers);
      }
    },
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    child: const Icon(Icons.add),
  ),
),
  )
      );
}

class _ViewDropdown extends StatelessWidget {
  final String value;
  final List<(String, String)> options;
  final void Function(String) onChanged;
  const _ViewDropdown(
      {required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.3))),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: value,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.primary),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
              items: options
                  .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              })));
}

// ══════════════════════════════════════════════════════════════
// STAGES VIEW
// ══════════════════════════════════════════════════════════════
class _StagesView extends StatefulWidget {
  final List<Deal> deals, pendingDeals, lostDeals;
    final DateTimeRange? initialDateRange;
  final VoidCallback onCreateDeal;
  final void Function(Deal) onViewDeal;
  final void Function(Deal) onEditDeal;
  final void Function(String) onDeleteDeal;
  const _StagesView(
      {super.key,
      required this.deals,
      required this.pendingDeals,
      required this.lostDeals,
      this.initialDateRange,
      required this.onCreateDeal,
      required this.onViewDeal,
      required this.onEditDeal,
      required this.onDeleteDeal});
  @override
  State<_StagesView> createState() => _StagesViewState();
}

class _StagesViewState extends State<_StagesView> {
  final _search = TextEditingController();
  String _q = '';
  DateTimeRange? _pipelineDateRange;

  List<String> _selectedPipelineStages = [];

  bool get _hasPipelineFilter =>
      _pipelineDateRange != null ||
      _selectedPipelineStages.isNotEmpty;

      @override
void initState() {
  super.initState();
  _pipelineDateRange = widget.initialDateRange;
}

      
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(children: [
              Expanded(
                  child: SearchBar(
                      controller: _search,
                      hint: 'Search deals…',
                      onChanged: (v) => setState(() => _q = v.toLowerCase()),
                      onClear: () => setState(() => _q = ''))),
                      
              const SizedBox(width: 8),

IconButton(
  tooltip: 'Filter',
  onPressed: _showPipelineFilter,
  icon: Badge(
    isLabelVisible: _hasPipelineFilter,
    label: const Text(''),
    child: const Icon(Icons.filter_alt_outlined),
  ),
),

const SizedBox(width: 4),
              if (PermissionHelper.can('users_roles'))
                ElevatedButton.icon(
                    onPressed: widget.onCreateDeal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create Deal',
                        style: TextStyle(fontSize: 13)),
                   ),
            ])),
        Container(height: 1, color: AppColors.divider),
        if (widget.pendingDeals.isNotEmpty || widget.lostDeals.isNotEmpty)
          Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                _StripChip(
                    label: 'Pending Follow-up',
                    count: widget.pendingDeals.length,
                    color: AppColors.warning),
                const SizedBox(width: 10),
                _StripChip(
                    label: 'Lost Deals',
                    count: widget.lostDeals.length,
                    color: AppColors.danger),
              ])),
        Expanded(
  child: RefreshIndicator(
    color: AppColors.primary,
    onRefresh: () => context.read<DealsCubit>().refresh(),
    child: ListView.builder(
      padding: const EdgeInsets.all(14),

      // Show only selected stages.
      // If nothing is selected, show all stages.
      itemCount: _selectedPipelineStages.isEmpty
          ? DealConstants.stages.length
          : _selectedPipelineStages.length,

      itemBuilder: (_, i) {
        final stage = _selectedPipelineStages.isEmpty
            ? DealConstants.stages[i]
            : _selectedPipelineStages[i];

        final filtered = widget.deals.where((d) {
          final canonicalStage =
              DealConstants.canonicalStage(d.stage);

          final matchesSearch =
              _q.isEmpty ||
              d.name.toLowerCase().contains(_q) ||
              d.companyName.toLowerCase().contains(_q);

          final dealDate = d.createdAt;

          final matchesDate =
    _pipelineDateRange == null ||
    (dealDate != null &&
        !dealDate.isBefore(_pipelineDateRange!.start) &&
        !dealDate.isAfter(
          _pipelineDateRange!.end.add(
            const Duration(days: 1),
          ),
        ));
          return canonicalStage == stage &&
              matchesSearch &&
              matchesDate;
        }).toList();

        return _StageColumn(
          stage: stage,
          deals: filtered,
          onView: widget.onViewDeal,
          onEdit: widget.onEditDeal,
          onDelete: widget.onDeleteDeal,
        );
      },
    ),
  ),
),
      ]); 
  
  // ===================
  // show pipleine
  // ===================
  void _showPipelineFilter() {
  final tempStages = List<String>.from(_selectedPipelineStages);
  DateTimeRange? tempDateRange = _pipelineDateRange;

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      'Pipeline Filters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Date Range',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDateRange: tempDateRange,
                          helpText: 'Select Date Range',
                          saveText: 'Apply',
                          confirmText: 'Apply',
                          cancelText: 'Cancel',
                        );

                        if (picked != null) {
                          setSheetState(() {
                            tempDateRange = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.date_range_outlined,
                          ),
                          suffixIcon: Icon(
                            Icons.calendar_month,
                          ),
                        ),
                        child: Text(
                          tempDateRange == null
                              ? 'Select Date Range'
                              : '${DateFormat('dd MMM yyyy').format(tempDateRange!.start)} - '
                                  '${DateFormat('dd MMM yyyy').format(tempDateRange!.end)}',
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Deal Stages',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    ...DealConstants.stages.map(
                      (stage) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(stage),
                        value: tempStages.contains(stage),
                        onChanged: (checked) {
                          setSheetState(() {
                            if (checked == true) {
                              if (!tempStages.contains(stage)) {
                                tempStages.add(stage);
                              }
                            } else {
                              tempStages.remove(stage);
                            }
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _pipelineDateRange = null;
                                _selectedPipelineStages.clear();
                              });

                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Reset'),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _pipelineDateRange = tempDateRange;
                                _selectedPipelineStages =
                                    List<String>.from(tempStages);
                              });

                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
} 
}

class _StripChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StripChip(
      {required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
                color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Center(
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color)))),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]));
}

class _StageColumn extends StatefulWidget {
  final String stage;
  final List<Deal> deals;
  final void Function(Deal) onView;
  final void Function(Deal) onEdit;
  final void Function(String) onDelete;
  const _StageColumn(
      {required this.stage,
      required this.deals,
      required this.onView,
      required this.onEdit,
      required this.onDelete});
  @override
  State<_StageColumn> createState() => _StageColumnState();
}

class _StageColumnState extends State<_StageColumn> {
  bool _collapsed = true;
  @override
  Widget build(BuildContext context) {
    final color = stageColor(widget.stage);
    return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(children: [
          GestureDetector(
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.07),
                      borderRadius: _collapsed
                          ? BorderRadius.circular(16)
                          : const BorderRadius.vertical(
                              top: Radius.circular(16))),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(9)),
                        child: Icon(_stageIcon(widget.stage),
                            size: 16, color: color)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(widget.stage,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                          Text(
                              '${widget.deals.length} deal${widget.deals.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ])),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('${widget.deals.length}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color))),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                        turns: _collapsed ? 0 : 0.5,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 20, color: color)),
                  ]))),
          AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _collapsed
                  ? const SizedBox.shrink()
                  : Column(
                      children: widget.deals.isEmpty
                          ? [
                              const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                      child: Text('No deals in this stage',
                                          style: TextStyle(
                                              color: AppColors.textHint,
                                              fontSize: 13))))
                            ]
                          : widget.deals
                              .map((d) => _DealTile(
                                  deal: d,
                                  onView: widget.onView,
                                  onEdit: widget.onEdit,
                                  onDelete: widget.onDelete))
                              .toList())),
        ]));
  }
}

class _DealTile extends StatelessWidget {
  final Deal deal;
  final void Function(Deal) onView;
  final void Function(Deal) onEdit;
  final void Function(String) onDelete;
  const _DealTile({
    required this.deal,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = stageColor(deal.stage);
    return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onView(deal),
                child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(children: [
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                              child: Text(
                                  deal.name.isNotEmpty
                                      ? deal.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(deal.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            Text(deal.companyName,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.person_outline,
                                  size: 11, color: AppColors.textHint),
                              const SizedBox(width: 3),
                              Flexible(
                                  child: Text(
                                      deal.assignTo.isNotEmpty
                                          ? deal.assignTo
                                          : 'Unassigned',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textHint))),
                            ]),
                          ])),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(fmtVal(deal.currency, deal.value),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: color)),
                            const SizedBox(height: 6),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              GestureDetector(
                                  onTap: () => onEdit(deal),
                                  behavior: HitTestBehavior.opaque,
                                  child: const Icon(Icons.edit_outlined,
                                      size: 16, color: AppColors.textHint)),
                              const SizedBox(width: 10),
                              GestureDetector(
                                  onTap: () => _confirmDelete(context),
                                  behavior: HitTestBehavior.opaque,
                                  child: const Icon(Icons.delete_outline,
                                      size: 17, color: AppColors.textHint)),
                            ]),
                          ]),
                    ])))));
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Delete Deal'),
                content: Text('Remove "${deal.name}"?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete',
                          style: TextStyle(color: AppColors.danger))),
                ]));
    if (ok == true && ctx.mounted) onDelete(deal.id);
  }
}

// ══════════════════════════════════════════════════════════════
// ALL DEALS VIEW
// ══════════════════════════════════════════════════════════════
class _AllDealsView extends StatefulWidget {
  final List<Deal> deals;
  final List<String> salesUsers;
  final String? initialStageFilter;
  final DateTimeRange? initialDateRange;
  final VoidCallback onCreateDeal;
  final void Function(Deal) onViewDeal;
  final void Function(Deal) onEditDeal;
  final void Function(String) onDeleteDeal;
  const _AllDealsView(
      {super.key,
      required this.deals,
      required this.salesUsers,
      this.initialStageFilter,
      this.initialDateRange,
      required this.onCreateDeal,
      required this.onViewDeal,
      required this.onEditDeal,
      required this.onDeleteDeal});
  @override
  State<_AllDealsView> createState() => _AllDealsViewState();
}

class _AllDealsViewState extends State<_AllDealsView> {
// date range
DateTimeRange? _dateRange;
DateTime? get _startDate => _dateRange?.start;
DateTime? get _endDate => _dateRange?.end;


  final _searchCtrl = TextEditingController();
  String _q = '',
    _stageFilter = 'All Stages',
    _userFilter = 'All Users',
    _clientTypeFilter = 'All Client Types';
bool _todayFollowupsOnly = false;
int _page = 1;
static const int _pageSize = 10;

@override
void initState() {
  super.initState();
    _dateRange = widget.initialDateRange;

  if (widget.initialStageFilter != null) {
    _stageFilter = widget.initialStageFilter!;
  }
}
void _showFilterSheet() {
  final allUsers = ['All Users', ...widget.salesUsers];
  final allStages = ['All Stages', ...DealConstants.stages];
  const allClientTypes = [
    'All Client Types',
    'B2B',
    'B2C',
  ];

  showModalBottomSheet(
    backgroundColor: AppColors.surface,
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "Filters",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
  "Date Range",
  style: TextStyle(
    fontWeight: FontWeight.w600,
  ),
),

const SizedBox(height: 8),

InkWell(
  borderRadius: BorderRadius.circular(12),
  onTap: () => _pickDateRange(setSheetState),
  child: InputDecorator(
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      prefixIcon: Icon(Icons.date_range_outlined),
      suffixIcon: Icon(Icons.calendar_month),
    ),
    child: Text(
      _dateRange == null
          ? "Select Date Range"
          : "${DateFormat('dd MMM yyyy').format(_dateRange!.start)}  -  "
            "${DateFormat('dd MMM yyyy').format(_dateRange!.end)}",
    ),
  ),
),

const SizedBox(height: 20),

                    const Text("Stage"),

                    const SizedBox(height: 6),

                    DropdownButtonFormField<String>(
                      value: _stageFilter,
                      items: allStages
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setSheetState(() {
                          _stageFilter = v!;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text("Assigned User"),

                    const SizedBox(height: 6),

                    DropdownButtonFormField<String>(
                      value: _userFilter,
                      items: allUsers
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(userName(e)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setSheetState(() {
                          _userFilter = v!;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text("Client Type"),

                    const SizedBox(height: 6),

                    DropdownButtonFormField<String>(
                      value: _clientTypeFilter,
                      items: allClientTypes
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setSheetState(() {
                          _clientTypeFilter = v!;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    CheckboxListTile(
                      value: _todayFollowupsOnly,
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Today's Follow-ups"),
                      onChanged: (v) {
                        setSheetState(() {
                          _todayFollowupsOnly = v ?? false;
                        });
                      },
                    ),

                    const SizedBox(height: 25),

                    Row(
                      children: [

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {

                              setState(() {
                                _dateRange = null;
                                _stageFilter = 'All Stages';
                                _userFilter = 'All Users';
                                _clientTypeFilter =
                                    'All Client Types';
                                _todayFollowupsOnly = false;
                                _page = 1;
                              });

                              Navigator.pop(context);
                            },
                            child: const Text("Reset"),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {

                              setState(() {
                                _page = 1;
                              });

                              Navigator.pop(context);
                            },
                            child: const Text("Apply"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
  @override
  void didUpdateWidget(_AllDealsView old) {
    super.didUpdateWidget(old);
    if (_userFilter != 'All Users' && !widget.salesUsers.contains(_userFilter))
      _userFilter = 'All Users';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Deal> get _filtered {
  final allUsers = ['All Users', ...widget.salesUsers];
  final safeUser = allUsers.contains(_userFilter) ? _userFilter : 'All Users';
  final allStages = ['All Stages', ...DealConstants.stages];
  final safeStage =
      allStages.contains(_stageFilter) ? _stageFilter : 'All Stages';
  const allClientTypes = ['All Client Types', 'B2B', 'B2C'];
  final safeClientType = allClientTypes.contains(_clientTypeFilter)
      ? _clientTypeFilter
      : 'All Client Types';
  final today = _dateOnly(DateTime.now());
  return widget.deals.where((d) {
    final phone = d.phone.replaceAll(RegExp(r'[^0-9+]'), '').toLowerCase();
    final localPhone = d.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final searchQuery = _q.replaceAll(RegExp(r'[^0-9+]'), '');

    final matchesPhone = searchQuery.isNotEmpty &&
        (phone.contains(searchQuery) ||
            localPhone.contains(searchQuery.replaceAll('+', '')));

    final matchQ = _q.isEmpty ||
        d.name.toLowerCase().contains(_q) ||
        d.companyName.toLowerCase().contains(_q) ||
        d.email.toLowerCase().contains(_q) ||
        matchesPhone;

    final matchStage = safeStage == 'All Stages' ||
        DealConstants.canonicalStage(d.stage).trim().toLowerCase() ==
            safeStage.trim().toLowerCase();
    final matchUser = safeUser == 'All Users' ||
        d.assignTo.trim().toLowerCase() ==
            userName(safeUser).trim().toLowerCase();
    final matchClientType = safeClientType == 'All Client Types' ||
        d.clientType.toUpperCase() == safeClientType;
    final followUpDt = DateTime.tryParse(d.followUpDate ?? '');
    final followUpDay = followUpDt == null
        ? null
        : _dateOnly(followUpDt.isUtc ? followUpDt.toLocal() : followUpDt);
    
    final dealDate = d.createdAt;

final matchDate =
    _dateRange == null ||
    (dealDate != null &&
        !dealDate.isBefore(_dateRange!.start) &&
        !dealDate.isAfter(
          _dateRange!.end.add(const Duration(days: 1)),
        ));
    final matchTodayFollowUps =
        !_todayFollowupsOnly || (followUpDay != null && followUpDay == today);

    return matchQ &&
        matchStage &&
        matchUser &&
        matchClientType &&
        matchTodayFollowUps &&
        matchDate;
  }).toList();
}
  bool get _hasFilter =>
   _dateRange != null ||
      _stageFilter != 'All Stages' ||
      _userFilter != 'All Users' ||
      _clientTypeFilter != 'All Client Types' ||
      _todayFollowupsOnly ||
      _q.isNotEmpty ||
      false;

  int get _totalPages {
    final count = _filtered.length;
    if (count == 0) return 1;
    return (count / _pageSize).ceil();
  }
Future<void> _pickDateRange(StateSetter setSheetState) async {
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
    initialDateRange: _dateRange,

    helpText: 'Select Date Range',
    saveText: 'Apply',
    confirmText: 'Apply',
    cancelText: 'Cancel',
  );


  if (picked == null) return;

setState(() {
  _dateRange = picked;
  _page = 1;
});

setSheetState(() {});
}
  List<Deal> get _pagedDeals {
    final items = _filtered;
    final safePage = _page.clamp(1, _totalPages);
    final start = (safePage - 1) * _pageSize;
    if (start >= items.length) return [];
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      
      // Search
Container(
  color: AppColors.surface,
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
  child: Row(
    children: [
      Expanded(
        child: SearchBar(
          controller: _searchCtrl,
          hint: 'Search deals...',
          onChanged: (v) => setState(() {
            _q = v.toLowerCase();
            _page = 1;
          }),
          onClear: () => setState(() {
            _q = '';
            _searchCtrl.clear();
            _page = 1;
          }),
        ),
      ),

      const SizedBox(width: 8),

      // Filter
      IconButton(
  tooltip: 'Filter',
  onPressed: _showFilterSheet,
  icon: Badge(
    isLabelVisible: _hasFilter,
    label: const Text(""),
    child: const Icon(Icons.filter_alt_outlined),
  ),
),

      // Menu
      PopupMenuButton<String>(
        color: AppColors.surface,
  onSelected: (value) async {
    switch (value) {
      case 'download_template':
        context.read<DealsTemplateCubit>().downloadTemplate();
        break;

      case 'import':
  context.read<DealsTemplateCubit>().pickAndImportTemplate();
  break;

      case 'rejected':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<DealsCubit>(),
              child: const RejectedDealsScreen(),
            ),
          ),
        );
        break;

        case 'export-all':
  showDialog(
  context: context,
  builder: (_) => ExportDealsDialog(
    title: "Export Deals",
    description:
        "Optionally filter by date range.\n"
        "Leave both dates blank to export all deals.",
    onExport: (start, end) {
      context.read<DealsTemplateCubit>().exportDeals(
        startDate: start,
        endDate: end,
      );
    },
  ),
);
  break;

  case 'export-followups':
  showDialog(
  context: context,
  builder: (_) => ExportDealsDialog(
    title: "Export followups",
    description:
        "Optionally filter by date range.\n"
        "Leave both dates blank to export all deals.",
    onExport: (start, end) {
      context.read<FollowUpsTemplateCubit>().exportFollowUps(
        deals: _filtered,
        startDate: start,
        endDate: end,
        
      );
    },
  ),
);
    }
  },
  itemBuilder: (_) => const [
    PopupMenuItem(
      value: 'download_template',
      child: Row(
        children: [
          Icon(Icons.download_rounded, color: Colors.blue),
          SizedBox(width: 10),
          Text('Download Template'),
        ],
      ),
    ),
      PopupMenuDivider(),

    PopupMenuItem(
      value: 'export-all',
      child: Row(
        children: [
          Icon(Icons.file_download_outlined, color: Colors.blue),
          SizedBox(width: 10),
          Text('Export all'),
        ],
      ),
    ),
      PopupMenuDivider(),

    PopupMenuItem(
      value: 'export-followups',
      child: Row(
        children: [
          Icon(Icons.history_outlined, color: Colors.blue),
          SizedBox(width: 10),
          Text('export-followups'),
        ],
      ),
    ),
      PopupMenuDivider(),

    PopupMenuItem(
      value: 'import',
      child: Row(
        children: [
          Icon(Icons.upload_file_rounded, color: Colors.green),
          SizedBox(width: 10),
          Text('Import Deals'),
        ],
      ),
    ),
  ],
),
    ],
  ),
),

// Buttons
      
      Container(height: 1, color: AppColors.divider),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Text('${_filtered.length} deal${_filtered.length != 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const Spacer(),
            if (_hasFilter)
              GestureDetector(
                  onTap: () => setState(() {
                      _dateRange = null;
                        _stageFilter = 'All Stages';
                        _userFilter = 'All Users';
                        _q = '';
                        _searchCtrl.clear();
                        _clientTypeFilter = 'All Client Types';
                        _todayFollowupsOnly = false;
                        _page = 1;
                      }),
                  child: const Text('Clear filters',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600))),
          ])),
      Expanded(
          child: _filtered.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.handshake_outlined,
                      size: 52, color: AppColors.textHint),
                  SizedBox(height: 10),
                  Text('No deals found',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15))
                ]))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => context.read<DealsCubit>().refresh(),
                  child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      itemCount: _pagedDeals.length,
                      itemBuilder: (_, i) => _DealRow(
                          deal: _pagedDeals[i],
                          onView: widget.onViewDeal,
                          onEdit: widget.onEditDeal,
                          onDelete: widget.onDeleteDeal)))),
      if (_filtered.isNotEmpty)
        PaginationBar(
          page: _page.clamp(1, _totalPages),
          totalPages: _totalPages,
          totalItems: _filtered.length,
          pageSize: _pageSize,
          onPrev: _page > 1 ? () => setState(() => _page -= 1) : null,
          onNext: _page < _totalPages ? () => setState(() => _page += 1) : null,
        ),
    ]);
    
  }
}

class _DealRow extends StatelessWidget {
  final Deal deal;
  final void Function(Deal) onView;
  final void Function(Deal) onEdit;
  final void Function(String) onDelete;
  const _DealRow({
    required this.deal,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = stageColor(deal.stage);
    final followUpDt = DateTime.tryParse(deal.followUpDate ?? '');
    final followUpLabel = followUpDt == null
        ? 'No follow-up'
        : DateFormat('dd MMM yy')
            .format(followUpDt.isUtc ? followUpDt.toLocal() : followUpDt);
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 7,
                  offset: const Offset(0, 2))
            ]),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onView(deal),
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Row(children: [
                        Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(11)),
                            child: Center(
                                child: Text(
                                    deal.name.isNotEmpty
                                        ? deal.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18)))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(deal.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              Text(deal.companyName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ])),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 90),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(fmtVal(deal.currency, deal.value),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: color)),
                                  const SizedBox(height: 3),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(
                                          DealConstants.canonicalStage(
                                              deal.stage),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: color))),
                                ])),
                      ]),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 10),
                      Row(children: [
                        Flexible(
                            child: _meta(
                                Icons.person_outline,
                                deal.assignTo.isNotEmpty
                                    ? deal.assignTo
                                    : 'Unassigned')),
                        const SizedBox(width: 8),
                        _meta(Icons.event_outlined, followUpLabel),
                        const Spacer(),
                        GestureDetector(
                            onTap: () => onEdit(deal),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.edit_outlined,
                                    size: 15, color: AppColors.primary))),
                        const SizedBox(width: 8),
                        GestureDetector(
                            onTap: () => _confirmDelete(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: AppColors.dangerLight,
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.delete_outline,
                                    size: 15, color: AppColors.danger))),
                      ]),
                    ])))));
  }

  Widget _meta(IconData ic, String t) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 12, color: AppColors.textHint),
        const SizedBox(width: 4),
        Flexible(
            child: Text(t,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary))),
      ]);

  Future<void> _confirmDelete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Delete Deal'),
                content: Text('Remove "${deal.name}"?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete',
                          style: TextStyle(color: AppColors.danger))),
                ]));
    if (ok == true && ctx.mounted) onDelete(deal.id);
  }
}


