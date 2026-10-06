// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/dashboard/ui/dashboard_screen.dart        ║
// ╚══════════════════════════════════════════════════════════════╝

// ignore_for_file: unnecessary_cast

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm_app/modals/followup_model.dart';
import 'package:crm_app/screen/LeaderBoard/ui/leader_board.dart';
import 'package:crm_app/screen/calendar/UI/calendar_screen.dart';
import 'package:crm_app/screen/dashboard/cubit/dashboard.dart';
import 'package:crm_app/screen/dashboard/cubit/notification_cubit.dart';
import 'package:crm_app/screen/dashboard/ui/dashboard_followup_page.ui.dart';
import 'package:crm_app/screen/dashboard/ui/meeting_summary_card.dart';
import 'package:crm_app/screen/document/deal/cubit/deal_doc_cubit.dart';
import 'package:crm_app/screen/document/deal/ui/deal_doc_ui.dart' show DealDocumentScreen;
import 'package:crm_app/screen/document/lead/cubit/leads_document_cubit.dart';
import 'package:crm_app/screen/document/lead/ui/lead_document_ui.dart';
import 'package:crm_app/screen/email/cubit/email_cubit.dart';
import 'package:crm_app/screen/email/cubit/email_history_cubit.dart';
import 'package:crm_app/screen/email/cubit/scheduled_email_cubit.dart';
import 'package:crm_app/screen/email/ui/EmailContactsScreen.dart';
import 'package:crm_app/screen/leads/ui/lead_screen.dart';
import 'package:crm_app/screen/message/cubit/chat_cubit.dart'
    show chatUnreadTotal, refreshChatUnreadTotal;
import 'package:crm_app/screen/message/ui/message_screen.dart';
import 'package:crm_app/screen/meeting/UI/meeting.dart';
import 'package:crm_app/screen/meeting/cubit/meeting_cubit.dart';
import 'package:crm_app/screen/proposal/UI/proposal_screen.dart';
import 'package:crm_app/screen/proposal/cubit/proposal_cubit.dart';
import 'package:crm_app/screen/tasks/view/target_screen.dart'
    show TargetScreen;
import 'package:crm_app/screen/tasks/view/task_screen.dart' show TaskScreen;
import 'package:crm_app/screen/users/user_cubit.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:crm_app/shareWidgets/crm_header.dart';
import 'package:crm_app/utils/missed_followup_timer.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:crm_app/modals/modals.dart' show Lead, AppConstants;
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show StatusBadge, EmptyState, LoadingState, ErrorState;
import 'package:crm_app/screen/deals/ui/deal_screen.dart' show DealsScreen;
import 'package:crm_app/screen/profile/ui/profile_screen.dart'
    show ProfileScreen;
import '../../invoice/ui/invoice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

String? _resolveProfileImageUrl(String? rawInput) {
  final raw = rawInput?.trim() ?? '';
  if (raw.isEmpty) return null;
  var path = raw.replaceAll('\\', '/');
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  if (!path.contains('/')) path = '/uploads/users/$path';
  if (!path.startsWith('/')) path = '/$path';
  return 'https://crm-backend-api.techzarinfo.cloud/$path';
}

String _initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

// ══════════════════════════════════════════════════════════════
// INVOICE RECORD MODEL
// ══════════════════════════════════════════════════════════════
class InvoiceRecord {
  final String id;
  final String invoiceNumber;
  final String status; // 'paid' | 'unpaid'
  final String currency;
  final double total;
  final double? inrAmount; // server-converted INR (if available)
  final double? exchangeRate; // rate used by server
  final DateTime? issueDate;
  final DateTime? dueDate;
  final DateTime? paidAt;

  const InvoiceRecord({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.currency,
    required this.total,
    this.inrAmount,
    this.exchangeRate,
    this.issueDate,
    this.dueDate,
    this.paidAt,
  });

  static double _d(dynamic v) {
    if (v == null) return 0;
    return double.tryParse(
            v.toString().replaceAll(RegExp(r'[,\s₹\$€£¥]'), '')) ??
        0;
  }

  factory InvoiceRecord.fromJson(Map<String, dynamic> j) => InvoiceRecord(
        id: j['_id']?.toString() ?? j['id']?.toString() ?? '',
        invoiceNumber: j['invoicenumber']?.toString() ??
            j['invoiceNumber']?.toString() ??
            '',
        status: (j['status'] ?? 'unpaid').toString().toLowerCase(),
        currency: (j['currency'] ?? 'INR').toString().toUpperCase(),
        total: _d(j['total'] ?? j['amount'] ?? j['grandTotal']),
        inrAmount: j['inrAmount'] != null ? _d(j['inrAmount']) : null,
        exchangeRate: j['exchangeRate'] != null ? _d(j['exchangeRate']) : null,
        issueDate: j['issueDate'] != null
            ? DateTime.tryParse(j['issueDate'].toString())
            : null,
        dueDate: j['dueDate'] != null
            ? DateTime.tryParse(j['dueDate'].toString())
            : null,
        paidAt: j['paidAt'] != null
            ? DateTime.tryParse(j['paidAt'].toString())
            : null,
      );
  Map<String, dynamic> toJson() => {
        '_id': id,
        'invoiceNumber': invoiceNumber,
        'status': status,
        'currency': currency,
        'total': total,
        'inrAmount': inrAmount,
        'exchangeRate': exchangeRate,
        'issueDate': issueDate?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
      };
}

// ══════════════════════════════════════════════════════════════
// DASHBOARD SUMMARY MODEL
// ══════════════════════════════════════════════════════════════
class DashboardSummary extends Equatable {
  final int totalLeads;
  final int totalDeals;
  final int dealsWon;
  final int pendingLeads; // leads not yet converted/closed
  final double leadsChange;
  final double dealsChange;
  final double paidRevenue; // in INR — shown as "Total Revenue" on card 3
  final double unpaidRevenue; // in INR
  final double totalRevenue; // in INR
  final String preferredCurrency;
  final int pendingInvoices;

  const DashboardSummary({
    this.totalLeads = 0,
    this.totalDeals = 0,
    this.dealsWon = 0,
    this.pendingLeads = 0,
    this.pendingInvoices = 0,
    this.leadsChange = 0,
    this.dealsChange = 0,
    this.paidRevenue = 0,
    this.unpaidRevenue = 0,
    this.totalRevenue = 0,
    this.preferredCurrency = 'INR',
  });

