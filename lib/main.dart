import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm_app/screen/dashboard/ui/dashboard_screen.dart'
    show DashboardScreen, dashboardDrawerOpen;
import 'package:crm_app/screen/deals/ui/deal_screen.dart' show DealsScreen;
import 'package:crm_app/screen/leads/cubit/lead_cubit.dart';
import 'package:crm_app/screen/leads/ui/lead_screen.dart' show LeadsScreen, LeadDetailSheet;
import 'package:crm_app/screen/login/ui/login_screen.dart' show LoginScreen;
import 'package:crm_app/screen/message/cubit/chat_cubit.dart'
    show refreshChatUnreadTotal;
import 'package:crm_app/screen/notification/cubit/notification_cubit.dart';
import 'package:crm_app/screen/notification/cubit/notification_state.dart' show NotificationLoaded, NotificationState;
import 'package:crm_app/screen/notification/ui/notifiication.dart';
import 'package:crm_app/screen/profile/ui/profile_screen.dart'
    show ProfileScreen;
import 'package:crm_app/screen/splash_screen/splash_screen.dart';
import 'package:crm_app/shareWidgets/crm_drawer.dart';
import 'package:crm_app/shareWidgets/crm_header.dart';
import 'package:crm_app/shareWidgets/missed_followup.dart';
import 'package:crm_app/shareWidgets/notifcation_service.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors, AppTheme;
import 'package:crm_app/utils/data_sync.dart';
import 'package:crm_app/utils/missed_followup_timer.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Only the login check must finish before the first frame (it picks
  // Home vs Login).
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final isLoggedIn = token != null && token.isNotEmpty;

  // Not needed to draw the splash — runs while the video plays; the splash
  // waits for it before opening Home / Login.
  final startup = Future.wait([
    NotificationService.initialize(),
    PermissionHelper.load(),
  ]).catchError((Object e) {
    debugPrint('Startup init error: $e');
    return <void>[];
  });

  runApp(CRMApp(isLoggedIn: isLoggedIn, startup: startup));
}

class CRMApp extends StatelessWidget {
  final bool isLoggedIn;

  /// Startup work still running when the app is first drawn.
  final Future<void>? startup;

  const CRMApp({super.key, required this.isLoggedIn, this.startup});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  navigatorKey: navigatorKey,
  title: 'CRM',
  theme: AppTheme.theme,
  debugShowCheckedModeBanner: false,

  home: SplashScreen(
    ready: startup,
    nextScreen: isLoggedIn
        ? const MainShell()
        : const LoginScreen(),
  ),

  routes: {
    '/login': (_) => const LoginScreen(),
    '/home': (_) => const MainShell(),
  },
);
  }
}

// ══════════════════════════════════════════════════════════════
// MAIN SHELL — shared header + drawer + bottom nav
// ══════════════════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
      

      // in _MainShellState
String? _pendingSelectedLeadId;

