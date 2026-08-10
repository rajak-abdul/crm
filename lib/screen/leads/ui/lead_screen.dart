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
    show AppConstants, Lead, AppUser, Attachment, CustomField;
import 'package:crm_app/screen/deals/modal/deal_modal.dart' show DealConstants;
import 'package:crm_app/screen/leads/cubit/call_cubit.dart';
import 'package:crm_app/screen/leads/cubit/lead_cubit.dart';
import 'package:crm_app/screen/leads/ui/lead.dart';
import 'package:crm_app/screen/leads/ui/reject_lead_screen.dart';
import 'package:crm_app/shareWidgets/missed_followup.dart';
import 'package:crm_app/shareWidgets/missed_followup_helper.dart';
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
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
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
  final String? selectedLeadId;
  final bool showBackButton;

  const LeadsScreen({
  super.key,
  this.selectedLeadId,    
  this.showBackButton = false,
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
        ),
      );
}

class _LeadsView extends StatefulWidget {
    final String? selectedLeadId;
    final bool showBackButton;
    
const _LeadsView({
    super.key,
    this.selectedLeadId,
    required this.showBackButton,

  });
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
  String _followupFilter = 'All Follow-ups';
   final List<String> _followupItems = [
  'All Follow-ups',
  'Today Follow-ups',
  'Missed Follow-ups',
  'Completed Follow-ups',
];
  bool _showRejectedOnly = false;

  final TextEditingController reasonController = TextEditingController();

  final Map<String, String> _assigneeIdToName = {};
  List<String> _assigneeDropdownItems = ['All Assignees'];

  int _currentPage = 1;
  bool _missedPopupShown = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
DateTime? _fromDate;
DateTime? _toDate;
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
  
Future<void> _showMissedFollowups(List<Lead> leads) async {
  if (_missedPopupShown) return;

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id') ?? '';

  final missedLeads = MissedFollowupHelper.getMissedFollowups(
    leads: leads,
    loggedInUserId: userId,
  );

  if (!mounted || missedLeads.isEmpty) return;

  _missedPopupShown = true;

  showDialog(
    context: context,
    builder: (_) => MissedFollowupDialog(
      missedLeads: missedLeads,
      onViewLead: (lead) {
        
        openDetail(context, lead);  
      },
    ),
  );
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

    return matchesSearch &&
    matchesStatus &&
    matchesSource &&
    matchesClientType &&
    matchesAssignee &&
    matchesFollowup &&
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LeadCubit, LeadState>(
      listener: (ctx, state) {
        if (state is LeadLoaded && !PermissionHelper.can('users_roles')) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showMissedFollowups(state.leads);
  });
}
        if (state is LeadActionSuccess) showApiSnack(ctx, state.message);
        if (state is LeadError && _isSessionExpiredMessage(state.message)) {
          Navigator.of(ctx, rootNavigator: true)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      builder: (context, state) {
        final allFiltered = state is LeadLoaded ? _filter(state.leads) : <Lead>[];

      if (state is LeadLoaded && widget.selectedLeadId != null) {
    final lead = state.leads.firstWhere(
      (e) => e.id == widget.selectedLeadId,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      openDetail(context, lead);
    });
  }
        final leads = allFiltered; // CHANGED — no more _paginate(); server already gave us one page
        final allCount = state is LeadLoaded ? (state.totalCount ?? state.leads.length) : 0;
        final totalPages = _totalPages(state);

        return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
  width: 250,
  child: SafeArea(
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          decoration: const BoxDecoration(
            color: AppColors.primary,
          ),
          child: const Row(
            children: [
              Icon(
                Icons.filter_alt,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Text(
                "Filters",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _FilterDrop(
  value: _statusFilter,
  items: const [
    'All Status',
    ...AppConstants.leadStatuses,
  ],
  icon: Icons.flag_outlined,
  onChanged: (v) {
    setState(() {
      _statusFilter = v!;
    });
  },
),

const SizedBox(height: 16),
_FilterDrop(
  value: _sourceFilter,
  items: const [
    'All Sources',
    ...AppConstants.leadSources,
  ],
  icon: Icons.radar_outlined,
  onChanged: (v) {
    setState(() {
      _sourceFilter = v!;
    });
  },
),

const SizedBox(height: 16),
_FilterDrop(
  value: _clientTypeFilter,
  items: const [
    'All Client Types',
    'B2B',
    'B2C',
  ],
  icon: Icons.business_outlined,
  onChanged: (v) {
    setState(() {
      _clientTypeFilter = v!;
    });
  },
),

const SizedBox(height: 16),
if (PermissionHelper.can('users_roles'))
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
      setState(() {
        _assigneeFilter = v!;
      });
    },
  ),
  

if (PermissionHelper.can('users_roles'))
  const SizedBox(height: 16),
  _FilterDrop(
  value: _followupFilter,
  items: _followupItems,
  icon: Icons.event_available_outlined,
  onChanged: (value) async {
  if (value == null) return;

  setState(() {
    _followupFilter = value;
  });

  await context.read<LeadCubit>().fetchAllLeads();
},
),

const SizedBox(height: 16),
InkWell(
  onTap: () async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDate: _fromDate ?? DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _fromDate = date;
      });
    }
  },
  child: InputDecorator(
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.calendar_today),
      border: OutlineInputBorder(),
    ),
    child: Text(
      _fromDate == null
          ? "From Date"
          : "${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}",
    ),
  ),
),