  static int _i(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
  static double _d(dynamic v) =>
      v == null ? 0 : double.tryParse(v.toString()) ?? 0;

factory DashboardSummary.fromSummaryJson(
    Map<String, dynamic> j) {
  Map<String, dynamic> d = j;

  for (final k in [
    'data',
    'summary',
    'stats',
    'overview',
    'result',
  ]) {
    if (j[k] is Map) {
      d = Map<String, dynamic>.from(j[k] as Map);
      break;
    }
  }

// ─────────────────────────────────────────────
// TOTAL REVENUE
// Sum preferredCurrencyValue from every currency
// ─────────────────────────────────────────────
double totalRevenue = 0;
String preferredCurrency = 'INR';

final revenueByCurrency =
    d['revenueByCurrency'];

if (revenueByCurrency is Map) {
  for (final value in revenueByCurrency.values) {
    if (value is Map) {
      final currency =
          value['preferredCurrency']?.toString();

      if (currency != null &&
          currency.trim().isNotEmpty) {
        preferredCurrency = currency.trim();
      }

      final preferredValue =
          double.tryParse(
            value['preferredCurrencyValue']?.toString() ?? '0',
          ) ??
          0;

      totalRevenue += preferredValue;
    }
  }
}
  // ─────────────────────────────────────────────
  // PENDING INVOICES
  // Sum count from every currency
  // ─────────────────────────────────────────────
  int pendingInvoiceCount = 0;

  final pendingByCurrency =
      d['pendingInvoicesByCurrency'];

  if (pendingByCurrency is Map) {
    for (final value in pendingByCurrency.values) {
      if (value is Map) {
        pendingInvoiceCount += _i(
          value['count'],
        );
      }
    }
  }

  return DashboardSummary(
    totalLeads: _i(
      d['totalLeads'] ??
          d['total_leads'] ??
          d['leads'] ??
          d['leadsCount'] ??
          d['leadCount'],
    ),

    totalDeals: _i(
      d['totalDeals'] ??
          d['total_deals'] ??
          d['deals'] ??
          d['dealsCount'] ??
          d['dealCount'],
    ),

    dealsWon: _i(
      d['totalDealsWon'] ??
          d['dealsWon'] ??
          d['won'] ??
          d['closedWon'] ??
          d['wonDeals'] ??
          d['deals_won'],
    ),

    pendingLeads: _i(
      d['pendingLeads'] ??
          d['pending_leads'] ??
          d['pending'] ??
          d['openLeads'] ??
          d['activeLeads'],
    ),

    // NEW
    pendingInvoices: pendingInvoiceCount,

    leadsChange: _d(
      d['leadsChange'] ??
          d['leads_change'] ??
          d['leadsGrowth'],
    ),

    dealsChange: _d(
      d['dealsChange'] ??
          d['deals_change'] ??
          d['dealsGrowth'],
    ),

    // NEW
    totalRevenue: totalRevenue,
    preferredCurrency: preferredCurrency,
  );
}

  @override
  List<Object?> get props => [
        totalLeads,
        totalDeals,
        dealsWon,
        pendingLeads,
        pendingInvoices,
        paidRevenue,
        unpaidRevenue,
        totalRevenue,
      ];
}

// ══════════════════════════════════════════════════════════════
// PIPELINE STAGE MODEL
// ══════════════════════════════════════════════════════════════
class PipelineStage extends Equatable {
  final String stage;
  final int count;
  final double value;
  final String currency;

  const PipelineStage({
    required this.stage,
    this.count = 0,
    this.value = 0,
    this.currency = 'INR',
  });

  factory PipelineStage.fromJson(Map<String, dynamic> j) => PipelineStage(
        stage: j['stage']?.toString() ??
            j['stageName']?.toString() ??
            j['_id']?.toString() ??
            j['name']?.toString() ??
            j['label']?.toString() ??
            'Unknown',
        count: DashboardSummary._i(j['count'] ??
            j['dealCount'] ??
            j['deals'] ??
            j['leads'] ??
            j['total'] ??
            j['totalDeals'] ??
            (j['items'] is List ? (j['items'] as List).length : null) ??
            (j['leads'] is List ? (j['leads'] as List).length : null) ??
            (j['records'] is List ? (j['records'] as List).length : null)),
        value: DashboardSummary._d(j['value'] ??
            j['totalValue'] ??
            j['amount'] ??
            j['dealValue'] ??
            j['revenue']),
        currency: j['currency']?.toString() ?? 'INR',
      );

  @override
  List<Object?> get props => [stage, count, value];
}

// ══════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════
abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final Map<String, dynamic>? topPerformer;
  final List<Lead> allLeads;
  final List<Lead> recentLeads;
  final DashboardSummary summary;
  final List<PipelineStage> pipeline;
  final List<InvoiceRecord> invoices;
  final List<FollowUpItem> todaysFollowUps;

  /// Raw deal rows from `/deals/getAll` for date- and user-scoped metrics.
  final List<Map<String, dynamic>> allDealRows;
  final String filterRange; // 'last7' | 'month'
  final int? filterMonth;
  final int? filterYear;
  

  const DashboardLoaded({
    required this.topPerformer,
    required this.allLeads,
    required this.recentLeads,
    required this.summary,
    required this.pipeline,
    required this.invoices,
    this.todaysFollowUps = const [],
    this.allDealRows = const [],
    this.filterRange = 'last7',
    this.filterMonth,
    this.filterYear,
  });

  bool get hasPipeline => pipeline.isNotEmpty;

  @override
  List<Object?> get props => [
        topPerformer,
        allLeads,
        recentLeads,
        summary,
        pipeline,
        invoices,
        todaysFollowUps,
        allDealRows,
        filterRange,
        filterMonth,
        filterYear,
      ];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}

// ══════════════════════════════════════════════════════════════
// SCREEN SHELL
// ══════════════════════════════════════════════════════════════
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => DashboardCubit()..loadDashboard()),
          BlocProvider(create: (_) => NotificationCubit()),
          BlocProvider(create: (_) => UserCubit()..loadUser()),
          BlocProvider(create: (_) => MeetingsCubit()..loadMeetings())
        ],
        child: const _DashboardShell(),
      );
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell();
  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell>
    with SingleTickerProviderStateMixin {
  String _authToken = '';
  static const _drawerFraction = 0.72;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _isOpen = false;
  bool _isOffline = false;
  Timer? _notifAutoRefreshTimer;
  static const _notifAutoRefreshInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _loadAuthToken(); // ✅ add this
    _loadNotifications();
    _notifAutoRefreshTimer = Timer.periodic(
        _notifAutoRefreshInterval, (_) => _autoRefreshNotifications());
    _checkInternet();
    _listenInternet();
  }

  Future<void> _autoRefreshNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final uid = prefs.getString('user_id') ?? '';
    if (uid.isEmpty) return;
    context.read<NotificationCubit>().refresh(userId: uid, silent: true);
  }

  Future<void> _checkInternet() async {
    final result = await Connectivity().checkConnectivity();

    if (!mounted) return;

    setState(() {
      _isOffline = result == ConnectivityResult.none;
    });
  }

  void _listenInternet() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;

      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
    });
  }

  String _userName = 'User';
String? _profileImage;