Future<void> _openLeadFromNotification(String leadId) async {
  debugPrint('========== VIEW LEAD START ==========');
  debugPrint('LEAD ID: $leadId');
  debugPrint('CURRENT IDX BEFORE: $_idx');
  debugPrint('CURRENT PENDING BEFORE: $_pendingSelectedLeadId');

  if (!mounted) {
    debugPrint('MAIN SHELL NOT MOUNTED');
    return;
  }

  setState(() {
    _pendingSelectedLeadId = leadId;
    _idx = 1;
  });

  debugPrint('IDX AFTER SETSTATE: $_idx');
  debugPrint('PENDING AFTER SETSTATE: $_pendingSelectedLeadId');

  await WidgetsBinding.instance.endOfFrame;

  debugPrint('========== END OF FRAME ==========');
  debugPrint('IDX AFTER FRAME: $_idx');
  debugPrint('PENDING AFTER FRAME: $_pendingSelectedLeadId');
}
  int _idx = 0;

  /// Bottom-nav tabs opened so far (Dashboard is the landing tab).
  final Set<int> _visitedTabs = {0};
  late final Connectivity _connectivity;
  AnimationController? _ctrl;
  Animation<double>? _anim;
  static const _drawerFraction = 0.72;
  late final NotificationCubit _notifCubit;
  late final LeadCubit _leadCubit;
  Timer? _notifAutoRefreshTimer;
  static const _notifAutoRefreshInterval = Duration(seconds: 15);
  static const String _missedFollowupLastShownKey =
    'global_missed_followup_last_shown';
  bool _isOpen = false;
  bool _isOffline = false;
  String _userName = 'User';
  String? _profileImage;
  /// Runs every [MissedFollowupTimer.tickInterval] and on app resume.
  /// Calls the API at most once per [MissedFollowupTimer.interval]: the
  /// saved time is the last successful check, shown or not (the key
  /// keeps its old name — logout clears it by that name).
  Future<void> _checkMissedFollowups() async {
  final reminder = MissedFollowupTimer.instance;
  if (!mounted || reminder.checking || reminder.popupOpen) return;

  reminder.checking = true;

  try {
    final prefs = await SharedPreferences.getInstance();

    final lastCheckedMillis =
        prefs.getInt(_missedFollowupLastShownKey);

    final now = DateTime.now();

    // Checked within the last hour — wait for the next tick.
    if (lastCheckedMillis != null) {
      final lastChecked =
          DateTime.fromMillisecondsSinceEpoch(lastCheckedMillis);

      if (now.difference(lastChecked) < MissedFollowupTimer.interval) {
        return;
      }
    }

    // Get missed follow-ups from your existing Cubit.
    // Page 1 only (10 rows) — the dialog loads further pages on scroll.
    final firstPage = await _leadCubit.getMissedFollowups(page: 1);

    // Saved after every successful check, even with nothing to show,
    // so the API isn't called again on every tick. A failed check
    // isn't saved and is retried on the next tick.
    await prefs.setInt(
      _missedFollowupLastShownKey,
      now.millisecondsSinceEpoch,
    );

    if (!mounted || firstPage.leads.isEmpty || reminder.popupOpen) {
      return;
    }

    reminder.popupOpen = true;

    showDialog(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => MissedFollowupDialog(
    firstPage: firstPage,
    loadPage: (page) => _leadCubit.getMissedFollowups(page: page),
    onViewLead: (lead) async {
  Navigator.of(dialogContext).pop();

  await Future.delayed(
    const Duration(milliseconds: 300),
  );

  if (!mounted) return;

  await _openLeadFromNotification(lead.id);
},
  ),
).whenComplete(() => reminder.popupOpen = false);
  } catch (e) {
    debugPrint(
      'Missed follow-up check failed: $e',
    );
  } finally {
    reminder.checking = false;
  }
}

  /// The timer pauses while the app is in the background, so check again
  /// on resume (the one-hour rule still decides whether to call the API).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMissedFollowups();
      // Role may have changed on the web while the app was away.
      PermissionHelper.refresh();
    }
  }
// Inside build(), right before you use `_screens` in the IndexedStack:

  @override
  void initState() {
    super.initState();
    // Fresh shell (e.g. after login): Dashboard first, no stale marks.
    shellActiveTab.value = 0;
    DataSync.instance.reset();
    _notifCubit = NotificationCubit();
    _leadCubit = LeadCubit();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl!, curve: Curves.easeOutCubic);

    _connectivity = Connectivity();
    _checkInternet();
    _connectivity.onConnectivityChanged.listen((result) {
      if (!mounted) return;
      final isOffline = result == ConnectivityResult.none;
      setState(() {
        _isOffline = isOffline;
        if (isOffline) _idx = 0;
      });
      
    });

    _loadUserInfo();
    _loadNotifications();
    // Live role.permissions from /users/me replace the ones saved at login.
    PermissionHelper.refresh();
    _notifAutoRefreshTimer = Timer.periodic(
        _notifAutoRefreshInterval, (_) => _autoRefreshNotifications());
    WidgetsBinding.instance.addObserver(this);
    MissedFollowupTimer.instance.start(
  owner: this,
  onTick: _checkMissedFollowups,
);
  }

  Future<void> _autoRefreshNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final uid = prefs.getString('user_id') ?? '';
    if (uid.isEmpty) return;
    _notifCubit.refresh(userId: uid, silent: true);
  }

  Future<void> _checkInternet() async {
    final result = await _connectivity.checkConnectivity();
    if (!mounted) return;
    setState(() => _isOffline = result == ConnectivityResult.none);
  }

  String? _resolveProfileImageUrl(String? rawInput) {
    final raw = rawInput?.trim() ?? '';
    if (raw.isEmpty) return null;
    var path = raw.replaceAll('\\', '/');
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (!path.contains('/')) path = '/uploads/users/$path';
    if (!path.startsWith('/')) path = '/$path';
    return 'https://crm-backend-api.techzarinfo.cloud/$path';
  }

  Future<void> _loadUserInfo() async {
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
  _notifCubit.load(uid);
}

  void _open() {
  setState(() => _isOpen = true);
  _ctrl?.forward();
  // Keep the drawer's Messages badge current.
  refreshChatUnreadTotal();
}

