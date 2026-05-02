// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/dashboard/ui/dashboard_screen.dart        ║
// ╚══════════════════════════════════════════════════════════════╝

// ignore_for_file: unnecessary_cast

import 'package:crm_app/screen/LeaderBoard/ui/leader_board.dart';
import 'package:crm_app/screen/dashboard/cubit/dashboard.dart';
import 'package:crm_app/screen/dashboard/cubit/notification_cubit.dart';
import 'package:crm_app/screen/leads/ui/lead_screen.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:crm_app/modals/modals.dart' show Lead, AppConstants;
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show StatusBadge, EmptyState, LoadingState, ErrorState;
import 'package:crm_app/screen/deals/ui/deal_screen.dart' show DealsScreen;
import 'package:crm_app/screen/profile/ui/profile_screen.dart' show ProfileScreen;
import '../../invoice/ui/invoice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

bool _isSessionExpiredMessage(String msg) {
  final m = msg.toLowerCase();
  return m.contains('session expired') ||
      m.contains('unauthorized') ||
      m.contains('401') ||
      m.contains('login again');
}

// ══════════════════════════════════════════════════════════════
// INVOICE RECORD MODEL
// ══════════════════════════════════════════════════════════════
class InvoiceRecord {
  final String    id;
  final String    invoiceNumber;
  final String    status;       // 'paid' | 'unpaid'
  final String    currency;
  final double    total;
  final double?   inrAmount;    // server-converted INR (if available)
  final double?   exchangeRate; // rate used by server
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
        id:            j['_id']?.toString() ?? j['id']?.toString() ?? '',
        invoiceNumber: j['invoicenumber']?.toString() ??
                       j['invoiceNumber']?.toString() ?? '',
        status:        (j['status'] ?? 'unpaid').toString().toLowerCase(),
        currency:      (j['currency'] ?? 'INR').toString().toUpperCase(),
        total:         _d(j['total'] ?? j['amount'] ?? j['grandTotal']),
        inrAmount:     j['inrAmount'] != null ? _d(j['inrAmount']) : null,
        exchangeRate:  j['exchangeRate'] != null ? _d(j['exchangeRate']) : null,
        issueDate:     j['issueDate'] != null
            ? DateTime.tryParse(j['issueDate'].toString())
            : null,
        dueDate:       j['dueDate'] != null
            ? DateTime.tryParse(j['dueDate'].toString())
            : null,
        paidAt:        j['paidAt'] != null
            ? DateTime.tryParse(j['paidAt'].toString())
            : null,
      );
}

// ══════════════════════════════════════════════════════════════
// DASHBOARD SUMMARY MODEL
// ══════════════════════════════════════════════════════════════
class DashboardSummary extends Equatable {
  final int    totalLeads;
  final int    totalDeals;
  final int    dealsWon;
  final int    pendingLeads;   // leads not yet converted/closed
  final double leadsChange;
  final double dealsChange;
  final double paidRevenue;    // in INR — shown as "Total Revenue" on card 3
  final double unpaidRevenue;  // in INR
  final double totalRevenue;   // in INR

   const DashboardSummary({
    this.totalLeads    = 0,
    this.totalDeals    = 0,
    this.dealsWon      = 0,
    this.pendingLeads  = 0,
    this.leadsChange   = 0,
    this.dealsChange   = 0,
    this.paidRevenue   = 0,
    this.unpaidRevenue = 0,
    this.totalRevenue  = 0,
  });

  static int    _i(dynamic v) =>
      v == null ? 0 : int.tryParse(v.toString())    ?? 0;
  static double _d(dynamic v) =>
      v == null ? 0 : double.tryParse(v.toString()) ?? 0;

  factory DashboardSummary.fromSummaryJson(Map<String, dynamic> j) {
    Map<String, dynamic> d = j;
    for (final k in ['data', 'summary', 'stats', 'overview', 'result']) {
      if (j[k] is Map) {
        d = Map<String, dynamic>.from(j[k] as Map);
        break;
      }
    }
    return DashboardSummary(
      totalLeads:  _i(d['totalLeads']  ?? d['total_leads']  ??
                      d['leads']       ?? d['leadsCount']   ?? d['leadCount']),
      totalDeals:  _i(d['totalDeals']  ?? d['total_deals']  ??
                      d['deals']       ?? d['dealsCount']   ?? d['dealCount']),
      dealsWon:    _i(d['totalDealsWon'] ?? d['dealsWon']   ?? d['won']          ??
                      d['closedWon']   ?? d['wonDeals']     ?? d['deals_won']),
      pendingLeads: _i(d['pendingLeads'] ?? d['pending_leads'] ??
                       d['pending']      ?? d['openLeads']   ?? d['activeLeads']),
      leadsChange: _d(d['leadsChange'] ?? d['leads_change'] ?? d['leadsGrowth']),
      dealsChange: _d(d['dealsChange'] ?? d['deals_change'] ?? d['dealsGrowth']),
    );
  }