const SizedBox(height: 16),

InkWell(
  onTap: () async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDate: _toDate ?? DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _toDate = date;
      });
    }
  },
  child: InputDecorator(
    decoration: const InputDecoration(
      //labelText: "To Date",
      prefixIcon: Icon(Icons.calendar_today),
      border: OutlineInputBorder(),
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
  await context.read<LeadCubit>().fetchAllLeads();
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
      ],
    ),
  ),
),
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
      icon: const Icon(Icons.filter_alt_outlined),
      onPressed: () {
        _scaffoldKey.currentState!.openDrawer();
      },
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
                child: _buildList(context, state, leads, allFiltered.length)),
            if (state is LeadLoaded && allFiltered.isNotEmpty)
  _PaginationBar(
    page: _currentPage,
    totalPages: totalPages,
    totalItems: allCount,
    pageSize: _kPageSize,
    onPrev: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
    onNext: _currentPage < totalPages ? () => _goToPage(_currentPage + 1) : null,
  ),
          ]),
          
      floatingActionButton:Padding(
        padding: const EdgeInsets.only(bottom: 60), // Move FAB up
        child: FloatingActionButton(
          onPressed: () => _openCreate(context),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      )
    
        );
      },
    );
    
  }
Future<void> showExportLeadsDialog(BuildContext context,LeadCubit leadCubit) async {
  DateTime? startDate;
  DateTime? endDate;

  await showDialog(
    context: context,
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
                    "Optionally filter by date range. Leave both blank to export all leads.",
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
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.download,color: Colors.white,),
                label: const Text("Export"),
                onPressed: ()async {

                  // Call Export API here
                  await leadCubit.exportLeads(
  startDate: startDate,
  endDate: endDate,
);
debugPrint("exportLeads called");
                  Navigator.pop(context);

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
      onRefresh: () => context.read<LeadCubit>().fetchAllLeads(page: _currentPage, limit: _kPageSize), // CHANGED
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
          body: BlocProvider.value(
            value: cubit,
            child: LeadDetailSheet(lead: fullLead ?? lead),
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
class LeadDetailSheet extends StatefulWidget {
  final Lead lead;
  const LeadDetailSheet({super.key, required this.lead});

  @override
  State<LeadDetailSheet> createState() => LeadDetailSheetState();
}

class LeadDetailSheetState extends State<LeadDetailSheet> {
 late Lead _currentLead;           // ADD
  Lead get lead => _currentLead;
  String _getImageUrl(String path) {
  if (path.startsWith('http://') ||
      path.startsWith('https://')) {
    return path;
  }

  return 'https://crm-backend-api.techzarinfo.cloud$path';
}
  final AudioPlayer _player = AudioPlayer();
    final ScrollController _followUpsScrollController = ScrollController(); // ADD

 @override
  void initState() {               // ADD
    super.initState();
    _currentLead = widget.lead;
  }


  @override
  void dispose() {
    _player.stop();
    _player.dispose();
        _followUpsScrollController.dispose(); // ADD
    super.dispose();
  }




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
    const base = 'https://crm.techzarinfo.cloud';
    final clean = rawPath.startsWith('/') ? rawPath : '/$rawPath';
    return '$base$clean';
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

  @override
  Widget build(BuildContext ctx) => DefaultTabController(
        length: 3,
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
                  tabs: [Tab(text: 'Details'), Tab(text: 'Activity'), Tab(text: 'Follow-ups'),],
                ),
              ),
              const Divider(height: 16, color: AppColors.divider),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildDetailsTab(ctrl),
                    _buildActivityTab(ctrl),
                    _buildFollowUpsTab(), // ADD
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
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

  Widget infoItem(
    IconData icon,
    String label,
    String value, {
    bool clickable = false,
  }) {
    return Padding(
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      clickable: lead.email.trim().isNotEmpty,
    ),
    infoItem(
      Icons.email_outlined,
      'Alternate Email',
      valueOrDash(lead.alternateEmail),
    ),
    infoItem(
      Icons.phone_outlined,
      'Phone',
      lead.phone.trim().isEmpty
          ? 'Not specified'
          : _formatPhone(lead.phone),
      clickable: lead.phone.trim().isNotEmpty,
    ),
    infoItem(
      Icons.phone_outlined,
      'Alternate Phone',
      lead.alternatePhoneNumber.trim().isEmpty
          ? 'Not specified'
          : _formatPhone(lead.alternatePhoneNumber),
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

      // ==========================================================
      // IMAGES
      // ==========================================================

      if (lead.images.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 16),

        const Text(
          'Images',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: lead.images.map(
            (image) {
              final imageUrl = _getImageUrl(image.path);

              return GestureDetector(
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

              // Close button
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
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
          ),
        );
      },
    ),
  ),
);
            },
          ).toList(),
        ),
      ],

      // ==========================================================
      // ATTACHMENTS
      // ==========================================================

      if (lead.attachments.isNotEmpty) ...[
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        const Text(
          'Attachments',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        ...lead.attachments.map(
          (a) => Builder(
            builder: (tileCtx) => Container(
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
                    Icons.insert_drive_file,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
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
                        const SizedBox(height: 3),
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
                    onPressed: () =>
                        _previewFile(tileCtx, a.path),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.download,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    tooltip: 'Download',
                    onPressed: () =>
                        _downloadFile(tileCtx, a.path, a.name),
                  ),
                ],
              ),
            ),
          ),
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
  String _getImageUrl(String path) {
  if (path.startsWith('http://') ||
      path.startsWith('https://')) {
    return path;
  }

  return 'https://crm-backend-api.techzarinfo.cloud$path';
}

  String _phoneCountryCode = '+91';
    final List<XFile> _selectedImages = [];
    final List<PlatformFile> _leadImages = [];

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
    _email = TextEditingController(text: l?.email);
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
    for (final c in [
  _name,
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
  _notes,
]) {
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
city: _city.text.trim(),
state: _state.text.trim(),
pincode: _pincode.text.trim(),
country: _country ?? '',
latitude: double.tryParse(_latitude.text.trim()),
longitude: double.tryParse(_longitude.text.trim()),
      industry: _industry ?? '',
      source: _source ?? '',
      clientType: _clientType ?? '',
      requirement: _req.text.trim(),
      status: _status,
      assignTo: _selectedAssignUserId ?? '',
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
                  children: [
  'Basic',
  'Business',
  'Location',
  'Manage',
  'Notes',
]                      .asMap()
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
                  if (_step == 2) _locationStep(),
                  if (_step == 3) _manageStep(),
                  if (_step == 4) _notesStep(),
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
    : (_step < 4
        ? () {
            if (_step == 0 && !_validateStep0()) return;

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
        size: 16,
      ),
                      label: Text(
  _saving
      ? 'Saving...'
      : (_step < 4
          ? 'Next'
          : (_isEdit ? 'Update' : 'Save to Server')),
),
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
         SectionHeader(
  title: "Basic Information",
  icon: Icons.person_outline,
  onAddField: () => _openCreateCustomField("Basic Information"),
),
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
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12), // change to 10 if needed
              ],
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
        
            ..._customFields
    .where((e) => e.cardTitle == "Basic Information")
    .map((e) => _buildCustomField(e)),
      ]);

  Widget _businessStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         SectionHeader(
  title: "Business Details",
  icon: Icons.business_outlined,
  onAddField: () => _openCreateCustomField("Business Details"),
),
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
            ..._customFields
    .where((e) => e.cardTitle == "Business Details")
    .map((e) => _buildCustomField(e)),
      ]);
    
  Widget _locationStep() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // LOCATION HEADING
      Row(
        children: [
          const Expanded(
            child: Text(
              'Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 👇 PASTE THE ICON BUTTON HERE
          IconButton(
            tooltip: 'Get current location',
            icon: const Icon(
              Icons.my_location,
              color: AppColors.primary,
            ),
            onPressed: _fetchCurrentLocation,
          ),
        ],
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
    ],
  );
}
  Widget _manageStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         SectionHeader(
  title: "Lead Management",
  icon: Icons.assignment_outlined,
  onAddField: () => _openCreateCustomField("Lead Management"),
),
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
        ..._customFields
    .where((e) => e.cardTitle == "Lead Management")
    .map((e) => _buildCustomField(e)),
      ]);

  Widget _notesStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         SectionHeader(
  title: "Additional Information",
  icon: Icons.notes_outlined,
  onAddField: () => _openCreateCustomField("Additional Information"),
),
        CrmTextField(
            label: 'Notes',
            hint: 'Context, observations...',
            controller: _notes,
            maxLines: 6),
            ..._customFields
    .where((e) => e.cardTitle == "Additional Information")
    .map((e) => _buildCustomField(e))
    .toList(),
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
              ...widget.existingLead!.images.map((image) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _getImageUrl(image.path),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),

                    Positioned(
                      top: -7,
                      right: -7,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            widget.existingLead!.images.remove(image);
                          });
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),

            // Newly selected images
            ..._selectedImages.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(image.path),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),

                  Positioned(
                    top: -7,
                    right: -7,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImages.removeAt(index);
                        });
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
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

