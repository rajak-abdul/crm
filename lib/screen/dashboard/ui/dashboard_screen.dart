// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/dashboard/ui/dashboard_screen.dart        ║
// ╚══════════════════════════════════════════════════════════════╝

// ignore_for_file: unnecessary_cast

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm_app/modals/followup_model.dart';
import 'package:crm_app/screen/dashboard/cubit/dashboard.dart';
import 'package:crm_app/screen/dashboard/ui/dashboard_followup_page.ui.dart';
import 'package:crm_app/screen/dashboard/ui/meeting_summary_card.dart';
import 'package:crm_app/screen/leads/ui/lead_screen.dart';
import 'package:crm_app/screen/message/cubit/chat_cubit.dart'
    show chatUnreadTotal, refreshChatUnreadTotal;
import 'package:crm_app/screen/meeting/cubit/meeting_cubit.dart';
import 'package:crm_app/screen/notification/cubit/notification_cubit.dart';
import 'package:crm_app/screen/notification/cubit/notification_state.dart';
import 'package:crm_app/screen/notification/ui/notifiication.dart';
import 'package:crm_app/screen/users/user_cubit.dart';
import 'package:crm_app/shareWidgets/crm_drawer.dart';
import 'package:crm_app/shareWidgets/crm_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:crm_app/utils/data_sync.dart';
import 'package:crm_app/utils/permission_helper.dart';
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

/// True while the dashboard's own drawer is open. MainShell hides its
/// bottom nav then, so the drawer runs the full height like the one on
/// the Leads / Deals tabs.
final ValueNotifier<bool> dashboardDrawerOpen = ValueNotifier<bool>(false);

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
        // Silent reload when you come back after 2+ min, or after leads /
        // deals changed anywhere in the app (bottom-nav tab 0).
        child: Builder(
          builder: (ctx) => TabRefreshScope<DashboardCubit, DashboardState>(
            area: SyncArea.dashboard,
            tabIndex: 0,
            isLoaded: (s) => s is DashboardLoaded,
            onRefresh: () => _refreshKeepingPeriod(ctx.read<DashboardCubit>()),
            child: const _DashboardShell(),
          ),
        ),
      );

  /// loadDashboard() resets the period filter to "all" — re-apply the
  /// period that was selected so a background refresh doesn't change it.
  static Future<void> _refreshKeepingPeriod(DashboardCubit cubit) async {
    final before = cubit.state;
    await cubit.loadDashboard();
    if (before is DashboardLoaded && before.filterRange != 'all') {
      await cubit.filterByPeriod(
        range: before.filterRange,
        month: before.filterMonth,
        year: before.filterYear,
      );
    }
  }
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell();
  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell>
    with SingleTickerProviderStateMixin {
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
    dashboardDrawerOpen.value = false;
    _notifAutoRefreshTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _isOpen = true);
    dashboardDrawerOpen.value = true;
    _ctrl.forward();
    // Keep the drawer's Messages badge current.
    refreshChatUnreadTotal();
  }

  void _close() {
    setState(() => _isOpen = false);
    // Bring the bottom nav back once the drawer has slid shut.
    _ctrl.reverse().whenComplete(() {
      if (!_isOpen) dashboardDrawerOpen.value = false;
    });
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

      // '/dashboard' only closes the drawer — this is the Dashboard.
      if (route == '/leads') {
        Navigator.of(context, rootNavigator: true).push(_slide(
          const LeadsScreen(
            showBackButton: true,
          ),
        ));
      } else if (route == '/deals') {
        Navigator.of(context, rootNavigator: true)
            .push(_slide(DealsScreen(initialTab: tab)));
      } else {
        pushDrawerScreen(
          context,
          route,
          notifCubit: context.read<NotificationCubit>(),
        );
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
                child: CrmDrawer(
                    onNavigate: _onDrawerNav,
                    onClose: _close,
                    isOpen: _isOpen)),
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

  // Each stat opens its module only when the role allows that module.
  final canLeads = PermissionHelper.can('leads');
  final canDeals = PermissionHelper.can('deals_all');
  final canInvoices = PermissionHelper.can('invoices');

  return _HeroOverviewCard(
    s: s,
    totalLeads: totalLeads,
    paidRev: totalRev,
    pendingInvoiceCount: pendingInvoiceCount,
    onTodayFollowUpsTap: !canLeads ? null : () async {
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

    onTotalLeadsTap: !canLeads ? null : () async {
      if (!await _canNavigate(context)) return;
      Navigator.of(context, rootNavigator: true).push(
        _slide(const LeadsScreen(showBackButton: true)),
      );
    },
    onDealsWonTap: !canDeals ? null : () async {
  if (!await _canNavigate(context)) return;
  Navigator.of(context, rootNavigator: true).push(
    _slide(const DealsScreen( initialStageFilter: 'Closed Won')),
  );
},
onPendingInvoicesTap: !canInvoices ? null : () async {
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
        // Sections follow the role's module permissions.
        if (PermissionHelper.can('leads')) ...[
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
        ],

        // ── Deal Pipeline ─────────────────────────────────────
        if (PermissionHelper.can('deals_all') ||
            PermissionHelper.can('deals_pipeline')) ...[
        Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const _SectionTitle('Deal Pipeline'),

    // "View Deals" opens the Deal Stages tab.
    if (s.hasPipeline && PermissionHelper.can('deals_pipeline'))
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
        ],

                // ── Meetings ────────────────────────────────────────
        if (PermissionHelper.can('meetings')) ...[
        const _SectionTitle('Meetings'),

        const SizedBox(height: 12),

        MeetingsCard(
  filterRange: s.filterRange,
  filterMonth: s.filterMonth,
  filterYear: s.filterYear,
),

        const SizedBox(height: 24),
        ],
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