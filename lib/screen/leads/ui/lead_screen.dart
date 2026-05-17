// ║               lib/screens/leads_screen.dart                  ║
// ╔══════════════════════════════════════════════════════════════╗
// ║  READ    → 🌐 GET  /leads/getAllLead                         ║
// ║  CREATE  → 🌐 POST /leads/create          (FormData)         ║
// ║  UPDATE  → 🌐 PUT  /leads/updateLead/:id  (FormData)         ║
// ║  DELETE  → 🌐 DEL  /leads/deleteLead/:id                     ║
// ║  STATUS  → 🌐 PATCH /leads/:id/status                        ║
// ║  FOLLOW  → 🌐 PATCH /leads/:id/followup                      ║
// ║  CONVERT → 🌐 PATCH /leads/:id/convert                       ║
// ╚══════════════════════════════════════════════════════════════
import 'dart:io';

import 'package:crm_app/modals/modals.dart'
    show AppConstants, Lead, AppUser, Attachment;
import 'package:crm_app/screen/deals/modal/deal_modal.dart' show DealConstants;
import 'package:crm_app/screen/leads/cubit/lead_cubit.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show
        SectionHeader,
        CrmTextField,
        LoadingState,
        showApiSnack,
        ErrorState,
        EmptyState,
        StatusBadge,
        CrmDropdown;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:crm_app/utils/permission_helper.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

// ── Pagination constant ───────────────────────────────────────
const int _kPageSize = 10;
const MethodChannel _downloadsChannel = MethodChannel('crm/downloads');

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

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _clampPickerDate(
  DateTime candidate, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final c = _dateOnly(candidate);
  final first = _dateOnly(firstDate);
  final last = _dateOnly(lastDate);
  if (c.isBefore(first)) return first;
  if (c.isAfter(last)) return last;
  return c;
}

