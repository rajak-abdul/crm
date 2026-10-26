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
import 'dart:async';
import 'dart:io';
import 'package:crm_app/modals/modals.dart'
    show
        AppConstants,
        Lead,
        AppUser,
        Attachment,
        CustomField,
        LeadActivity,
        LeadNote;
import 'package:crm_app/screen/leads/cubit/call_cubit.dart';
import 'package:crm_app/screen/leads/cubit/lead_cubit.dart';
import 'package:crm_app/screen/leads/ui/lead.dart';
import 'package:crm_app/shareWidgets/actitvity_timeline_ui.dart';
import 'package:crm_app/shareWidgets/contact_actions.dart';
import 'package:crm_app/shareWidgets/linked_work_index.dart';
import 'package:crm_app/shareWidgets/linked_work_tab.dart';
import 'package:crm_app/shareWidgets/record_emails_tab.dart';
import 'package:crm_app/screen/leads/ui/meeting.dart';
import 'package:crm_app/screen/leads/ui/reject_lead_screen.dart';
import 'package:crm_app/screen/leads/ui/convert_lead_dialog.dart';
import 'package:crm_app/screen/leads/ui/status_reason_sheet.dart';
import 'package:crm_app/screen/meeting/UI/meeting.dart';
import 'package:crm_app/screen/meeting/cubit/meeting_cubit.dart';
import 'package:crm_app/screen/meeting/cubit/meeting_state.dart';
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
import 'package:crm_app/utils/data_sync.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final String? selectedLeadId;
  final bool showBackButton;
  final VoidCallback? onLeadOpened;

  /// Set only when this is the bottom-nav Leads tab: enables silent
  /// refresh when stale / changed (TabRefreshScope). Null when pushed.
  final int? tabIndex;

  const LeadsScreen({
  super.key,
  this.selectedLeadId,
  this.showBackButton = false,
  this.onLeadOpened,
  this.tabIndex,
});
  @override
  Widget build(BuildContext context) => MultiBlocProvider(

        providers: [
          BlocProvider(
            create: (_) => LeadCubit()..fetchAllLeads(),
          ),
          BlocProvider(
            create: (_) => CallCubit(),
          ),
        ],
        child: _LeadsView(
          selectedLeadId: selectedLeadId,
          showBackButton: showBackButton,
          onLeadOpened: onLeadOpened,
          tabIndex: tabIndex,
        ),
      );
}