Future<void> _loadAuthToken() async {
  final prefs = await SharedPreferences.getInstance();
  if (!mounted) return;
  final name = (prefs.getString('user_name') ?? '').trim();
  final rawImage = (prefs.getString('profile_image') ??
          prefs.getString('profileImage') ??
          '')
      .trim();
  setState(() {
    _authToken = prefs.getString('token') ?? '';
    if (name.isNotEmpty) _userName = name;
    _profileImage = _resolveProfileImageUrl(rawImage);
  });
}

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id') ?? '';
    if (uid.isEmpty || !mounted) return;
    context.read<NotificationCubit>().load(uid);
  }

  @override
  void dispose() {
    _notifAutoRefreshTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _isOpen = true);
    _ctrl.forward();
    // Keep the drawer's Messages badge current.
    refreshChatUnreadTotal();
  }

  void _close() {
    setState(() => _isOpen = false);
    _ctrl.reverse();
  }

  void _toggle() => _isOpen ? _close() : _open();

  Route _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );

  void _onDrawerNav(String route, {int tab = 0}) async {
    final result = await Connectivity().checkConnectivity();

    if (result == ConnectivityResult.none) {
      _close();

      return;
    }

    _close();

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;

      if (route == '/leads') {
        Navigator.of(context, rootNavigator: true)
    .push(_slide(
      const LeadsScreen(
        showBackButton: true,
      ),
    ));
      } else if (route == '/deals') {
        Navigator.of(context, rootNavigator: true)
            .push(_slide(DealsScreen(initialTab: tab)));
      } else if (route == '/invoice') {
  Navigator.of(context, rootNavigator: true)
      .push(_slide(const InvoiceScreen()));

} else if (route == '/proposals') {
  Navigator.of(context, rootNavigator: true).push(
    _slide(
      BlocProvider(
        create: (_) => ProposalCubit(),
        child: const ProposalListScreen(),
      ),
    ),
  );
} else if (route == '/meetings') {
  Navigator.of(context, rootNavigator: true)
      .push(_slide(const MeetingsScreen()));

} else if (route == '/calendar') {
  Navigator.of(context, rootNavigator: true)
      .push(_slide(const CalendarScreen()));

} else if (route == '/messages') {
  Navigator.of(context, rootNavigator: true)
      .push(_slide(const MessagesScreen()));

} else if (route == '/tasks') {
  Navigator.of(context, rootNavigator: true)
      .push(_slide(const TaskScreen()));

} else if (route == '/targets') {
  final notifCubit = context.read<NotificationCubit>();
  Navigator.of(context, rootNavigator: true).push(_slide(TargetScreen(
    onOpenNotifications: () => Navigator.of(context, rootNavigator: true)
        .push(_slide(NotificationsScreen(cubit: notifCubit))),
  )));

} else if (route == '/lead-documents') {
  Navigator.of(context, rootNavigator: true).push(
    _slide(
      BlocProvider(
        create: (_) => LeadsCubit(),
        child: const LeadsDoc(),
      ),
    ),
  );
}  else if (route == '/deal-documents') {
  Navigator.of(context, rootNavigator: true).push(
    _slide(
      BlocProvider(
        create: (_) => DealDocCubit(
          Dio(),
        ),
        child: const DealDocumentScreen(),
      ),
    ),
  );
}

else if (route == '/email') {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(
    _slide(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => EmailContactsCubit(),
          ),
          BlocProvider(
            create: (_) => EmailHistoryCubit(),
          ),
        ],
        child: const EmailContactsScreen(),
      ),
    ),
  );
}

 else if (route == '/LeaderboardPage') {
        Navigator.of(context, rootNavigator: true)
            .push(_slide(LeaderboardPage(authToken: _authToken)));
      }
    });
  }

  void _openNotificationsSheet() {
    final notifCubit = context.read<NotificationCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: notifCubit,
        child: DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.92,
          minChildSize: 0.3,
          builder: (ctx, ctrl) => Container(
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
                    borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    NotificationPanel(
                      cubit: notifCubit,
                      onViewAll: () {
                        Navigator.pop(ctx);
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (!mounted) return;
                          Navigator.of(context, rootNavigator: true).push(
                              _slide(NotificationsScreen(cubit: notifCubit)));
                        });
                      },
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _openProfile() async {
    final result = await Connectivity().checkConnectivity();

    if (result == ConnectivityResult.none) {
      _close();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You are offline. Profile is not available.",
          ),
        ),
      );

      return;
    }

    _close();

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true)
          .push(_slide(const ProfileScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final dw = sw * _drawerFraction;

    return Material(
      color: const Color(0xFF0F172A),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (ctx, _) {
          final t = _anim.value;
          return Stack(children: [
            Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: dw,
                child: _CrmDrawer(
                    onNavigate: _onDrawerNav,
                    onClose: _close,
                    onProfileTap: _openProfile)),
            Transform(
              transform: Matrix4.identity()
                ..translate(t * dw, 0.0)
                ..scale(1.0 - t * 0.10),
              alignment: Alignment.centerLeft,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t * 22),
                child: _MainContent(
  isOffline: _isOffline,
  onMenuTap: _toggle,
  isDrawerOpen: _isOpen,
  onNotifTap: _openNotificationsSheet,
  userName: _userName,
  profileImage: _profileImage,
),
              ),
            ),
            if (_isOpen)
              Positioned(
                  left: dw * t,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                      onTap: _close,
                      child:
                          Container(color: Colors.black.withOpacity(0.3 * t)))),
          ]);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DRAWER
// ══════════════════════════════════════════════════════════════
class _CrmDrawer extends StatefulWidget {
  final void Function(String route, {int tab}) onNavigate;

  final VoidCallback onClose;
  final VoidCallback onProfileTap;

  const _CrmDrawer({
    required this.onNavigate,
    required this.onClose,
    required this.onProfileTap,
  });
  @override
  State<_CrmDrawer> createState() => _CrmDrawerState();
}

class _CrmDrawerState extends State<_CrmDrawer> {
  String _active = '/dashboard';
  bool _dealsExpanded = false;
  bool _documentsExpanded = false;
  bool _emailExpanded = false;
  String _drawerName = 'CRM User';
  String _drawerEmail = 'crm.stagingzar.com';
  String? _drawerImage;
  String _userRole = '';
  Map<String, dynamic> _permissions = {};

  @override
  void initState() {
    super.initState();
    _loadDrawerProfile();
  }

  Future<void> _loadDrawerProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRole = (prefs.getString('role') ?? '').trim();
      final savedName = (prefs.getString('user_name') ?? '').trim();
      final savedEmail = (prefs.getString('email') ?? '').trim();
      final savedImage = ((prefs.getString('profile_image') ??
                  prefs.getString('profileImage')) ??
              '')
          .trim();

      if (mounted &&
          (savedName.isNotEmpty ||
              savedEmail.isNotEmpty ||
              savedImage.isNotEmpty)) {
        setState(() {
          _userRole = savedRole;
          if (savedName.isNotEmpty) _drawerName = savedName;
          if (savedEmail.isNotEmpty) _drawerEmail = savedEmail;
          _drawerImage = _resolveImageUrl(savedImage);
        });
      }

      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final dio = Dio(BaseOptions(
        baseUrl: 'https://crm-backend-api.techzarinfo.cloud/api',
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ))
        ..interceptors.add(AuthInterceptor());
      final res = await dio.get(
        '/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      var map = _extractUserMap(res.data);
     final role = map['role'];

Map<String, dynamic> permissions = {};

if (role is Map) {
  final roleMap = Map<String, dynamic>.from(role);

  final rolePermissions = roleMap['permissions'];

  if (rolePermissions is Map) {
    permissions = Map<String, dynamic>.from(rolePermissions);
  }
}
      if (map['user'] is Map) {
        map = Map<String, dynamic>.from(map['user'] as Map);
      }
      var firstName =
          (map['firstName'] ?? map['first_name'] ?? '').toString().trim();
      var lastName =
          (map['lastName'] ?? map['last_name'] ?? '').toString().trim();
      final nameRaw = (map['name'] ?? map['fullName'] ?? '').toString().trim();
      if (firstName.isEmpty && lastName.isEmpty && nameRaw.isNotEmpty) {
        final parts =
            nameRaw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
        firstName = parts.isNotEmpty ? parts.first : '';
        lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
      final email = (map['email'] ?? '').toString().trim();
      var imageRaw = _extractImagePath(map);
      if (imageRaw.isEmpty) imageRaw = savedImage;

      final fullName = '$firstName $lastName'.trim();
      final resolvedName = fullName.isNotEmpty
          ? fullName
          : (savedName.isNotEmpty
              ? savedName
              : (email.isNotEmpty && email.contains('@')
                  ? email.split('@').first
                  : 'User'));
      if (!mounted) return;
      setState(() {
        _drawerName = resolvedName;
        _drawerEmail = email.isEmpty ? 'crm.stagingzar.com' : email;
        _drawerImage = _resolveImageUrl(imageRaw);
        _permissions = permissions;
      });
    } catch (_) {}
  }

