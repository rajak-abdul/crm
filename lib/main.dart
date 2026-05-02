// ============================================================
// lib/main.dart
//
// On startup:
//   • Checks SharedPreferences for 'auth_token'
//   • If found  → goes straight to MainShell (home)
//   • If missing → shows LoginScreen
//
// After login success → pushReplacementNamed('/home')
// Logout anywhere    → Navigator.pushReplacementNamed(ctx, '/login')
// =======================================================================

import 'package:crm_app/screen/dashboard/ui/dashboard_screen.dart' show DashboardScreen;
import 'package:crm_app/screen/leads/ui/lead_screen.dart' show LeadsScreen;
import 'package:crm_app/screen/login/ui/login_screen.dart' show LoginScreen;
import 'package:crm_app/screen/userRole/ui/user_role_screen.dart' show UserRoleScreen;
import 'package:crm_app/thems/app_themes.dart' show AppColors, AppTheme;
import 'package:crm_app/utils/permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Check if user is already logged in
  final prefs     = await SharedPreferences.getInstance();
  final token     = prefs.getString('token');
  final isLoggedIn = token != null && token.isNotEmpty;

  await PermissionHelper.load();


  runApp(CRMApp(isLoggedIn: isLoggedIn));
}

class CRMApp extends StatelessWidget {
  final bool isLoggedIn;
  const CRMApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRM',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      
      // Named routes for clean Login ↔ Home navigation
      initialRoute: isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home':  (_) => const MainShell(),
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MAIN SHELL — bottom navigation
// ══════════════════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  bool get _canManageUsers => PermissionHelper.can('users_roles');

  List<Widget> get _screens => [
  const DashboardScreen(),
  const LeadsScreen(),
  if (_canManageUsers)
    const UserRoleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

// ─── Custom Bottom Nav ────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  const _BottomNav({required this.selectedIndex, required this.onTap});
  bool get _canManageUsers => PermissionHelper.can('users_roles');

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
    ),
    child: SafeArea( 
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _NavItem(icon: Icons.dashboard_outlined,       activeIcon: Icons.dashboard_rounded,       label: 'Dashboard', isSelected: selectedIndex == 0, onTap: () => onTap(0)),
          _NavItem(icon: Icons.people_outline,           activeIcon: Icons.people_rounded,          label: 'Leads',     isSelected: selectedIndex == 1, onTap: () => onTap(1)),
if (_canManageUsers)
  _NavItem(
    icon: Icons.manage_accounts_outlined,
    activeIcon: Icons.manage_accounts_rounded,
    label: 'Users',
    isSelected: selectedIndex == 2,
    onTap: () => onTap(2),
  ),
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

  const _NavItem({required this.icon, required this.activeIcon, required this.label,
      required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: isSelected ? 18 : 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isSelected ? activeIcon : icon, size: 22,
            color: isSelected ? AppColors.primary : AppColors.textSecondary),
        if (isSelected) ...[
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ]),
    ),
  );
}