class _LeadsView extends StatefulWidget {
    final String? selectedLeadId;
    final bool showBackButton;
    final VoidCallback? onLeadOpened;
    final int? tabIndex;

const _LeadsView({
    super.key,
    this.selectedLeadId,
    required this.showBackButton,
    this.onLeadOpened,
    this.tabIndex,
  });
 @override
  State<_LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends State<_LeadsView> {

  String? _autoOpenedLeadId;
  final TextEditingController _searchController = TextEditingController();
  String _search = '',
      _statusFilter = 'All Status',
      _sourceFilter = 'All Sources',
      _clientTypeFilter = 'All Client Types';
  String _assigneeFilter = 'All Assignees';
  String _followupFilter = 'All Follow-ups';
   final List<String> _followupItems = [
  'All Follow-ups',
  'Today Follow-ups',
  'Missed Follow-ups',
  'Completed Follow-ups',
];
  bool _showRejectedOnly = false;

  // "Tasks" filter — leads with an open linked task / running target.
  static const _linkedAll = 'All Linked Work';
  static const _linkedTasks = 'Active Tasks';
  static const _linkedTargets = 'Active Targets';
  String _linkedFilter = _linkedAll;

  /// Only the options the role can see (assigned_tasks / my_targets).
  List<String> get _linkedItems => [
        _linkedAll,
        if (PermissionHelper.can('assigned_tasks')) _linkedTasks,
        if (PermissionHelper.can('my_targets')) _linkedTargets,
      ];

  /// Re-filter when the task/target lookup changes while this filter is on.
  void _onLinkedWorkChanged() {
    if (mounted && _linkedFilter != _linkedAll) _loadLinkedLeads();
  }

  // Linked mode (Active Tasks / Active Targets): the matching leads can sit
  // on any server page, so they're loaded by id, then filtered and paged
  // here — the count and pagination follow the filtered result.
  final Map<String, Lead> _linkedCache = {};
  bool _linkedLoading = false;
  String? _linkedError;
  int _linkedPage = 1;

  bool get _linkedMode => _linkedFilter != _linkedAll;

  Set<String> get _linkedIds => LinkedWorkIndex.notifier.value.activeIds(
        LinkedWorkKind.lead,
        tasks: _linkedFilter == _linkedTasks,
      );

  /// Loads any matching leads not cached yet. [reload] refetches them all.
  Future<void> _loadLinkedLeads({bool reload = false}) async {
    if (!_linkedMode) return;
    if (reload) _linkedCache.clear();
    final missing =
        _linkedIds.where((id) => !_linkedCache.containsKey(id)).toList();
    if (missing.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    setState(() {
      _linkedLoading = true;
      _linkedError = null;
    });
    try {
      final leads = await context.read<LeadCubit>().fetchLeadsByIds(missing);
      if (!mounted) return;
      setState(() {
        for (final l in leads) {
          _linkedCache[l.id] = l;
        }
        _linkedLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _linkedLoading = false;
        _linkedError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Pull-to-refresh in linked mode: fresh tasks/targets, then fresh leads.
  Future<void> _refreshLinked() async {
    await LinkedWorkIndex.refresh();
    await _loadLinkedLeads(reload: true);
  }

  void _setLinkedFilter(String v) {
    setState(() {
      _linkedFilter = v;
      _linkedPage = 1;
    });
    if (v != _linkedAll) {
      // Current tasks/targets first, then the leads they point at.
      LinkedWorkIndex.refresh().then((_) => _loadLinkedLeads());
      _loadLinkedLeads();
    }
  }

  final TextEditingController reasonController = TextEditingController();

  final Map<String, String> _assigneeIdToName = {};
  List<String> _assigneeDropdownItems = ['All Assignees'];

  int _currentPage = 1;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
DateTime? _fromDate;
DateTime? _toDate;
  @override
  void initState() {
    super.initState();
    _loadAssignees();
    LinkedWorkIndex.refresh(); // task/target icons on the cards
    LinkedWorkIndex.notifier.addListener(_onLinkedWorkChanged);
  }

  @override
  void dispose() {
    LinkedWorkIndex.notifier.removeListener(_onLinkedWorkChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignees() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final tenantSlug = prefs.getString('tenant_slug') ?? '';
    if (token.isEmpty || tenantSlug.isEmpty) return;

    final dio = Dio(BaseOptions(
      baseUrl: 'https://crm-backend-api.techzarinfo.cloud/$tenantSlug/api',
    ));
    final res = await dio.get(
      '/users',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    debugPrint("Assignees response: ${res.data}");

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
  } catch (e, s) {
    debugPrint("LOAD ASSIGNEES ERROR: $e");
    debugPrint("$s");
  }
}
  List<Lead> _filter(List<Lead> all) {
  if (all.isEmpty) return all;
  final q = _search.toLowerCase();
  return all.where((l) {
    final phone = l.phone.replaceAll(RegExp(r'[^0-9+]'), '').toLowerCase();
    final localPhone = l.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final searchQuery = q.replaceAll(RegExp(r'[^0-9+]'), '');

    final matchesPhone = searchQuery.isNotEmpty &&
        (phone.contains(searchQuery) ||
            localPhone.contains(searchQuery.replaceAll('+', '')));

    final matchesSearch = _search.isEmpty ||
        l.name.toLowerCase().contains(q) ||
        l.email.toLowerCase().contains(q) ||
        matchesPhone;

    final matchesStatus =
        _statusFilter == 'All Status' || l.status == _statusFilter;
    final matchesSource =
        _sourceFilter == 'All Sources' || l.source == _sourceFilter;
    final matchesClientType = _clientTypeFilter == 'All Client Types' ||
        (l.clientType.isNotEmpty && l.clientType == _clientTypeFilter);
    final matchesAssignee = _assigneeFilter == 'All Assignees' ||
        (l.assignedToId != null && l.assignedToId == _assigneeFilter) ||
        l.assignTo.trim() == _assigneeFilter;
      final today = DateTime.now();
final todayOnly = DateTime(today.year, today.month, today.day);

final followupDate = l.followUpDate == null
    ? null
    : DateTime(
        l.followUpDate!.year,
        l.followUpDate!.month,
        l.followUpDate!.day,
      );
final matchesDate =
    (_fromDate == null || (followupDate != null && !followupDate.isBefore(_fromDate!))) &&
    (_toDate == null || (followupDate != null && !followupDate.isAfter(_toDate!)));

final status = l.status.trim().toLowerCase();

final hasCompletedFollowup =
    l.followUpNotes.isNotEmpty;

final isTodayFollowup =
    followupDate != null &&
    followupDate == todayOnly &&
    status != "converted" &&
    status != "rejected";

final isMissedFollowup =
    followupDate != null &&
    followupDate.isBefore(todayOnly) &&
    l.followUpNotes.isEmpty &&
    status != "converted";
    final matchesFollowup =
    _followupFilter == 'All Follow-ups' ||

    (_followupFilter == 'Today Follow-ups' &&
        isTodayFollowup) ||

    (_followupFilter == 'Missed Follow-ups' &&
        isMissedFollowup) ||

    (_followupFilter == 'Completed Follow-ups' &&
        hasCompletedFollowup);
    //     final isRejected =
    // l.status.trim().toLowerCase().contains('Rejected');
debugPrint(
  "${l.name} | "
  "assignedToId=${l.assignedToId} | "
  "assignTo=${l.assignTo} | "
  "selected=$_assigneeFilter",
);    

    final linked = LinkedWorkIndex.notifier.value;
    final matchesLinked = _linkedFilter == _linkedAll ||
        (_linkedFilter == _linkedTasks &&
            linked.hasActiveTask(LinkedWorkKind.lead, l.id)) ||
        (_linkedFilter == _linkedTargets &&
            linked.hasActiveTarget(LinkedWorkKind.lead, l.id));

    return matchesSearch &&
    matchesStatus &&
    matchesSource &&
    matchesClientType &&
    matchesAssignee &&
    matchesFollowup &&
    matchesLinked &&
    matchesDate;
        
        
        
  }).toList();
}

  int _totalPages(LeadState state) {
    if (state is! LeadLoaded) return 1;
    if (state.totalCount != null) {
      return (state.totalCount! / _kPageSize).ceil().clamp(1, 99999);
    }
   
    return state.leads.length < _kPageSize ? _currentPage : _currentPage + 1;
  }

  Future<void> _goToPage(int page) async {
    setState(() => _currentPage = page);
    await context.read<LeadCubit>().fetchAllLeads(page: page, limit: _kPageSize);
  }

  void _resetPage() {
    if (_currentPage != 1) {
      setState(() => _currentPage = 1);
      context.read<LeadCubit>().fetchAllLeads(page: 1, limit: _kPageSize);
    }
  }

  bool get _hasActiveFilters =>
      _statusFilter != 'All Status' ||
      _sourceFilter != 'All Sources' ||
      _clientTypeFilter != 'All Client Types' ||
      _assigneeFilter != 'All Assignees' ||
      _followupFilter != 'All Follow-ups' ||
      _linkedFilter != _linkedAll ||
      _fromDate != null ||
      _toDate != null;

  Future<void> _clearAllFilters() async {
    setState(() {
      _statusFilter = 'All Status';
      _sourceFilter = 'All Sources';
      _clientTypeFilter = 'All Client Types';
      _assigneeFilter = 'All Assignees';
      _followupFilter = 'All Follow-ups';
      _linkedFilter = _linkedAll;
      _linkedPage = 1;
      _fromDate = null;
      _toDate = null;
      _resetPage();
    });
    await context.read<LeadCubit>().fetchAllLeads();
  }

  void _showFilterSheet() {
    final leadCubit = context.read<LeadCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        // Draggable so a swipe down anywhere on the sheet (when scrolled
        // to the top) slides it down and closes it.
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => StatefulBuilder(
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
                  controller: scrollCtrl,
                  // Content may fit without scrolling — still take the
                  // drag so a swipe down moves the sheet.
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.filter_alt, color: AppColors.primary),
                          SizedBox(width: 12),
                          Text(
                            "Filters",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Status",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      _FilterDrop(
                        value: _statusFilter,
                        items: const [
                          'All Status',
                          ...AppConstants.leadStatuses,
                        ],
                        icon: Icons.flag_outlined,
                        onChanged: (v) {
                          setSheetState(() => _statusFilter = v!);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Source",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      _FilterDrop(
                        value: _sourceFilter,
                        items: const [
                          'All Sources',
                          ...AppConstants.leadSources,
                        ],
                        icon: Icons.radar_outlined,
                        onChanged: (v) {
                          setSheetState(() => _sourceFilter = v!);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Client Type",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      _FilterDrop(
                        value: _clientTypeFilter,
                        items: const [
                          'All Client Types',
                          'B2B',
                          'B2C',
                        ],
                        icon: Icons.business_outlined,
                        onChanged: (v) {
                          setSheetState(() => _clientTypeFilter = v!);
                          setState(() {});
                        },
                      ),
                      if (PermissionHelper.can('users_roles')) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Assignee",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        _FilterDrop(
                          value: _assigneeFilter,
                          items: _assigneeDropdownItems,
                          icon: Icons.person_outline,
                          labelBuilder: (value) {
                            if (value == 'All Assignees') {
                              return value;
                            }
                            return _assigneeIdToName[value] ?? value;
                          },
                          onChanged: (v) {
                            setSheetState(() => _assigneeFilter = v!);
                            setState(() {});
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        "Follow-up",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _FilterDrop(
                              value: _followupFilter,
                              items: _followupItems,
                              icon: Icons.event_available_outlined,
                              onChanged: (value) async {
                                if (value == null) return;
                                setSheetState(() => _followupFilter = value);
                                setState(() {});
                                await leadCubit.fetchAllLeads();
                              },
                            ),
                          ),
                          if (_followupFilter != 'All Follow-ups')
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () async {
                                setSheetState(
                                    () => _followupFilter = 'All Follow-ups');
                                setState(() {});
                                await leadCubit.fetchAllLeads();
                              },
                            ),
                        ],
                      ),
                      // Tasks: leads with an open linked task / target.
                      if (_linkedItems.length > 1) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Tasks",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        _FilterDrop(
                          value: _linkedItems.contains(_linkedFilter)
                              ? _linkedFilter
                              : _linkedAll,
                          items: _linkedItems,
                          icon: Icons.task_alt_outlined,
                          onChanged: (v) {
                            if (v == null) return;
                            setSheetState(() {});
                            _setLinkedFilter(v);
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        "From Date",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2100),
                            initialDate: _fromDate ?? DateTime.now(),
                          );

                          if (date != null) {
                            setSheetState(() => _fromDate = date);
                            setState(() {});
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.calendar_today),
                            suffixIcon: _fromDate == null
                                ? null
                                : IconButton(
                                    tooltip: 'Clear',
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setSheetState(() => _fromDate = null);
                                      setState(() {});
                                    },
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                          child: Text(
                            _fromDate == null
                                ? "From Date"
                                : "${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}",
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "To Date",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2100),
                            initialDate: _toDate ?? DateTime.now(),
                          );

                          if (date != null) {
                            setSheetState(() => _toDate = date);
                            setState(() {});
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.calendar_today),
                            suffixIcon: _toDate == null
                                ? null
                                : IconButton(
                                    tooltip: 'Clear',
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setSheetState(() => _toDate = null);
                                      setState(() {});
                                    },
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                          child: Text(
                            _toDate == null
                                ? "To Date"
                                : "${_toDate!.day}/${_toDate!.month}/${_toDate!.year}",
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _statusFilter = 'All Status';
                                  _sourceFilter = 'All Sources';
                                  _clientTypeFilter = 'All Client Types';
                                  _assigneeFilter = 'All Assignees';
                                  _followupFilter = 'All Follow-ups';
                                  _linkedFilter = _linkedAll;
                                  _linkedPage = 1;
                                  _fromDate = null;
                                  _toDate = null;
                                  _resetPage();
                                });
                                Navigator.pop(context);
                              },
                              child: const Text("Reset"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                _resetPage();
                                await leadCubit.fetchAllLeads();
                                if (mounted) {
                                  Navigator.pop(context);
                                }
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) =>
      // Bottom-nav tab only: silent reload of the current page when you
      // come back after 2+ min, or after leads changed elsewhere.
      TabRefreshScope<LeadCubit, LeadState>(
        area: SyncArea.leads,
        tabIndex: widget.tabIndex,
        isLoaded: (s) => s is LeadLoaded,
        onRefresh: () => context.read<LeadCubit>().fetchAllLeads(
              page: _currentPage,
              limit: _kPageSize,
              silent: true,
            ),
        child: Builder(builder: _buildLeads),
      );

  Widget _buildLeads(BuildContext context) {
    return BlocConsumer<LeadCubit, LeadState>(
      listener: (ctx, state) {
        if (state is LeadActionSuccess) showApiSnack(ctx, state.message);
        if (state is LeadError && _isSessionExpiredMessage(state.message)) {
          Navigator.of(ctx, rootNavigator: true)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      builder: (context, state) {
        final allFiltered = state is LeadLoaded ? _filter(state.leads) : <Lead>[];

      if (state is LeadLoaded &&
    widget.selectedLeadId != null &&
    _autoOpenedLeadId != widget.selectedLeadId) {
  _autoOpenedLeadId = widget.selectedLeadId;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;
    try {
      final leadCubit = context.read<LeadCubit>();
      final lead = await leadCubit.fetchLeadById(widget.selectedLeadId!);
      if (!mounted) return;
      if (lead != null) {
  openDetail(context, lead);

  widget.onLeadOpened?.call();
}
    } catch (e, st) {
      debugPrint('EXCEPTION IN AUTO-OPEN: $e');
      debugPrint('$st');
    }
  });
}
        // Normal: the server gives one page, filtered here.
        // Linked mode: every matching lead (any page), filtered + paged here.
        final List<Lead> filtered;
        final List<Lead> leads;
        final int allCount;
        final int totalPages;
        final int page;
        if (_linkedMode) {
          filtered = _filter([
            for (final id in _linkedIds)
              if (_linkedCache[id] != null) _linkedCache[id]!,
          ])
            ..sort((a, b) => (b.createdAt ?? DateTime(0))
                .compareTo(a.createdAt ?? DateTime(0)));
          allCount = filtered.length;
          totalPages = (allCount / _kPageSize).ceil().clamp(1, 99999);
          page = _linkedPage.clamp(1, totalPages);
          leads = filtered.sublist(
            (page - 1) * _kPageSize,
            (page * _kPageSize).clamp(0, allCount),
          );
        } else {
          filtered = allFiltered;
          leads = allFiltered; // server already gave us one page
          allCount = state is LeadLoaded
              ? (state.totalCount ?? state.leads.length)
              : 0;
          totalPages = _totalPages(state);
          page = _currentPage;
        }

        return Scaffold(
            key: _scaffoldKey,
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: widget.showBackButton,
leading: widget.showBackButton
    ? IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      )
    : null,
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
                  
//                 TextField(
//                       controller: _searchController,
//                       onChanged: (value) {
//   setState(() {
//     _search = value.trim().toLowerCase();
//     _resetPage();
//   });
// },
//                       decoration: InputDecoration(
//                         hintText: 'Search leads...',
//                         prefixIcon: const Icon(Icons.search,
//                             color: AppColors.textSecondary, size: 20),
//                         suffixIcon: _search.isNotEmpty
//                             ? IconButton(
//                                 icon: const Icon(Icons.clear, size: 18),
//                                 onPressed: () {
//   _searchController.clear();
//   setState(() {
//     _search = '';
//     _resetPage();
//   });
// },)
//                             : null,
//                         filled: true,
//                         fillColor: AppColors.background,
//                         contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 14, vertical: 12),
//                         border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide:
//                                 const BorderSide(color: AppColors.border)),
//                         enabledBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide:
//                                 const BorderSide(color: AppColors.border)),
//                         focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: const BorderSide(
//                                 color: AppColors.primary, width: 1.5)),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
                Row(
  children: [

    Expanded(
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _search = value;
            _resetPage();
          });
        },
        decoration: const InputDecoration(
          hintText: "Search Leads",
          prefixIcon: Icon(Icons.search),
        ),
      ),
    ),

    const SizedBox(width: 8),

    IconButton(
      tooltip: _hasActiveFilters ? 'Clear filters' : 'Filters',
      icon: Icon(
        _hasActiveFilters
            ? Icons.filter_alt_off_outlined
            : Icons.filter_alt_outlined,
      ),
      onPressed: _hasActiveFilters ? _clearAllFilters : _showFilterSheet,
    ),
    PopupMenuButton<String>(
      color: AppColors.surface,
  onSelected: (value) async {
    switch (value) {
      case "reject":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<LeadCubit>(),
              child: const RejectedLeadsScreen(),
            ),
          ),
        );
        break;

      case "template":
        _downloadTemplate(context);
        break;

      case "import":
        _pickAndImportLeads(context);
        break;

      case "export":
  showExportLeadsDialog(
    context,
    context.read<LeadCubit>(),
  );
  break;

  case "export_followups":
       showExportFollowUpsDialog(
    context,
    context.read<LeadCubit>(),
  );
      break;
    }
  },
  
  itemBuilder: (_) => [
    const PopupMenuItem<String>(
      value: 'import',
      child: Row(
        children: [
          Icon(Icons.upload_file_outlined, size: 18, color: AppColors.primary),
          SizedBox(width: 12),
          Text('Import Leads'),
        ],
      ),
    ),
    const PopupMenuDivider(),

    const PopupMenuItem<String>(
    value: 'export_followups',
    child: Row(children: [
      Icon(Icons.event_note_outlined, size: 18, color: AppColors.primary),
      SizedBox(width: 12),
      Text('Export Follow-ups'),
    ]),
  ),
  const PopupMenuDivider(),

    const PopupMenuItem<String>(
      value: 'export',
      child: Row(
        children: [
          Icon(Icons.download_outlined, size: 18, color: AppColors.primary),
          SizedBox(width: 12),
          Text('Export Leads'),
        ],
      ),
    ),
        const PopupMenuDivider(),

    const PopupMenuItem<String>(
      value: 'template',
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 18),
          SizedBox(width: 12),
          Text('Download Template'),
        ],
      ),
    ),
    if (PermissionHelper.can('users_roles')) ...[
  const PopupMenuDivider(),
  const PopupMenuItem<String>(
    value: 'reject',
    child: Row(
      children: [
        Icon(Icons.block, size: 18, color: AppColors.danger),
        SizedBox(width: 12),
        Text('Rejected Leads', style: TextStyle(color: AppColors.danger)),
      ],
    ),
  ),
],
  ],
),
  ],
),
                const SizedBox(height: 10),
                // stoppped
              ]),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Text(
                    '${filtered.length} lead${filtered.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                if (_statusFilter != 'All Status' ||
                    _sourceFilter != 'All Sources' ||
                    _clientTypeFilter != 'All Client Types' ||
                    _assigneeFilter != 'All Assignees' ||
                    _linkedFilter != _linkedAll) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _statusFilter = 'All Status';
                      _sourceFilter = 'All Sources';
                      _clientTypeFilter = 'All Client Types';
                      _assigneeFilter = 'All Assignees';
                      _linkedFilter = _linkedAll;
                      _linkedPage = 1;
                      _showRejectedOnly = false;
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
                child: _linkedMode
                    ? _buildList(
                        context,
                        state,
                        leads,
                        filtered.length,
                        linkedLoading: _linkedLoading && leads.isEmpty,
                        linkedError: leads.isEmpty ? _linkedError : null,
                      )
                    : _buildList(context, state, leads, filtered.length)),
            if ((_linkedMode || state is LeadLoaded) && filtered.isNotEmpty)
  _PaginationBar(
    page: page,
    totalPages: totalPages,
    totalItems: allCount,
    pageSize: _kPageSize,
    // Linked mode pages locally; normal mode asks the server.
    onPrev: page > 1
        ? () => _linkedMode
            ? setState(() => _linkedPage = page - 1)
            : _goToPage(page - 1)
        : null,
    onNext: page < totalPages
        ? () => _linkedMode
            ? setState(() => _linkedPage = page + 1)
            : _goToPage(page + 1)
        : null,
  ),
          ]),
          
      // create_lead: true → enabled, false → shown but disabled.
      floatingActionButton:Padding(
        padding: const EdgeInsets.only(bottom: 60), // Move FAB up
        child: Opacity(
          opacity: PermissionHelper.can('create_lead') ? 1 : 0.45,
          child: FloatingActionButton(
            onPressed: PermissionHelper.can('create_lead')
                ? () => _openCreate(context)
                : null,
            tooltip: PermissionHelper.can('create_lead')
                ? 'Create Lead'
                : 'You don\'t have permission to create leads',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      )
    
        );
      },
    );
    
  }
Future<void> showExportLeadsDialog(BuildContext context,LeadCubit leadCubit) async {
  DateTime? startDate;
  DateTime? endDate;
  bool exporting = false;
  String? dateError;
  final screenContext = context;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            title: Row(
              children: [
                const Icon(
                  Icons.download,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Export Leads",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                )
              ],
            ),
            content: SizedBox(
              width: 330,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Leave both dates blank to export all leads, or pick a start and end date to export leads created in that range.",
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Start Date",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),

                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2100),
                        initialDate: startDate ?? DateTime.now(),
                      );

                      if (picked != null) {
                        setState(() {
                          startDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        startDate == null
                            ? "Select Start Date"
                            : DateFormat("dd/MM/yyyy").format(startDate!),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    "End Date",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),

                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2100),
                        initialDate: endDate ?? DateTime.now(),
                      );

                      if (picked != null) {
                        setState(() {
                          endDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        endDate == null
                            ? "Select End Date"
                            : DateFormat("dd/MM/yyyy").format(endDate!),
                      ),
                    ),
                  ),
                  if (dateError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dateError!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: exporting ? null : () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download, color: Colors.white),
                label: Text(exporting ? "Exporting..." : "Export"),
                onPressed: exporting
                    ? null
                    : () async {
                        if ((startDate == null) != (endDate == null)) {
                          setState(() => dateError =
                              'Please select both start and end date');
                          return;
                        }
                        if (startDate != null &&
                            endDate != null &&
                            startDate!.isAfter(endDate!)) {
                          setState(() => dateError =
                              'Start date must be before end date');
                          return;
                        }
                        setState(() {
                          dateError = null;
                          exporting = true;
                        });
                        final err = await leadCubit.exportLeads(
                          startDate: startDate,
                          endDate: endDate,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (screenContext.mounted) {
                          showApiSnack(
                            screenContext,
                            err ?? 'Leads exported to Downloads',
                            isError: err != null,
                          );
                        }
                      },
              )
            ],
          );
        },
      );
    },
  );
}