  Map<String, dynamic> _extractUserMap(dynamic body) {
    if (body is Map) {
      if (body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      if (body['user'] is Map) {
        return Map<String, dynamic>.from(body['user'] as Map);
      }
      if (body['result'] is Map) {
        return Map<String, dynamic>.from(body['result'] as Map);
      }
      return Map<String, dynamic>.from(body);
    }
    return <String, dynamic>{};
  }

  String _extractImagePath(Map<String, dynamic> map) {
    final raw = map['profileImage'] ?? map['avatarUrl'] ?? map['avatar'];
    if (raw is Map) {
      return (raw['url'] ??
              raw['path'] ??
              raw['location'] ??
              raw['secure_url'] ??
              '')
          .toString()
          .trim();
    }
    return (raw ?? '').toString().trim();
  }

  String? _resolveImageUrl(String? rawInput) {
    final raw = rawInput?.trim() ?? '';
    if (raw.isEmpty) return null;

    var path = raw.replaceAll('\\', '/');

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    if (!path.contains('/')) {
      path = '/uploads/users/$path';
    }

    if (!path.startsWith('/')) {
      path = '/$path';
    }

    return 'https://crm-backend-api.techzarinfo.cloud/$path';
  }

  Future<void> _logout() async {
      final prefs = await SharedPreferences.getInstance();

    MissedFollowupTimer.instance.stop();

    await prefs.remove('global_missed_followup_last_shown');
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.remove('permissions');
    await prefs.remove('profileImage');
    await prefs.remove('profile_image');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
final showDashboard = _permissions['dashboard'] == true;
final showLeads = _permissions['leads'] == true;
final showDeals = _permissions['deals_all'] == true;
final showDeal_pipeline = _permissions['deals_pipeline'] == true;
final showInvoices = _permissions['invoices'] == true;
final showDocuments = _permissions['documents'] == true;
final showMeetings = _permissions['meetings'] == true;
final showLeaderboard = _permissions['streak_leaderboard'] == true;
final showProposals = _permissions['proposal'] == true;
final showEmailCampaign = _permissions['email_campaigns'] == true;
final showEmail = _permissions['email_chat'] == true;

 return  Container(
        color: const Color(0xFF0F172A),
        child: SafeArea(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Text('MENU',
                style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4)),
          ),
          if (showDashboard)
          _Item(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
              active: _active == '/dashboard',
              activeColor: AppColors.primary,
              onTap: () {
                setState(() => _active = '/dashboard');
                widget.onClose();
              }),
              if (showLeads)
          _Item(
              icon: Icons.people_outline,
              activeIcon: Icons.people_rounded,
              label: 'Leads',
              active: _active == '/leads',
              activeColor: AppColors.success,
              onTap: () {
                setState(() => _active = '/leads');
                widget.onNavigate('/leads');
              }),
              if (showDeals || showDeal_pipeline)
          _ExpandItem(
            icon: Icons.handshake_outlined,
            activeIcon: Icons.handshake_rounded,
            label: 'Deals',
            expanded: _dealsExpanded,
            active: _active.startsWith('/deals'),
            activeColor: const Color(0xFF8B5CF6),
            onToggle: () => setState(() => _dealsExpanded = !_dealsExpanded),
            children: [
              if (showDeal_pipeline)

              _SubItem(
                  icon: Icons.filter_alt_outlined,
                  label: 'Deal Stages',
                  active: _active == '/deals/stages',
                  onTap: () {
                    setState(() => _active = '/deals/stages');
                    widget.onNavigate('/deals', tab: 1);
                  }),
                  if (showDeals)
              _SubItem(
                  icon: Icons.view_list_rounded,
                  label: 'All Deals',
                  active: _active == '/deals/all',
                  onTap: () {
                    setState(() => _active = '/deals/all');
                    widget.onNavigate('/deals', tab: 0);
                  }),
            ],
          ),
          if(showInvoices)
          _Item(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Invoice',
              active: _active == '/invoice',
              activeColor: AppColors.warning,
              onTap: () {
                setState(() => _active = '/invoice');
                widget.onNavigate('/invoice');
              }),
      if (showProposals)
  _Item(
    icon: Icons.description_outlined,
    activeIcon: Icons.description_rounded,
    label: 'Proposals',
    active: _active == '/proposals',
    activeColor: const Color(0xFF3B82F6),
    onTap: () {
      setState(() => _active = '/proposals');
      widget.onNavigate('/proposals');
    },
  ),
              if(showMeetings)
              _Item(
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Meetings',
    active: _active == '/meetings',
    activeColor: const Color(0xFF3B82F6),
    onTap: () {
      setState(() => _active = '/meetings');
      widget.onNavigate('/meetings');
    }),
    _Item(
    icon: Icons.event_outlined,
    activeIcon: Icons.event_rounded,
    label: 'Calendar',
    active: _active == '/calendar',
    activeColor: const Color(0xFF06B6D4),
    onTap: () {
      setState(() => _active = '/calendar');
      widget.onNavigate('/calendar');
    }),
    _Item(
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment_rounded,
    label: 'My Tasks',
    active: _active == '/tasks',
    activeColor: const Color(0xFF0B6FB5),
    onTap: () {
      setState(() => _active = '/tasks');
      widget.onNavigate('/tasks');
    }),
    _Item(
    icon: Icons.track_changes_outlined,
    activeIcon: Icons.track_changes_rounded,
    label: 'My Targets',
    active: _active == '/targets',
    activeColor: const Color(0xFF0369A1),
    onTap: () {
      setState(() => _active = '/targets');
      widget.onNavigate('/targets');
    }),
    ValueListenableBuilder<int>(
      valueListenable: chatUnreadTotal,
      builder: (_, unread, __) => _Item(
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Messages',
        active: _active == '/messages',
        activeColor: const Color(0xFF2563EB),
        badgeCount: unread,
        onTap: () {
          setState(() => _active = '/messages');
          widget.onNavigate('/messages');
        }),
    ),
    if(showDocuments)
    _ExpandItem(
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
      label: 'Documents',
      expanded: _documentsExpanded,
      active: _active == '/lead-documents' || _active == '/deal-documents',
      activeColor: AppColors.success,
      onToggle: () =>
          setState(() => _documentsExpanded = !_documentsExpanded),
      children: [
        _SubItem(
            icon: Icons.description_outlined,
            label: 'Lead Documents',
            active: _active == '/lead-documents',
            onTap: () {
              setState(() => _active = '/lead-documents');
              widget.onNavigate('/lead-documents');
            }),
        _SubItem(
            icon: Icons.folder_copy_outlined,
            label: 'Deal Documents',
            active: _active == '/deal-documents',
            onTap: () {
              setState(() => _active = '/deal-documents');
              widget.onNavigate('/deal-documents');
            }),
      ],
    ),
    if (showEmail)
  _ExpandItem(
    icon: Icons.email_outlined,
    activeIcon: Icons.email_rounded,
    label: 'Email',
    expanded: _emailExpanded,
    active: _active.startsWith('/email'),
    activeColor: const Color(0xFF3B82F6),
    onToggle: () => setState(
      () => _emailExpanded = !_emailExpanded,
    ),
    children: [
      _SubItem(
        icon: Icons.contacts_outlined,
        label: 'Contacts',
        active: _active == '/email/contacts',
        onTap: () {
          setState(
            () => _active = '/email/contacts',
          );

          widget.onNavigate('/email');
        },
      ),

      _SubItem(
        icon: Icons.campaign_outlined,
        label: 'Campaigns',
        active: _active == '/email/campaigns',
        onTap: () {
          setState(
            () => _active = '/email/campaigns',
          );

          // Add campaign navigation here
        },
      ),
    ],
  ),

    if(showLeaderboard)
          _Item(
              icon: Icons.leaderboard_outlined,
              activeIcon: Icons.leaderboard_outlined,
              label: 'Leaderboard',
              active: _active == '/LeaderboardPage',
              activeColor: AppColors.warning,
              onTap: () {
                setState(() => _active = '/LeaderboardPage');
                widget.onNavigate('/LeaderboardPage');
              }),
          const Spacer(),
          const Divider(
              color: Color(0xFF1E293B), height: 1, indent: 20, endIndent: 20),
          _Item(
              icon: Icons.logout_outlined,
              activeIcon: Icons.logout_rounded,
              label: 'Logout',
              active: false,
              activeColor: AppColors.danger,
              onTap: _logout),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 4, 22, 16),
          ),
        ])),

      );
  }
}