MimeType _mimeTypeForAttachmentExt(String ext) {
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

String _mimeStringForAttachmentExt(String ext) {
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

// ══════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════
class LeadsScreen extends StatelessWidget {
  const LeadsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => LeadCubit()..fetchAllLeads(),
        child: const _LeadsView(),
      );
}

class _LeadsView extends StatefulWidget {
  const _LeadsView();
  @override
  State<_LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends State<_LeadsView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '',
      _statusFilter = 'All Status',
      _sourceFilter = 'All Sources',
      _clientTypeFilter = 'All Client Types';
  String _assigneeFilter = 'All Assignees';

  final Map<String, String> _assigneeIdToName = {};
  List<String> _assigneeDropdownItems = ['All Assignees'];

  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadAssignees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final dio = Dio(BaseOptions(baseUrl: 'https://sales.stagingzar.com/api'));
      final res = await dio.get(
        '/users',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final body = res.data;
      List<dynamic> raw = [];
      if (body is List) {
        raw = body;
      } else if (body is Map) {
        for (final k in [
          'data',
          'users',
          'staff',
          'employees',
          'result',
          'records'
        ]) {
          if (body[k] is List) {
            raw = body[k] as List;
            break;
          }
        }
      }

      final idToName = <String, String>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final id = (item['_id'] ?? item['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        final first =
            (item['firstName'] ?? item['first_name'] ?? '').toString().trim();
        final last =
            (item['lastName'] ?? item['last_name'] ?? '').toString().trim();
        final full = '$first $last'.trim();
        idToName[id] =
            full.isNotEmpty ? full : (item['name']?.toString().trim() ?? '');
      }

      if (!mounted) return;
      setState(() {
        _assigneeIdToName
          ..clear()
          ..addAll(idToName);
        _assigneeDropdownItems = [
          'All Assignees',
          ...idToName.keys.toList()..sort(),
        ];
      });
    } catch (_) {
      // Keep dropdown as only "All Assignees" if it fails.
    }
  }

  List<Lead> _filter(List<Lead> all) {
    if (all.isEmpty) return all;
    final q = _search.toLowerCase();
    return all.where((l) {
      final matchesSearch =
          _search.isEmpty || l.name.toLowerCase().startsWith(q);

      final matchesStatus =
          _statusFilter == 'All Status' || l.status == _statusFilter;
      final matchesSource =
          _sourceFilter == 'All Sources' || l.source == _sourceFilter;
      final matchesClientType = _clientTypeFilter == 'All Client Types' ||
          (l.clientType.isNotEmpty && l.clientType == _clientTypeFilter);
      final matchesAssignee = _assigneeFilter == 'All Assignees' ||
          (l.assignedToId != null && l.assignedToId == _assigneeFilter) ||
          l.assignTo.trim() == _assigneeFilter;
      return matchesSearch &&
          matchesStatus &&
          matchesSource &&
          matchesClientType &&
          matchesAssignee;
    }).toList();
  }

  List<Lead> _paginate(List<Lead> filtered) {
    final start = (_currentPage - 1) * _kPageSize;
    if (start >= filtered.length) return [];
    final end = (start + _kPageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  int _totalPages(int filteredCount) =>
      (filteredCount / _kPageSize).ceil().clamp(1, 99999);

  void _resetPage() {
    if (_currentPage != 1) setState(() => _currentPage = 1);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LeadCubit, LeadState>(
      listener: (ctx, state) {
        if (state is LeadActionSuccess) showApiSnack(ctx, state.message);
        if (state is LeadError && _isSessionExpiredMessage(state.message)) {
          Navigator.of(ctx, rootNavigator: true)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      builder: (context, state) {
        final allFiltered =
            state is LeadLoaded ? _filter(state.leads) : <Lead>[];
        final leads = _paginate(allFiltered);
        final allCount = state is LeadLoaded ? state.leads.length : 0;
        final totalPages = _totalPages(allFiltered.length);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Leads'),
            backgroundColor: AppColors.surface,
            actions: [
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('$allCount total',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Column(children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        setState(() {
                          _search = _searchController.text;
                          _resetPage();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search leads...',
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textSecondary, size: 20),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() {
                                      _searchController.clear();
                                      _search = '';
                                      _resetPage();
                                    }))
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (PermissionHelper.can('users_roles'))
                    ElevatedButton.icon(
                      onPressed: () => _openCreate(context),
                      icon:
                          const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text(
                        'Create Lead',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _FilterDrop(
                          value: _statusFilter,
                          items: const [
                            'All Status',
                            ...AppConstants.leadStatuses
                          ],
                          icon: Icons.flag_outlined,
                          onChanged: (v) => setState(() {
                                _statusFilter = v!;
                                _resetPage();
                              }))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _FilterDrop(
                          value: _sourceFilter,
                          items: const [
                            'All Sources',
                            ...AppConstants.leadSources
                          ],
                          icon: Icons.radar_outlined,
                          onChanged: (v) => setState(() {
                                _sourceFilter = v!;
                                _resetPage();
                              }))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _FilterDrop(
                          value: _clientTypeFilter,
                          items: const [
                            'All Client Types',
                            'B2B',
                            'B2C',
                          ],
                          icon: Icons.corporate_fare_outlined,
                          onChanged: (v) => setState(() {
                                _clientTypeFilter = v!;
                                _resetPage();
                              }))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _FilterDrop(
                          value: _assigneeFilter,
                          items: _assigneeDropdownItems,
                          icon: Icons.person_outline,
                          labelBuilder: (id) => id == 'All Assignees'
                              ? 'All Assignees'
                              : (_assigneeIdToName[id] ?? id),
                          onChanged: (v) => setState(() {
                                _assigneeFilter = v ?? 'All Assignees';
                                _resetPage();
                              }))),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Text(
                    '${allFiltered.length} lead${allFiltered.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                if (_statusFilter != 'All Status' ||
                    _sourceFilter != 'All Sources' ||
                    _clientTypeFilter != 'All Client Types' ||
                    _assigneeFilter != 'All Assignees') ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _statusFilter = 'All Status';
                      _sourceFilter = 'All Sources';
                      _clientTypeFilter = 'All Client Types';
                      _assigneeFilter = 'All Assignees';
                      _resetPage();
                    }),
                    child: const Text('Clear',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
            ),
            Expanded(
                child: _buildList(context, state, leads, allFiltered.length)),
            if (state is LeadLoaded && allFiltered.isNotEmpty)
              _PaginationBar(
                page: _currentPage,
                totalPages: totalPages,
                totalItems: allFiltered.length,
                pageSize: _kPageSize,
                onPrev: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                onNext: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
          ]),
        );
      },
    );
  }

  Widget _buildList(
      BuildContext context, LeadState state, List<Lead> leads, int total) {
    if (state is LeadLoading) {
      return const LoadingState(message: 'Fetching leads...');
    }
    if (state is LeadError) {
      return ErrorState(
          message: state.message,
          onRetry: () => context.read<LeadCubit>().fetchAllLeads());
    }
    if (leads.isEmpty) {
      return EmptyState(
          message: _search.isNotEmpty ? 'No matches' : 'No leads yet',
          icon: Icons.people_outline);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<LeadCubit>().fetchAllLeads(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: leads.length,
        itemBuilder: (_, i) => _LeadCard(
          lead: leads[i],
          onTap: () => _openDetail(context, leads[i]),
          onEdit: () => _openEdit(context, leads[i]),
          onDelete: () => _confirmDelete(context, leads[i].id),
          onStatusChange: (s) =>
              context.read<LeadCubit>().updateStatus(leads[i].id, s),
          onConvert: () => _openConvert(context, leads[i]),
        ),
      ),
    );
  }

  void _openCreate(BuildContext ctx) {
    final salesUsers = ctx.read<LeadCubit>().salesUsers;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: BlocProvider.value(
            value: ctx.read<LeadCubit>(),
            child: _LeadFormModal(salesUsers: salesUsers),
          ),
        ),
      ),
    );
  }

  void _openEdit(BuildContext ctx, Lead lead) {
    final salesUsers = ctx.read<LeadCubit>().salesUsers;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: BlocProvider.value(
            value: ctx.read<LeadCubit>(),
            child: _LeadFormModal(salesUsers: salesUsers, existingLead: lead),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext ctx, Lead lead) async {
    final cubit = ctx.read<LeadCubit>();
    final fullLead = await cubit.fetchLeadById(lead.id);
    if (!ctx.mounted) return;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: BlocProvider.value(
            value: cubit,
            child: _LeadDetailSheet(lead: fullLead ?? lead),
          ),
        ),
      ),
    );
  }

  void _openConvert(BuildContext ctx, Lead lead) {
    final isConverted = lead.status.trim().toLowerCase() == 'converted';
    if (isConverted) {
      showApiSnack(ctx, 'This lead is already converted to a deal.');
      return;
    }
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: BlocProvider.value(
            value: ctx.read<LeadCubit>(),
            child: _ConvertLeadSheet(lead: lead),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, String id) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Lead'),
        content: const Text('This will permanently delete the lead. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      final err = await ctx.read<LeadCubit>().deleteLead(id);
      if (err != null && ctx.mounted) showApiSnack(ctx, err, isError: true);
    }
  }
}