Future<void> _downloadTemplate(BuildContext context) async {
  final leadCubit = context.read<LeadCubit>();
  final error = await leadCubit.downloadLeadTemplate();
  if (!context.mounted) return;
  showApiSnack(
    context,
    error != null
        ? 'Failed to download template: $error'
        : 'Template downloaded',
    isError: error != null,
  );
}

Future<void> _pickAndImportLeads(BuildContext context) async {
  final leadCubit = context.read<LeadCubit>();

  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
    withData: true,
  );
  final file = picked?.files.first;
  if (file == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final r = await leadCubit.importLeadsFromFile(file);
    debugPrint('=== IMPORT ===: success=${r.successCount} failed=${r.failedCount}');
    r.errors.forEach(debugPrint);
    if (!context.mounted) return;
    Navigator.pop(context);
    showApiSnack(context, 'Imported ${r.successCount}, failed ${r.failedCount}',
        isError: r.failedCount > 0);
  } catch (e) {
    debugPrint('=== IMPORT ERROR ===: $e');
    if (!context.mounted) return;
    Navigator.pop(context);
    showApiSnack(context, 'Import failed: $e', isError: true);
  }
}
  Widget _buildList(
      BuildContext context, LeadState state, List<Lead> leads, int total,
      {bool linkedLoading = false, String? linkedError}) {
    if (_linkedMode) {
      if (linkedLoading) {
        return const LoadingState(message: 'Fetching linked leads...');
      }
      if (linkedError != null) {
        return ErrorState(
            message: linkedError, onRetry: () => _loadLinkedLeads());
      }
      if (leads.isEmpty) {
        return EmptyState(
            message: _linkedFilter == _linkedTasks
                ? 'No leads with active tasks'
                : 'No leads with active targets',
            icon: Icons.task_alt_outlined);
      }
    } else {
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
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _linkedMode
          ? _refreshLinked()
          : Future.wait([
              context.read<LeadCubit>().fetchAllLeads(page: _currentPage, limit: _kPageSize), // CHANGED
              LinkedWorkIndex.refresh(),
            ]),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: leads.length,
        itemBuilder: (_, i) => _LeadCard(
          lead: leads[i],
          onTap: () => openDetail(context, leads[i]),
          onEdit: () => _openEdit(context, leads[i]),
          onReject: () => _confirmReject(context, leads[i].id),
          onStatusChange: (s) =>
              context.read<LeadCubit>().updateStatus(leads[i].id, s),
          onAddFollowUp: () => showAddFollowUpDialog(context, leads[i]),
          onConvert: () => _openConvert(context, leads[i]),
        ),
      ),
    );
  }
  
Future<void> showAddFollowUpDialog(
  BuildContext context,
  Lead lead,
) async {
  final notesController = TextEditingController();
  final leadCubit = context.read<LeadCubit>(); // capture before dialog opens
  bool saving = false;
  PlatformFile? selectedAudio;
bool uploadingAudio = false;

  await showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "Add Follow-up",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black),
                children: [
                  const TextSpan(
                    text: "Lead: ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: lead.name),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Notes *",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),

const Text(
  "Audio (Optional)",
  style: TextStyle(
    fontWeight: FontWeight.w600,
  ),
),

const SizedBox(height: 8),

Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  ),
  
  child: Row(
  children: [
    const Icon(
      Icons.audiotrack,
      color: AppColors.primary,
    ),
    const SizedBox(width: 10),

    Expanded(
      child: Text(
        selectedAudio?.name ?? "No audio selected",
        overflow: TextOverflow.ellipsis,
      ),
    ),

    if (selectedAudio != null)
      IconButton(
        tooltip: "Remove audio",
        icon: const Icon(
          Icons.close,
          color: Colors.red,
          size: 20,
        ),
        onPressed: saving
            ? null
            : () {
                setDialogState(() {
                  selectedAudio = null;
                });
              },
      ),

    InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: saving
          ? null
          : () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: [
                  'mp3',
                  'wav',
                  'm4a',
                  'aac',
                ],
                withData: true,
              );

              if (result != null) {
                setDialogState(() {
                  selectedAudio = result.files.single;
                });
              }
            },
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.upload_file,
          color: Colors.white,
        ),
      ),
    ),
  ],
)
),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 5,
              enabled: !saving,
              decoration: InputDecoration(
                hintText: "Enter follow-up notes...",
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(dialogCtx),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: saving
    ? null
    : () async {
        final note = notesController.text.trim();

        if (note.isEmpty) {
          showApiSnack(
            context,
            "Please enter follow-up notes",
            isError: true,
          );
          return;
        }

        setDialogState(() => saving = true);

        final error = await leadCubit.addFollowUpNote(
          lead.id,
          note,
          audioFile: selectedAudio,
        );

        if (!dialogCtx.mounted) return;

        if (error == null) {
          Navigator.pop(dialogCtx);
          showApiSnack(context, "Follow-up note added");
        } else {
          setDialogState(() => saving = false);
          showApiSnack(context, error, isError: true);
        }
      },
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const SizedBox.shrink(),
            label: Text(saving ? "Saving..." : "Save Follow-up"),
          ),
        ],
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

  void openDetail(BuildContext ctx, Lead lead) async {
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
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider(create: (_) => MeetingsCubit()..loadMeetings()),
            ],
            child: LeadDetailSheet(lead: fullLead ?? lead, leadCubit: cubit),
          ),
        ),
      ),
    );
  }

  Future<void> _openConvert(BuildContext ctx, Lead lead) async {
    final isConverted = lead.status.trim().toLowerCase() == 'converted';
    if (isConverted) {
      showApiSnack(ctx, 'This lead is already converted to a deal.');
      return;
    }
    final cubit = ctx.read<LeadCubit>();

    // Default currency = "currency" from GET /users/me
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final currency = await cubit.getAccountCurrency();
    if (!ctx.mounted) return;
    Navigator.of(ctx).pop(); // close loader

    await showConvertLeadDialog(
      ctx,
      leadName: lead.name,
      companyName: lead.companyName,
      initialCurrency: currency,
      onConvert: (r) => cubit.convertToDeal(
        lead.id,
        r.dealValue,
        r.currency,
        stage: r.stage,
        notes: r.notes,
      ),
    );
  }

  Future<void> _confirmReject(BuildContext ctx, String id) async {
  final reasonController = TextEditingController();

  final reason = await showDialog<String>(
    context: ctx,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Reject Lead"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Please enter the reason for rejecting this lead.",
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Enter reason...",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
          ),
          onPressed: () {
            final text = reasonController.text.trim();

            if (text.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text("Please enter a rejection reason"),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.pop(dialogContext, text);
          },
          child: const Text(
            "Reject",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (reason == null || reason.isEmpty) return;

  debugPrint("Reject Reason: $reason");

  final err = await ctx.read<LeadCubit>().rejectLead(
        id,
        reason,
      );

  if (err != null && ctx.mounted) {
    showApiSnack(ctx, err, isError: true);
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
    .map((e) => DropdownMenuItem(
      value: e,
      child: Row(
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              labelBuilder != null ? labelBuilder!(e) : e,
            ),
          ),
        ],
      ),
    ))
    .toList(),
          onChanged: onChanged,
        )),
      );
}

// ─── Lead Card ────────────────────────────────────────────────
class _LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap, onEdit, onReject, onConvert,onAddFollowUp;
  final Future<String?> Function(String) onStatusChange;
  const _LeadCard(
      {required this.lead,
      required this.onTap,
      required this.onEdit,
      required this.onReject,
      required this.onStatusChange,
      required this.onConvert,
       required this.onAddFollowUp
      });

  @override
  Widget build(BuildContext ctx) {

    final isConverted = lead.status.trim().toLowerCase() == 'converted';
    final today = DateTime.now();
final todayOnly = DateTime(today.year, today.month, today.day);

final followupDate = lead.followUpDate == null
    ? null
    : DateTime(
        lead.followUpDate!.year,
        lead.followUpDate!.month,
        lead.followUpDate!.day,
      );

final isMissedFollowup =
    followupDate != null &&
    followupDate.isBefore(todayOnly) &&
    lead.followUpNotes.isEmpty &&
    lead.status.trim().toLowerCase() != "converted" &&
    lead.status.trim().toLowerCase() != "rejected";
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
                    // Name + task/target icons when this lead is linked.
                    Row(children: [
                      Flexible(
                        child: Text(lead.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ),
                      const SizedBox(width: 6),
                      LinkedWorkBadges(
                          kind: LinkedWorkKind.lead, id: lead.id),
                    ]),
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
                  GestureDetector(
                    onTap: () {
                      ctx.read<CallCubit>().makeCall(lead.phone);
                    },
                    child: const Icon(
                      Icons.call_outlined,
                      size: 18,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (!isConverted)
                    GestureDetector(
                        onTap: onConvert,
                        child: const Icon(Icons.swap_horiz_outlined,
                            size: 18, color: AppColors.textHint)),
                  if (!isConverted)
      const SizedBox(width: 0),
      
IconButton(
    padding: EdgeInsets.zero,

  icon: Icon(
    size: 18,
    Icons.visibility,
    color: isMissedFollowup
    ? Colors.red
    : Colors.black87,
  ),
  tooltip: "View Follow-up Notes",
  onPressed: () => _showFollowUpNotes(
    ctx,
    lead,
  ),
),
    PopupMenuButton<String>(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
       elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(
        Icons.more_vert,
        size: 20,
        color: AppColors.textHint,
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
            break;

          case 'followup':
            onAddFollowUp();
            break;

          case 'Reject':
            onReject();
            break;
        }
      },
      itemBuilder: (_) => [
  const PopupMenuItem<String>(
    value: 'edit',
    child: Row(
      children: [
        Icon(Icons.edit_outlined, size: 18),
        SizedBox(width: 12),
        Text('Edit'),
      ],
    ),
  ),
  const PopupMenuDivider(),
  const PopupMenuItem<String>(
    value: 'followup',
    child: Row(
      children: [
        Icon(
          Icons.event_available_outlined,
          size: 18,
          color: AppColors.primary,
        ),
        SizedBox(width: 12),
        Text(
          'Add Follow-up',
          style: TextStyle(
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  ),
  if (PermissionHelper.can('users_roles')) ...[
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'Reject',
      child: Row(
        children: [
          Icon(
            Icons.block,
            size: 18,
            color: AppColors.danger,
          ),
          SizedBox(width: 12),
          Text(
            'Reject',
            style: TextStyle(color: AppColors.danger),
          ),
        ],
      ),
    ),
  ],
],
    ),

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
  InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () async {
      final picked = await showDatePicker(
        context: ctx,
        initialDate: lead.followUpDate!,
        firstDate: DateTime(2023),
        lastDate: DateTime(2100),
      );

      if (picked != null) {
        final err = await ctx.read<LeadCubit>().updateFollowUp(
          lead.id,
          picked,
        );

        if (err != null) {
          showApiSnack(ctx, err, isError: true);
        }
      }
    },
    child: _chip(
      Icons.event_outlined,
      DateFormat('dd MMM').format(lead.followUpDate!),
      c: AppColors.primary,
    ),
  ),
            ]),
          ),
        ]),
      ),
    );
  }
  void _showFollowUpNotes(
  BuildContext context,
  Lead lead,
) {
  final today = DateTime.now();
final todayOnly = DateTime(today.year, today.month, today.day);

final followupDate = lead.followUpDate == null
    ? null
    : DateTime(
        lead.followUpDate!.year,
        lead.followUpDate!.month,
        lead.followUpDate!.day,
      );

final isMissedFollowup =
    followupDate != null &&
    followupDate.isBefore(todayOnly) &&
    lead.followUpNotes.isEmpty &&
    lead.status.trim().toLowerCase() != "converted" &&
    lead.status.trim().toLowerCase() != "rejected";

    final AudioPlayer _player = AudioPlayer();
    
if (isMissedFollowup) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
          ),
          SizedBox(width: 8),
          Text("Missed Follow-up"),
        ],
      ),
      content: const Text(
        "No follow-up notes logged — this follow-up was missed.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        ),
      ],
    ),
  );
  return;
}

  showDialog(
  context: context,
  builder: (_) {
    final scrollController = ScrollController();

 return WillPopScope(
      onWillPop: () async {
        await _player.stop();
        await _player.dispose();
        return true;
      },   
       child: AlertDialog(
 backgroundColor: AppColors.surface,
title: Text(
  "Follow-up History — ${lead.name}",
  style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
  ),
),      
content: lead.followUpNotes.isEmpty
    ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Text(
          "No follow-up notes yet.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      )
    : ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SizedBox(
          width: double.maxFinite,
      child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: ListView.separated(
         controller: scrollController,
          shrinkWrap: true,
          itemCount: lead.followUpNotes.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, index) {
  final note = lead.followUpNotes[index];

  return Card(
    color: AppColors.surface,
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(
                  Icons.notes,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  note.note,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            note.createdAt == null
                ? "-"
                : DateFormat(
                    "dd MMM yyyy • hh:mm a",
                  ).format(note.createdAt!),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),

          if (note.audioPath != null &&
              note.audioPath!.isNotEmpty) ...[
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.audiotrack,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      note.audioName ?? "Audio",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  StreamBuilder<PlayerState>(
  stream: _player.playerStateStream,
  builder: (context, snapshot) {
    final playing = snapshot.data?.playing ?? false;

    return IconButton(
      icon: Icon(
        playing
            ? Icons.pause_circle_filled
            : Icons.play_circle_fill,
        color: AppColors.primary,
      ),
      onPressed: () async {
        if (playing) {
          await _player.pause();
        } else {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token') ?? '';
          final tenantSlug = prefs.getString('tenant_slug') ?? '';

          final previewUrl =
              "https://crm-backend-api.techzarinfo.cloud/$tenantSlug/api/files/preview"
              "?filePath=${Uri.encodeComponent(note.audioPath!)}";

          await _player.setUrl(
            previewUrl,
            headers: {
              "Authorization": "Bearer $token",
            },
          );

          await _player.play();
        }
      },
    );
  },
),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
},
        ),
      ),
        ),
),
      actions: [
        TextButton(
  onPressed: () async {
    await _player.stop();
    await _player.dispose();
    Navigator.pop(context);
  },
  child: const Text("Close"),
),
      ],
       ),
    );
  },
  ).then((_) async {
  await _player.stop();
  await _player.dispose();
});
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
                  if (s == lead.status) return;
                  final cubit = ctx.read<LeadCubit>();
                  String? err;
                  if (s == 'Cold') {
                    final reason = await showStatusReasonSheet(ctx,
                        status: s, leadName: lead.name);
                    if (reason == null) return; // cancelled
                    err = await cubit.updateStatusWithReason(
                        lead.id, s, reason);
                  } else {
                    err = await cubit.updateStatus(lead.id, s);
                  }
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
class LeadDetailSheet extends StatefulWidget {
  final Lead lead;
  final LeadCubit leadCubit;