class _Item extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  /// Shown as a count pill when greater than 0 (e.g. unread messages).
  final int badgeCount;
  const _Item(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.active,
      required this.activeColor,
      required this.onTap,
      this.badgeCount = 0});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color:
                  active ? activeColor.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(active ? activeIcon : icon,
                size: 20,
                color: active ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            active ? Colors.white : const Color(0xFF94A3B8)))),
            if (badgeCount > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              if (active) const SizedBox(width: 8),
            ],
            if (active)
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: activeColor, shape: BoxShape.circle)),
          ]),
        ),
      );
}

class _ExpandItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool expanded, active;
  final Color activeColor;
  final VoidCallback onToggle;
  final List<Widget> children;
  const _ExpandItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.expanded,
      required this.active,
      required this.activeColor,
      required this.onToggle,
      required this.children});
  @override
  Widget build(BuildContext context) => Column(children: [
        GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: active
                      ? activeColor.withOpacity(0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(active ? activeIcon : icon,
                    size: 20,
                    color: active ? activeColor : const Color(0xFF64748B)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : const Color(0xFF94A3B8)))),
                AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFF475569))),
              ]),
            )),
        AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Column(children: children)
                : const SizedBox.shrink()),
      ]);
}

class _SubItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SubItem(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(left: 30, right: 14, top: 2, bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF8B5CF6).withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: active
                      ? const Color(0xFF8B5CF6).withOpacity(0.3)
                      : Colors.transparent)),
          child: Row(children: [
            Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF334155),
                    shape: BoxShape.circle)),
            Icon(icon,
                size: 15,
                color:
                    active ? const Color(0xFF8B5CF6) : const Color(0xFF64748B)),
            const SizedBox(width: 9),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: active ? Colors.white : const Color(0xFF64748B))),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// MAIN CONTENT
// ══════════════════════════════════════════════════════════════
class _MainContent extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onNotifTap;
  final bool isDrawerOpen;
  final bool isOffline;
  final String userName;
  final String? profileImage;
  const _MainContent({
    required this.isOffline,
    required this.onMenuTap,
    required this.onNotifTap,
    required this.isDrawerOpen,
    required this.userName,
    this.profileImage,
  });
Route _slide(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child),
    );

Future<bool> _canNavigate(BuildContext context) async {
  final result = await Connectivity().checkConnectivity();
  if (result == ConnectivityResult.none) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("You are offline. Only Dashboard is available."),
      ),
    );
    return false;
  }
  return true;
} 
Widget _buildHeroCard(
  BuildContext context,
  DashboardLoaded s,
) {
  final sm = s.summary;

  final totalLeads = sm.totalLeads;

  final totalRev = sm.totalRevenue;

  final pendingInvoiceCount =
      sm.pendingInvoices;

  return _HeroOverviewCard(
    s: s,
    totalLeads: totalLeads,
    paidRev: totalRev,
    pendingInvoiceCount: pendingInvoiceCount,
    onTodayFollowUpsTap: () async {
      if (!await _canNavigate(context)) return;

      Navigator.of(
        context,
        rootNavigator: true,
      ).push(
        _slide(
          FollowUpsScreen(
            items: s.todaysFollowUps,
          ),
        ),
      );
    },

    onTotalLeadsTap: () async {
      if (!await _canNavigate(context)) return;
      Navigator.of(context, rootNavigator: true).push(
        _slide(const LeadsScreen(showBackButton: true)),
      );
    },
    onDealsWonTap: () async {
  if (!await _canNavigate(context)) return;
  Navigator.of(context, rootNavigator: true).push(
    _slide(const DealsScreen( initialStageFilter: 'Closed Won')),
  );
},
onPendingInvoicesTap: () async {
  if (!await _canNavigate(context)) return;
  Navigator.of(context, rootNavigator: true).push(
    _slide(const InvoiceScreen(initialStatusFilter: 'Unpaid')),
  );
},

  );
}
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: BlocConsumer<DashboardCubit, DashboardState>(
          listener: (context, state) {},
          builder: (context, state) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
  final result = await Connectivity().checkConnectivity();

  if (result == ConnectivityResult.none) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No internet connection"),
      ),
    );
    return;
  }

  await context.read<DashboardCubit>().refresh();
},
            child: CustomScrollView(
              physics: isDrawerOpen
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── App Bar ──────────────────────────────────
               SliverToBoxAdapter(
  child: _CurvedHeaderHero(
    header: BlocBuilder<NotificationCubit, NotificationState>(
      builder: (ctx, ns) {
        final unread = ns is NotificationLoaded ? ns.unreadCount : 0;
        return CrmHeader(
  userName: userName,
  profileImage: profileImage,
  isOffline: isOffline,
  isDrawerOpen: isDrawerOpen,
  onMenuTap: onMenuTap,
  onNotifTap: onNotifTap,
  onAvatarTap: () async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You are offline. Profile is not available."),
        ),
      );
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ProfileScreen(),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  },
  unreadCount: unread,
);
      },
    ),
    heroCard: state is DashboardLoaded
        ? _buildHeroCard(context, state)
        : const SizedBox(height: 160), // placeholder while loading/error
  ),
),
                if (state is DashboardLoading)
                  const SliverFillRemaining(
                      child: LoadingState(message: 'Loading dashboard...'))
                else if (state is DashboardError)
                  SliverFillRemaining(
                      child: ErrorState(
                          message: state.message,
                          onRetry: () =>
                              context.read<DashboardCubit>().loadDashboard()))
                else if (state is DashboardLoaded)
                  SliverToBoxAdapter(
                      child: _DashboardBody(
                    s: state,
                    isOffline: isOffline, showHero: false
                  ))
                else
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// DASHBOARD BODY
// ══════════════════════════════════════════════════════════════
class _DashboardBody extends StatelessWidget {
  final DashboardLoaded s;
  final bool isOffline;
  final bool showHero;