  @override
  List<Object?> get props => [
    totalLeads, totalDeals, dealsWon, pendingLeads,
    paidRevenue, unpaidRevenue, totalRevenue,
  ];
}

// ══════════════════════════════════════════════════════════════
// PIPELINE STAGE MODEL
// ══════════════════════════════════════════════════════════════
class PipelineStage extends Equatable {
  final String stage;
  final int    count;
  final double value;
  final String currency;

  const PipelineStage({
    required this.stage,
    this.count    = 0,
    this.value    = 0,
    this.currency = 'INR',
  });

  factory PipelineStage.fromJson(Map<String, dynamic> j) => PipelineStage(
        stage:    j['stage']?.toString()     ??
                  j['stageName']?.toString() ??
                  j['_id']?.toString()       ??
                  j['name']?.toString()      ??
                  j['label']?.toString()     ?? 'Unknown',
        count:    DashboardSummary._i(
                  j['count']  ?? j['dealCount'] ??
                  j['deals']  ?? j['leads'] ?? j['total'] ?? j['totalDeals'] ??
                  (j['items'] is List ? (j['items'] as List).length : null) ??
                  (j['leads'] is List ? (j['leads'] as List).length : null) ??
                  (j['records'] is List ? (j['records'] as List).length : null)),
        value:    DashboardSummary._d(
                  j['value']  ?? j['totalValue'] ??
                  j['amount'] ?? j['dealValue']  ?? j['revenue']),
        currency: j['currency']?.toString() ?? 'INR',
      );

  @override List<Object?> get props => [stage, count, value];
}