// ── Pagination Bar ────────────────────────────────────────────
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

// ─── Filter Dropdown ──────────────────────────────────────────
class _FilterDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final void Function(String?) onChanged;
  final String Function(String value)? labelBuilder;
  const _FilterDrop(
      {required this.value,
      required this.items,
      required this.icon,
      required this.onChanged,
      this.labelBuilder});
  bool get active => value != items.first;
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: active ? AppColors.primary : AppColors.textSecondary),
          style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.primary : AppColors.textSecondary),
          items: items
              .toSet()
              .toList()
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Row(children: [
                    Icon(icon, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                        child: Text(
                      labelBuilder != null ? labelBuilder!(e) : e,
                      overflow: TextOverflow.ellipsis,
                    )),
                  ])))
              .toList(),
          onChanged: onChanged,
        )),
      );
}

// ─── Lead Card ────────────────────────────────────────────────
class _LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap, onEdit, onDelete, onConvert;
  final Future<String?> Function(String) onStatusChange;
  const _LeadCard(
      {required this.lead,
      required this.onTap,
      required this.onEdit,
      required this.onDelete,
      required this.onStatusChange,
      required this.onConvert});

  @override
  Widget build(BuildContext ctx) {
    final isConverted = lead.status.trim().toLowerCase() == 'converted';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                      child: Text(
                    lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(lead.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    if (lead.companyName.isNotEmpty)
                      Text(lead.companyName,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                  ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                GestureDetector(
                  onTap: () => _showStatusMenu(ctx),
                  child: StatusBadge(status: lead.status),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  if (!isConverted)
                    GestureDetector(
                        onTap: onConvert,
                        child: const Icon(Icons.swap_horiz_outlined,
                            size: 18, color: AppColors.textHint)),
                  if (!isConverted) const SizedBox(width: 8),
                  GestureDetector(
                      onTap: onEdit,
                      child: const Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.textHint)),
                  const SizedBox(width: 10),
                  GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.textHint)),
                ]),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16))),
            child: Row(children: [
              if (lead.country.isNotEmpty)
                _chip(Icons.public_outlined, lead.country),
              const SizedBox(width: 5),
              _chip(Icons.radar_outlined,
                  lead.source.isEmpty ? 'N/A' : lead.source),
              if (lead.clientType.isNotEmpty) ...[
                const SizedBox(width: 5),
                _chip(Icons.corporate_fare_outlined, lead.clientType),
              ],
              const Spacer(),
              if (lead.followUpDate != null)
                _chip(Icons.event_outlined,
                    DateFormat('dd MMM').format(lead.followUpDate!),
                    c: AppColors.primary),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showStatusMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: BlocProvider.value(
            value: ctx.read<LeadCubit>(),
            child: _StatusPickerSheet(
                currentStatus: lead.status,
                onStatusSelected: (s) async {
                  Navigator.pop(ctx);
                  final err =
                      await ctx.read<LeadCubit>().updateStatus(lead.id, s);
                  if (err != null && ctx.mounted) {
                    showApiSnack(ctx, err, isError: true);
                  }
                }),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData i, String t, {Color c = AppColors.textSecondary}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 13, color: c),
        const SizedBox(width: 4),
        Text(t,
            style:
                TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500)),
      ]);
}

// ─── Status Picker Sheet ──────────────────────────────────────
class _StatusPickerSheet extends StatelessWidget {
  final String currentStatus;
  final void Function(String) onStatusSelected;
  const _StatusPickerSheet(
      {required this.currentStatus, required this.onStatusSelected});

  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('Update Status',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...AppConstants.leadStatuses.map((s) {
            final selected = s == currentStatus;
            return ListTile(
              onTap: () => onStatusSelected(s),
              leading: StatusBadge(status: s),
              trailing: selected
                  ? const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 20)
                  : null,
              dense: true,
            );
          }),
          const SizedBox(height: 8),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// LEAD DETAIL SHEET
// ══════════════════════════════════════════════════════════════
class _LeadDetailSheet extends StatefulWidget {
  final Lead lead;
  const _LeadDetailSheet({required this.lead});

  @override
  State<_LeadDetailSheet> createState() => _LeadDetailSheetState();
}

class _LeadDetailSheetState extends State<_LeadDetailSheet> {
  Lead get lead => widget.lead;

  ScaffoldMessengerState? _snackMessenger(BuildContext context) {
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

  String _buildUrl(String rawPath) {
    const base = 'https://sales.stagingzar.com';
    final clean = rawPath.startsWith('/') ? rawPath : '/$rawPath';
    return '$base$clean';
  }

  Future<void> _previewFile(BuildContext context, String rawPath) async {
    debugPrint('=== PREVIEW DEBUG === rawPath: "$rawPath"');
    final url = _buildUrl(rawPath);
    debugPrint('=== PREVIEW URL === "$url"');
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
            ));
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(
            context,
            SnackBar(
              content: Text('Could not open file: $e'),
              backgroundColor: Colors.red,
            ));
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  // DOWNLOAD — uses file_saver so Android scoped storage is
  // respected (no direct write to public /Download).
  // SnackBars: bottom sheets use ScaffoldMessenger + Scaffold (see _openDetail).
  // ══════════════════════════════════════════════════════════
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
    debugPrint('=== DOWNLOAD URL === $url');