  const _DashboardBody({
    required this.s,
    required this.isOffline,
    this.showHero = true,
  });

  // INR formatter
  static String _inr(double v) {
    final f =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return f.format(v);
  }

  static String _pct(double v) =>
      v >= 0 ? '+${v.toStringAsFixed(1)}%' : '${v.toStringAsFixed(1)}%';

  static Route _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child),
      );

  Future<bool> _canNavigate(BuildContext context) async {
    final result = await Connectivity().checkConnectivity();

    if (result == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You are offline. Only Dashboard is available.",
          ),
        ),
      );

      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final sm = s.summary;
    final totalLeads = sm.totalLeads;

    // Revenue values
    final totalRev = sm.totalRevenue;
    // Pending leads: prefer API value; fallback = count leads that aren'9t 'Converted'
final pendingInvoiceCount =
    sm.pendingInvoices;

   

    final topUser = s.topPerformer ??
        {
          "name": "No Performer",
          "email": "",
          "conversionRate": 0,
          "convertedLeads": 0,
          "totalLeads": 0,
          "productiveDays": 0,
        };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Section: Overview (hero card) ──────────────────────
        if (showHero) ...[
  _HeroOverviewCard(
    s: s,
    totalLeads: totalLeads,
    paidRev: totalRev,
    pendingInvoiceCount: pendingInvoiceCount,
  ),
  const SizedBox(height: 20),
],
                // ── Recent Leads ──────────────────────────────────────
        const _SectionTitle('Recent Leads'),
        const SizedBox(height: 12),
        s.recentLeads.isEmpty
            ? const EmptyState(
                message: 'No recent leads', icon: Icons.people_outline)
            : Column(
                children: s.recentLeads
                    .take(5)
                    .map(
  (l) => _MiniLeadCard(
    lead: l,
    onTap: () async {
      if (!await _canNavigate(context)) return;

      Navigator.of(context, rootNavigator: true).push(
        _slide(
          LeadsScreen(
            selectedLeadId: l.id,
            showBackButton: true,
          ),
        ),
      );
    },
  ),
)
                    .toList()),

        const SizedBox(height: 20),
        
        // ── Deal Pipeline ─────────────────────────────────────
        Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const _SectionTitle('Deal Pipeline'),

    if (s.hasPipeline)
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final result =
                await Connectivity().checkConnectivity();

            if (result == ConnectivityResult.none) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'You are offline. Only Dashboard is available.',
                  ),
                ),
              );
              return;
            }

            if (!context.mounted) return;

            Navigator.of(
              context,
              rootNavigator: true,
            ).push(
              MaterialPageRoute(
                builder: (_) =>  DealsScreen(
                  initialTab: 1,
                  showBackButton: true,
                    filterRange: s.filterRange,
                    filterMonth: s.filterMonth,
                    filterYear: s.filterYear,

                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View Deals',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
  ],
),
        const SizedBox(height: 12),
        _PipelineCard(s: s),

        const SizedBox(height: 24),

                // ── Meetings ────────────────────────────────────────
        const _SectionTitle('Meetings'),
 
        const SizedBox(height: 12),
 
        MeetingsCard(
  filterRange: s.filterRange,
  filterMonth: s.filterMonth,
  filterYear: s.filterYear,
),           
 
        const SizedBox(height: 24),

        // // ── Top Performer ─────────────────────────────────────
        // const _SectionTitle('Top Performer'),

        // const SizedBox(height: 12),

        // _TopPerformerCard(user: topUser),

        // const SizedBox(height: 24),
  
            ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HERO OVERVIEW CARD  — big revenue number + range pill + side stats
// ══════════════════════════════════════════════════════════════
class _HeroOverviewCard extends StatelessWidget {
  final DashboardLoaded s;
  final int totalLeads;
  final double paidRev;
  final int pendingInvoiceCount;
  final VoidCallback? onTodayFollowUpsTap;
  final VoidCallback? onTotalLeadsTap;
  final VoidCallback? onDealsWonTap;
  final VoidCallback? onPendingInvoicesTap;

  const _HeroOverviewCard({
    required this.s,
    required this.totalLeads,
    required this.paidRev,
    required this.pendingInvoiceCount,
    this.onTodayFollowUpsTap,
    this.onTotalLeadsTap,
    this.onDealsWonTap,
    this.onPendingInvoicesTap,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

String _formatRevenue(
  double value,
  String currency,
) {
  switch (currency.toUpperCase()) {
    case 'USD':
      return NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 2,
      ).format(value);

    case 'EUR':
      return NumberFormat.currency(
        locale: 'de_DE',
        symbol: '€',
        decimalDigits: 2,
      ).format(value);

    case 'INR':
      return NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 2,
      ).format(value);

    case 'GBP':
      return NumberFormat.currency(
        locale: 'en_GB',
        symbol: '£',
        decimalDigits: 2,
      ).format(value);

    case 'JPY':
      return NumberFormat.currency(
        locale: 'ja_JP',
        symbol: '¥',
        decimalDigits: 0,
      ).format(value);

    case 'AUD':
      return NumberFormat.currency(
        locale: 'en_AU',
        symbol: 'A\$',
        decimalDigits: 2,
      ).format(value);

    case 'CAD':
      return NumberFormat.currency(
        locale: 'en_CA',
        symbol: 'C\$',
        decimalDigits: 2,
      ).format(value);

    case 'CHF':
      return NumberFormat.currency(
        locale: 'de_CH',
        symbol: 'CHF ',
        decimalDigits: 2,
      ).format(value);

    case 'MYR':
      return NumberFormat.currency(
        locale: 'ms_MY',
        symbol: 'RM ',
        decimalDigits: 2,
      ).format(value);

    case 'AED':
      return NumberFormat.currency(
        locale: 'ar_AE',
        symbol: 'د.إ ',
        decimalDigits: 2,
      ).format(value);

    case 'SGD':
      return NumberFormat.currency(
        locale: 'en_SG',
        symbol: 'S\$',
        decimalDigits: 2,
      ).format(value);

    case 'ZAR':
      return NumberFormat.currency(
        locale: 'en_ZA',
        symbol: 'R ',
        decimalDigits: 2,
      ).format(value);

    case 'SAR':
      return NumberFormat.currency(
        locale: 'ar_SA',
        symbol: 'ر.س ',
        decimalDigits: 2,
      ).format(value);

    default:
      return '$currency ${value.toStringAsFixed(2)}';
  }
}

  String _rangeLabel() {
  if (s.filterRange == 'all') return 'All';
  if (s.filterRange == 'today') return 'Today';
  if (s.filterRange == 'last7') return 'Last 7 days';
  if (s.filterRange == 'year' && s.filterYear != null) return '${s.filterYear}';
  if (s.filterMonth != null && s.filterYear != null) {
    return '${_months[s.filterMonth! - 1]} ${s.filterYear}';
  }
  return 'Last 7 days';
}

  void _showRangeSheet(BuildContext context) {
  final cubit = context.read<DashboardCubit>();
  String tempRange = s.filterRange;
  int tempMonth = s.filterMonth ?? DateTime.now().month;
  int tempYear = s.filterYear ?? DateTime.now().year;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (context, setSheetState) {
        Widget option(String label, String value) {
          final active = tempRange == value;
          return GestureDetector(
            onTap: () => setSheetState(() => tempRange = value),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: active ? AppColors.primaryLight : AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: active ? AppColors.primary : AppColors.border),
              ),
              child: Row(children: [
                Icon(
                  active
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ]),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView (
          
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter by Period',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              option('All', 'all'),
              option('Today', 'today'),
              option('Last 7 days', 'last7'),
              option('This Month', 'month'),
              if (tempRange == 'month') ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempMonth,
                      decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder()),
                      items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                              value: i + 1, child: Text(_months[i]))),
                      onChanged: (v) =>
                          setSheetState(() => tempMonth = v ?? tempMonth),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempYear,
                      decoration: const InputDecoration(
                          labelText: 'Year', border: OutlineInputBorder()),
                      items: List.generate(
                              6, (i) => DateTime.now().year - i)
                          .map((y) =>
                              DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => tempYear = v ?? tempYear),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
              ],
              option('This Year', 'year'),
              if (tempRange == 'year') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: tempYear,
                  decoration: const InputDecoration(
                      labelText: 'Year', border: OutlineInputBorder()),
                  items: List.generate(6, (i) => DateTime.now().year - i)
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => tempYear = v ?? tempYear),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (tempRange == 'month') {
                      cubit.filterByPeriod(
                          range: 'month', month: tempMonth, year: tempYear);
                    } else if (tempRange == 'year') {
                      cubit.filterByPeriod(range: 'year', year: tempYear);
                    } else {
                      cubit.filterByPeriod(range: tempRange);
                    }
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
          )
        );
      },
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final todaysFollowUps = s.todaysFollowUps.length;
    final dealsWon = s.summary.dealsWon;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Revenue + range pill ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
  paidRev > 0
      ? _formatRevenue(
          paidRev,
          s.summary.preferredCurrency,
        )
      : '0',
                      style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                     Text(
  'Total Revenue (${s.summary.preferredCurrency})',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Builder(builder: (btnCtx) {
                return GestureDetector(
                  onTap: () => _showRangeSheet(btnCtx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_rangeLabel(),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 16, color: AppColors.primary),
                    ]),
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 22),

         // ── Side stats row ──
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Left: Today's follow-ups (emphasised, red) — tappable
    Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTodayFollowUpsTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 26, color: AppColors.danger),
                const SizedBox(height: 8),
                Text('$todaysFollowUps',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger)),
                const SizedBox(height: 4),
                const Text('Today Follow-ups',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger)),
              ],
            ),
          ),
        ),
      ),
    ),
    const SizedBox(width: 16),
    // Right: Total Leads / Deals Won / Pending Invoices
    Expanded(
      flex: 2,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTotalLeadsTap,
              child: _HeroStatRow(
                  icon: Icons.description_outlined,
                  iconColor: AppColors.purple,
                  label: 'Total Leads',
                  value: '$totalLeads'),
            ),
          ),
          const SizedBox(height: 14),