  const LeadDetailSheet({super.key, required this.lead,required this.leadCubit
});

  @override
  State<LeadDetailSheet> createState() => LeadDetailSheetState();
}

class LeadDetailSheetState extends State<LeadDetailSheet> {
  
  late Lead _currentLead;           // ADD
  Lead get lead => _currentLead;
  List<LeadActivity> _activities = [];
  bool _activityLoading = false;
  
  String _getImageUrl(String path) {
  if (path.startsWith('http://') ||
      path.startsWith('https://')) {
    return path;
  }

  return 'https://crm-backend-api.techzarinfo.cloud$path';
}
  final AudioPlayer _player = AudioPlayer();
    final ScrollController _followUpsScrollController = ScrollController(); // ADD
  final GlobalKey<ScaffoldMessengerState> _detailMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

 @override
  void initState() {               // ADD
    super.initState();
    _currentLead = widget.lead;
      WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadLeadActivity();
  });

  }


  @override
  void dispose() {
    _player.stop();
    _player.dispose();
        _followUpsScrollController.dispose(); // ADD
    super.dispose();
  }




  ScaffoldMessengerState? _snackMessenger(BuildContext context) {
    // GlobalKey lookup first — immune to the passed-in context going
    // stale (e.g. a list item's context deactivated by a rebuild that
    // happened during an awaited call, like refreshing meetings after
    // an edit).
    final localSheet = _detailMessengerKey.currentState;
    if (localSheet != null) return localSheet;
    if (!context.mounted) return null;
    final local = ScaffoldMessenger.maybeOf(context);
    if (local != null) return local;
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNav == null || !rootNav.context.mounted) return null;
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
    const base = 'https://crm.techzarinfo.cloud';
    final clean = rawPath.startsWith('/') ? rawPath : '/$rawPath';
    return '$base$clean';
  }

  Future<void> _loadLeadActivity() async {
  if (!mounted) return;

  setState(() {
    _activityLoading = true;
  });

  final activities = await widget.leadCubit
    .fetchLeadActivity(_currentLead.id);

  if (!mounted) return;

  setState(() {
    _activities = activities;
    _activityLoading = false;
  });
}

  Future<void> _deleteLeadAttachment(dynamic attachment) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete attachment?'),
        content: Text(
          'Are you sure you want to delete "${attachment.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );

  if (confirm != true || !mounted) return;

  try {
    final retainedAttachmentPaths = _currentLead.attachments
        .where((file) => file.path != attachment.path)
        .map((file) => file.path)
        .where((path) => path.isNotEmpty)
        .toList();

    final error = await context.read<LeadCubit>().updateLead(
      _currentLead.id,
      _currentLead,
      retainedAttachmentPaths: retainedAttachmentPaths,
      retainedImagePaths: _currentLead.images
          .map((image) => image.path)
          .where((path) => path.isNotEmpty)
          .toList(),
    );

    if (!mounted) return;

    if (error != null) {
      showApiSnack(
        context,
        error,
        isError: true,
      );
      return;
    }

    setState(() {
      _currentLead = _currentLead.copyWith(
        attachments: _currentLead.attachments
            .where((file) => file.path != attachment.path)
            .toList(),
      );
    });

    showApiSnack(
      context,
      'Attachment deleted successfully',
    );
  } catch (e) {
    if (!mounted) return;

    showApiSnack(
      context,
      'Failed to delete attachment: $e',
      isError: true,
    );
  }
}
  
  Future<void> _previewFile(BuildContext context, String rawPath) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token') ?? '';
  final tenantSlug = prefs.getString('tenant_slug') ?? '';

  if (token.isEmpty || tenantSlug.isEmpty) {
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
    'crm-backend-api.techzarinfo.cloud',
    '/$tenantSlug/api/files/preview',
    {'filePath': cleanPath},
  ).toString();
  debugPrint('Preview URL: $url');

  try {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Authorization': 'Bearer $token'},
        receiveTimeout: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 20),
      ),
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Empty file response from server');
    }

    final fileName = rawPath.split('/').last;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(data, flush: true);

    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done && context.mounted) {
      _showSnack(
        context,
        SnackBar(
          content: Text('Could not open file: ${result.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } on DioException catch (e) {
    debugPrint('=== PREVIEW DIO ERROR === ${e.response?.statusCode} ${e.response?.data}');
    if (!context.mounted) return;
    final msg = (e.response?.data is Map)
        ? (e.response!.data['message'] ?? e.message)
        : e.message;
    _showSnack(
      context,
      SnackBar(
        content: Text('Preview failed: $msg'),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e) {
    debugPrint('=== PREVIEW ERROR === $e');
    if (!context.mounted) return;
    _showSnack(
      context,
      SnackBar(
        content: Text('Could not open file: $e'),
        backgroundColor: Colors.red,
      ),
    );
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
  final tenantSlug = prefs.getString('tenant_slug');
  if (token == null || token.isEmpty || tenantSlug == null || tenantSlug.isEmpty) {
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
    'crm-backend-api.techzarinfo.cloud',
    '/$tenantSlug/api/files/download',
    {'filePath': cleanPath},
  ).toString();
  debugPrint("Download URL: $url");

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

  // Optional tabs, by role permission.
  bool get _showTasks => PermissionHelper.can('assigned_tasks');
  bool get _showTargets => PermissionHelper.can('my_targets');
  bool get _showLinkedWork => _showTasks || _showTargets;
  bool get _showMeetings => PermissionHelper.can('meetings');
  // Emails tab = the Email Campaign module.
  bool get _showEmails => PermissionHelper.can('email_campaigns');
  int get _tabCount =>
      6 +
      (_showLinkedWork ? 1 : 0) +
      (_showMeetings ? 1 : 0) +
      (_showEmails ? 1 : 0);

  @override
  Widget build(BuildContext ctx) => ScaffoldMessenger(
        key: _detailMessengerKey,
        child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DefaultTabController(
        length: _tabCount,
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
            Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: TabBar(
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    labelColor: AppColors.primary,
    unselectedLabelColor: AppColors.textSecondary,
    indicatorColor: AppColors.primary,
    labelStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
    ),
    // Tasks & Targets and Meetings follow the role's permissions;
    // keep in step with the TabBarView children below.
    tabs: [
   const Tab(
    icon: Icon(Icons.info_outline, size: 18),
    text: 'Details',
  ),
   const Tab(
    icon: Icon(Icons.timeline_outlined, size: 18),
    text: 'Activity',
  ),
   if (_showLinkedWork)
   Tab(
    icon: const Icon(Icons.task_alt_outlined, size: 18),
    text: LinkedWorkTab.labelFor(tasks: _showTasks, targets: _showTargets),
  ),
   const Tab(
    icon: Icon(Icons.event_note_outlined, size: 18),
    text: 'Follow-ups',
  ),
   const Tab(
    icon: Icon(Icons.attach_file_outlined, size: 18),
    text: 'Attachments',
  ),
   const Tab(
    icon: Icon(Icons.image_outlined, size: 18),
    text: 'Images',
  ),
   const Tab(
    icon: Icon(Icons.notes_outlined, size: 18),
    text: 'Notes',
  ),
   if (_showMeetings)
   const Tab(
    icon: Icon(Icons.meeting_room_outlined, size: 18),
    text: 'Meetings',
  ),
   if (_showEmails)
   const Tab(
    icon: Icon(Icons.mail_outline_rounded, size: 18),
    text: 'Emails',
  ),
],
  ),
),
              const Divider(height: 16, color: AppColors.divider),
              Expanded(
  child: TabBarView(
    children: [
      // 1. Details
      _buildDetailsTab(ctrl),

      // 2. Activity
      _buildActivityTab(ctrl),

      // 3. Tasks & Targets linked to this lead
      if (_showLinkedWork)
      LinkedWorkTab(
        key: ValueKey('linked-work-${lead.id}'),
        kind: LinkedWorkKind.lead,
        id: lead.id,
        showTasks: _showTasks,
        showTargets: _showTargets,
      ),

      // 3. Follow-ups
      _buildFollowUpsTab(),

      // 4. Attachments
      Stack(
        children: [
          _buildAttachmentsTab(),

          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Upload attachment',
              onPressed: _uploadAttachment,
              child: const Icon(
                Icons.attach_file,
                size: 20,
              ),
            ),
          ),
        ],
      ),

      // 5. Images
      Stack(
        children: [
          _buildImagesTab(),

          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Upload image',
              onPressed: _uploadImage,
              child: const Icon(
                Icons.upload_rounded,
                size: 20,
              ),
            ),
          ),
        ],
      ),

      // 6. Notes
      Stack(
        children: [
          _buildNotesTab(),

          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              tooltip: 'Add note',
              onPressed: _showAddNoteDialog,
              child: const Icon(
                Icons.note_add_outlined,
                size: 20,
              ),
            ),
          ),
        ],
      ),

      // 7. Meetings
      if (_showMeetings) _buildMeetingsTab(),

      // 8. Emails — GET /leads/:id/emails
      if (_showEmails)
      RecordEmailsTab(
        key: ValueKey('emails-${lead.id}'),
        kind: LinkedWorkKind.lead,
        id: lead.id,
        recipientName: lead.name,
        recipientEmail: lead.email,
      ),
    ],
  ),
),
            ]),
          ),
        ),
      )));
      Widget _buildMeetingsTab() {
  return Stack(
    children: [
      _buildLeadMeetings(),

      Positioned(
        right: 20,
        bottom: 20,
        child: BlocBuilder<MeetingsCubit, MeetingsState>(
          builder: (context, state) {
            final connected = switch (state) {
              MeetingsLoaded(:final googleConnected) => googleConnected,
              MeetingsCreating(:final googleConnected) => googleConnected,
              _ => false,
            };

            return Opacity(
              opacity: connected ? 1 : 0.45,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                tooltip: connected
                    ? 'Create meeting'
                    : 'Connect Google to create meetings',
                onPressed: connected
                    ? _createMeetingForLead
                    : () => showConnectGoogleDialog(context),
                child: Icon(
                  connected ? Icons.add : Icons.lock_outline,
                  size: 20,
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
Widget _buildLeadMeetings() {
  return BlocBuilder<MeetingsCubit, MeetingsState>(
    builder: (context, state) {
      if (state is MeetingsLoading) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (state is MeetingsError) {
        return Center(
          child: Text(
            state.message,
            style: const TextStyle(
              color: Colors.red,
            ),
          ),
        );
      }

      if (state is MeetingsLoaded) {
        final leadMeetings = state.meetings.where((meeting) {
          return meeting.leadId == lead.id;
        }).toList();

        if (leadMeetings.isEmpty) {
          return const Center(
            child: Text(
              'No meetings for this lead',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            90,
          ),
          itemCount: leadMeetings.length,
          itemBuilder: (context, index) {
            final meeting = leadMeetings[index];

            return MeetingCard(
              meeting: meeting,
              meetingsCubit: context.read<MeetingsCubit>(),
              onMeetingUpdated: (message) async {
                _showSnack(
                  context,
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            );
          },
        );
      }

      return const Center(
        child: Text(
          'No meetings for this lead',
          style: TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
      );
    },
  );
}

void _createMeetingForLead() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return CreateMeetingSheet(
        leadId: lead.id,
        checkZoomConnection: () =>
            context.read<MeetingsCubit>().checkZoomConnection(),
        onSubmit: ({
          required title,
          required description,
          required startDateTime,
          required endDateTime,
          required attendees,
          required reminderMinutes,
          required provider,
        }) async {
          final success = await context
              .read<MeetingsCubit>()
              .createMeeting(
                title: title,
                description: description,
                leadId: lead.id,
                startDateTime: startDateTime,
                endDateTime: endDateTime,
                attendees: attendees,
                reminderMinutes: reminderMinutes,
                provider: provider,
              );

          if (!mounted) return;

          if (!success) {
            throw Exception(context.read<MeetingsCubit>().lastError ??
                'Failed to create meeting.');
          }

          Navigator.pop(context);

          await context
              .read<MeetingsCubit>()
              .loadMeetings();

          if (!mounted) return;

          showApiSnack(context, 'Meeting created successfully');
        },
      );
    },
  );
}Future<void> _uploadAttachment() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    final List<MultipartFile> files = [];

    for (final file in result.files) {
      if (file.path == null || file.path!.isEmpty) {
        continue;
      }

      files.add(
        await MultipartFile.fromFile(
          file.path!,
          filename: file.name,
        ),
      );
    }

    if (!mounted) return;

    if (files.isEmpty) {
      Navigator.of(context).pop();

      showApiSnack(
        context,
        'Unable to read selected files',
        isError: true,
      );
      return;
    }

    final cubit = context.read<LeadCubit>();

    final error = await cubit.updateLead(
      _currentLead.id,
      _currentLead,
      attachments: files,
      images: const [],
      retainedAttachmentPaths: _currentLead.attachments
          .map((a) => a.path)
          .where((path) => path.isNotEmpty)
          .toList(),
      retainedImagePaths: _currentLead.images
          .map((image) => image.path)
          .where((path) => path.isNotEmpty)
          .toList(),
    );

    if (!mounted) return;

    Navigator.of(context).pop();

    if (error != null) {
      showApiSnack(
        context,
        error,
        isError: true,
      );
      return;
    }

    showApiSnack(
      context,
      files.length == 1
          ? 'Attachment uploaded successfully'
          : '${files.length} attachments uploaded successfully',
    );

    await _refreshLead();
  } catch (e) {
    if (!mounted) return;

    Navigator.of(context).pop();

    showApiSnack(
      context,
      'Failed to upload attachment: $e',
      isError: true,
    );
  }
}
Future<void> _showAddNoteDialog() async {
  final notesController = TextEditingController();
  bool saving = false;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: AppColors.surface,

            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.note_add_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Add Note',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            content: TextField(
              controller: notesController,
              autofocus: true,
              maxLines: 5,
              enabled: !saving,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Enter your note...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Cancel'),
              ),

              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final note =
                            notesController.text.trim();

                        if (note.isEmpty) {
                          showApiSnack(
                            context,
                            'Please enter a note',
                            isError: true,
                          );
                          return;
                        }

                        setDialogState(() {
                          saving = true;
                        });

                        final error =
                            await context
                                .read<LeadCubit>()
                                .addNote(
                                  _currentLead.id,
                                  note,
                                );

                        if (!dialogContext.mounted) {
                          return;
                        }

                        if (error == null) {
                          Navigator.pop(dialogContext);

                          showApiSnack(
                            context,
                            'Note added successfully',
                          );

                          await _refreshLead();
                        } else {
                          setDialogState(() {
                            saving = false;
                          });

                          showApiSnack(
                            context,
                            error,
                            isError: true,
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

 
}
Future<void> _uploadImage() async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Upload Image',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 16),

              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.camera_alt_outlined),
                ),
                title: const Text('Camera'),
                subtitle: const Text('Take a new photo'),
                onTap: () {
                  Navigator.pop(
                    context,
                    ImageSource.camera,
                  );
                },
              ),

              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.photo_library_outlined),
                ),
                title: const Text('Gallery'),
                subtitle: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(
                    context,
                    ImageSource.gallery,
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );

  if (source == null || !mounted) return;

  try {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (image == null || !mounted) return;

    // Continue with your existing upload code
    final multipartImage = await MultipartFile.fromFile(
      image.path,
      filename: image.name,
    );

    // Your existing updateLead() code here...
  } catch (e) {
    if (!mounted) return;

    showApiSnack(
      context,
      'Failed to select image: $e',
      isError: true,
    );
  }
}

Future<void> _refreshLead() async {
  try {
    final cubit = context.read<LeadCubit>();

    final refreshedLead = await cubit.fetchLeadById(lead.id);

    if (!mounted || refreshedLead == null) return;

    setState(() {
      _currentLead = refreshedLead;
    });
  } catch (e) {
    debugPrint('Failed to refresh lead: $e');
  }
}

Widget _buildNotesTab() {
  final notes = _currentLead.notesList;

  if (notes.isEmpty) {
    return const Center(
      child: Text(
        'No notes',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: notes.length,
    itemBuilder: (context, index) {
      final note = notes[index];

      final createdBy = note.createdBy?.fullName ?? 'Unknown';

      return Card(
  margin: const EdgeInsets.only(bottom: 10),
  child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NOTE TEXT
            Expanded(
              child: Text(
                note.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // EDIT
            IconButton(
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              onPressed: () {
                _editNote(note);
              },
            ),

            // DELETE
            IconButton(
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
              onPressed: () {
                _deleteNote(note);
              },
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          '$createdBy • ${note.createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(note.createdAt!) : ''}',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  ),
);
    },
  );
}

Widget _buildImagesTab() {
  if (lead.images.isEmpty) {
    return const Center(
      child: Text(
        'No images',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  return GridView.builder(
    padding: const EdgeInsets.all(20),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemCount: lead.images.length,
    itemBuilder: (context, index) {
      final image = lead.images[index];
      final imageUrl = _getImageUrl(image.path);

      return Stack(
        children: [
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black87,
                builder: (dialogContext) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(10),
                    child: Stack(
                      children: [
                        Center(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) {
                                return const Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 60,
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: AppColors.background,
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            right: 5,
            bottom: 5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Download',
                    iconSize: 18,
                    onPressed: () {
                      _downloadFile(
                        context,
                        image.path,
                        image.path.split('/').last,
                      );
                    },
                    icon: const Icon(
                      Icons.download,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete',
                    iconSize: 18,
                    onPressed: () {
                      _deleteLeadImage(image);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _deleteNote(LeadNote note) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete note?'),
        content: const Text(
          'Are you sure you want to delete this note?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );

  if (confirm != true || !mounted) return;

  try {
    final error = await context.read<LeadCubit>().deleteNote(
      _currentLead.id,
      note.id,
    );

    if (!mounted) return;

    if (error != null) {
      showApiSnack(
        context,
        error,
        isError: true,
      );
      return;
    }

    // Remove the deleted note from the current UI immediately.
    setState(() {
      _currentLead = _currentLead.copyWith(
        notesList: _currentLead.notesList
            .where((n) => n.id != note.id)
            .toList(),
      );
    });

    showApiSnack(
      context,
      'Note deleted successfully',
    );
  } catch (e) {
    if (!mounted) return;

    showApiSnack(
      context,
      'Failed to delete note: $e',
      isError: true,
    );
  }
}
Future<void> _editNote(LeadNote note) async {
  final controller = TextEditingController(
    text: note.text,
  );

  bool saving = false;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Edit Note',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              enabled: !saving,
              decoration: InputDecoration(
                hintText: 'Enter note...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final text = controller.text.trim();

                        if (text.isEmpty) {
                          showApiSnack(
                            context,
                            'Please enter a note',
                            isError: true,
                          );
                          return;
                        }

                        setDialogState(() {
                          saving = true;
                        });

                        final error =
                            await context.read<LeadCubit>().updateNote(
                                  _currentLead.id,
                                  note.id,
                                  text,
                                );

                        if (!dialogContext.mounted) return;

                        if (error != null) {
                          setDialogState(() {
                            saving = false;
                          });

                          showApiSnack(
                            context,
                            error,
                            isError: true,
                          );
                          return;
                        }

                        Navigator.pop(dialogContext);

                        // Update UI immediately without DB.
                        if (mounted) {
                          setState(() {
                            _currentLead = _currentLead.copyWith(
                              notesList: _currentLead.notesList.map((n) {
                                if (n.id == note.id) {
                                  return LeadNote(
                                    id: n.id,
                                    text: text,
                                    createdBy: n.createdBy,
                                    createdAt: n.createdAt,
                                    updatedAt: DateTime.now(),
                                  );
                                }

                                return n;
                              }).toList(),
                            );
                          });

                          showApiSnack(
                            context,
                            'Note updated successfully',
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
}

Future<void> _deleteLeadImage(dynamic image) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete image?'),
        content: const Text(
          'Are you sure you want to delete this image?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );

  if (confirm != true || !mounted) return;

  try {
    // Keep all images except the one being deleted.
    final retainedImagePaths = _currentLead.images
        .where((img) => img.path != image.path)
        .map((img) => img.path)
        .where((path) => path.isNotEmpty)
        .toList();

    final cubit = context.read<LeadCubit>();

    final error = await cubit.updateLead(
      _currentLead.id,
      _currentLead,
      retainedAttachmentPaths: _currentLead.attachments
          .map((a) => a.path)
          .where((path) => path.isNotEmpty)
          .toList(),
      retainedImagePaths: retainedImagePaths,
    );

    if (!mounted) return;

    if (error != null) {
      showApiSnack(
        context,
        error,
        isError: true,
      );
      return;
    }

    // Remove immediately from the UI.
    setState(() {
      _currentLead = _currentLead.copyWith(
        images: _currentLead.images
            .where((img) => img.path != image.path)
            .toList(),
      );
    });

    showApiSnack(
      context,
      'Image deleted successfully',
    );
  } catch (e) {
    if (!mounted) return;

    showApiSnack(
      context,
      'Failed to delete image: $e',
      isError: true,
    );
  }
}

Widget _buildAttachmentsTab() {
  if (lead.attachments.isEmpty) {
    return const Center(
      child: Text(
        'No attachments',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  return ListView.builder(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    itemCount: lead.attachments.length,
    itemBuilder: (context, index) {
      final attachment = lead.attachments[index];

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 22,
              color: AppColors.primary,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '${(attachment.size / 1024).toStringAsFixed(1)} KB',
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
                Icons.visibility_outlined,
                size: 19,
                color: AppColors.primary,
              ),
              onPressed: () {
                _previewFile(
                  context,
                  attachment.path,
                );
              },
            ),

            IconButton(
              icon: const Icon(
                Icons.download_outlined,
                size: 19,
                color: AppColors.primary,
              ),
              onPressed: () {
                _downloadFile(
                  context,
                  attachment.path,
                  attachment.name,
                );
              },
            ),

             // DELETE
    IconButton(
      tooltip: 'Delete',
      icon: const Icon(
        Icons.delete_outline,
        size: 19,
        color: Colors.red,
      ),
      onPressed: () {
        _deleteLeadAttachment(attachment);
      },
    )

          ],
        ),
      );
    },
  );
}
Widget _buildFollowUpsTab() {
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);

  final followupDate = lead.followUpDate == null
      ? null
      : DateTime(
          lead.followUpDate!.year,
          lead.followUpDate!.month,
          lead.followUpDate!.day,
        );

  final isMissedFollowup = followupDate != null &&
      followupDate.isBefore(todayOnly) &&
      lead.followUpNotes.isEmpty &&
      lead.status.trim().toLowerCase() != "converted" &&
      lead.status.trim().toLowerCase() != "rejected";

  final status = lead.status.trim().toLowerCase();
  final canAdd = status != 'converted' && status != 'rejected'; // ADD

  Widget body; // ADD — holds whichever state below, wrapped later
  if (isMissedFollowup) {
    body = ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        SizedBox(height: 40),
        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
        SizedBox(height: 12),
        Text(
          "Missed Follow-up",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        SizedBox(height: 6),
        Text(
          "No follow-up notes logged — this follow-up was missed.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  } else if (lead.followUpNotes.isEmpty) {
    body = const Center(
      child: Text(
        "No follow-up notes yet.",
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
    );
  } else {
    body = Scrollbar(
      controller: _followUpsScrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _followUpsScrollController,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: lead.followUpNotes.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, index) {
          final note = lead.followUpNotes[index];
          return Card(
            color: AppColors.surface,
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(Icons.notes, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          note.note,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.createdAt == null
                        ? "-"
                        : DateFormat("dd MMM yyyy • hh:mm a")
                            .format(note.createdAt!),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (note.audioPath != null && note.audioPath!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.audiotrack, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              note.audioName ?? "Audio",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StreamBuilder<PlayerState>(
                            stream: _player.playerStateStream,
                            builder: (context, snapshot) {
                              final playing = snapshot.data?.playing ?? false;
                              return IconButton(
                                icon: Icon(
                                  playing
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_fill,
                                  color: AppColors.primary,
                                ),
                                onPressed: () async {
                                  if (playing) {
                                    await _player.pause();
                                  } else {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    final token = prefs.getString('token') ?? '';
                                    final tenantSlug =
                                        prefs.getString('tenant_slug') ?? '';

                                    final previewUrl =
                                        "https://crm-backend-api.techzarinfo.cloud/$tenantSlug/api/files/preview"
                                        "?filePath=${Uri.encodeComponent(note.audioPath!)}";

                                    await _player.setUrl(
                                      previewUrl,
                                      headers: {"Authorization": "Bearer $token"},
                                    );
                                    await _player.play();
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  return Stack(
  children: [
    Positioned.fill(child: body),
    if (canAdd)
      Positioned(
        right:20,
        bottom: 16,
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _openAddFollowUpDialog(context),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.add, size: 30, color: Colors.white),
            ),
          ),
        ),
      ),
  ],
);
}
Future<void> _openAddFollowUpDialog(BuildContext context) async {
  final notesController = TextEditingController();
  final leadCubit = context.read<LeadCubit>();
  bool saving = false;
  PlatformFile? selectedAudio;

  await showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_available_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text("Add Follow-up",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black),
                children: [
                  const TextSpan(text: "Lead: ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: lead.name),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("Notes *", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            const Text("Audio (Optional)",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.audiotrack, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedAudio?.name ?? "No audio selected",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selectedAudio != null)
                    IconButton(
                      tooltip: "Remove audio",
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: saving
                          ? null
                          : () => setDialogState(() => selectedAudio = null),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: saving
                        ? null
                        : () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
                              withData: true,
                            );
                            if (result != null) {
                              setDialogState(
                                  () => selectedAudio = result.files.single);
                            }
                          },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.upload_file, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 5,
              enabled: !saving,
              decoration: InputDecoration(
                hintText: "Enter follow-up notes...",
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(dialogCtx),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: saving
                ? null
                : () async {
                    final note = notesController.text.trim();
                    if (note.isEmpty) {
                      showApiSnack(context, "Please enter follow-up notes",
                          isError: true);
                      return;
                    }

                    setDialogState(() => saving = true);

                    final error = await leadCubit.addFollowUpNote(
                      lead.id,
                      note,
                      audioFile: selectedAudio,
                    );

                    if (!dialogCtx.mounted) return;

                    if (error == null) {
                      Navigator.pop(dialogCtx);
                      showApiSnack(context, "Follow-up note added");
                      final updated = await leadCubit.fetchLeadById(lead.id);
                      if (mounted && updated != null) {
                        setState(() => _currentLead = updated);
                      }
                    } else {
                      setDialogState(() => saving = false);
                      showApiSnack(context, error, isError: true);
                    }
                  },
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const SizedBox.shrink(),
            label: Text(saving ? "Saving..." : "Save Follow-up"),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildDetailsTab(ScrollController ctrl) {
  String valueOrDash(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? 'Not specified' : v;
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Not specified';
    return DateFormat('M/d/yyyy').format(date.toLocal());
  }

  /// [onTap] makes the value a link (phone → call/copy, email → mail/copy).
  Widget infoItem(
    IconData icon,
    String label,
    String value, {
    bool clickable = false,
    VoidCallback? onTap,
  }) {
    clickable = clickable || onTap != null;
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.primary.withOpacity(.65),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: clickable
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    decoration:
                        onTap != null ? TextDecoration.underline : null,
                    decorationColor: AppColors.primary.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: row,
    );
  }

  Widget column(List<Widget> children) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  final leftColumn = [
    infoItem(
      Icons.person_outline,
      'Lead Name',
      valueOrDash(lead.name),
    ),
    infoItem(
      Icons.business_outlined,
      'Company',
      valueOrDash(lead.companyName),
    ),
    infoItem(
      Icons.email_outlined,
      'Email',
      valueOrDash(lead.email),
      onTap: lead.email.trim().isEmpty
          ? null
          : () => showEmailActions(context, email: lead.email),
    ),
    infoItem(
      Icons.email_outlined,
      'Alternate Email',
      valueOrDash(lead.alternateEmail),
      onTap: lead.alternateEmail.trim().isEmpty
          ? null
          : () => showEmailActions(context, email: lead.alternateEmail),
    ),
    infoItem(
      Icons.phone_outlined,
      'Phone',
      lead.phone.trim().isEmpty
          ? 'Not specified'
          : _formatPhone(lead.phone),
      onTap: lead.phone.trim().isEmpty
          ? null
          : () => showPhoneActions(
                context,
                number: dialableNumber(lead.phone),
                display: _formatPhone(lead.phone),
              ),
    ),
    infoItem(
      Icons.phone_outlined,
      'Alternate Phone',
      lead.alternatePhoneNumber.trim().isEmpty
          ? 'Not specified'
          : _formatPhone(lead.alternatePhoneNumber),
      onTap: lead.alternatePhoneNumber.trim().isEmpty
          ? null
          : () => showPhoneActions(
                context,
                number: dialableNumber(lead.alternatePhoneNumber),
                display: _formatPhone(lead.alternatePhoneNumber),
              ),
    ),
    infoItem(
      Icons.corporate_fare_outlined,
      'Client Type',
      valueOrDash(lead.clientType),
    ),
    infoItem(
      Icons.public_outlined,
      'Source',
      valueOrDash(lead.source),
    ),
    infoItem(
      Icons.business_center_outlined,
      'Industry',
      valueOrDash(lead.industry),
    ),
    infoItem(
      Icons.people_outline,
      'Number of Employees',
      lead.numberOfEmployees == null
          ? 'Not specified'
          : lead.numberOfEmployees.toString(),
    ),
  ];

  final rightColumn = [
    infoItem(
      Icons.person_outline,
      'Status',
      valueOrDash(lead.status),
    ),
    infoItem(
      Icons.description_outlined,
      'Requirement',
      valueOrDash(lead.requirement),
    ),
    infoItem(
      Icons.location_on_outlined,
      'Address',
      valueOrDash(lead.address),
    ),
    infoItem(
      Icons.location_on_outlined,
      'City',
      valueOrDash(lead.city),
    ),
    infoItem(
      Icons.location_on_outlined,
      'State',
      valueOrDash(lead.state),
    ),
    infoItem(
      Icons.location_on_outlined,
      'Pincode',
      valueOrDash(lead.pincode),
    ),
    infoItem(
      Icons.public_outlined,
      'Country',
      valueOrDash(lead.country),
    ),
    infoItem(
      Icons.my_location_outlined,
      'Latitude',
      lead.latitude == null
          ? 'Not specified'
          : lead.latitude.toString(),
    ),
    infoItem(
      Icons.my_location_outlined,
      'Longitude',
      lead.longitude == null
          ? 'Not specified'
          : lead.longitude.toString(),
    ),
    infoItem(
      Icons.calendar_today_outlined,
      'Follow-up Date',
      formatDate(lead.followUpDate),
    ),
    infoItem(
      Icons.calendar_today_outlined,
      'Created',
      formatDate(lead.createdAt),
    ),
  ];

  return ListView(
    controller: ctrl,
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    children: [
      const Text(
        'Client Information',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      const SizedBox(height: 24),

      LayoutBuilder(
        builder: (context, constraints) {
          // Two columns like your screenshot
          if (constraints.maxWidth >= 600) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                column(leftColumn),
                const SizedBox(width: 45),
                column(rightColumn),
              ],
            );
          }

          // One column on smaller screens
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...leftColumn,
              ...rightColumn,
            ],
          );
        },
      ),

      // ==========================================================
      // NOTES
      // ==========================================================

      if (lead.notes.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 16),

        const Text(
          'Notes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Text(
            lead.notes,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],

      // ==========================================================
      // CUSTOM FIELDS
      // ==========================================================

      if (lead.customFields.isNotEmpty) ...[
        const SizedBox(height: 24),

        const Text(
          'Custom Fields',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        ...lead.customFields.map(
          (field) {
            final fieldValue = field.value.trim().isEmpty
                ? 'Not specified'
                : field.value;

            return _row(
              field.type == 'date'
                  ? Icons.calendar_today_outlined
                  : field.type == 'dropdown'
                      ? Icons.arrow_drop_down_circle_outlined
                      : Icons.tune_outlined,
              field.name,
              fieldValue,
            );
          },
        ),
      ],

    ],
  );
}
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
  return ActivityTimeline(
    controller: ctrl,
    isLoading: _activityLoading,
    subtitle: 'Recent activity and updates for this lead',
    activities: [
      for (final a in _activities)
        ActivityTimelineItem(
          type: a.type,
          title: _activityTitle(a.type),
          description: a.description,
          performedBy: a.performedByName,
          timestamp: a.timestamp,
        ),
    ],
  );
}

String _activityTitle(String type) {
  switch (type) {
    case 'lead_created':
      return 'Lead Created';

    case 'lead_edited':
      return 'Lead Updated';

    case 'status_changed':
      return 'Status Changed';

    case 'lead_converted':
      return 'Lead Converted';

    case 'attachment_uploaded':
      return 'Attachment Uploaded';

    case 'meeting_scheduled':
      return 'Meeting Scheduled';

    case 'notes_updated':
      return 'Notes Updated';

    case 'followup_rescheduled':
      return 'Follow-up Rescheduled';

    case 'target_linked':
      return 'Target Linked';

    case 'task_activity':
      return 'Task Activity';

    default:
      return 'Activity';
  }
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
  if (v.isEmpty) return null;
  final atCount = '@'.allMatches(v).length;
  if (atCount != 1) return 'Invalid email format';
  if (!RegExp(r'^[^@]+@[^@]+\.com$', caseSensitive: false).hasMatch(v)) {
    return 'Email must end with .com (e.g. name@gmail.com)';
  }
  return null;
}

String? _validateName(String value) =>
    value.trim().isEmpty ? 'Lead name is required' : null;

String? _validateCompany(String value) =>
    value.trim().isEmpty ? 'Company name is required' : null;

String? _validatePhone(String value) {
  final v = value.trim().replaceAll(RegExp(r'[^0-9]'), '');

  if (v.isEmpty) {
    return 'Phone number is required';
  }

  if (v.length > 12) {
    return 'Phone number must not exceed 12 digits';
  }

  return null;
}

// ══════════════════════════════════════════════════════════════
// LEAD FORM MODAL  — CREATE + EDIT
// ══════════════════════════════════════════════════════════════
/// Dashed rounded-rect outline (the "Add custom field" button).
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));
    const dash = 6.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

class _LeadFormModal extends StatefulWidget {
  final List<AppUser> salesUsers;
  final Lead? existingLead;
  
  const _LeadFormModal({required this.salesUsers, this.existingLead});
  @override
  State<_LeadFormModal> createState() => _LeadFormModalState();
}

class _LeadFormModalState extends State<_LeadFormModal> {
  String _getImageUrl(String path) {
  if (path.startsWith('http://') ||
      path.startsWith('https://')) {
    return path;
  }

  return 'https://crm-backend-api.techzarinfo.cloud$path';
}

  String _phoneCountryCode = '+91';
  String _alternatePhoneCountryCode = '+91';
    final List<XFile> _selectedImages = [];
    final List<PlatformFile> _leadImages = [];
    late final TextEditingController _alternatePhone;
    late final TextEditingController _alternateEmail;

  late final TextEditingController _name,
    _company,
    _phone,
    _email,
    _addr,
    _city,
    _state,
    _pincode,
    _latitude,
    _longitude,
    _req,
    _notes;

  String? _nameError;
  String? _companyError;
  String? _phoneError;
  String? _emailError;

  /// Name of the lead already using the typed phone / email
  /// (GET /leads/check-duplicate). Warning only — never blocks saving.
  String? _phoneDupLead;
  String? _emailDupLead;
  Timer? _dupDebounce;
  int _dupSeq = 0;

  final List<PlatformFile> _attachments = [];
  final List<Attachment> _existingAttachments = [];
  String? _country, _industry, _source;

  /// Typed industry when "Other" is picked.
  final TextEditingController _otherIndustry = TextEditingController();

  /// Digits only — sent as `NumberOfEmployees`.
  final TextEditingController _employees = TextEditingController();

  /// `B2B` | `B2C` | null = not chosen yet.
  String? _clientType;
  String _status = 'Hot';
  DateTime? _followUp;
  int _step = 0;
  bool _saving = false;

  String? _selectedAssignUserId;

  /// Sales users can't reassign: on create the lead is theirs, on edit it
  /// keeps its current owner. Same rule LeadCubit uses (no users_roles).
  final bool _assigneeLocked = !PermissionHelper.can('users_roles');

  /// Name shown in the locked Assign To field.
  String _lockedAssigneeName = '';
  late final List<AppUser> _salesUsers;
  late final List<String> _countries;
  late final List<String> _industries;
  late final List<String> _sources;

  bool get _isEdit => widget.existingLead != null;
   List<CustomField> _customFields = [];

  @override
  void initState() {
    super.initState();

    _customFields = List<CustomField>.from(
  widget.existingLead?.customFields ?? const [],
);

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
    _alternatePhone = TextEditingController(
  text: _extractLocalNumber(l?.alternatePhoneNumber ?? ''),
);
    // Match the flags shown in the phone fields; otherwise saving without
    // touching the number re-prefixes it with +91.
    _phoneCountryCode = '+${_splitPhone(l?.phone ?? '').$2}';
    _alternatePhoneCountryCode =
        '+${_splitPhone(l?.alternatePhoneNumber ?? '').$2}';
    _email = TextEditingController(text: l?.email);
    _alternateEmail = TextEditingController(text: l?.alternateEmail);
    _addr = TextEditingController(text: l?.address);
_city = TextEditingController(text: l?.city);
_state = TextEditingController(text: l?.state);
_pincode = TextEditingController(text: l?.pincode);
_latitude = TextEditingController(
  text: l?.latitude?.toString() ?? '',
);
_longitude = TextEditingController(
  text: l?.longitude?.toString() ?? '',
);
_req = TextEditingController(text: l?.requirement);
_notes = TextEditingController(text: l?.notes);
    if (l != null) {
      _existingAttachments.addAll(l.attachments);
      _employees.text = l.numberOfEmployees?.toString() ?? '';
      _country = (l.country.isNotEmpty && _countries.contains(l.country))
          ? l.country
          : null;
      if (_industries.contains(l.industry)) {
        _industry = l.industry;
      } else if (l.industry.trim().isNotEmpty) {
        // A custom industry was saved via "Other".
        _industry = 'Other';
        _otherIndustry.text = l.industry.trim();
      }
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

    if (_assigneeLocked) {
      if (l != null) {
        // Edit: keep the current owner.
        final id = (l.assignedToId?.trim().isNotEmpty ?? false)
            ? l.assignedToId!.trim()
            : _selectedAssignUserId;
        _selectedAssignUserId = id;
        _lockedAssigneeName = l.assignTo.trim().isNotEmpty
            ? l.assignTo.trim()
            : (_salesUsers.where((u) => u.id == id).firstOrNull?.fullName ??
                'Unassigned');
      } else {
        _assignLoggedInUser();
      }
    }
  }

  /// Create: the lead belongs to whoever is logged in.
  Future<void> _assignLoggedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id')?.trim() ?? '';
    if (!mounted || id.isEmpty) return;
    final listed = _salesUsers.where((u) => u.id == id).firstOrNull?.fullName;
    setState(() {
      _selectedAssignUserId = id;
      _lockedAssigneeName = (listed?.isNotEmpty ?? false)
          ? listed!
          : (prefs.getString('user_name')?.trim() ?? '');
    });
  }

  /// Re-checks phone + email for duplicates 500ms after the user stops
  /// typing. Values that are invalid, too short, or unchanged from the lead
  /// being edited (it would match itself) aren't sent.
  void _scheduleDuplicateCheck() {
    _dupDebounce?.cancel();
    _dupDebounce = Timer(const Duration(milliseconds: 500), () async {
      final digits = RegExp(r'[^0-9]');
      final local = _phone.text.trim().replaceAll(digits, '');
      final fullPhone = _fullPhoneNumber().replaceAll(digits, '');
      final email = _email.text.trim();

      final original = widget.existingLead;
      final checkPhone = local.length >= 6 &&
          _validatePhone(local) == null &&
          fullPhone != (original?.phone ?? '').replaceAll(digits, '');
      final checkEmail = email.isNotEmpty &&
          _validateEmail(email) == null &&
          email.toLowerCase() !=
              (original?.email ?? '').trim().toLowerCase();

      final seq = ++_dupSeq;
      final hits = (checkPhone || checkEmail)
          ? await context.read<LeadCubit>().checkDuplicate(
                phoneNumber: checkPhone ? fullPhone : null,
                email: checkEmail ? email : null,
              )
          : const <String, String>{};
      // A newer keystroke has started its own check.
      if (!mounted || seq != _dupSeq) return;
      setState(() {
        _phoneDupLead = hits?['phoneNumber'];
        _emailDupLead = hits?['email'];
      });
    });
  }

  Widget _duplicateWarning(String field, String? leadName) => leadName == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.warning_amber_rounded,
                    size: 13, color: AppColors.warning),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  leadName.isEmpty
                      ? 'This $field is already used by another lead'
                      : 'This $field is already used by "$leadName"',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );

  @override
  void dispose() {
    _dupDebounce?.cancel();
    for (final c in [
  _name,
  _company,
  _phone,
  _alternatePhone,
  _email,
  _alternateEmail,
  _addr,
  _city,
  _state,
  _pincode,
  _latitude,
  _longitude,
  _req,
  _notes,
  _otherIndustry,
  _employees,
]) {
  c.dispose();
}
    super.dispose();
  }

  /// Splits a stored phone into (ISO code, dial code, local number).
  ///
  /// Numbers saved from the app carry the country code ("919876543210"),
  /// but imported / web leads are often bare national numbers
  /// ("9876543210", "09876543210"). Parsing those as international used to
  /// pick a wrong country (+98 Iran → "76543210") or fail and leave the raw
  /// value, longer than the field's max length — so it couldn't be edited.
  /// Only numbers with a "+" or more than 10 digits are treated as
  /// international; the rest are Indian national numbers.
  (String, String, String) _splitPhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return ('IN', '91', '');

    final international = rawPhone.trim().startsWith('+') ||
        (digits.length > 10 && !digits.startsWith('0'));
    if (international) {
      try {
        final parsed = PhoneNumber.parse('+$digits');
        if (parsed.nsn.isNotEmpty) {
          return (parsed.isoCode.name, parsed.countryCode, parsed.nsn);
        }
      } catch (_) {}
    }
    return ('IN', '91', digits.replaceFirst(RegExp(r'^0+'), ''));
  }

  String _extractLocalNumber(String rawPhone) => _splitPhone(rawPhone).$3;

  String _getInitialCountryCode(String rawPhone) => _splitPhone(rawPhone).$1;

  String _fullPhoneNumber() {
    final countryCode = _phoneCountryCode.replaceAll('+', '');
    final localNumber = _phone.text.trim();

    return '$countryCode$localNumber';
  }

  Future<Map<String, List<MultipartFile>>> _buildMultipartFiles() async {
  final attachments = <MultipartFile>[];
  final images = <MultipartFile>[];

  // Normal files
  for (final f in _attachments) {
    try {
      MultipartFile multipartFile;

      if (f.bytes != null) {
        multipartFile = MultipartFile.fromBytes(
          f.bytes!,
          filename: f.name,
        );
      } else if (f.path != null && f.path!.isNotEmpty) {
        multipartFile = await MultipartFile.fromFile(
          f.path!,
          filename: f.name,
        );
      } else {
        continue;
      }

      attachments.add(multipartFile);
    } catch (e) {
      debugPrint('Attachment skip [${f.name}]: $e');
    }
  }

  // Images selected using ImagePicker
  for (final image in _selectedImages) {
    try {
      final multipartFile = await MultipartFile.fromFile(
        image.path,
        filename: image.name,
      );

      images.add(multipartFile);
    } catch (e) {
      debugPrint('Image skip [${image.name}]: $e');
    }
  }

  return {
    'attachments': attachments,
    'images': images,
  };
}

  List<String> get _retainedAttachmentPaths => _existingAttachments
      .map((a) => a.path)
      .where((p) => p.isNotEmpty)
      .toList();

  Future<void> _pickLeadImage() async {
  final picker = ImagePicker();

  final image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
  );

  if (image == null || !mounted) return;

  setState(() {
    _selectedImages.add(image);
  });
}



  Future<void> _fetchCurrentLocation() async {
  try {
    // Check whether location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return;

      showApiSnack(
        context,
        'Please enable location services',
        isError: true,
      );
      return;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        showApiSnack(
          context,
          'Location permission denied',
          isError: true,
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;

      showApiSnack(
        context,
        'Location permission permanently denied. Enable it from Settings.',
        isError: true,
      );
      return;
    }

    // Show loading state
    if (mounted) {
      setState(() {});
    }

    // Get current GPS position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    // Save coordinates
    _latitude.text = position.latitude.toString();
    _longitude.text = position.longitude.toString();

    // Reverse geocode coordinates
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      final place = placemarks.first;

      final addressParts = <String>[
        if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
        if ((place.subLocality ?? '').trim().isNotEmpty)
          place.subLocality!.trim(),
      ];

      _addr.text = addressParts.join(', ');

      _city.text =
          (place.locality ?? place.subAdministrativeArea ?? '').trim();

      _state.text = (place.administrativeArea ?? '').trim();

      _pincode.text = (place.postalCode ?? '').trim();

      final countryName = (place.country ?? '').trim();

      if (countryName.isNotEmpty && _countries.contains(countryName)) {
        _country = countryName;
      }
    }

    if (!mounted) return;

    setState(() {});

    showApiSnack(
      context,
      'Current location added',
    );
  } catch (e) {
    debugPrint('Location error: $e');

    if (!mounted) return;

    showApiSnack(
      context,
      'Unable to get current location',
      isError: true,
    );
  }
}

  void _removeExistingAttachment(Attachment file) {
    setState(() => _existingAttachments.remove(file));
  }

  bool _validateStep0() {
    final nameErr = _validateName(_name.text);
    final companyErr = _validateCompany(_company.text);
    final phoneErr = _validatePhone(_phone.text);
    final emailErr = _validateEmail(_email.text);
    setState(() {
      _nameError = nameErr;
      _companyError = companyErr;
      _phoneError = phoneErr;
      _emailError = emailErr;
    });
    return nameErr == null &&
        companyErr == null &&
        phoneErr == null &&
        emailErr == null;
  }

  Future<void> _submit() async {
    if (!_validateStep0()) {
      // Errors are shown under the fields on the first step
      setState(() => _step = 0);
      return;
    }
    setState(() => _saving = true);

    final lead = Lead(
      id: '',
      name: _name.text.trim(),
      companyName: _company.text.trim(),
      phone: _fullPhoneNumber(),
        alternatePhoneNumber: _alternatePhone.text.trim().isEmpty
      ? ''
      : '$_alternatePhoneCountryCode${_alternatePhone.text.trim()}',
  alternateEmail: _alternateEmail.text.trim(),

      email: _email.text.trim(),
      address: _addr.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pincode: _pincode.text.trim(),
country: _country ?? '',
latitude: double.tryParse(_latitude.text.trim()),
longitude: double.tryParse(_longitude.text.trim()),
      industry: _industry == 'Other' && _otherIndustry.text.trim().isNotEmpty
          ? _otherIndustry.text.trim()
          : _industry ?? '',
      numberOfEmployees: int.tryParse(_employees.text.trim()),
      source: _source ?? '',
      clientType: _clientType ?? '',
      requirement: _req.text.trim(),
      status: _status,
      assignTo: _selectedAssignUserId ?? '',
      // LeadCubit sends `assignedToId` as `assignTo` — without this the
      // picked rep was never saved.
      assignedToId: _selectedAssignUserId,
      followUpDate: _followUp,
      notes: _notes.text.trim(),
      customFields: _customFields,
      
    );

    final cubit = context.read<LeadCubit>();
    String? err;
    final fileGroups = await _buildMultipartFiles();

final attachmentFiles =
    fileGroups['attachments'] ?? [];

final imageFiles =
    fileGroups['images'] ?? [];
    if (!mounted) return;
    if (_isEdit) {
  err = await cubit.updateLead(
    widget.existingLead!.id,
    lead,
    attachments: attachmentFiles,
    images: imageFiles,
    retainedAttachmentPaths: _retainedAttachmentPaths,
  );
} else {
  err = await cubit.createLead(
    lead,
    attachments: attachmentFiles,
    images: imageFiles,
  );
}
    if (!mounted) return;

    setState(() => _saving = false);

if (err == null) {
  showApiSnack(
    context,
    widget.existingLead == null
        ? "Lead created successfully"
        : "Lead updated successfully",
  );

  Navigator.pop(context);
} else {
  showApiSnack(
    context,
    err,
    isError: true,
  );
}  }

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
            // ── Title + close ──
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
              child: Row(children: [
                Expanded(
                  child: Text(_isEdit ? 'Edit Lead' : 'Create Lead',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close,
                          size: 20, color: AppColors.textPrimary),
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.divider,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)))),
                ),
              ]),
            ),
            // ── Step indicator ──
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
              child: _stepper(),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
                child: ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                  if (_step == 0) _basicStep(),
                  if (_step == 1) _businessStep(),
                  if (_step == 2) _locationStep(),
                  if (_step == 3) _manageStep(),
                  if (_step == 4) _notesStep(),
                  const SizedBox(height: 20),
                  Row(children: [
                    if (_step > 0) ...[
                      Expanded(
                          child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _step--),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Back',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                        ),
                      )),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                        flex: _step > 0 ? 2 : 1,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primary.withOpacity(0.28),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6)),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _saving
                                ? null
                                : (_step < 4
                                    ? () {
                                        if (_step == 0 && !_validateStep0()) {
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
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _step < 4
                                        ? Icons.arrow_forward
                                        : Icons.cloud_upload_outlined,
                                    size: 20,
                                  ),
                            label: Text(
                              _saving
                                  ? 'Saving...'
                                  : (_step < 4
                                      ? 'Next'
                                      : (_isEdit ? 'Update' : 'Save')),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                          ),
                        )),
                  ]),
                  const SizedBox(height: 20),
                ])),
          ]),
        ),
      );

  Widget _brokenImage({double? size}) => Container(
        width: size,
        height: size,
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );

  // Thumbnail: tap to preview full screen, × to remove
  Widget _imageThumb(ImageProvider provider, {required VoidCallback onRemove}) =>
      SizedBox(
        width: 90,
        height: 90,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => _previewImage(provider, onRemove: onRemove),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image(
                  image: provider,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _brokenImage(size: 90),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );

  void _previewImage(ImageProvider provider, {required VoidCallback onRemove}) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image(
                    image: provider,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _brokenImage(size: 120),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Remove image',
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onRemove();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // FORM DESIGN — step indicator, section header, field style,
  // "Add custom field" button
  // ══════════════════════════════════════════════════════════

  static const _stepLabels = [
    'Basic',
    'Business',
    'Location',
    'Manage',
    'Notes',
  ];

  /// Numbered circles with labels; the active one has a soft ring, done
  /// steps turn green with a check. Tapping jumps to a step (moving past
  /// Basic still needs Basic to be valid).
  Widget _stepper() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _stepLabels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i > 0 && _step == 0 && !_validateStep0()) return;
                  setState(() => _step = i);
                },
                child: Column(children: [
                  SizedBox(
                    height: 38,
                    child: Row(children: [
                      Expanded(child: i > 0 ? _stepDash(i - 1) : const SizedBox()),
                      _stepCircle(i),
                      Expanded(
                          child: i < _stepLabels.length - 1
                              ? _stepDash(i)
                              : const SizedBox()),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stepLabels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          i == _step ? FontWeight.w600 : FontWeight.w500,
                      color: i == _step
                          ? AppColors.primary
                          : AppColors.textHint,
                    ),
                  ),
                ]),
              ),
            ),
        ],
      );

  Widget _stepCircle(int i) {
    final done = i < _step;
    final active = i == _step;
    final circle = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? AppColors.success
            : active
                ? AppColors.primary
                : AppColors.divider,
        shape: BoxShape.circle,
      ),
      child: done
          ? const Icon(Icons.check, color: Colors.white, size: 15)
          : Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textHint,
              ),
            ),
    );
    if (!active) return circle;
    // Soft ring around the active step
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: circle,
    );
  }

  /// Short dash between step i and i + 1.
  Widget _stepDash(int i) => Center(
        child: Container(
          width: 12,
          height: 2,
          decoration: BoxDecoration(
            color: i < _step ? AppColors.success : AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  /// Icon tile · title · rule, at the top of each step.
  Widget _stepHeader(String title, IconData icon, {Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 2),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Divider(color: AppColors.border, thickness: 1),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing],
        ]),
      );

  /// White, rounded, bordered — matches CrmTextField.
  InputDecoration _formFieldDecoration({String? hint, Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surface,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 1.5),
    );
  }

  /// Full-width dashed "+ Add custom field" for one section.
  Widget _addCustomFieldButton(String cardTitle) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: AppColors.primary.withOpacity(0.4),
            radius: 14,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openCreateCustomField(cardTitle),
              child: const SizedBox(
                height: 52,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Add custom field',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _fieldError(String? error) => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text(
            error,
            style: const TextStyle(fontSize: 11, color: AppColors.danger),
          ),
        );

  Widget _basicStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader('Basic Information', Icons.person_outline),
        CrmTextField(
            label: 'Lead Name',
            required: true,
            hint: 'Full name',
            controller: _name,
            onChanged: (v) {
              final err = _validateName(v);
              if (_nameError != err) setState(() => _nameError = err);
            }),
        _fieldError(_nameError),
        const SizedBox(height: 14),
        CrmTextField(
            label: 'Company Name',
            required: true,
            hint: 'Organisation',
            controller: _company,
            onChanged: (v) {
              final err = _validateCompany(v);
              if (_companyError != err) setState(() => _companyError = err);
            }),
        _fieldError(_companyError),
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
  disableLengthCheck: false,
  decoration: _formFieldDecoration(
    hint: 'Enter phone number',
  ),
  onChanged: (phone) {
    _phoneCountryCode = phone.countryCode;
    final err = _validatePhone(phone.number);
    if (_phoneError != err) setState(() => _phoneError = err);
    _scheduleDuplicateCheck();
  },
  onCountryChanged: (country) {
    setState(() {
      _phoneCountryCode = '+${country.dialCode}';
      _phoneError = null;
    });
  },
  onSubmitted: (_) {},
  validator: (phone) {
  if (phone == null || phone.number.trim().isEmpty) {
    return 'Phone number is required';
  }

  try {
    if (!phone.isValidNumber()) {
      return 'Enter a valid phone number';
    }
  } catch (_) {
    return 'Enter a valid phone number';
  }

  return null;
},
),            _fieldError(_phoneError),
            _duplicateWarning('phone number', _phoneDupLead),
            const SizedBox(height: 6),
                // Alternative Mobile Number — Basic Information
    Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      'Alternative Mobile Number',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
    const SizedBox(height: 6),
    IntlPhoneField(
  controller: _alternatePhone,
  initialCountryCode: _getInitialCountryCode(
    widget.existingLead?.alternatePhoneNumber ?? '',
  ),
  showCountryFlag: true,
  disableLengthCheck: false,
  decoration: _formFieldDecoration(
    hint: 'Enter alternative phone number',
  ),
  onChanged: (phone) {
    _alternatePhoneCountryCode = phone.countryCode;
  },
  onCountryChanged: (country) {
    setState(() {
      _alternatePhoneCountryCode = '+${country.dialCode}';
    });
  },
  validator: (phone) {
  // Alternative phone is optional.
  if (phone == null || phone.number.trim().isEmpty) {
    return null;
  }

  try {
    if (!phone.isValidNumber()) {
      return 'Enter a valid alternative phone number';
    }
  } catch (_) {
    return 'Enter a valid alternative phone number';
  }

  return null;
},
),
  ],
),
                const SizedBox(height: 6),

            CrmTextField(
              label: 'Email',
              hint: 'name@gmail.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              enableInteractiveSelection: true,
              onChanged: (v) {
                final err = _validateEmail(v);
                if (_emailError != err) {
                  setState(() => _emailError = err);
                }
                _scheduleDuplicateCheck();
              },
            ),

                const SizedBox(height: 6),

    // Alternative Email — Basic Information
    CrmTextField(
      label: 'Alternative Email',
      hint: 'alternative@gmail.com',
      controller: _alternateEmail,
      keyboardType: TextInputType.emailAddress,
      enableInteractiveSelection: true,
    ),

            _fieldError(_emailError),
            _duplicateWarning('email', _emailDupLead),
          ],
        ),
        const SizedBox(height: 14),
        
            ..._customFields
    .where((e) => e.cardTitle == "Basic Information")
    .map((e) => _buildCustomField(e)),
        _addCustomFieldButton("Basic Information"),
      ]);

  Widget _businessStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader('Business Details', Icons.business_outlined),
        CrmDropdown(
            label: 'Industry',
            value: _industry,
            items: _industries,
            hint: 'Select Industry',
            onChanged: (v) => setState(() => _industry = v)),
        if (_industry == 'Other') ...[
          const SizedBox(height: 14),
          CrmTextField(
              label: 'Other Industry',
              hint: 'Enter industry',
              controller: _otherIndustry),
        ],
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
        const SizedBox(height: 14),
        CrmTextField(
            label: 'Number of Employees',
            hint: 'e.g. 50',
            controller: _employees,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ]),
            ..._customFields
    .where((e) => e.cardTitle == "Business Details")
    .map((e) => _buildCustomField(e)),
        _addCustomFieldButton("Business Details"),
      ]);
    
  Widget _locationStep() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // LOCATION HEADING (+ fill from current location)
      _stepHeader(
        'Location',
        Icons.location_on_outlined,
        trailing: IconButton(
          tooltip: 'Get current location',
          icon: const Icon(
            Icons.my_location,
            color: AppColors.primary,
          ),
          onPressed: _fetchCurrentLocation,
        ),
      ),

      const SizedBox(height: 12),

      // ADDRESS
      CrmTextField(
        label: 'Address',
        controller: _addr,
      ),

      const SizedBox(height: 12),

      // CITY
      CrmTextField(
        label: 'City',
        controller: _city,
      ),

      const SizedBox(height: 12),

      // STATE
      CrmTextField(
        label: 'State',
        controller: _state,
      ),

      const SizedBox(height: 12),

      // PINCODE
      CrmTextField(
        label: 'Pincode',
        controller: _pincode,
      ),

      const SizedBox(height: 12),

      // COUNTRY
      CrmDropdown(
        label: 'Country',
        value: _country,
        items: _countries,
        hint: 'Select Country',
        onChanged: (value) {
          setState(() {
            _country = value;
          });
        },
      ),

      const SizedBox(height: 12),

      // LATITUDE
      CrmTextField(
        label: 'Latitude',
        controller: _latitude,
      ),

      const SizedBox(height: 12),

      // LONGITUDE
      CrmTextField(
        label: 'Longitude',
        controller: _longitude,
      ),

      const SizedBox(height: 20),

        // =========================
