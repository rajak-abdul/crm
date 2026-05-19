// ╔══════════════════════════════════════════════════════════════╗
// ║              lib/screen/deals/ui/deal_screen.dart            ║
// ║  Pure UI — all API calls live in deals_cubit.dart            ║
// ╚══════════════════════════════════════════════════════════════╝

// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:crm_app/modals/modals.dart' show AppConstants;
import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show showApiSnack, ErrorState, LoadingState;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:crm_app/utils/permission_helper.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart'
    show FilePicker, FileType, PlatformFile;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart' hide PhoneNumber;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

bool _isSessionExpiredMessage(String msg) {
  final m = msg.toLowerCase();

  return m.contains('session expired') ||
      m.contains('unauthorized') ||
      m.contains('401') ||
      m.contains('login again') ||
      m.contains('token failed') ||
      m.contains('invalid token') ||
      m.contains('jwt expired') ||
      m.contains('token expired') ||
      m.contains('authentication failed');
}

// ── UI-only helpers ───────────────────────────────────────────
Color _stageColor(String s) => switch (DealConstants.canonicalStage(s)) {
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

const MethodChannel _dealDownloadsChannel = MethodChannel('crm/downloads');

MimeType _dealMimeTypeForAttachmentExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return MimeType.pdf;
    case 'jpg':
    case 'jpeg':
      return MimeType.jpeg;
    case 'png':
      return MimeType.png;
    case 'gif':
      return MimeType.gif;
    case 'doc':
    case 'docx':
      return MimeType.microsoftWord;
    case 'xls':
    case 'xlsx':
      return MimeType.microsoftExcel;
    case 'ppt':
    case 'pptx':
      return MimeType.microsoftPresentation;
    case 'csv':
      return MimeType.csv;
    case 'zip':
      return MimeType.zip;
    case 'txt':
      return MimeType.text;
    case 'json':
      return MimeType.json;
    default:
      return MimeType.other;
  }
}

String _dealMimeStringForAttachmentExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'csv':
      return 'text/csv';
    case 'txt':
      return 'text/plain';
    case 'json':
      return 'application/json';
    case 'zip':
      return 'application/zip';
    default:
      return 'application/octet-stream';
  }
}

String _userName(String raw) => raw.split('||').first;
String _userId(String raw) =>
    raw.split('||').length > 1 ? raw.split('||')[1] : raw;

// ══════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════
class DealsScreen extends StatefulWidget {
  final int initialTab;
  const DealsScreen({super.key, this.initialTab = 0});
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
  Widget build(BuildContext context) => BlocProvider.value(
      value: _cubit, child: _DealsShell(initialTab: widget.initialTab));
}

class _DealsShell extends StatefulWidget {
  final int initialTab;
  const _DealsShell({required this.initialTab});
  @override
  State<_DealsShell> createState() => _DealsShellState();
}

class _DealsShellState extends State<_DealsShell> {
  late String _view;
  DealsLoaded? _lastLoaded;

  static const _viewOptions = [
    ('stages', 'Deal Stages'),
    ('alldeals', 'All Deals'),
  ];

  @override
  void initState() {
    super.initState();
    _view = widget.initialTab == 1 ? 'stages' : 'alldeals';
  }

