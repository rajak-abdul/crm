import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrmDrawer extends StatefulWidget {
  final void Function(String route, {int tab}) onNavigate;
  final VoidCallback onClose;

  const CrmDrawer({
    super.key,
    required this.onNavigate,
    required this.onClose,
  });

  @override
  State<CrmDrawer> createState() => _CrmDrawerState();
}

class _CrmDrawerState extends State<CrmDrawer> {
  String _active = '/dashboard';
  bool _dealsExpanded = false;
  bool _documentsExpanded = false;

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

  void _setActive(String route) => setState(() => _active = route);

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF0F172A),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
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
                    _setActive('/dashboard');
                    widget.onNavigate('/dashboard');
                  }),
              _Item(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people_rounded,
                  label: 'Leads',
                  active: _active == '/leads',
                  activeColor: AppColors.success,
                  onTap: () {
                    _setActive('/leads');
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
                        _setActive('/deals/stages');
                        widget.onNavigate('/deals', tab: 1);
                      }),
                  _SubItem(
                      icon: Icons.view_list_rounded,
                      label: 'All Deals',
                      active: _active == '/deals/all',
                      onTap: () {
                        _setActive('/deals/all');
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
                    _setActive('/invoice');
                    widget.onNavigate('/invoice');
                  }),
                  _Item(
  icon: Icons.calendar_month_outlined,
  activeIcon: Icons.calendar_month_rounded,
  label: 'Meetings',
  active: _active == '/meetings',
  activeColor: const Color(0xFF3B82F6),
  onTap: () {
    _setActive('/meetings');
    widget.onNavigate('/meetings');
  },
),
              _ExpandItem(
                icon: Icons.folder_outlined,
                activeIcon: Icons.folder_rounded,
                label: 'Documents',
                expanded: _documentsExpanded,
                active: _active == '/lead-documents' ||
                    _active == '/deal-documents',
                activeColor: AppColors.success,
                onToggle: () => setState(
                    () => _documentsExpanded = !_documentsExpanded),
                children: [
                  _SubItem(
                      icon: Icons.description_outlined,
                      label: 'Lead Documents',
                      active: _active == '/lead-documents',
                      onTap: () {
                        _setActive('/lead-documents');
                        widget.onNavigate('/lead-documents');
                      }),
                  _SubItem(
                      icon: Icons.folder_copy_outlined,
                      label: 'Deal Documents',
                      active: _active == '/deal-documents',
                      onTap: () {
                        _setActive('/deal-documents');
                        widget.onNavigate('/deal-documents');
                      }),
                ],
              ),
              _Item(
                  icon: Icons.leaderboard_outlined,
                  activeIcon: Icons.leaderboard_outlined,
                  label: 'Leaderboard',
                  active: _active == '/LeaderboardPage',
                  activeColor: AppColors.warning,
                  onTap: () {
                    _setActive('/LeaderboardPage');
                    widget.onNavigate('/LeaderboardPage');
                  }),
              const Spacer(),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          margin:
              const EdgeInsets.only(left: 30, right: 14, top: 2, bottom: 2),
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
                color: active
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF64748B)),
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