Material(
  color: Colors.transparent,
  child: InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onDealsWonTap,
    child: _HeroStatRow(
        icon: Icons.emoji_events_outlined,
        iconColor: AppColors.success,
        label: 'Deals Won',
        value: '$dealsWon'),
  ),
),
const SizedBox(height: 14),
          Material(
  color: Colors.transparent,
  child: InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onPendingInvoicesTap,
    child: _HeroStatRow(
        icon: Icons.description_outlined,
        iconColor: AppColors.warning,
        label: 'Pending Invoices',
        value: '$pendingInvoiceCount'),
  ),
),
        ],
      ),
    ),
  ],
),
        ],
      ),
    );
  }
}

class _HeroStatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _HeroStatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      ]);
}

// ══════════════════════════════════════════════════════════════
// PERIOD FILTER  — Last 7 days / Month  (used from _HeroOverviewCard's
// range pill for last7/today; kept here for month/year fine-tuning if
// wired into a screen that still wants a dedicated row)
// ══════════════════════════════════════════════════════════════
class _PeriodFilter extends StatelessWidget {
  final String selectedRange;
  final int? selectedMonth;
  final int? selectedYear;
  final void Function(String range, int? month, int? year) onChanged;

  const _PeriodFilter({
    required this.selectedRange,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onChanged,
  });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List.generate(5, (i) => now.year - i);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        const Icon(Icons.calendar_month_outlined,
            size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _label(),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
        ),
        if (selectedRange == 'last7' || selectedRange == 'today')
          _DropBtn<String>(
            value: selectedRange,
            hint: 'Range',
            items: const [
              DropdownMenuItem(value: 'today', child: Text('Today')),
              DropdownMenuItem(value: 'last7', child: Text('Last 7 days')),
              DropdownMenuItem(value: 'month', child: Text('Month')),
            ],
            onChanged: (v) {
              if (v == 'today') {
                context.read<DashboardCubit>().filterByPeriod(
                      range: 'today',
                    );
              } else if (v == 'last7') {
                context.read<DashboardCubit>().filterByPeriod(
                      range: 'last7',
                    );
              } else {
                final now = DateTime.now();

                context.read<DashboardCubit>().filterByPeriod(
                      range: 'month',
                      month: now.month,
                      year: now.year,
                    );
              }
            },
          ),
        if (selectedRange == 'month') ...[
          const SizedBox(width: 8),
          _DropBtn(
            value: selectedMonth,
            hint: 'Month',
            items: List.generate(12,
                (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i]))),
            onChanged: (v) => onChanged(selectedRange, v, selectedYear),
          ),
          const SizedBox(width: 8),
          _DropBtn(
            value: selectedYear,
            hint: 'Year',
            items: years
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => onChanged(selectedRange, selectedMonth, v),
          ),
        ],
        if (selectedRange == 'month' &&
            (selectedMonth != null || selectedYear != null)) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => onChanged('last7', null, null),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.danger),
            ),
          ),
        ],
      ]),
    );
  }

  String _label() {
    if (selectedRange == 'today') return 'Today';

    if (selectedRange == 'last7') return 'Last 7 days';

    if (selectedMonth != null && selectedYear != null) {
      return '${_months[selectedMonth! - 1]} $selectedYear';
    }

    if (selectedMonth != null) return _months[selectedMonth! - 1];

    if (selectedYear != null) return '$selectedYear';

    return 'All time';
  }
}