    final lastDot = fileName.lastIndexOf('.');
    final baseName = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    final extOnly = lastDot > 0 ? fileName.substring(lastDot + 1) : '';
    final mime = _mimeTypeForAttachmentExt(extOnly);

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
        final path = await _downloadsChannel.invokeMethod<String>(
          'saveToDownloads',
          <String, dynamic>{
            'fileName': fileName,
            'bytes': Uint8List.fromList(data),
            'mimeType': _mimeStringForAttachmentExt(extOnly),
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

      debugPrint('=== SAVE PATH === $savedPath');

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
      debugPrint('=== DIO ERROR === ${e.response?.statusCode} '
          '${e.response?.data}');
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
          ));
    } on PlatformException catch (e) {
      debugPrint('=== DOWNLOAD PLATFORM ERROR === ${e.code} ${e.message}');
      if (!context.mounted) return;
      _hideSnack(context);
      _showSnack(
          context,
          SnackBar(
            content: Text('Download failed: ${e.message ?? e.code}'),
            backgroundColor: Colors.red,
          ));
    } catch (e) {
      debugPrint('=== DOWNLOAD ERROR === $e');
      if (!context.mounted) return;
      _hideSnack(context);
      _showSnack(
          context,
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: Colors.red,
          ));
    }
  }

  @override
  Widget build(BuildContext ctx) => DefaultTabController(
        length: 2,
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                          gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent]),
                          borderRadius: BorderRadius.circular(14)),
                      child: Center(
                          child: Text(
                        lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
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
                        Text(lead.name,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text(lead.companyName,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ])),
                  StatusBadge(status: lead.status),
                ]),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: [Tab(text: 'Details'), Tab(text: 'Activity')],
                ),
              ),
              const Divider(height: 16, color: AppColors.divider),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildDetailsTab(ctrl),
                    _buildActivityTab(ctrl),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _buildDetailsTab(ScrollController ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            _row(
              Icons.phone_outlined,
              'Phone',
              lead.phone.trim().isEmpty ? '-' : _formatPhone(lead.phone),
            ),
            _row(Icons.email_outlined, 'Email', lead.email),
            if (lead.address.isNotEmpty)
              _row(Icons.location_on_outlined, 'Address', lead.address),
            _row(Icons.public_outlined, 'Country', lead.country),
            if (lead.industry.isNotEmpty)
              _row(Icons.business_outlined, 'Industry', lead.industry),
            _row(Icons.radar_outlined, 'Source',
                lead.source.isEmpty ? '-' : lead.source),
            if (lead.clientType.isNotEmpty)
              _row(Icons.corporate_fare_outlined, 'Client Type',
                  lead.clientType),
            _row(Icons.person_outline, 'Assigned To',
                lead.assignTo.trim().isEmpty ? '-' : lead.assignTo.trim()),
            if (lead.followUpDate != null)
              _row(Icons.event_outlined, 'Follow-up',
                  DateFormat('dd MMM yyyy').format(lead.followUpDate!)),
            if (lead.requirement.isNotEmpty)
              _row(Icons.list_alt_outlined, 'Requirement', lead.requirement),
            if (lead.notes.isNotEmpty)
              _row(Icons.notes_outlined, 'Notes', lead.notes),
            if (lead.attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Attachments',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              ...lead.attachments.map((a) => Builder(
                    builder: (tileCtx) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.insert_drive_file,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500)),
                                Text('${(a.size / 1024).toStringAsFixed(1)} KB',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint)),
                              ]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility,
                              size: 18, color: AppColors.primary),
                          tooltip: 'Preview',
                          onPressed: () => _previewFile(tileCtx, a.path),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download,
                              size: 18, color: AppColors.primary),
                          tooltip: 'Download',
                          onPressed: () =>
                              _downloadFile(tileCtx, a.path, a.name),
                        ),
                      ]),
                    ),
                  )),
            ],
          ]);
  String _formatPhone(String phone) {
    if (phone.trim().isEmpty) return '-';

    try {
      final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

      final parsedPhone = PhoneNumber.parse('+$cleaned');

      final countryCode = parsedPhone.countryCode;
      final nationalNumber = parsedPhone.nsn;

      return '+$countryCode $nationalNumber';
    } catch (e) {
      return phone;
    }
  }

  Widget _buildActivityTab(ScrollController ctrl) {
    final activities = <Map<String, dynamic>>[
      if (lead.createdAt != null)
        {
          'icon': Icons.add_circle_outline,
          'label': 'Lead created',
          'date': lead.createdAt!,
        },
      if (lead.updatedAt != null)
        {
          'icon': Icons.edit_calendar_outlined,
          'label': 'Lead updated',
          'date': lead.updatedAt!,
        },
      if (lead.followUpDate != null)
        {
          'icon': Icons.event_available_outlined,
          'label': 'Last Follow-Up',
          'date': lead.followUpDate!,
        },
      if (lead.lastReminderAt != null)
        {
          'icon': Icons.notifications_active_outlined,
          'label': 'Last Reminder Sent',
          'date': lead.lastReminderAt!,
        },
    ];

    if (activities.isEmpty) {
      return const Center(
        child: Text('No activity available',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

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
                Text(val,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500)),
              ])),
        ]),
      );
}