// ══════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════
abstract class DashboardState extends Equatable {
  const DashboardState();
  @override List<Object?> get props => [];
}
class DashboardInitial extends DashboardState {}
class DashboardLoading  extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<Lead>          allLeads;
  final List<Lead>          recentLeads;
  final DashboardSummary    summary;
  final List<PipelineStage> pipeline;
  final List<InvoiceRecord> invoices;
  /// Raw deal rows from `/deals/getAll` for date- and user-scoped metrics.
  final List<Map<String, dynamic>> allDealRows;
  final String              filterRange; // 'last7' | 'month'
  final int?                filterMonth;
  final int?                filterYear;

  const DashboardLoaded({
    required this.allLeads,
    required this.recentLeads,
    required this.summary,
    required this.pipeline,
    required this.invoices,
    this.allDealRows = const [],
    this.filterRange = 'last7',
    this.filterMonth,
    this.filterYear,
  });

  bool get hasPipeline => pipeline.isNotEmpty;

  @override
  List<Object?> get props => [
    allLeads, recentLeads, summary, pipeline,
    invoices, allDealRows, filterRange, filterMonth, filterYear,
  ];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override List<Object?> get props => [message];
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
        ],
        child: const _DashboardShell(),
      );
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell();
  @override State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell>
    with SingleTickerProviderStateMixin {
   String _authToken = '';
  static const _drawerFraction = 0.72;
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
      _loadAuthToken();        // ✅ add this
    _loadNotifications();
  }
  Future<void> _loadAuthToken() async {
  final prefs = await SharedPreferences.getInstance();
  if (mounted) setState(() => _authToken = prefs.getString('token') ?? '');
}

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final uid   = prefs.getString('user_id') ?? '';
    if (uid.isEmpty || !mounted) return;
    context.read<NotificationCubit>().load(uid);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _open()   { setState(() => _isOpen = true);  _ctrl.forward(); }
  void _close()  { setState(() => _isOpen = false); _ctrl.reverse(); }
  void _toggle() => _isOpen ? _close() : _open();

  Route _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );

  void _onDrawerNav(String route, {int tab = 0}) {
  _close();
  Future.delayed(const Duration(milliseconds: 260), () {
    if (!mounted) return;
    if (route == '/leads') {
      Navigator.of(context, rootNavigator: true)
          .push(_slide(const LeadsScreen()));
    } else if (route == '/deals') {
      Navigator.of(context, rootNavigator: true)
          .push(_slide(DealsScreen(initialTab: tab)));
    } else if (route == '/invoice') {
      Navigator.of(context, rootNavigator: true)
          .push(_slide(const InvoiceScreen()));
    } else if (route == '/LeaderboardPage') {  // ✅ add this
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
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
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
                        Future.delayed(
                            const Duration(milliseconds: 200), () {
                          if (!mounted) return;
                          Navigator.of(context, rootNavigator: true)
                              .push(_slide(
                                  NotificationsScreen(cubit: notifCubit)));
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

  void _openProfile() {
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
                left: 0, top: 0, bottom: 0, width: dw,
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
                  onMenuTap:    _toggle,
                  isDrawerOpen: _isOpen,
                  onNotifTap:   _openNotificationsSheet,
                ),
              ),
            ),
            if (_isOpen)
              Positioned(
                  left: dw * t, top: 0, right: 0, bottom: 0,
                  child: GestureDetector(
                      onTap: _close,
                      child: Container(
                          color: Colors.black.withOpacity(0.3 * t)))),
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
  @override State<_CrmDrawer> createState() => _CrmDrawerState();
}

class _CrmDrawerState extends State<_CrmDrawer> {
  String _active        = '/dashboard';
  bool   _dealsExpanded = false;
  String _drawerName = 'CRM User';
  String _drawerEmail = 'crm.stagingzar.com';
  String? _drawerImage;
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadDrawerProfile();
  }

  Future<void> _loadDrawerProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = (prefs.getString('user_name') ?? '').trim();
      final savedEmail = (prefs.getString('email') ?? '').trim();
      final savedImage = ((prefs.getString('profile_image') ??
                  prefs.getString('profileImage')) ??
              '')
          .trim();

      if (mounted &&
          (savedName.isNotEmpty || savedEmail.isNotEmpty || savedImage.isNotEmpty)) {
        setState(() {
          if (savedName.isNotEmpty) _drawerName = savedName;
          if (savedEmail.isNotEmpty) _drawerEmail = savedEmail;
          _drawerImage = _resolveImageUrl(savedImage);

        });
      }

      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final dio = Dio(BaseOptions(
        baseUrl: 'https://sales.stagingzar.com/api',
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ));
      final res = await dio.get(
        '/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      var map = _extractUserMap(res.data);
      if (map['user'] is Map) {
        map = Map<String, dynamic>.from(map['user'] as Map);
      }
      var firstName = (map['firstName'] ?? map['first_name'] ?? '').toString().trim();
      var lastName = (map['lastName'] ?? map['last_name'] ?? '').toString().trim();
      final nameRaw = (map['name'] ?? map['fullName'] ?? '').toString().trim();
      if (firstName.isEmpty && lastName.isEmpty && nameRaw.isNotEmpty) {
        final parts = nameRaw
            .split(RegExp(r'\s+'))
            .where((e) => e.isNotEmpty)
            .toList();
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
      });
    } catch (_) {}
  }

  Map<String, dynamic> _extractUserMap(dynamic body) {
    if (body is Map) {
      if (body['data'] is Map) return Map<String, dynamic>.from(body['data'] as Map);
      if (body['user'] is Map) return Map<String, dynamic>.from(body['user'] as Map);
      if (body['result'] is Map) return Map<String, dynamic>.from(body['result'] as Map);
      return Map<String, dynamic>.from(body);
    }
    return <String, dynamic>{};
  }

  String _extractImagePath(Map<String, dynamic> map) {
    final raw = map['profileImage'] ?? map['avatarUrl'] ?? map['avatar'];
    if (raw is Map) {
      return (raw['url'] ?? raw['path'] ?? raw['location'] ?? raw['secure_url'] ?? '')
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

    return 'https://sales.stagingzar.com$path';
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
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
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF0F172A),
        child: SafeArea(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Row(children: [
              GestureDetector(
                onTap: widget.onProfileTap,
                child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        _drawerImage != null ? NetworkImage(_drawerImage!) : null,
                    child: _drawerImage == null ? const Icon(Icons.person) : null,
                  ),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_drawerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  Text(_drawerEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 11)),
                ]),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Text('MENU',
                style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4)),
          ),
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
          _ExpandItem(
            icon: Icons.handshake_outlined,
            activeIcon: Icons.handshake_rounded,
            label: 'Deals',
            expanded: _dealsExpanded,
            active: _active.startsWith('/deals'),
            activeColor: const Color(0xFF8B5CF6),
            onToggle: () =>
                setState(() => _dealsExpanded = !_dealsExpanded),
            children: [
              _SubItem(
                  icon: Icons.filter_alt_outlined,
                  label: 'Deal Stages',
                  active: _active == '/deals/stages',
                  onTap: () {
                    setState(() => _active = '/deals/stages');
                    widget.onNavigate('/deals', tab: 1);
                  }),
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
            if (PermissionHelper.can('admin_access'))
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
              color: Color(0xFF1E293B), height: 1,
              indent: 20, endIndent: 20),
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


class _Item extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _Item(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.active,
      required this.activeColor,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
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
            if (active)
              Container(
                  width: 7, height: 7,
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
              margin: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 2),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: active
                      ? activeColor.withOpacity(0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(active ? activeIcon : icon,
                    size: 20,
                    color: active
                        ? activeColor
                        : const Color(0xFF64748B)),
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
          margin: const EdgeInsets.only(
              left: 30, right: 14, top: 2, bottom: 2),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
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
                width: 6, height: 6,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF334155),
                    shape: BoxShape.circle)),
            Icon(icon,
                size: 15,
                color: active
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF64748B)),
            const SizedBox(width: 9),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: active
                        ? Colors.white
                        : const Color(0xFF64748B))),
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
  const _MainContent({
    required this.onMenuTap,
    required this.onNotifTap,
    required this.isDrawerOpen,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: BlocConsumer<DashboardCubit, DashboardState>(
          listener: (context, state) {
            if (state is DashboardError &&
                _isSessionExpiredMessage(state.message)) {
              Navigator.of(context, rootNavigator: true)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            }
          },
          builder: (context, state) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () =>
                context.read<DashboardCubit>().refresh(),
            child: CustomScrollView(
              physics: isDrawerOpen
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── App Bar ──────────────────────────────────
                SliverAppBar(
                  expandedHeight: 140,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppColors.primary,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1D4ED8),
                            Color(0xFF2563EB),
                            Color(0xFF0EA5E9)
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(children: [
                                  GestureDetector(
                                    onTap: onMenuTap,
                                    child: Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                          color: Colors.white
                                              .withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                            milliseconds: 200),
                                        transitionBuilder: (child, anim) =>
                                            RotationTransition(
                                                turns: anim,
                                                child: FadeTransition(
                                                    opacity: anim,
                                                    child: child)),
                                        child: Icon(
                                          isDrawerOpen
                                              ? Icons.close_rounded
                                              : Icons.menu_rounded,
                                          key: ValueKey(isDrawerOpen),
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Good Morning 👋',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.75),
                                              fontSize: 12)),
                                      const Text('CRM Dashboard',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight:
                                                  FontWeight.w800)),
                                    ],
                                  )),
                                  // ── Notification Bell ───────
                                  BlocBuilder<NotificationCubit,
                                      NotificationState>(
                                    builder: (ctx, ns) {
                                      final unread = ns
                                              is NotificationLoaded
                                          ? ns.unreadCount
                                          : 0;
                                      return GestureDetector(
                                        onTap: onNotifTap,
                                        child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(
                                                        10),
                                                decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(12)),
                                                child: const Icon(
                                                  Icons
                                                      .notifications_outlined,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                              ),
                                              if (unread > 0)
                                                Positioned(
                                                  top: -4, right: -4,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 5,
                                                        vertical: 2),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: AppColors
                                                          .danger,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(10),
                                                      border: Border.all(
                                                          color:
                                                              Colors.white,
                                                          width: 1.5),
                                                    ),
                                                    child: Text(
                                                      unread > 99
                                                          ? '99+'
                                                          : '$unread',
                                                      style:
                                                          const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ]),
                                      );
                                    },
                                  ),
                                ])
                              ]),
                        ),
                      ),
                    ),
                  ),
                ),

                if (state is DashboardLoading)
                  const SliverFillRemaining(
                      child: LoadingState(
                          message: 'Loading dashboard...'))
                else if (state is DashboardError)
                  SliverFillRemaining(
                      child: ErrorState(
                          message: state.message,
                          onRetry: () => context
                              .read<DashboardCubit>()
                              .loadDashboard()))
                else if (state is DashboardLoaded)
                  SliverToBoxAdapter(
                      child: _DashboardBody(s: state))
                else
                  const SliverFillRemaining(child: SizedBox()),
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
  const _DashboardBody({required this.s});

  // INR formatter
  static String _inr(double v) {
    final f = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return f.format(v);
  }

  static String _pct(double v) =>
      v >= 0 ? '+${v.toStringAsFixed(1)}%' : '${v.toStringAsFixed(1)}%';

  static Route _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(
                    begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: a, curve: Curves.easeOutCubic)),
            child: child),
      );

  @override
  Widget build(BuildContext context) {
    final sm         = s.summary;
    final totalLeads = sm.totalLeads > 0 ? sm.totalLeads : s.allLeads.length;

    // Revenue values
    final paidRev  = sm.paidRevenue;   // card 3 shows this as "Total Revenue"
    final unpaidRev = sm.unpaidRevenue;
    final totalRev  = sm.totalRevenue;

    // Pending leads: prefer API value; fallback = count leads that aren't 'Converted'
    final pendingInvoiceCount = s.invoices
    .where((inv) => inv.status == 'unpaid')
    .length;

    final paidPct = totalRev > 0
        ? '${(paidRev / totalRev * 100).toStringAsFixed(0)}% of total'
        : '—';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Period Filter Row ─────────────────────────────────
        _PeriodFilter(
          selectedRange: s.filterRange,
          selectedMonth: s.filterMonth,
          selectedYear:  s.filterYear,
          onChanged: (range, month, year) {
            context.read<DashboardCubit>().filterByPeriod(
                  range: range, month: month, year: year);
          },
        ),
        const SizedBox(height: 16),

        // ── Section: Overview ─────────────────────────────────
        const _SectionTitle('Overview'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            // Card 1: Total Leads
            _StatCard(
              label: 'Total Leads',
              value: '$totalLeads',
              icon: Icons.people_alt_outlined,
              color: AppColors.primary,
              bg: AppColors.primaryLight,
              trend: _pct(sm.leadsChange),
              up: sm.leadsChange >= 0,
            ),
            // Card 2: Deals Won
            _StatCard(
              label: 'Deals Won',
              value: '${sm.dealsWon}',
              icon: Icons.emoji_events_outlined,
              color: AppColors.success,
              bg: AppColors.successLight,
              trend: _pct(sm.dealsChange),
              up: sm.dealsChange >= 0,
            ),
            // Card 3: Total Revenue (paid invoices value in INR)
            _StatCard(
              label: 'Total Revenue',
              value: paidRev > 0 ? _inr(paidRev) : '—',
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.purple,
              bg: AppColors.purpleLight,
              trend: paidPct,
              up: paidRev > 0,
            ),
            // Card 4: Pending Leads — replaces old "Total Revenue" card
            _StatCard(
  label: 'Pending Invoices',
  value: '$pendingInvoiceCount',
  icon: Icons.receipt_long_outlined,
  color: AppColors.warning,
  bg: AppColors.warningLight,
  trend: pendingInvoiceCount > 0
      ? '$pendingInvoiceCount unpaid'
      : 'All paid',
  up: pendingInvoiceCount == 0,
),
          ],
        ),

        // ── Revenue Breakdown bar ─────────────────────────────
        if (totalRev > 0) ...[
          const SizedBox(height: 16),
          _RevenueBreakdown(
            paid:   paidRev,
            unpaid: unpaidRev,
            total:  totalRev,
          ),
        ],

        const SizedBox(height: 24),

        // ── Quick Actions ─────────────────────────────────────
        const _SectionTitle('Quick Actions'),
        const SizedBox(height: 12),
        Row(children: [
          _QuickCard(
              icon: Icons.people_outline,
              label: 'Leads',
              color: AppColors.success,
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .push(_slide(const LeadsScreen()))),
          const SizedBox(width: 12),
          _QuickCard(
              icon: Icons.handshake_outlined,
              label: 'All Deals',
              color: const Color(0xFF6366F1),
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .push(_slide(const DealsScreen(initialTab: 0)))),
          const SizedBox(width: 12),
          _QuickCard(
              icon: Icons.receipt_long_outlined,
              label: 'Invoices',
              color: AppColors.warning,
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .push(_slide(const InvoiceScreen()))),
        ]),

        const SizedBox(height: 24),

        // ── Deal Pipeline ─────────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          const _SectionTitle('Deal Pipeline'),
          if (s.hasPipeline)
            _Pill(
                label:
                    '${s.pipeline.fold(0, (a, b) => a + b.count)} deals',
                color: AppColors.primary,
                bg: AppColors.primaryLight),
        ]),
        const SizedBox(height: 12),
        _PipelineCard(s: s),

        const SizedBox(height: 24),

        // ── Recent Leads ──────────────────────────────────────
        const _SectionTitle('Recent Leads'),
        const SizedBox(height: 12),
        s.recentLeads.isEmpty
            ? const EmptyState(
                message: 'No recent leads',
                icon: Icons.people_outline)
            : Column(
                children: s.recentLeads
                    .take(5)
                    .map((l) => _MiniLeadCard(lead: l))
                    .toList()),

        const SizedBox(height: 32),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PERIOD FILTER  — Last 7 days / Month
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
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
        if (selectedRange == 'last7')
          _DropBtn<String>(
            value: selectedRange,
            hint: 'Range',
            items: const [
              DropdownMenuItem(value: 'last7', child: Text('Last 7 days')),
              DropdownMenuItem(value: 'month', child: Text('Month')),
            ],
            onChanged: (v) {
              final next = v ?? 'last7';
              if (next == 'month') {
                onChanged(next, selectedMonth, selectedYear ?? now.year);
              } else {
                onChanged(next, null, null);
              }
            },
          ),
        if (selectedRange == 'month') ...[
          const SizedBox(width: 8),
          _DropBtn(
            value:   selectedMonth,
            hint:    'Month',
            items:   List.generate(12,
                (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i]))),
            onChanged: (v) => onChanged(selectedRange, v, selectedYear),
          ),
          const SizedBox(width: 8),
          _DropBtn(
            value:   selectedYear,
            hint:    'Year',
            items:   years
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
    if (selectedRange == 'last7') return 'Last 7 days';
    if (selectedMonth != null && selectedYear != null) {
      return '${_months[selectedMonth! - 1]} $selectedYear';
    }
    if (selectedMonth != null) return _months[selectedMonth! - 1];
    if (selectedYear  != null) return '$selectedYear';
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
          color: value != null
              ? AppColors.primaryLight
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null
                ? AppColors.primary
                : AppColors.border,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value:       value,
            hint:        Text(hint,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            items:       items,
            onChanged:   onChanged,
            isDense:     true,
            icon:        Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: value != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: value != null
                    ? AppColors.primary
                    : AppColors.textPrimary),
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

  static String _inr(double v) => NumberFormat.currency(
          locale: 'en_IN', symbol: '₹', decimalDigits: 0)
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  label: 'Paid',
                  value: _inr(paid),
                  color: AppColors.success)),
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
                valueColor: const AlwaysStoppedAnimation(
                    AppColors.success))),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text('${(pct * 100).toStringAsFixed(0)}% collected',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success)),
          Text(
              '${((1 - pct) * 100).toStringAsFixed(0)}% outstanding',
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
      {required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ]);
}