// IMAGE SECTION
// =========================
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.primaryLight,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: AppColors.primary.withOpacity(0.2),
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(
            Icons.image_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),

          const Text(
            'Images',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),

          const Spacer(),

          IconButton(
            tooltip: 'Upload image',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.primary,
            ),
            onPressed: _pickLeadImage,
          ),
        ],
      ),

      const SizedBox(height: 12),

      // Existing + newly selected images
      if ((widget.existingLead?.images.isNotEmpty ?? false) ||
          _selectedImages.isNotEmpty)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // Existing images
            if (widget.existingLead != null)
              ...widget.existingLead!.images.map((image) => _imageThumb(
                    NetworkImage(_getImageUrl(image.path)),
                    onRemove: () => setState(
                        () => widget.existingLead!.images.remove(image)),
                  )),

            // Newly selected images
            ..._selectedImages.map((image) => _imageThumb(
                  FileImage(File(image.path)),
                  onRemove: () =>
                      setState(() => _selectedImages.remove(image)),
                )),
          ],
        )
      else
        const Text(
          'No images uploaded',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
    ],
  ),
),

    ],
  );
}
  Widget _manageStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader('Lead Management', Icons.assignment_outlined),
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
        if (_assigneeLocked)
          // Read-only: sales users can't reassign.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  _lockedAssigneeName.isNotEmpty
                      ? _lockedAssigneeName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _lockedAssigneeName.isNotEmpty
                      ? _lockedAssigneeName
                      : 'Assigned to you',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
              const Icon(Icons.lock_outline,
                  size: 16, color: AppColors.textHint),
            ]),
          )
        else if (_salesUsers.isEmpty)
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
        ..._customFields
    .where((e) => e.cardTitle == "Lead Management")
    .map((e) => _buildCustomField(e)),
        _addCustomFieldButton("Lead Management"),
      ]);

  Widget _notesStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader('Additional Information', Icons.notes_outlined),
        CrmTextField(
            label: 'Notes',
            hint: 'Context, observations...',
            controller: _notes,
            maxLines: 6),
            ..._customFields
    .where((e) => e.cardTitle == "Additional Information")
    .map((e) => _buildCustomField(e)),
        _addCustomFieldButton("Additional Information"),
        const SizedBox(height: 20),

        Container(
          
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.attach_file, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('Attachments',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
      

              const SizedBox(width: 6),
              const Text('(max 5 MB each)',
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
      //
      
      
      Future<void> _openCreateCustomField(String cardTitle) async {
  final nameController = TextEditingController();

  String fieldType = 'text';

  final List<TextEditingController> optionControllers = [];

  final result = await showDialog<CustomField>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Create Custom Field"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Field Name",
                    ),
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: fieldType,
                    decoration: const InputDecoration(
                      labelText: "Field Type",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'text',
                        child: Text("Text"),
                      ),
                      DropdownMenuItem(
                        value: 'number',
                        child: Text("Number"),
                      ),
                      DropdownMenuItem(
                        value: 'date',
                        child: Text("Date"),
                      ),
                      DropdownMenuItem(
                        value: 'dropdown',
                        child: Text("Dropdown"),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;

                      setDialogState(() {
                        fieldType = v;

                        // Clear options when changing away
                        // from dropdown.
                        if (fieldType != 'dropdown') {
                          for (final controller
                              in optionControllers) {
                            controller.dispose();
                          }
                          optionControllers.clear();
                        }
                      });
                    },
                  ),

                  // ⭐ DROPDOWN OPTIONS
                  if (fieldType == 'dropdown') ...[
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Dropdown Options',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    ...List.generate(
                      optionControllers.length,
                      (index) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller:
                                      optionControllers[index],
                                  decoration: InputDecoration(
                                    labelText:
                                        'Option ${index + 1}',
                                    border:
                                        const OutlineInputBorder(),
                                  ),
                                ),
                              ),

                              IconButton(
  icon: const Icon(
    Icons.close,
    color: Colors.red,
  ),
  onPressed: () {
    setDialogState(() {
      final controller =
          optionControllers.removeAt(index);

      controller.dispose();
    });
  },
),
                            ],
                          ),
                        );
                      },
                    ),

                    OutlinedButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          optionControllers.add(
                            TextEditingController(),
                          );
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Option'),
                    ),
                  ],
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text("Cancel"),
              ),

              ElevatedButton(
                onPressed: () {
                  final fieldName =
                      nameController.text.trim();

                  if (fieldName.isEmpty) {
                    return;
                  }

                  // ⭐ Get dropdown options
                  final options = optionControllers
                      .map((controller) =>
                          controller.text.trim())
                      .where((value) => value.isNotEmpty)
                      .toList();

                  // ⭐ THIS IS YOUR CustomField(...)
                  Navigator.pop(
                    dialogContext,
                    CustomField(
                      id: '',
                      cardTitle: cardTitle,
                      name: fieldName,
                      type: fieldType,
                      options: options,
                        value: fieldType == 'dropdown' && options.isNotEmpty
      ? options.first
      : '',

                    ),
                  );
                },
                child: const Text("Create"),
              ),
            ],
          );
        },
      );
    },
  );

  // Dispose controllers
  
  if (result != null && mounted) {
    setState(() {
      _customFields.add(result);
    });
  }
}
// ==================
// this is for custom field
// ==================
Widget _buildCustomField(CustomField field) {
  Widget fieldWidget;

  switch (field.type) {
    case 'number':
      fieldWidget = TextFormField(
        initialValue: field.value,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: _formFieldDecoration(hint: field.name),
        onChanged: (value) => field.value = value,
      );
      break;

    case 'dropdown':
    case 'select':
      fieldWidget = DropdownButtonFormField<String>(
        value: field.options.contains(field.value) ? field.value : null,
        isExpanded: true,
        decoration: _formFieldDecoration(hint: 'Select'),
        items: field.options
            .map((option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (String? selectedValue) {
          if (selectedValue == null) return;
          // Update the actual CustomField object
          setState(() => field.value = selectedValue);
        },
      );
      break;

    case 'date':
      fieldWidget = InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final initialDate =
              DateTime.tryParse(field.value) ?? DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked == null || !mounted) return;
          setState(() {
            field.value = DateFormat('yyyy-MM-dd').format(picked);
          });
        },
        child: InputDecorator(
          decoration: _formFieldDecoration(
            suffix: const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.textSecondary),
          ),
          child: Text(
            field.value.isEmpty ? 'Select date' : field.value,
            style: TextStyle(
              fontSize: 14,
              color: field.value.isEmpty
                  ? AppColors.textHint
                  : AppColors.textPrimary,
            ),
          ),
        ),
      );
      break;

    case 'text':
    default:
      fieldWidget = TextFormField(
        initialValue: field.value,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: _formFieldDecoration(hint: field.name),
        onChanged: (value) => field.value = value,
      );
  }

  return Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + "Custom" tag
        Row(children: [
          Flexible(
            child: Text(
              field.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Custom',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fieldWidget),
            const SizedBox(width: 10),
            // Square trash button, same height as the field
            SizedBox(
              width: 50,
              height: 50,
              child: OutlinedButton(
                onPressed: () => _removeCustomField(field),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Saved fields (with an id) ask first; a field added in this session
/// is just dropped.
Future<void> _removeCustomField(CustomField field) async {
  if (field.id.isNotEmpty) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove custom field?'),
        content: Text('Remove "${field.name}" from this lead?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
  }
  setState(() => _customFields.remove(field));
}

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