/// Narrow currency dropdown aligned with deal create/edit forms.
class _ConvertSheetCompactDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final double width;
  final void Function(String) onChanged;

  const _ConvertSheetCompactDrop({
    required this.value,
    required this.items,
    required this.width,
    required this.onChanged,
  });

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
                    value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
}

// ─── Convert Lead Sheet ───────────────────────────────────────
class _ConvertLeadSheet extends StatefulWidget {
  final Lead lead;
  const _ConvertLeadSheet({required this.lead});
  @override
  State<_ConvertLeadSheet> createState() => _ConvertLeadSheetState();
}

class _ConvertLeadSheetState extends State<_ConvertLeadSheet> {
  final _dealValue = TextEditingController();
  DateTime? _closeDate;
  String _currency = '₹ INR';
  bool _loading = false;

  @override
  void dispose() {
    _dealValue.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = double.tryParse(_dealValue.text.trim());
    if (value == null || value <= 0) {
      showApiSnack(context, 'Enter a valid deal value', isError: true);
      return;
    }
    if (_closeDate == null) {
      showApiSnack(context, 'Select expected close date', isError: true);
      return;
    }
    setState(() => _loading = true);
    final currencyCode = _currency.split(' ').last;
    final err = await context
        .read<LeadCubit>()
        .convertToDeal(widget.lead.id, value, _closeDate!, currencyCode);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      Navigator.pop(context);
    } else {
      showApiSnack(context, err, isError: true);
    }
  }

  @override
  Widget build(BuildContext ctx) => Container(
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.swap_horiz_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Convert to Deal',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text(widget.lead.name,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ])),
          ]),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Deal Value',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConvertSheetCompactDrop(
                value: _currency,
                items: DealConstants.currencies,
                width: 110,
                onChanged: (v) => setState(() => _currency = v),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _dealValue,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
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
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Expected Close Date',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final firstDate = _dateOnly(DateTime.now());
              final lastDate = firstDate.add(const Duration(days: 730));
              final initialDate = _clampPickerDate(
                firstDate,
                firstDate: firstDate,
                lastDate: lastDate,
              );

              final p = await showDatePicker(
                context: ctx,
                initialDate: initialDate,
                firstDate: firstDate,
                lastDate: lastDate,
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(
                      colorScheme:
                          const ColorScheme.light(primary: AppColors.primary)),
                  child: child!,
                ),
              );
              if (p != null) setState(() => _closeDate = p);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.event_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                    _closeDate != null
                        ? DateFormat('dd MMM yyyy').format(_closeDate!)
                        : 'Pick close date',
                    style: TextStyle(
                        fontSize: 14,
                        color: _closeDate != null
                            ? AppColors.textPrimary
                            : AppColors.textHint)),
                const Spacer(),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.swap_horiz_outlined, size: 16),
              label: Text(_loading ? 'Converting...' : 'Convert to Deal'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13)),
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// VALIDATION HELPERS
// ══════════════════════════════════════════════════════════════
class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    final capped =
        digitsOnly.length > 12 ? digitsOnly.substring(0, 12) : digitsOnly;

    return newValue.copyWith(
      text: capped,
      selection: TextSelection.collapsed(
        offset: capped.length,
      ),
    );
  }
}

String? _validateEmail(String value) {
  final v = value.trim();
  if (v.isEmpty) return 'Email required';
  final atCount = '@'.allMatches(v).length;
  if (atCount != 1) return 'Invalid email format';
  if (!RegExp(r'^[^@]+@[^@]+\.com$', caseSensitive: false).hasMatch(v)) {
    return 'Email must end with .com (e.g. name@gmail.com)';
  }
  return null;
}

String? _validatePhone(String value) {
  final v = value.trim().replaceAll(RegExp(r'[^0-9]'), '');

  if (v.isEmpty) {
    return 'Phone required';
  }

  if (v.length > 12) {
    return 'Phone number must not exceed 12 digits';
  }

  return null;
}

// ══════════════════════════════════════════════════════════════
// LEAD FORM MODAL  — CREATE + EDIT
// ══════════════════════════════════════════════════════════════
class _LeadFormModal extends StatefulWidget {
  final List<AppUser> salesUsers;
  final Lead? existingLead;
  const _LeadFormModal({required this.salesUsers, this.existingLead});
  @override
  State<_LeadFormModal> createState() => _LeadFormModalState();
}

class _LeadFormModalState extends State<_LeadFormModal> {
  String _phoneCountryCode = '+91';
  late final TextEditingController _name,
      _company,
      _phone,
      _email,
      _addr,
      _req,
      _notes;

  String? _phoneError;
  String? _emailError;

  final List<PlatformFile> _attachments = [];
  final List<Attachment> _existingAttachments = [];
  String? _country, _industry, _source;

  /// `B2B` | `B2C` | null = not chosen yet.
  String? _clientType;
  String _status = 'Hot';
  DateTime? _followUp;
  int _step = 0;
  bool _saving = false;

  String? _selectedAssignUserId;
  late final List<AppUser> _salesUsers;
  late final List<String> _countries;
  late final List<String> _industries;
  late final List<String> _sources;

  bool get _isEdit => widget.existingLead != null;