// ══════════════════════════════════════════════════════════════
// STAT CARD
// ══════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String label, value, trend;
  final IconData icon;
  final Color color, bg;
  final bool up;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.bg,
      required this.trend,
      required this.up});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ]),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color)),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: up
                        ? AppColors.successLight
                        : AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(trend,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: up
                            ? AppColors.success
                            : AppColors.danger)),
              ),
            ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ]),
        ]),
      );
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
        symbol: c == 'INR' ? '₹' : c == 'USD' ? r'$' : c,
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
                ? _buildFromApi()
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

  Widget _buildFromApi() {
    final maxCount = s.pipeline
        .map((e) => e.count)
        .fold(1, (a, b) => a > b ? a : b);
    return Column(
      children: s.pipeline.map((stage) {
        final color   = _stageColor(stage.stage);
        final percent = stage.count / maxCount;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Expanded(
                  child: Text(stage.stage,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('${stage.count} deal${stage.count != 1 ? "s" : ""}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              if (stage.value > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      _fmtVal(stage.value, stage.currency),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 7,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(color))),
          ]),
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
  const _MiniLeadCard({required this.lead});
  @override
   Widget build(BuildContext ctx) => Container(
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
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text(
                lead.name.isNotEmpty
                    ? lead.name[0].toUpperCase()
                    : '?',
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
          Column(crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            StatusBadge(status: lead.status),
            const SizedBox(height: 4),
            Text(lead.source,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
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
  const _Pill(
      {required this.label, required this.color, required this.bg});
  @override
  Widget build(BuildContext ctx) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700)));
}