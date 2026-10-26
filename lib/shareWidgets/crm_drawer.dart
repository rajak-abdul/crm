// ╔══════════════════════════════════════════════════════════════╗
// ║              lib/shareWidgets/crm_drawer.dart                ║
// ║  The app's side drawer — one widget for the Dashboard tab     ║
// ║  and the Leads / Deals tabs of MainShell.                     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:convert';

import 'package:crm_app/screen/LeaderBoard/ui/leader_board.dart';
import 'package:crm_app/screen/calendar/UI/calendar_screen.dart';
import 'package:crm_app/screen/documents_hub/presentation/view/documents_hub_screen.dart';
import 'package:crm_app/screen/email/cubit/email_cubit.dart';
import 'package:crm_app/screen/email/cubit/email_history_cubit.dart';
import 'package:crm_app/screen/email/ui/EmailContactsScreen.dart';
import 'package:crm_app/screen/invoice/ui/invoice_screen.dart';
import 'package:crm_app/screen/meeting/UI/meeting.dart';
import 'package:crm_app/screen/message/cubit/chat_cubit.dart'
    show chatUnreadTotal;
import 'package:crm_app/screen/message/ui/message_screen.dart';
import 'package:crm_app/screen/notification/cubit/notification_cubit.dart';
import 'package:crm_app/screen/notification/ui/notifiication.dart';
import 'package:crm_app/screen/proposal/UI/proposal_screen.dart';
import 'package:crm_app/screen/proposal/cubit/proposal_cubit.dart';
import 'package:crm_app/screen/tasks/view/target_screen.dart'
    show TargetScreen;
import 'package:crm_app/screen/tasks/view/task_screen.dart' show TaskScreen;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:crm_app/utils/data_sync.dart';
import 'package:crm_app/utils/missed_followup_timer.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════
// DRAWER NAVIGATION — screens pushed on top of the shell
// ══════════════════════════════════════════════════════════════

Route _slide(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

/// Pushes the screen for a drawer [route] that opens on top of the shell
/// (everything except Dashboard / Leads / Deals, which each shell handles
/// itself). Returns false when [route] isn't one of these screens.
/// [notifCubit] backs the Target screen's notifications link.
Future<bool> pushDrawerScreen(
  BuildContext context,
  String route, {
  NotificationCubit? notifCubit,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);

  switch (route) {
    case '/invoice':
      navigator.push(_slide(const InvoiceScreen()));
    case '/proposals':
      navigator.push(_slide(BlocProvider(
        create: (_) => ProposalCubit(),
        child: const ProposalListScreen(),
      )));
    case '/meetings':
      navigator.push(_slide(const MeetingsScreen()));
    case '/calendar':
      navigator.push(_slide(const CalendarScreen()));
    case '/messages':
      navigator.push(_slide(const MessagesScreen()));
    case '/tasks':
      navigator.push(_slide(const TaskScreen()));
    case '/targets':
      navigator.push(_slide(TargetScreen(
        onOpenNotifications: notifCubit == null
            ? null
            : () => navigator
                .push(_slide(NotificationsScreen(cubit: notifCubit))),
      )));
    case '/documents-hub':
      navigator.push(_slide(const DocumentsHubScreen()));
    case '/email':
      navigator.push(_slide(MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => EmailContactsCubit()),
          BlocProvider(create: (_) => EmailHistoryCubit()),
        ],
        child: const EmailContactsScreen(),
      )));
    case '/LeaderboardPage':
      final prefs = await SharedPreferences.getInstance();
      navigator.push(_slide(
        LeaderboardPage(authToken: prefs.getString('token') ?? ''),
      ));
    default:
      return false;
  }
  return true;
}

// ══════════════════════════════════════════════════════════════
// DRAWER
// ══════════════════════════════════════════════════════════════
class CrmDrawer extends StatefulWidget {
  final void Function(String route, {int tab}) onNavigate;

  final VoidCallback onClose;

  /// Route of the screen behind the drawer ('/dashboard', '/leads',
  /// '/deals/all'), so the right item is highlighted.
  final String currentRoute;

  /// Whether the drawer is open. Each time it opens, the highlight goes
  /// back to [currentRoute] — a screen opened from the drawer (Invoice,
  /// Tasks, ...) is closed by then.
  final bool isOpen;

  const CrmDrawer({
    super.key,
    required this.onNavigate,
    required this.onClose,
    this.currentRoute = '/dashboard',
    this.isOpen = false,
  });
  @override
  State<CrmDrawer> createState() => _CrmDrawerState();
}

class _CrmDrawerState extends State<CrmDrawer> {
  /// role.permissions from /users/me, cached as JSON for the next open.
  static const _permsCacheKey = 'drawer_role_permissions';

  late String _active = widget.currentRoute;

  // Opened on the Deals tab so the highlighted "All Deals" is visible.
  late bool _dealsExpanded = widget.currentRoute.startsWith('/deals');
  bool _emailExpanded = false;
  bool _tasksExpanded = false;
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