  @override
  void initState() {
    super.initState();

    _countries = AppConstants.countries.toSet().toList()..sort();
    _industries = AppConstants.industries.toSet().toList()..sort();
    _sources = AppConstants.leadSources.toSet().toList()..sort();

    final seen = <String>{};
    _salesUsers = widget.salesUsers
        .where((u) => u.id.isNotEmpty && seen.add(u.id))
        .toList();

    final l = widget.existingLead;
    _name = TextEditingController(text: l?.name);
    _company = TextEditingController(text: l?.companyName);
    _phone = TextEditingController(
      text: _extractLocalNumber(l?.phone ?? ''),
    );
    _email = TextEditingController(text: l?.email);
    _addr = TextEditingController(text: l?.address);
    _req = TextEditingController(text: l?.requirement);
    _notes = TextEditingController(text: l?.notes);

    if (l != null) {
      _existingAttachments.addAll(l.attachments);
      _country = (l.country.isNotEmpty && _countries.contains(l.country))
          ? l.country
          : null;
      _industry = (l.industry.isNotEmpty && _industries.contains(l.industry))
          ? l.industry
          : null;
      _source = (l.source.isNotEmpty && _sources.contains(l.source))
          ? l.source
          : null;
      final ct = l.clientType.trim().toUpperCase();
      _clientType = (ct == 'B2B' || ct == 'B2C') ? ct : null;
      _status = l.status;
      _followUp = l.followUpDate;

      if (l.assignTo.isNotEmpty) {
        final existing = l.assignTo.trim();
        final match = _salesUsers.where((u) => u.id == existing).firstOrNull ??
            _salesUsers
                .where(
                    (u) => u.fullName.toLowerCase() == existing.toLowerCase())
                .firstOrNull;
        _selectedAssignUserId = match?.id;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _company, _phone, _email, _addr, _req, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String _extractLocalNumber(String rawPhone) {
    try {
      final cleaned = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

      final parsed = PhoneNumber.parse('+$cleaned');

      return parsed.nsn;
    } catch (e) {
      return rawPhone;
    }
  }

  String _getInitialCountryCode(String rawPhone) {
    try {
      final cleaned = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

      final parsed = PhoneNumber.parse('+$cleaned');

      return parsed.isoCode.name;
    } catch (e) {
      return 'IN'; // safe fallback only
    }
  }

  String _fullPhoneNumber() {
    final countryCode = _phoneCountryCode.replaceAll('+', '');
    final localNumber = _phone.text.trim();

    return '$countryCode$localNumber';
  }

  Future<List<MultipartFile>> _buildMultipartFiles() async {
    final files = <MultipartFile>[];
    for (final f in _attachments) {
      try {
        if (f.bytes != null) {
          files.add(MultipartFile.fromBytes(f.bytes!, filename: f.name));
        } else if (f.path != null && f.path!.isNotEmpty) {
          files.add(await MultipartFile.fromFile(f.path!, filename: f.name));
        }
      } catch (e) {
        debugPrint('Attachment skip [${f.name}]: $e');
      }
    }
    return files;
  }

  List<String> get _retainedAttachmentPaths => _existingAttachments
      .map((a) => a.path)
      .where((p) => p.isNotEmpty)
      .toList();

  void _removeExistingAttachment(Attachment file) {
    setState(() => _existingAttachments.remove(file));
  }

  bool _validateStep0() {
    bool valid = true;
    if (_name.text.isEmpty) {
      showApiSnack(context, 'Lead name required', isError: true);
      valid = false;
    }
    if (_company.text.trim().isEmpty) {
      showApiSnack(context, 'Company name required', isError: true);
      valid = false;
    }
    final phoneErr = _validatePhone(_phone.text);
    final emailErr = _validateEmail(_email.text);
    setState(() {
      _phoneError = phoneErr;
      _emailError = emailErr;
    });
    if (phoneErr != null || emailErr != null) valid = false;
    return valid;
  }

  Future<void> _submit() async {
    final phoneErr = _validatePhone(_phone.text);
    final emailErr = _validateEmail(_email.text);
    setState(() {
      _phoneError = phoneErr;
      _emailError = emailErr;
    });
    if (_name.text.isEmpty) {
      showApiSnack(context, 'Lead name required', isError: true);
      return;
    }
    if (_company.text.trim().isEmpty) {
      showApiSnack(context, 'Company name required', isError: true);
      return;
    }
    if (phoneErr != null) {
      showApiSnack(context, phoneErr, isError: true);
      return;
    }
    if (emailErr != null) {
      showApiSnack(context, emailErr, isError: true);
      return;
    }
    setState(() => _saving = true);

    final lead = Lead(
      id: '',
      name: _name.text.trim(),
      companyName: _company.text.trim(),
      phone: _fullPhoneNumber(),
      email: _email.text.trim(),
      address: _addr.text.trim(),
      country: _country ?? '',
      industry: _industry ?? '',
      source: _source ?? '',
      clientType: _clientType!,
      requirement: _req.text.trim(),
      status: _status,
      assignTo: _selectedAssignUserId ?? '',
      followUpDate: _followUp,
      notes: _notes.text.trim(),
    );

    final cubit = context.read<LeadCubit>();
    String? err;
    final files = await _buildMultipartFiles();
    if (!mounted) return;
    if (_isEdit) {
      err = await cubit.updateLead(
        widget.existingLead!.id,
        lead,
        attachments: files,
        retainedAttachmentPaths: _retainedAttachmentPaths,
      );
    } else {
      err = await cubit.createLead(lead, attachments: files);
    }
    if (!mounted) return;

    setState(() => _saving = false);
    if (err == null) {
      Navigator.pop(context);
    } else {
      showApiSnack(context, err, isError: true);
    }
  }

  @override
  Widget build(BuildContext ctx) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Text(_isEdit ? 'Edit Lead' : 'Create Lead',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6)),
                ),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.divider,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)))),
              ]),
            ),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                  children: ['Basic', 'Business', 'Manage', 'Notes']
                      .asMap()
                      .entries
                      .map((e) {
                final i = e.key;
                final done = i < _step;
                final active = i == _step;
                return Expanded(
                    child: Row(children: [
                  Expanded(
                      child: GestureDetector(
                    onTap: () => setState(() => _step = i),
                    child: Column(children: [
                      Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: done
                                ? AppColors.success
                                : active
                                    ? AppColors.primary
                                    : AppColors.divider,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                              child: done
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 13)
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                          color: active
                                              ? Colors.white
                                              : AppColors.textHint,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)))),
                      const SizedBox(height: 3),
                      Text(e.value,
                          style: TextStyle(
                              fontSize: 9,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textHint,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w400)),
                    ]),
                  )),
                  if (i < 3)
                    Container(
                        height: 1.5,
                        width: 12,
                        color:
                            i < _step ? AppColors.success : AppColors.border),
                ]));
              }).toList()),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
                child: ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                  if (_step == 0) _basicStep(),
                  if (_step == 1) _businessStep(),
                  if (_step == 2) _manageStep(),
                  if (_step == 3) _notesStep(),
                  const SizedBox(height: 20),
                  Row(children: [
                    if (_step > 0) ...[
                      Expanded(
                          child: OutlinedButton.icon(
                        onPressed: () => setState(() => _step--),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back'),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13)),
                      )),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                        child: ElevatedButton.icon(
                      onPressed: _saving
                          ? null
                          : (_step < 3
                              ? () {
                                  if (_step == 0 && !_validateStep0()) return;
                                  if (_step == 1 &&
                                      (_clientType == null ||
                                          _clientType!.isEmpty)) {
                                    showApiSnack(
                                      context,
                                      'Please select Client Type (B2B or B2C).',
                                      isError: true,
                                    );
                                    return;
                                  }
                                  setState(() => _step++);
                                }
                              : _submit),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(
                              _step < 3
                                  ? Icons.arrow_forward
                                  : Icons.cloud_upload_outlined,
                              size: 16),
                      label: Text(_saving
                          ? 'Saving...'
                          : (_step < 3
                              ? 'Next'
                              : (_isEdit ? 'Update' : 'Save to Server'))),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                    )),
                  ]),
                  const SizedBox(height: 20),
                ])),
          ]),
        ),
      );

  Widget _basicStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
            title: 'Basic Information', icon: Icons.person_outline),
        CrmTextField(
            label: 'Lead Name',
            required: true,
            hint: 'Full name',
            controller: _name),
        const SizedBox(height: 14),
        CrmTextField(
            label: 'Company Name',
            required: true,
            hint: 'Organisation',
            controller: _company),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Phone Number ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TextSpan(
                    text: '*',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            IntlPhoneField(
              controller: _phone,
              initialCountryCode: _getInitialCountryCode(
                widget.existingLead?.phone ?? '',
              ),
              showCountryFlag: true,
              disableLengthCheck: true,
              decoration: const InputDecoration(
                hintText: '9876543210',
                border: OutlineInputBorder(),
              ),
              onChanged: (phone) {
                _phoneCountryCode = phone.countryCode;

                final err = _validatePhone(phone.number);

                if (_phoneError != err) {
                  setState(() {
                    _phoneError = err;
                  });
                }
              },
            ),
            if (_phoneError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  _phoneError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.danger,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            CrmTextField(
              label: 'Email',
              required: true,
              hint: 'name@gmail.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) {
                final err = _validateEmail(v);
                if (_emailError != err) {
                  setState(() => _emailError = err);
                }
              },
            ),
            if (_emailError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  _emailError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.danger,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        CrmTextField(
            label: 'Address',
            hint: 'Street, City',
            controller: _addr,
            maxLines: 2),
        const SizedBox(height: 14),
        CrmDropdown(
            label: 'Country',
            value: _country,
            items: _countries,
            hint: 'Select Country',
            onChanged: (v) => setState(() => _country = v)),
      ]);

  Widget _businessStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
            title: 'Business Details', icon: Icons.business_outlined),
        CrmDropdown(
            label: 'Industry',
            value: _industry,
            items: _industries,
            hint: 'Select Industry',
            onChanged: (v) => setState(() => _industry = v)),
        const SizedBox(height: 14),
        CrmDropdown(
            label: 'Source',
            value: _source,
            items: _sources,
            hint: 'Select Source',
            onChanged: (v) => setState(() => _source = v)),
        const SizedBox(height: 14),
        CrmDropdown(
            label: 'Client Type',
            value: _clientType,
            items: const ['B2B', 'B2C'],
            hint: 'Client Type',
            onChanged: (v) => setState(() => _clientType = v)),
        const SizedBox(height: 14),
        CrmTextField(
            label: 'Requirement',
            hint: 'What is the lead looking for?',
            controller: _req,
            maxLines: 4),
      ]);

  Widget _manageStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
            title: 'Lead Management', icon: Icons.tune_outlined),
        const Text('Status',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.leadStatuses.map((s) {
              final sel = _status == s;
              return GestureDetector(
                onTap: () => setState(() => _status = s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(s,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.textSecondary)),
                ),
              );
            }).toList()),
        const SizedBox(height: 16),
        const Text('Assign To',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        if (_salesUsers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(children: [
              Icon(Icons.person_search_outlined,
                  size: 16, color: AppColors.textHint),
              SizedBox(width: 10),
              Text('No sales reps available',
                  style: TextStyle(fontSize: 14, color: AppColors.textHint)),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _salesUsers.any((u) => u.id == _selectedAssignUserId)
                    ? _selectedAssignUserId
                    : null,
                isExpanded: true,
                hint: const Row(children: [
                  Icon(Icons.person_search_outlined,
                      size: 16, color: AppColors.textHint),
                  SizedBox(width: 8),
                  Text('Select Sales Rep',
                      style:
                          TextStyle(fontSize: 14, color: AppColors.textHint)),
                ]),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                items: _salesUsers
                    .map((u) => DropdownMenuItem<String>(
                          value: u.id,
                          child: Row(children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                u.fullName.isNotEmpty
                                    ? u.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(u.fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary)),
                            ),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedAssignUserId = v),
              ),
            ),
          ),
        const SizedBox(height: 14),
        const Text('Follow-up Date',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final firstDate = _dateOnly(DateTime.now());
            final lastDate = firstDate.add(const Duration(days: 730));
            final initialDate = _clampPickerDate(
              _followUp ?? firstDate.add(const Duration(days: 3)),
              firstDate: firstDate,
              lastDate: lastDate,
            );

            final p = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: lastDate,
              builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                      colorScheme:
                          const ColorScheme.light(primary: AppColors.primary)),
                  child: child!),
            );
            if (p != null) setState(() => _followUp = p);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.event_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                  _followUp != null
                      ? DateFormat('dd MMM yyyy').format(_followUp!)
                      : 'Pick a date',
                  style: TextStyle(
                      fontSize: 14,
                      color: _followUp != null
                          ? AppColors.textPrimary
                          : AppColors.textHint)),
              const Spacer(),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary),
            ]),
          ),
        ),
      ]);

  Widget _notesStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(
            title: 'Additional Notes', icon: Icons.notes_outlined),
        CrmTextField(
            label: 'Notes',
            hint: 'Context, observations...',
            controller: _notes,
            maxLines: 6),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.attach_file, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text('Attachments',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              SizedBox(width: 6),
              Text('(max 5 MB each)',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Files'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            if (_isEdit && _existingAttachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Current attachments',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ..._existingAttachments.map((file) {
                final sizeKB = (file.size / 1024).toStringAsFixed(1);
                final ext = file.name.contains('.')
                    ? file.name.split('.').last.toLowerCase()
                    : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: Icon(_fileIcon(ext),
                          size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary)),
                            Text('$sizeKB KB',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textHint)),
                          ]),
                    ),
                    GestureDetector(
                      onTap: () => _removeExistingAttachment(file),
                      child: const Icon(Icons.close,
                          size: 18, color: AppColors.danger),
                    ),
                  ]),
                );
              }),
            ],
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (_isEdit)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('New attachments',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
              ..._attachments.map((file) {
                final sizeKB = (file.size / 1024).toStringAsFixed(1);
                final ext = file.name.split('.').last.toLowerCase();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: Icon(_fileIcon(ext),
                          size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary)),
                            Text('$sizeKB KB',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textHint)),
                          ]),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _attachments.remove(file)),
                      child: const Icon(Icons.close,
                          size: 18, color: AppColors.danger),
                    ),
                  ]),
                );
              }),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.summarize_outlined,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text('Summary',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ]),
            const SizedBox(height: 10),
            ...[
              ['Name', _name.text.isEmpty ? '-' : _name.text],
              ['Company', _company.text.isEmpty ? '-' : _company.text],
              ['Phone', _phone.text.isEmpty ? '-' : _phone.text],
              ['Country', _country ?? '-'],
              ['Source', _source ?? '-'],
              ['Client Type', _clientType ?? '-'],
              ['Status', _status],
              if (_isEdit)
                [
                  'Files',
                  '${_existingAttachments.length} existing, ${_attachments.length} new'
                ],
              if (!_isEdit && _attachments.isNotEmpty)
                ['Files', '${_attachments.length} attached'],
            ].map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(children: [
                    SizedBox(
                        width: 70,
                        child: Text(r[0],
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary))),
                    const Text(': ',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textHint)),
                    Expanded(
                        child: Text(r[1],
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary))),
                  ]),
                )),
          ]),
        ),
      ]);

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      final sizeMB = file.size / (1024 * 1024);
      if (sizeMB > 5) {
        if (mounted) {
          showApiSnack(context, '${file.name} exceeds 5 MB limit',
              isError: true);
        }
        continue;
      }
      final duplicateInExisting =
          _existingAttachments.any((a) => a.name == file.name);
      if (_attachments.any((a) => a.name == file.name) || duplicateInExisting) {
        continue;
      }
      setState(() => _attachments.add(file));
    }
  }

  IconData _fileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return Icons.image_outlined;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