  void _openCreate(List<String> users) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
          value: context.read<DealsCubit>(),
          child: _DealFormModal(users: users)));

  void _openEdit(Deal deal, List<String> users) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
          value: context.read<DealsCubit>(),
          child: _DealFormModal(users: users, editDeal: deal)));

  void _openDetail(Deal deal) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _DealDetailSheet(deal: deal),
      );

  Widget _buildLoaded(BuildContext ctx, DealsLoaded loaded) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _view == 'stages'
          ? _StagesView(
              key: const ValueKey('stages'),
              deals: loaded.allDeals,
              pendingDeals: loaded.pendingDeals,
              lostDeals: loaded.lostDeals,
              onCreateDeal: () => _openCreate(loaded.salesUsers),
              onViewDeal: (d) => _openDetail(d),
              onEditDeal: (d) => _openEdit(d, loaded.salesUsers),
              onDeleteDeal: (id) => ctx.read<DealsCubit>().deleteDeal(id))
          : _AllDealsView(
              key: const ValueKey('alldeals'),
              deals: loaded.allDeals,
              salesUsers: loaded.salesUsers,
              onCreateDeal: () => _openCreate(loaded.salesUsers),
              onViewDeal: (d) => _openDetail(d),
              onEditDeal: (d) => _openEdit(d, loaded.salesUsers),
              onDeleteDeal: (id) => ctx.read<DealsCubit>().deleteDeal(id)));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Deals'),
          backgroundColor: AppColors.surface,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop()),
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
              if (_isSessionExpiredMessage(state.message)) {
                Navigator.of(ctx, rootNavigator: true)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
                return;
              }
              showApiSnack(ctx, state.message, isError: true);
            }
          },
          builder: (ctx, state) {
            if (state is DealsLoaded) _lastLoaded = state;
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
  final VoidCallback onCreateDeal;
  final void Function(Deal) onViewDeal;
  final void Function(Deal) onEditDeal;
  final void Function(String) onDeleteDeal;
  const _StagesView(
      {super.key,
      required this.deals,
      required this.pendingDeals,
      required this.lostDeals,
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
                  child: _SearchBar(
                      controller: _search,
                      hint: 'Search deals…',
                      onChanged: (v) => setState(() => _q = v.toLowerCase()),
                      onClear: () => setState(() => _q = ''))),
              const SizedBox(width: 10),
              if (PermissionHelper.can('users_roles'))
                ElevatedButton.icon(
                    onPressed: widget.onCreateDeal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create Deal',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        minimumSize: Size.zero)),
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
                    itemCount: DealConstants.stages.length,
                    itemBuilder: (_, i) {
                      final stage = DealConstants.stages[i];
                      final filtered = widget.deals
                          .where((d) =>
                              DealConstants.canonicalStage(d.stage) == stage &&
                              (_q.isEmpty ||
                                  d.name.toLowerCase().contains(_q) ||
                                  d.companyName.toLowerCase().contains(_q)))
                          .toList();
                      return _StageColumn(
                          stage: stage,
                          deals: filtered,
                          onView: widget.onViewDeal,
                          onEdit: widget.onEditDeal,
                          onDelete: widget.onDeleteDeal);
                    }))),
      ]);
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
  bool _collapsed = false;
  @override
  Widget build(BuildContext context) {
    final color = _stageColor(widget.stage);
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
    final color = _stageColor(deal.stage);
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
                            Text(_fmtVal(deal.currency, deal.value),
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
  final VoidCallback onCreateDeal;
  final void Function(Deal) onViewDeal;
  final void Function(Deal) onEditDeal;
  final void Function(String) onDeleteDeal;
  const _AllDealsView(
      {super.key,
      required this.deals,
      required this.salesUsers,
      required this.onCreateDeal,
      required this.onViewDeal,
      required this.onEditDeal,
      required this.onDeleteDeal});
  @override
  State<_AllDealsView> createState() => _AllDealsViewState();
}

class _AllDealsViewState extends State<_AllDealsView> {
  final _searchCtrl = TextEditingController();
  String _q = '',
      _stageFilter = 'All Stages',
      _userFilter = 'All Users',
      _clientTypeFilter = 'All Client Types';
  bool _todayFollowupsOnly = false;
  int _page = 1;
  static const int _pageSize = 10;

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
      final matchQ = _q.isEmpty || d.name.toLowerCase().contains(_q);
      final matchStage = safeStage == 'All Stages' ||
          DealConstants.canonicalStage(d.stage).trim().toLowerCase() ==
              safeStage.trim().toLowerCase();
      final matchUser = safeUser == 'All Users' ||
          d.assignTo.trim().toLowerCase() ==
              _userName(safeUser).trim().toLowerCase();
      final matchClientType = safeClientType == 'All Client Types' ||
          d.clientType.toUpperCase() == safeClientType;
      final followUpDt = DateTime.tryParse(d.followUpDate ?? '');
      final followUpDay = followUpDt == null
          ? null
          : _dateOnly(followUpDt.isUtc ? followUpDt.toLocal() : followUpDt);
      final matchTodayFollowUps =
          !_todayFollowupsOnly || (followUpDay != null && followUpDay == today);
      return matchQ &&
          matchStage &&
          matchUser &&
          matchClientType &&
          matchTodayFollowUps;
    }).toList();
  }

  bool get _hasFilter =>
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
    final allUsers = ['All Users', ...widget.salesUsers];
    final allStages = ['All Stages', ...DealConstants.stages];
    const allClientTypes = ['All Client Types', 'B2B', 'B2C'];
    return Column(children: [
      Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(
                child: _SearchBar(
                    controller: _searchCtrl,
                    hint: 'Search deal name…',
                    onChanged: (v) => setState(() {
                          _q = v.toLowerCase();
                          _page = 1;
                        }),
                    onClear: () => setState(() {
                          _q = '';
                          _page = 1;
                        }))),
            const SizedBox(width: 10),
            if (PermissionHelper.can('users_roles'))
              ElevatedButton.icon(
                  onPressed: widget.onCreateDeal,
                  icon: const Icon(Icons.add, size: 16),
                  label:
                      const Text('Create Deal', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      minimumSize: Size.zero)),
          ])),
      Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(children: [
            Expanded(
                child: _FDrop(
                    value: allStages.contains(_stageFilter)
                        ? _stageFilter
                        : 'All Stages',
                    items: allStages,
                    icon: Icons.flag_outlined,
                    onChanged: (v) => setState(() {
                          _stageFilter = v;
                          _page = 1;
                        }))),
            const SizedBox(width: 10),
            Expanded(
                child: _FDrop(
                    value: allUsers.contains(_userFilter)
                        ? _userFilter
                        : 'All Users',
                    items: allUsers,
                    icon: Icons.person_outline,
                    labelBuilder: (s) => s == 'All Users' ? s : _userName(s),
                    onChanged: (v) => setState(() {
                          _userFilter = v;
                          _page = 1;
                        }))),
          ])),
      Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(children: [
            Expanded(
                child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() {
                _todayFollowupsOnly = !_todayFollowupsOnly;
                _page = 1;
              }),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: _todayFollowupsOnly
                        ? AppColors.primaryLight
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _todayFollowupsOnly
                            ? AppColors.primary
                            : AppColors.border)),
                child: Row(
                  children: [
                    const Icon(Icons.today_outlined,
                        size: 13, color: AppColors.textHint),
                    const SizedBox(width: 6),
                    Text(
                      'Today Follow-ups',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: _todayFollowupsOnly
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _todayFollowupsOnly
                              ? AppColors.primary
                              : AppColors.textSecondary),
                    ),
                    const Spacer(),
                    if (_todayFollowupsOnly)
                      const Icon(Icons.check_circle,
                          size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _FDrop(
                    value: allClientTypes.contains(_clientTypeFilter)
                        ? _clientTypeFilter
                        : 'All Client Types',
                    items: allClientTypes,
                    icon: Icons.corporate_fare_outlined,
                    onChanged: (v) => setState(() {
                          _clientTypeFilter = v;
                          _page = 1;
                        }))),
          ])),
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
        _PaginationBar(
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
    final color = _stageColor(deal.stage);
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
                                  Text(_fmtVal(deal.currency, deal.value),
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

class _DealDetailSheet extends StatelessWidget {
  final Deal deal;
  final GlobalKey<ScaffoldMessengerState> _detailMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  _DealDetailSheet({required this.deal});

  DateTime? _followUpLocal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  ScaffoldMessengerState? _snackMessenger(BuildContext context) {
    final localSheet = _detailMessengerKey.currentState;
    if (localSheet != null) return localSheet;
    final local = ScaffoldMessenger.maybeOf(context);
    if (local != null) return local;
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNav == null) return null;
    return ScaffoldMessenger.maybeOf(rootNav.context);
  }

  void _showSnack(BuildContext context, SnackBar snackBar) {
    final messenger = _snackMessenger(context);
    if (messenger == null) return;
    try {
      messenger.showSnackBar(snackBar);
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retry = _snackMessenger(context);
        retry?.showSnackBar(snackBar);
      });
    }
  }

  void _hideSnack(BuildContext context) {
    final messenger = _snackMessenger(context);
    if (messenger == null) return;
    try {
      messenger.hideCurrentSnackBar();
    } catch (_) {}
  }

  /// Public file URL on staging (same pattern as lead detail).
  String _buildPreviewUrl(String rawPath) {
    const base = 'https://sales.stagingzar.com';
    final clean = rawPath.startsWith('/') ? rawPath : '/$rawPath';
    return '$base$clean';
  }

  Future<void> _previewFile(BuildContext context, String rawPath) async {
    final url = _buildPreviewUrl(rawPath);
    final uri = Uri.parse(url);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _showSnack(
          context,
          const SnackBar(
            content: Text('No app found to open this file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(
          context,
          SnackBar(
            content: Text('Could not open file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(
      BuildContext context, String rawPath, String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      if (!context.mounted) return;
      _showSnack(
        context,
        const SnackBar(
          content: Text('Login required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cleanPath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
    final url = Uri.https(
      'sales.stagingzar.com',
      '/api/files/download',
      {'filePath': cleanPath},
    ).toString();

    final lastDot = fileName.lastIndexOf('.');
    final baseName = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    final extOnly = lastDot > 0 ? fileName.substring(lastDot + 1) : '';
    final mime = _dealMimeTypeForAttachmentExt(extOnly);

    if (!context.mounted) return;
    _showSnack(
      context,
      const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Downloading…'),
        ]),
        duration: Duration(seconds: 60),
      ),
    );

    try {
      String savedPath;
      if (Platform.isAndroid) {
        final response = await Dio().get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Authorization': 'Bearer $token'},
            receiveTimeout: const Duration(seconds: 60),
            connectTimeout: const Duration(seconds: 30),
          ),
        );
        final data = response.data;
        if (data == null || data.isEmpty) {
          throw Exception('Empty file response from server');
        }
        final path = await _dealDownloadsChannel.invokeMethod<String>(
          'saveToDownloads',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': Uint8List.fromList(data),
            'mimeType': _dealMimeStringForAttachmentExt(extOnly),
          },
        );
        savedPath = path ?? '';
      } else {
        savedPath = await FileSaver.instance.saveFile(
          name: baseName,
          link: LinkDetails(link: url, headers: {
            'Authorization': 'Bearer $token',
          }),
          ext: extOnly,
          mimeType: mime,
        );
      }

      if (savedPath.isEmpty ||
          savedPath.startsWith('Error While Saving') ||
          savedPath.contains('Something went wrong')) {
        throw Exception(savedPath);
      }

      if (!context.mounted) return;
      _hideSnack(context);
      _showSnack(
        context,
        SnackBar(
          content: Text(Platform.isAndroid
              ? 'Saved to Downloads: $fileName'
              : 'Saved: $fileName (Files app → On My iPhone → this app)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } on DioException catch (e) {
      if (!context.mounted) return;
      _hideSnack(context);
      final msg = (e.response?.data is Map)
          ? (e.response!.data['message'] ?? e.message)
          : e.message;
      _showSnack(
        context,
        SnackBar(
          content: Text('Download failed: $msg'),
          backgroundColor: Colors.red,
        ),
      );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      _hideSnack(context);
      _showSnack(
        context,
        SnackBar(
          content: Text('Download failed: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _hideSnack(context);
      _showSnack(
        context,
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
        key: _detailMessengerKey,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DefaultTabController(
            length: 3,
            child: DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, ctrl) => Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(children: [
                  Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(children: [
                      Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                AppColors.primary,
                                AppColors.accent
                              ]),
                              borderRadius: BorderRadius.circular(14)),
                          child: Center(
                              child: Text(
                            deal.name.isNotEmpty
                                ? deal.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20),
                          ))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(deal.name,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            Text(deal.companyName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                          ])),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: _stageColor(deal.stage).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(DealConstants.canonicalStage(deal.stage),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _stageColor(deal.stage)))),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: TabBar(
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      tabs: [
                        Tab(text: 'Details'),
                        Tab(text: 'Activity'),
                        Tab(text: 'Follow-up history'),
                      ],
                    ),
                  ),
                  const Divider(height: 16, color: AppColors.divider),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDetailsTab(ctrl),
                        _buildActivityTab(ctrl),
                        _buildFollowupHistoryTab(ctrl),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _buildDetailsTab(ScrollController ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          _row(Icons.payments_outlined, 'Deal Value',
              _fmtVal(deal.currency, deal.value)),
          if (_followUpLocal(deal.followUpDate) != null)
            _row(
              Icons.event_outlined,
              'Follow Up',
              DateFormat('dd MMM yyyy, hh:mm a')
                  .format(_followUpLocal(deal.followUpDate)!),
            ),
          _row(
              Icons.person_outline,
              'Assigned To',
              deal.assignTo.trim().isEmpty
                  ? 'Unassigned'
                  : deal.assignTo.trim()),
          _row(
            Icons.phone_outlined,
            'Phone',
            deal.phone.trim().isEmpty
                ? '-'
                : _formatPhone(deal.phone, deal.countryCode),
          ),
          _row(Icons.email_outlined, 'Email',
              deal.email.trim().isEmpty ? '-' : deal.email),
          _row(Icons.public_outlined, 'Country',
              deal.country.trim().isEmpty ? '-' : deal.country),
          if (deal.industry.isNotEmpty)
            _row(Icons.business_outlined, 'Industry', deal.industry),
          if (deal.source.isNotEmpty)
            _row(Icons.radar_outlined, 'Source', deal.source),
          if (deal.address.isNotEmpty)
            _row(Icons.location_on_outlined, 'Address', deal.address),
          if (deal.notes.isNotEmpty)
            _row(Icons.notes_outlined, 'Notes', deal.notes),
          if (deal.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Attachments',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...deal.attachments.map(
              (a) => Builder(
                builder: (tileCtx) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${(a.size / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.visibility,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Preview',
                        onPressed: () => _previewFile(tileCtx, a.path),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.download,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Download',
                        onPressed: () => _downloadFile(tileCtx, a.path, a.name),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      );

  String _formatPhone(String phone, String countryCode) {
    if (phone.trim().isEmpty) return '-';

    try {
      final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

      final parsedPhone = PhoneNumber.parse(
        '+$cleaned',
      );

      final code = parsedPhone.countryCode;
      final nationalNumber = parsedPhone.nsn;

      return '+$code $nationalNumber';
    } catch (e) {
      return phone;
    }
  }

  Widget _buildActivityTab(ScrollController ctrl) {
    final followUp = _followUpLocal(deal.followUpDate);
    final activities = <Map<String, dynamic>>[
      {
        'icon': Icons.add_circle_outline,
        'label': 'Deal created',
        'date': deal.createdAt,
      },
      if (deal.updatedAt != null)
        {
          'icon': Icons.edit_calendar_outlined,
          'label': 'Deal updated',
          'date': deal.updatedAt!,
        },
      if (followUp != null)
        {
          'icon': Icons.event_available_outlined,
          'label': 'Last Follow-Up',
          'date': followUp,
        },
      if (deal.lastReminderAt != null)
        {
          'icon': Icons.notifications_active_outlined,
          'label': 'Last Reminder Sent',
          'date': deal.lastReminderAt!.toLocal(),
        },
    ];

    return ListView.separated(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemBuilder: (_, i) {
        final item = activities[i];
        final icon = item['icon'] as IconData;
        final label = item['label'] as String;
        final date = item['date'] as DateTime;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal()),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ]),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: activities.length,
    );
  }

  Widget _buildFollowupHistoryTab(ScrollController ctrl) {
    DateTime? pickDt(FollowUpHistoryItem h) => (h.followUpDate ?? h.date);

    final now = DateTime.now();
    final upcoming = <FollowUpHistoryItem>[];
    final past = <FollowUpHistoryItem>[];

    for (final h in deal.followUpHistory) {
      final dt = pickDt(h);
      if (dt == null) continue;
      if (dt.isAfter(now) || dt.isAtSameMomentAs(now)) {
        upcoming.add(h);
      } else {
        past.add(h);
      }
    }

    upcoming.sort((a, b) => pickDt(a)!.compareTo(pickDt(b)!));
    past.sort((a, b) => pickDt(b)!.compareTo(pickDt(a)!)); // newest past first

    final hasAny = upcoming.isNotEmpty || past.isNotEmpty;
    if (!hasAny) {
      return ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        children: const [
          Text(
            'No follow-up history yet.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    List<Widget> cardsFor(List<FollowUpHistoryItem> items,
        {required bool upcoming}) {
      final bg = upcoming ? AppColors.purpleLight : AppColors.successLight;
      final fg = upcoming ? AppColors.purple : AppColors.success;
      final icon = upcoming ? Icons.alarm_outlined : Icons.check_circle_outline;
      return items.map((h) {
        final dt = pickDt(h)!;
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal()),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      upcoming ? 'Scheduled' : 'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList();
    }

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        if (upcoming.isNotEmpty) ...[
          const Text(
            'Upcoming follow-ups',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ...cardsFor(upcoming, upcoming: true),
        ],
        if (past.isNotEmpty) ...[
          if (upcoming.isNotEmpty) const SizedBox(height: 6),
          const Text(
            'Past follow-ups',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ...cardsFor(past, upcoming: false),
        ],
      ],
    );
  }

  Widget _row(IconData icon, String lbl, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(lbl,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(val.isEmpty ? '-' : val,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500)),
              ])),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// DEAL FORM MODAL
// ══════════════════════════════════════════════════════════════
class _DealFormModal extends StatefulWidget {
  final List<String> users;
  final Deal? editDeal;
  const _DealFormModal({required this.users, this.editDeal});
  @override
  State<_DealFormModal> createState() => _DealFormModalState();
}

class _DealFormModalState extends State<_DealFormModal> {
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _followUpComment = TextEditingController();

  String _currency = '₹ INR';
  String _countryCode = '+91 IN';
  String _stage = 'Qualification';
  String _industry = 'IT';
  String _source = 'Website';
  String _clientType = 'B2B';
  String _country = 'India';
  String? _assignTo;

  DateTime? _followUpDate;
  TimeOfDay? _followUpTime;

  /// Server-side files already on the deal (edit only); × removes from list
  /// and `retainedAttachmentPaths` on save.
  final List<Attachment> _existingAttachments = [];
  final List<PlatformFile> _attachments = [];
  static const int _maxBytes = 5 * 1024 * 1024; // 5 MB

  bool _saving = false;
  bool _fetching = false;
  final GlobalKey<ScaffoldMessengerState> _sheetMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool get _isEdit => widget.editDeal != null;

  ScaffoldMessengerState? _sheetMessenger() =>
      _sheetMessengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);

  void _showSheetSnack(
    String message, {
    Color? backgroundColor,
  }) {
    final messenger = _sheetMessenger();
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  int get _attachmentSlotsUsed =>
      _existingAttachments.length + _attachments.length;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefillAndFetch(widget.editDeal!);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _value,
      _phone,
      _email,
      _company,
      _address,
      _notes,
      _followUpComment
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _prefillAndFetch(Deal cached) async {
    _prefill(cached);
    setState(() => _fetching = true);
    try {
      final fresh = await context.read<DealsCubit>().getDealById(cached.id);
      if (mounted && fresh != null) _prefill(fresh);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _prefill(Deal d) {
    _name.text = d.name;
    _value.text =
        d.value == 0 ? '' : d.value.toStringAsFixed(d.value % 1 == 0 ? 0 : 2);
    _phone.text = d.phone;
    _email.text = d.email;
    _company.text = d.companyName;
    _address.text = d.address;
    _notes.text = d.notes;
    _followUpComment.text = d.followUpComment ?? '';

    _currency = DealConstants.currencies.contains(d.currency)
        ? d.currency
        : DealConstants.currencies.first;
    _countryCode = DealConstants.countryCodes.contains(d.countryCode)
        ? d.countryCode
        : DealConstants.countryCodes.first;
    _stage =
        DealConstants.stages.contains(DealConstants.canonicalStage(d.stage))
            ? DealConstants.canonicalStage(d.stage)
            : DealConstants.stages.first;
    _industry = DealConstants.industries.contains(d.industry)
        ? d.industry
        : DealConstants.industries.first;
    _source = AppConstants.leadSources.contains(d.source)
        ? d.source
        : AppConstants.leadSources.first;
    _clientType =
        (d.clientType == 'B2B' || d.clientType == 'B2C') ? d.clientType : 'B2B';
    _country = AppConstants.countries.contains(d.country)
        ? d.country
        : AppConstants.countries.first;

    if (d.assignTo.isNotEmpty) {
      _assignTo = widget.users
          .where((u) =>
              _userName(u).trim().toLowerCase() ==
              d.assignTo.trim().toLowerCase())
          .firstOrNull;
    }
    if (d.followUpDate != null && d.followUpDate!.isNotEmpty) {
      final dt = DateTime.tryParse(d.followUpDate!);
      if (dt != null) {
        final local = dt.isUtc ? dt.toLocal() : dt;
        _followUpDate = local;
        _followUpTime = TimeOfDay(hour: local.hour, minute: local.minute);
      }
    }

    _existingAttachments
      ..clear()
      ..addAll(d.attachments);

    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final maxDate = firstDate.add(const Duration(days: 365 * 2));
    final current = _followUpDate ?? firstDate;
    final safeInitialDate = current.isBefore(firstDate) ? firstDate : current;

    final d = await showDatePicker(
        context: context,
        initialDate: safeInitialDate,
        firstDate: firstDate,
        lastDate: maxDate);
    if (d != null && mounted) setState(() => _followUpDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: _followUpTime ?? TimeOfDay.now());
    if (t != null && mounted) setState(() => _followUpTime = t);
  }

  Future<void> _pickFiles() async {
    if (_attachmentSlotsUsed >= 5) {
      _snack('Maximum 5 files allowed');
      return;
    }
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, withData: true, type: FileType.any);
    if (result == null) return;
    final toAdd = <PlatformFile>[];
    for (final f in result.files) {
      if (_attachmentSlotsUsed + toAdd.length >= 5) {
        _snack('Maximum 5 files allowed');
        break;
      }
      if (f.size > _maxBytes) {
        _snack('${f.name} exceeds 5 MB');
        continue;
      }
      if (_existingAttachments.any((a) => a.name == f.name) ||
          _attachments.any((a) => a.name == f.name)) {
        continue;
      }
      toAdd.add(f);
    }
    if (toAdd.isNotEmpty && mounted) setState(() => _attachments.addAll(toAdd));
  }

  void _removeAttachment(int i) => setState(() => _attachments.removeAt(i));

  void _removeExistingAttachment(Attachment file) {
    setState(() => _existingAttachments.remove(file));
  }

  // ── SAVE ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('Deal Name is required');
      return;
    }
    if (_value.text.trim().isEmpty) {
      _snack('Deal Value is required');
      return;
    }
    final phoneDigits = _phone.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    if (phoneDigits.isEmpty) {
      _snack('Phone Number is required');
      return;
    }

    if (phoneDigits.length > 12) {
      _snack('Phone Number must not exceed 12 digits');
      return;
    }
    if (_email.text.trim().isEmpty) {
      _snack('Email is required');
      return;
    }
    if (_company.text.trim().isEmpty) {
      _snack('Company Name is required');
      return;
    }

    setState(() => _saving = true);
    final cubit = context.read<DealsCubit>();

    final selectedUser =
        _assignTo ?? (widget.users.isNotEmpty ? widget.users.first : null);
    final assignToId = (selectedUser != null && selectedUser.isNotEmpty)
        ? _userId(selectedUser)
        : null;

    final payload = <String, dynamic>{
      'dealName': _name.text.trim(),
      'companyName': _company.text.trim(),
      'phoneNumber': _phone.text.trim(),
      'email': _email.text.trim(),
      'stage': _stage,
      'industry': _industry,
      'source': _source,
      'clientType': _clientType,
      'country': _country,
      'address': _address.text.trim(),
      'notes': _notes.text.trim(),
      'currency': _currency.split(' ').last, // "₹ INR" → "INR"
      'countryCode': _countryCode,
      'dealValue':
          (double.tryParse(_value.text.replaceAll(',', '')) ?? 0).toString(),
      if (assignToId != null) 'assignTo': assignToId,
    };

    String? dealId;

    if (_isEdit) {
      // ── EDIT FLOW ───────────────────────────────────────────
      // Keep/remove server files (same idea as lead update).
      payload['retainedAttachmentPaths'] = _existingAttachments
          .map((a) => a.path)
          .where((p) => p.isNotEmpty)
          .toList();

      await cubit.updateDeal(widget.editDeal!.id, payload);
      dealId = widget.editDeal!.id;

      if (!mounted) return;

      if (_attachments.isNotEmpty) {
        final okUpload = await cubit.uploadAttachments(dealId, _attachments);
        if (!okUpload && mounted) {
          _showSheetSnack(
            'Deal updated — new attachment upload failed',
            backgroundColor: AppColors.warning,
          );
        }
      }
    } else {
      // ── CREATE FLOW ─────────────────────────────────────────
      // FIX: Attachments are sent INSIDE createDeal as multipart.
      // Do NOT call uploadAttachments again after create — that
      // would double-upload and may fail if the endpoint differs.
      dealId = await cubit.createDeal(payload, _attachments);
    }

    if (!mounted) return;

    // ── Schedule follow-up (both create + edit) ───────────────
    if (dealId != null && _followUpDate != null) {
      final tod = _followUpTime ?? const TimeOfDay(hour: 9, minute: 0);
      final dt = DateTime(_followUpDate!.year, _followUpDate!.month,
          _followUpDate!.day, tod.hour, tod.minute);
      final ok = await cubit.scheduleFollowUp(dealId,
          followUpDate: dt, comment: _followUpComment.text);
      if (!ok && mounted) {
        _showSheetSnack(
          'Deal saved — follow-up scheduling failed',
          backgroundColor: AppColors.warning,
        );
      }
    }

    if (dealId != null) {
      await cubit.loadDeals();
    }

    if (!mounted) return;
    setState(() => _saving = false);

    // Show success snack and close modal
    if (mounted) {
      _showSheetSnack(
        _isEdit ? 'Deal updated successfully' : 'Deal created successfully',
        backgroundColor: AppColors.success,
      );
      Navigator.pop(context);
    }
  }

  void _snack(String msg) =>
      _showSheetSnack(msg, backgroundColor: AppColors.danger);

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
        key: _sheetMessengerKey,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: DraggableScrollableSheet(
              initialChildSize: 0.96,
              maxChildSize: 0.98,
              minChildSize: 0.5,
              builder: (_, ctrl) => Container(
                  decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24))),
                  child: Padding(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        Container(
                            margin: const EdgeInsets.only(top: 10),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(2))),
                        Container(
                            color: AppColors.surface,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: _isEdit
                                          ? AppColors.warningLight
                                          : AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(
                                      _isEdit
                                          ? Icons.edit_outlined
                                          : Icons.handshake_outlined,
                                      color: _isEdit
                                          ? AppColors.warning
                                          : AppColors.primary,
                                      size: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        _isEdit
                                            ? 'Edit Deal'
                                            : 'Create New Deal',
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary)),
                                    Text(
                                        _isEdit
                                            ? 'Update deal details below'
                                            : 'Fill in deal details below',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                  ])),
                              if (_fetching)
                                const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary)),
                              const SizedBox(width: 8),
                              IconButton(
                                  onPressed: _saving
                                      ? null
                                      : () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                      backgroundColor: AppColors.divider,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)))),
                            ])),
                        const Divider(height: 1, color: AppColors.divider),
                        Expanded(
                            child: ListView(
                                controller: ctrl,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  18 + MediaQuery.of(context).viewInsets.bottom,
                                ),
                                children: [
                              // ── § 1 Deal Information ──────────────────────────
                              const _SecHeader(
                                  title: 'Deal Information',
                                  icon: Icons.info_outline),
                              const SizedBox(height: 14),
                              const _FieldLabel('Deal Name', required: true),
                              const SizedBox(height: 6),
                              _tf(_name, 'e.g. Enterprise CRM Setup'),
                              const SizedBox(height: 16),

                              const _FieldLabel('Deal Value', required: true),
                              const SizedBox(height: 6),
                              Row(children: [
                                _CompactDrop(
                                    value: _currency,
                                    items: DealConstants.currencies,
                                    width: 110,
                                    onChanged: (v) =>
                                        setState(() => _currency = v)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _tf(_value, '0.00',
                                        type: TextInputType.number)),
                              ]),
                              const SizedBox(height: 16),

                              const _FieldLabel('Phone Number', required: true),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(
                                  child: IntlPhoneField(
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(12),
                                    ],
                                    controller: _phone,
                                    initialCountryCode: 'IN',
                                    disableLengthCheck: true,
                                    decoration: const InputDecoration(
                                      hintText: '9876543210',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (phone) {
                                      _phone.text = phone.number;
                                      _countryCode =
                                          '${phone.countryCode} ${phone.countryISOCode}';
                                    },
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),

                              const _FieldLabel('Email', required: true),
                              const SizedBox(height: 6),
                              _tf(_email, 'deal@company.com',
                                  type: TextInputType.emailAddress),
                              const SizedBox(height: 16),

                              const _FieldLabel('Stage'),
                              const SizedBox(height: 6),
                              _FullDrop(
                                  value: _stage,
                                  items: DealConstants.stages,
                                  icon: Icons.flag_outlined,
                                  onChanged: (v) => setState(() => _stage = v)),
                              const SizedBox(height: 16),

                              const _FieldLabel('Company Name', required: true),
                              const SizedBox(height: 6),
                              _tf(_company, 'Organisation name'),
                              const SizedBox(height: 16),

                              const _SecHeader(
                                  title: 'Business Details',
                                  icon: Icons.business_outlined),
                              const SizedBox(height: 14),
                              const _FieldLabel('Industry'),
                              const SizedBox(height: 6),
                              _FullDrop(
                                  value: _industry,
                                  items: DealConstants.industries,
                                  icon: Icons.business_outlined,
                                  onChanged: (v) =>
                                      setState(() => _industry = v)),
                              const SizedBox(height: 16),

                              const _FieldLabel('Source'),
                              const SizedBox(height: 6),
                              _FullDrop(
                                  value: _source,
                                  items: AppConstants.leadSources,
                                  icon: Icons.radar_outlined,
                                  onChanged: (v) =>
                                      setState(() => _source = v)),
                              const SizedBox(height: 16),
                              const _FieldLabel('Client Type'),
                              const SizedBox(height: 6),
                              _FullDrop(
                                  value: _clientType,
                                  items: const ['B2B', 'B2C'],
                                  icon: Icons.corporate_fare_outlined,
                                  onChanged: (v) =>
                                      setState(() => _clientType = v)),
                              const SizedBox(height: 16),

                              const _FieldLabel('Address'),
                              const SizedBox(height: 6),
                              _tf(_address, 'Street, City, Zip', maxLines: 2),
                              const SizedBox(height: 16),

                              const _FieldLabel('Country'),
                              const SizedBox(height: 6),
                              _FullDrop(
                                  value: _country,
                                  items: AppConstants.countries,
                                  icon: Icons.public_outlined,
                                  onChanged: (v) =>
                                      setState(() => _country = v)),
                              const SizedBox(height: 24),

                              // ── § 2 Follow-up ─────────────────────────────────
                              const _SecHeader(
                                  title: 'Follow-up',
                                  icon: Icons.alarm_outlined),
                              const SizedBox(height: 14),

                              Row(children: [
                                Expanded(
                                    child: GestureDetector(
                                        onTap: _pickDate,
                                        child: _pickerBox(
                                            icon: Icons.calendar_today_outlined,
                                            label: _followUpDate != null
                                                ? DateFormat('dd MMM yyyy')
                                                    .format(_followUpDate!)
                                                : 'Select date',
                                            active: _followUpDate != null))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: GestureDetector(
                                        onTap: _pickTime,
                                        child: _pickerBox(
                                            icon: Icons.access_time_outlined,
                                            label: _followUpTime != null
                                                ? _followUpTime!.format(context)
                                                : 'Select time',
                                            active: _followUpTime != null))),
                              ]),

                              if (_followUpDate == null &&
                                  _followUpTime == null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(children: [
                                      const Icon(Icons.info_outline,
                                          size: 13, color: AppColors.textHint),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: Text(
                                              'Optional: Set a reminder for follow-up',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textHint
                                                      .withOpacity(0.8)))),
                                    ]))
                              else
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: GestureDetector(
                                        onTap: () => setState(() {
                                              _followUpDate = null;
                                              _followUpTime = null;
                                            }),
                                        child: const Row(children: [
                                          Icon(Icons.close_rounded,
                                              size: 13,
                                              color: AppColors.danger),
                                          SizedBox(width: 4),
                                          Text('Clear follow-up',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.danger)),
                                        ]))),

                              const SizedBox(height: 16),
                              const _FieldLabel('Follow-up Comment'),
                              const SizedBox(height: 6),
                              _tf(_followUpComment,
                                  'Add a note about this follow-up…',
                                  maxLines: 3),
                              const SizedBox(height: 24),

                              // ── § 3 Management ────────────────────────────────
                              const _SecHeader(
                                  title: 'Management',
                                  icon: Icons.tune_outlined),
                              const SizedBox(height: 14),

                              const _FieldLabel('Assign To'),
                              const SizedBox(height: 6),
                              widget.users.isEmpty
                                  ? Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppColors.border)),
                                      alignment: Alignment.centerLeft,
                                      child: const Text('No users available',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textHint)))
                                  : _FullDrop(
                                      value: _assignTo ?? widget.users.first,
                                      items: widget.users,
                                      icon: Icons.person_outline,
                                      labelBuilder: _userName,
                                      onChanged: (v) =>
                                          setState(() => _assignTo = v)),
                              const SizedBox(height: 16),

                              const _FieldLabel('Notes'),
                              const SizedBox(height: 6),
                              _tf(_notes, 'Any additional context…',
                                  maxLines: 4),
                              const SizedBox(height: 24),

                              // ── § 4 Attachments ───────────────────────────────
                              const _SecHeader(
                                  title: 'Attachments',
                                  icon: Icons.attach_file_rounded),
                              const SizedBox(height: 14),

                              GestureDetector(
                                  onTap: _attachmentSlotsUsed < 5
                                      ? _pickFiles
                                      : null,
                                  child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18),
                                      decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: _attachmentSlotsUsed < 5
                                                  ? AppColors.primary
                                                      .withOpacity(0.4)
                                                  : AppColors.border)),
                                      child: Column(children: [
                                        Icon(Icons.cloud_upload_outlined,
                                            size: 32,
                                            color: _attachmentSlotsUsed < 5
                                                ? AppColors.primary
                                                : AppColors.textHint),
                                        const SizedBox(height: 8),
                                        Text(
                                            _attachmentSlotsUsed < 5
                                                ? 'Tap to upload files'
                                                : 'Maximum 5 files reached',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: _attachmentSlotsUsed < 5
                                                    ? AppColors.primary
                                                    : AppColors.textHint)),
                                        const SizedBox(height: 4),
                                        const Text(
                                            'Any file type · Max 5 MB per file · Up to 5 files',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textHint)),
                                      ]))),
                              const SizedBox(height: 12),

                              if (_isEdit &&
                                  _existingAttachments.isNotEmpty) ...[
                                const Text(
                                  'Current attachments',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._existingAttachments.map((file) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _fileIcon(file.name),
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  file.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  _fileSize(file.size),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () =>
                                                _removeExistingAttachment(file),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppColors.dangerLight,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                                color: AppColors.danger,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const SizedBox(height: 8),
                              ],

                              if (_attachments.isNotEmpty) ...[
                                if (_isEdit)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'New attachments',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ..._attachments.asMap().entries.map((e) =>
                                    Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: AppColors.border)),
                                        child: Row(children: [
                                          Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                  color: AppColors.primaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              child: Icon(
                                                  _fileIcon(e.value.name),
                                                  size: 16,
                                                  color: AppColors.primary)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(e.value.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textPrimary)),
                                                Text(_fileSize(e.value.size),
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary)),
                                              ])),
                                          GestureDetector(
                                              onTap: () =>
                                                  _removeAttachment(e.key),
                                              child: Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                      color:
                                                          AppColors.dangerLight,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6)),
                                                  child: const Icon(
                                                      Icons.close_rounded,
                                                      size: 14,
                                                      color:
                                                          AppColors.danger))),
                                        ]))),
                              ],

                              const SizedBox(height: 28),

                              Row(children: [
                                Expanded(
                                    child: OutlinedButton(
                                        onPressed: _saving
                                            ? null
                                            : () => Navigator.pop(context),
                                        child: const Text('Cancel'))),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: ElevatedButton.icon(
                                        onPressed: (_saving || _fetching)
                                            ? null
                                            : _save,
                                        style: _isEdit
                                            ? ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.warning)
                                            : null,
                                        icon: _saving
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : Icon(
                                                _isEdit
                                                    ? Icons.check_outlined
                                                    : Icons.save_outlined,
                                                size: 16),
                                        label: Text(_saving
                                            ? (_isEdit
                                                ? 'Updating…'
                                                : 'Saving…')
                                            : (_isEdit
                                                ? 'Update Deal'
                                                : 'Save Deal')))),
                              ]),
                              const SizedBox(height: 24),
                            ])),
                      ])))),
        ),
      );

  Widget _pickerBox(
          {required IconData icon,
          required String label,
          required bool active}) =>
      Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: active ? AppColors.primaryLight : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? AppColors.primary : AppColors.border)),
          child: Row(children: [
            Icon(icon,
                size: 16,
                color: active ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            active ? AppColors.primary : AppColors.textHint))),
          ]));

  Widget _tf(TextEditingController c, String hint,
          {TextInputType type = TextInputType.text, int maxLines = 1}) =>
      TextField(
          controller: c,
          keyboardType: type,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
              hintText: hint,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 14, vertical: maxLines > 1 ? 14 : 13),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5))));

  static IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext))
      return Icons.image_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['doc', 'docx'].contains(ext)) return Icons.description_outlined;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_outlined;
    return Icons.attach_file_outlined;
  }

  static String _fileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(String) onChanged;
  final VoidCallback onClear;
  const _SearchBar(
      {required this.controller,
      required this.hint,
      required this.onChanged,
      required this.onClear});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 42,
      child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search,
                  size: 18, color: AppColors.textSecondary),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        controller.clear();
                        onClear();
                      })
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5)))));
}