const SizedBox(height: 16),
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
 if ((widget.existingLead?.images.isNotEmpty ?? false) ||
    _selectedImages.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // =========================
        // EXISTING SERVER IMAGES
        // =========================
                          

        if (widget.existingLead != null)
          ...widget.existingLead!.images.map((image) {
              final imageUrl = _getImageUrl(image.path);

  debugPrint('IMAGE PATH FROM API: ${image.path}');
  debugPrint('IMAGE URL: $imageUrl');

            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),


                  
                  child: Image.network(
                    _getImageUrl(image.path),
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),

                // X button
                Positioned(
                  top: -8,
                  right: -8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        widget.existingLead!.images.remove(image);
                      });
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),

        // =========================
        // NEWLY UPLOADED IMAGES
        // =========================
        ..._selectedImages.asMap().entries.map((entry) {
          final index = entry.key;
          final image = entry.value;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(image.path),
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                ),
              ),

              // X button
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImages.removeAt(index);
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    ),
  ),
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
    case 'text':
      fieldWidget = TextFormField(
        initialValue: field.value,
        decoration: InputDecoration(
          labelText: field.name,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          field.value = value;
        },
      );
      break;

    case 'number':
      fieldWidget = TextFormField(
        initialValue: field.value,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: field.name,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          field.value = value;
        },
      );
      break;

    case 'dropdown':