  @override
  void didUpdateWidget(CrmDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Shell switched tab (e.g. via the bottom nav), or the drawer was
    // reopened — highlight the screen behind it.
    final reopened = widget.isOpen && !oldWidget.isOpen;
    if (widget.currentRoute != oldWidget.currentRoute || reopened) {
      _active = widget.currentRoute;
      if (_active.startsWith('/deals')) _dealsExpanded = true;
    }
    // Pick up role changes made by an admin (served from the 2-min
    // /users/me cache, so reopening doesn't spam the API).
    if (reopened) _loadDrawerProfile();
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

      // Last known permissions first, so the menu isn't empty while
      // /users/me is in flight (or offline).
      final cachedPerms = prefs.getString(_permsCacheKey);
      if (cachedPerms != null && cachedPerms.isNotEmpty) {
        final decoded = jsonDecode(cachedPerms);
        if (decoded is Map && mounted) {
          setState(() => _permissions = Map<String, dynamic>.from(decoded));
        }
      }

      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      // /users/me (tenant-scoped — without the slug it fails and every
      // permission-gated item stays hidden). Shared with the dashboard and
      // UserCubit for 2 min via SessionCache.
      var map = _extractUserMap(await SessionCache.usersMe());
     final role = map['role'];

Map<String, dynamic> permissions = {};

if (role is Map) {
  final roleMap = Map<String, dynamic>.from(role);

  final rolePermissions = roleMap['permissions'];

  if (rolePermissions is Map) {
    permissions = Map<String, dynamic>.from(rolePermissions);
  }
}
      debugPrint('[CrmDrawer] role permissions: $permissions');
      if (permissions.isNotEmpty) {
        await prefs.setString(_permsCacheKey, jsonEncode(permissions));
        // The /users/me values (true / false) become the app's permissions;
        // screens that changed rebuild.
        await PermissionHelper.apply(permissions);
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
        // Keep the cached set if the response carried no role permissions.
        if (permissions.isNotEmpty) _permissions = permissions;
      });
    } catch (e) {
      debugPrint('[CrmDrawer] /users/me failed: $e');
    }
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
    // Next user mustn't see this user's /users/me, /users/sales or marks.
    SessionCache.clear();
    DataSync.instance.reset();

    await prefs.remove('global_missed_followup_last_shown');
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.remove('permissions');
    await prefs.remove(_permsCacheKey);
    await prefs.remove('profileImage');
    await prefs.remove('profile_image');
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
// One role.permissions key (GET /users/me) per drawer item.
bool can(String key) => _permissions[key] == true;
final showDashboard = can('dashboard');
final showLeads = can('leads');
final showDeals = can('deals_all');
final showDealPipeline = can('deals_pipeline');
final showInvoices = can('invoices');
final showProposals = can('proposal');
final showMeetings = can('meetings');
final showCalendar = can('schedule_view');
final showMyTasks = can('assigned_tasks');
final showMyTargets = can('my_targets');
final showMessages = can('messages');
final showDocuments = can('documents');
final showEmailCampaign = can('email_campaigns');
final showLeaderboard = can('streak_leaderboard');

 // Scrolls when the items (with Deals / Email expanded) are taller than
 // the screen; otherwise Logout stays pinned to the bottom.
 return  Container(
        color: const Color(0xFF0F172A),
        child: SafeArea(
            child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
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
                // The Dashboard tab just closes; Leads / Deals switch to it.
                widget.onNavigate('/dashboard');
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
              if (showDeals || showDealPipeline)
          _ExpandItem(
            icon: Icons.handshake_outlined,
            activeIcon: Icons.handshake_rounded,
            label: 'Deals',
            expanded: _dealsExpanded,
            active: _active.startsWith('/deals'),
            activeColor: const Color(0xFF8B5CF6),
            onToggle: () => setState(() => _dealsExpanded = !_dealsExpanded),
            children: [
              if (showDealPipeline)
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
    if (showCalendar)
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
    if (showMyTasks || showMyTargets)
    _ExpandItem(
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment_rounded,
    label: 'Tasks',
    expanded: _tasksExpanded,
    active: _active == '/tasks' || _active == '/targets',
    activeColor: const Color(0xFF0B6FB5),
    onToggle: () => setState(() => _tasksExpanded = !_tasksExpanded),
    children: [
      if (showMyTasks)
      _SubItem(
        icon: Icons.assignment_outlined,
        label: 'My Tasks',
        active: _active == '/tasks',
        onTap: () {
          setState(() => _active = '/tasks');
          widget.onNavigate('/tasks');
        },
      ),
      if (showMyTargets)
      _SubItem(
        icon: Icons.track_changes_outlined,
        label: 'My Targets',
        active: _active == '/targets',
        onTap: () {
          setState(() => _active = '/targets');
          widget.onNavigate('/targets');
        },
      ),
    ],
  ),
    if (showMessages)
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
    _Item(
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder_rounded,
    label: 'Documents Hub',
    active: _active == '/documents-hub',
    activeColor: AppColors.success,
    onTap: () {
      setState(() => _active = '/documents-hub');
      widget.onNavigate('/documents-hub');
    }),
    if (showEmailCampaign)
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
        label: 'Email Campaign',
        active: _active == '/email/contacts',
        onTap: () {
          setState(
            () => _active = '/email/contacts',
          );

          widget.onNavigate('/email');
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
        ])),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(children: [
              const Spacer(),
              const SizedBox(height: 12),
              const Divider(
                  color: Color(0xFF1E293B),
                  height: 1,
                  indent: 20,
                  endIndent: 20),
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
            ]),
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