class _FDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final void Function(String) onChanged;
  final String Function(String)? labelBuilder;
  const _FDrop(
      {required this.value,
      required this.items,
      required this.icon,
      required this.onChanged,
      this.labelBuilder});
  bool get _active => value != items.first;
  @override
  Widget build(BuildContext context) => Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: _active ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _active ? AppColors.primary : AppColors.border)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: _active ? AppColors.primary : AppColors.textSecondary),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: _active ? FontWeight.w600 : FontWeight.w400,
                  color: _active ? AppColors.primary : AppColors.textSecondary),
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Row(children: [
                        Icon(icon, size: 13, color: AppColors.textHint),
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text(
                                labelBuilder != null ? labelBuilder!(e) : e,
                                overflow: TextOverflow.ellipsis))
                      ])))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              })));
}

class _SecHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SecHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary))
      ]));
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(
      text: text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary),
      children: required
          ? [
              const TextSpan(
                  text: ' *', style: TextStyle(color: AppColors.danger))
            ]
          : []));
}

class _CompactDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final double width;
  final void Function(String) onChanged;
  const _CompactDrop(
      {required this.value,
      required this.items,
      required this.width,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isDense: true,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: AppColors.textSecondary),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              })));
}

class _FullDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final void Function(String) onChanged;
  final String Function(String)? labelBuilder;
  const _FullDrop(
      {required this.value,
      required this.items,
      required this.icon,
      required this.onChanged,
      this.labelBuilder});
  @override
  Widget build(BuildContext context) => Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textSecondary),
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Row(children: [
                        Icon(icon, size: 14, color: AppColors.textHint),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                labelBuilder != null ? labelBuilder!(e) : e,
                                overflow: TextOverflow.ellipsis))
                      ])))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              })));
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = (page * pageSize) > totalItems ? totalItems : (page * pageSize);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            '$start-$end of $totalItems',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous page',
          ),
          Text(
            '$page / $totalPages',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FORMAT HELPERS
// ══════════════════════════════════════════════════════════════
String _fmtVal(String currency, double v) {
  final symbol = DealConstants.currencySymbol(currency);
  if (v >= 10000000) return '$symbol${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '$symbol${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '$symbol${(v / 1000).toStringAsFixed(1)}K';
  return '$symbol${v.toStringAsFixed(0)}';
}