case 'select':
  fieldWidget = DropdownButtonFormField<String>(
    value: field.options.contains(field.value)
        ? field.value
        : null,

    decoration: InputDecoration(
      labelText: field.name,
      border: const OutlineInputBorder(),
    ),

    items: field.options.map((option) {
      return DropdownMenuItem<String>(
        value: option,
        child: Text(option),
      );
    }).toList(),

    onChanged: (String? selectedValue) {
      if (selectedValue == null) return;

      // IMPORTANT: update the actual CustomField object
      field.value = selectedValue;

      debugPrint(
        'DROPDOWN CHANGED => '
        'name=${field.name}, '
        'value=${field.value}, '
        'options=${field.options}',
      );

      setState(() {});
    },
  );
  break;
    case 'date':
      fieldWidget = InkWell(
        onTap: () async {
          DateTime initialDate = DateTime.now();

          if (field.value.isNotEmpty) {
            try {
              initialDate = DateTime.parse(field.value);
            } catch (_) {}
          }

          final picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );

          if (picked == null || !mounted) return;

          final formatted =
              DateFormat('yyyy-MM-dd').format(picked);

          setState(() {
            field.value = formatted;
          });
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: field.name,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(
            field.value.isEmpty
                ? 'Select date'
                : field.value,
          ),
        ),
      );
      break;

    default:
      fieldWidget = TextFormField(
        initialValue: field.value,
        decoration: InputDecoration(
          labelText: field.name,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          field.value = value;
        },
      );
  }
  

  return Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: fieldWidget,
        ),

        const SizedBox(width: 4),

        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          icon: const Icon(
            Icons.close,
            size: 20,
            color: Colors.red,
          ),
          onPressed: () async {
            if (field.id.isNotEmpty) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text(
                      'Remove custom field?',
                    ),
                    content: Text(
                      'Remove "${field.name}" from this lead?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                            false,
                          );
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                            true,
                          );
                        },
                        child: const Text('Remove'),
                      ),
                    ],
                  );
                },
              );

              if (confirmed != true || !mounted) {
                return;
              }
            }

            setState(() {
              _customFields.remove(field);
            });
          },
        ),
      ],
    ),
  );
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