void _close() {
  setState(() => _isOpen = false);
  _ctrl?.reverse();
}

@override
void dispose() {
  debugPrint('DIAG MainShellState DISPOSED\n${StackTrace.current}');
  debugPrint('DIAG MainShellState DISPOSED');
debugPrintStack();
  _notifAutoRefreshTimer?.cancel();
  WidgetsBinding.instance.removeObserver(this);
  // Only stops the timer if this shell still owns it — a replacement
  // shell may already have started its own.
  MissedFollowupTimer.instance.stop(owner: this);
  _ctrl?.dispose();
  _notifCubit.close();
  _leadCubit.close();
  super.dispose();
}
  void _toggle() => _isOpen ? _close() : _open();

Route _slide(Widget page) => PageRouteBuilder(
  opaque: true,
  barrierColor: AppColors.background,
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, animation, __, child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
      ),
      child: child,
    );
  },
);
  void _onDrawerNav(String route, {int tab = 0}) async {
    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none && route != '/dashboard') {
      _close();
      return;
    }

    _close();

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;

      if (route == '/dashboard') {
        setState(() => _idx = 0);
      } else if (route == '/leads') {
        setState(() => _idx = 1);
      } else if (route == '/deals' && tab == 0) {
        setState(() => _idx = 2);
      } else if (route == '/deals') {
        // The Deals tab always opens on All Deals; Deal Stages opens on
        // top, the same as from the Dashboard drawer.
        Navigator.of(context, rootNavigator: true)
            .push(_slide(DealsScreen(initialTab: tab)));
      } else {
        pushDrawerScreen(context, route, notifCubit: _notifCubit);
      }
    });
  }

  void _openNotificationsSheet() {
    final notifCubit = _notifCubit;
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
      debugPrint('MainShell.build() called, _idx=$_idx, pending=$_pendingSelectedLeadId');

    final sw = MediaQuery.of(context).size.width;
    final dw = sw * _drawerFraction;

    // Each tab is built — and loads its data — only the first time it's
    // opened, then kept alive by the IndexedStack. TabRefreshScope inside
    // each tab reloads it silently when it's stale or something changed.
    // The open tab's permission was turned off (live /users/me refresh):
    // fall back to the Dashboard instead of showing a hidden tab.
    if ((_idx == 1 && !PermissionHelper.can('leads')) ||
        (_idx == 2 &&
            !PermissionHelper.can('deals_all') &&
            !PermissionHelper.can('deals_pipeline'))) {
      _idx = 0;
    }
    _visitedTabs.add(_idx);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) shellActiveTab.value = _idx;
    });
      final screens = [
    const DashboardScreen(),
    _visitedTabs.contains(1)
        ? LeadsScreen(
            key: const PageStorageKey('leads_tab'), // ADD THIS
            showBackButton: false,
            tabIndex: 1,
            selectedLeadId: _pendingSelectedLeadId,
            onLeadOpened: () => setState(() => _pendingSelectedLeadId = null),
          )
        : const SizedBox.shrink(),
    _visitedTabs.contains(2)
        ? const DealsScreen(
            initialTab: 0,
            showBackButton: false,
            tabIndex: 2,
          )
        : const SizedBox.shrink(),
  ];

    return BlocProvider.value(
  value: _notifCubit,
  child: Material(
        color: const Color(0xFF0F172A),
        child: AnimatedBuilder(
          animation: _anim?? const AlwaysStoppedAnimation(0.0),
          builder: (ctx, _) {
          final t = _anim?.value ?? 0.0;
            return Stack(children: [
              Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: dw,
                  child: CrmDrawer(
                    onNavigate: _onDrawerNav,
                    onClose: _close,
                    currentRoute: switch (_idx) {
                      1 => '/leads',
                      2 => '/deals/all',
                      _ => '/dashboard',
                    },
                    isOpen: _isOpen,
                  )),
              Transform(
                transform: Matrix4.identity()
                  ..translate(t * dw, 0.0)
                  ..scale(1.0 - t * 0.10),
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(t * 22),
                  child: Scaffold(
                    backgroundColor: AppColors.background,
                    body: Column(
                      children: [
                        BlocBuilder<NotificationCubit, NotificationState>(
  builder: (ctx, ns) {
    final unread =
        ns is NotificationLoaded ? ns.unreadCount : 0;

    if (_idx == 0) {
      return const SizedBox.shrink(); // Hide header on Dashboard
    }

    return CrmHeader(
      userName: _userName,
      profileImage: _profileImage,
      isOffline: _isOffline,
      isDrawerOpen: _isOpen,
      showBackground: true,
      onMenuTap: _toggle,
      onNotifTap: _openNotificationsSheet,
      onAvatarTap: () async {
        final result =
            await _connectivity.checkConnectivity();
        if (result == ConnectivityResult.none) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "You are offline. Profile is not available.",
              ),
            ),
          );
          return;
        }

        Navigator.of(context, rootNavigator: true)
            .push(_slide(const ProfileScreen()));
      },
      unreadCount: unread,
    );
  },
),
                        Expanded(
                          child: IndexedStack(index: _idx, children: screens),
                        ),
                      ],
                    ),
                    // Hidden while the Dashboard tab's own drawer is open,
                    // so that drawer runs full height like this shell's.
                    bottomNavigationBar: ValueListenableBuilder<bool>(
                      valueListenable: dashboardDrawerOpen,
                      builder: (_, drawerOpen, nav) =>
                          drawerOpen && _idx == 0
                              ? const SizedBox.shrink()
                              : nav!,
                      child: _BottomNav(
                        selectedIndex: _idx,
                        onTap: (i) async {
                          final result =
                              await _connectivity.checkConnectivity();
                          if (result == ConnectivityResult.none && i != 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "No Internet. Only Dashboard is available."),
                              ),
                            );
                            setState(() => _idx = 0);
                            return;
                          }
                          setState(() => _idx = i);
                        },
                      ),
                    ),
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
                        child: Container(
                            color: Colors.black.withOpacity(0.3 * t)))),
            ]);
          },
        ),
      ),
    );
  }
}

// ─── Custom Bottom Nav ────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4))
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      isSelected: selectedIndex == 0,
                      onTap: () => onTap(0)),
                  // Indices stay fixed (they index the IndexedStack), so
                  // hiding a tab doesn't shift the others.
                  if (PermissionHelper.can('leads'))
                  _NavItem(
                      icon: Icons.people_outline,
                      activeIcon: Icons.people_rounded,
                      label: 'Leads',
                      isSelected: selectedIndex == 1,
                      onTap: () => onTap(1)),
                  if (PermissionHelper.can('deals_all') ||
                      PermissionHelper.can('deals_pipeline'))
                  _NavItem(
                      icon: Icons.handshake_outlined,
                      activeIcon: Icons.handshake_rounded,
                      // Pipeline-only users land on Deal Stages.
                      label: PermissionHelper.can('deals_all')
                          ? 'All Deals'
                          : 'Deal Stages',
                      isSelected: selectedIndex == 2,
                      onTap: () => onTap(2)),
                ]),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 18 : 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isSelected ? activeIcon : icon,
                size: 22,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ],
          ]),
        ),
      );
}