class _DropBtn<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _DropBtn({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value != null ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null ? AppColors.primary : AppColors.border,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: Text(hint,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            items: items,
            onChanged: onChanged,
            isDense: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color:
                  value != null ? AppColors.primary : AppColors.textSecondary,
            ),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    value != null ? AppColors.primary : AppColors.textPrimary),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// REVENUE BREAKDOWN
// ══════════════════════════════════════════════════════════════
class _RevenueBreakdown extends StatelessWidget {
  final double paid, unpaid, total;
  const _RevenueBreakdown({
    required this.paid,
    required this.unpaid,
    required this.total,
  });

  static String _inr(double v) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(v);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? paid / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.purpleLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 16, color: AppColors.purple)),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Invoice Revenue (INR)',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _AmtBox(
                  label: 'Paid', value: _inr(paid), color: AppColors.success)),
          const SizedBox(width: 10),
          Expanded(
              child: _AmtBox(
                  label: 'Unpaid',
                  value: _inr(unpaid),
                  color: AppColors.danger)),
          const SizedBox(width: 10),
          Expanded(
              child: _AmtBox(
                  label: 'Total',
                  value: _inr(total),
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppColors.dangerLight,
                valueColor: const AlwaysStoppedAnimation(AppColors.success))),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(pct * 100).toStringAsFixed(0)}% collected',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success)),
          Text('${((1 - pct) * 100).toStringAsFixed(0)}% outstanding',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger)),
        ]),
      ]),
    );
  }
}

class _AmtBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AmtBox(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 3),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]);
}

// ══════════════════════════════════════════════════════════════
// PIPELINE CARD
// ══════════════════════════════════════════════════════════════
class _PipelineCard extends StatelessWidget {
  final DashboardLoaded s;
  const _PipelineCard({required this.s});

  static Color _stageColor(String stage) {
    final sl = stage.toLowerCase();
    if (sl.contains('qualif')) return const Color(0xFF0EA5E9);
    if (sl.contains('proposal') || sl.contains('negotiation')) {
      return const Color(0xFF8B5CF6); // purple
    }
    if (sl.contains('invoice')) return const Color(0xFFF59E0B);
    if (sl.contains('won')) return AppColors.success;
    if (sl.contains('lost')) return AppColors.danger;
    if (sl.contains('close')) return AppColors.success;
    return AppColors.primary;
  }

  static String _fmtVal(double v, String c) {
    final f = NumberFormat.currency(
        locale: c == 'INR' ? 'en_IN' : 'en_US',
        symbol: c == 'INR'
            ? '₹'
            : c == 'USD'
                ? r'$'
                : c,
        decimalDigits: 0);
    return f.format(v);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.stacked_line_chart_rounded,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Deal Pipeline',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            s.hasPipeline
                ? _buildFromApi(context)
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No pipeline stages from API',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ],
        ),
      );

  Widget _buildFromApi(BuildContext context) {
  final maxCount =
      s.pipeline.map((e) => e.count).fold(
            1,
            (a, b) => a > b ? a : b,
          );

  return Column(
    children: s.pipeline.map((stage) {
      final color = _stageColor(stage.stage);
      final percent = stage.count / maxCount;

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),

            onTap: () async {
              final result =
                  await Connectivity().checkConnectivity();

              if (result == ConnectivityResult.none) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'You are offline. Only Dashboard is available.',
                    ),
                  ),
                );
                return;
              }

              if (!context.mounted) return;

              Navigator.of(
                context,
                rootNavigator: true,
              ).push(
                MaterialPageRoute(
                  builder: (_) => DealsScreen(
                    initialStageFilter: stage.stage,
                    showBackButton: true,
                  ),
                ),
              );
            },

            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stage.stage,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: Text(
                          '${stage.count} deal${stage.count != 1 ? "s" : ""}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),

                      if (stage.value > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _fmtVal(
                              stage.value,
                              stage.currency,
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(width: 4),

                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: color,
                      ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 10,
                      backgroundColor: AppColors.divider,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}
}

// ══════════════════════════════════════════════════════════════
// SMALL WIDGETS
// ══════════════════════════════════════════════════════════════
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext ctx) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]),
            child: Column(children: [
              Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 20, color: color)),
              const SizedBox(height: 7),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ]),
          ),
        ),
      );
}

class _MiniLeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback? onTap;
  const _MiniLeadCard({required this.lead, this.onTap});
  @override
  Widget build(BuildContext ctx) => InkWell(
  onTap: onTap,
  borderRadius: BorderRadius.circular(14),
  child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text(
                lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(lead.companyName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            StatusBadge(status: lead.status),
            const SizedBox(height: 4),
            Text(lead.source,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
  ),
      );
}

class _TopPerformerCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _TopPerformerCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['name'] ?? '';
    final email = user['email'] ?? '';
    final conversion = (user['conversionRate'] ?? 0).toDouble();
    final converted = user['convertedLeads'] ?? 0;
    final total = user['totalLeads'] ?? 0;
    final activeDays = user['productiveDays'] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final result = await Connectivity().checkConnectivity();

          if (result == ConnectivityResult.none) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "You are offline. Leaderboard is not available.",
                ),
              ),
            );

            return;
          }

          final prefs = await SharedPreferences.getInstance();

          final token = prefs.getString('token') ?? '';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeaderboardPage(
                authToken: token,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7ED), Color(0xFFFFFBF5)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emoji_events,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Top Performer",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── User Info ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("#1",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(email,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.flash_on,
                              size: 14, color: Colors.orange),
                          Text(" ${conversion.toStringAsFixed(1)}%",
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 10),
                          const Icon(Icons.local_fire_department,
                              size: 14, color: Colors.orange),
                          Text(" $activeDays d",
                              style: const TextStyle(fontSize: 12)),
                        ])
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium,
                      size: 18, color: Colors.orange),
                )
              ],
            ),

            const SizedBox(height: 16),

            // ── Stats ──
            Row(
              children: [
                Expanded(
                  child: _tpBox(
                    title: "Conversion",
                    value: "${conversion.toStringAsFixed(1)}%",
                    sub: "$converted/$total",
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tpBox(
                    title: "Active Days",
                    value: "$activeDays",
                    sub: "—",
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Progress ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Performance",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("${conversion.toStringAsFixed(1)}%",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: conversion / 100,
                minHeight: 6,
                backgroundColor: Colors.orange.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            )
          ]),
        ),
      ),
    );
  }
}

class _tpBox extends StatelessWidget {
  final String title, value, sub;
  final Color color;

  const _tpBox({
    required this.title,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext ctx) => Text(text,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary));
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _Pill({required this.label, required this.color, required this.bg});
  @override
  Widget build(BuildContext ctx) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)));
}
class _CurvedHeaderHero extends StatelessWidget {
  final Widget header;
  final Widget heroCard;
  final double curveHeight; // how far the blue extends past the header

  const _CurvedHeaderHero({
    required this.header,
    required this.heroCard,
    this.curveHeight = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1D4ED8),
                Color(0xFF2563EB),
                Color(0xFF0EA5E9),
              ],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: 0, child: header),
                SizedBox(height: curveHeight),
              ],
            ),
          ),
        ),
        Column(
          children: [
            header,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: heroCard,
            ),
          ],
        ),
      ],
    );
  }
}