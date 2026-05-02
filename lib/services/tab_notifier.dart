// lib/services/tab_notifier.dart
//
// Global ValueNotifier that allows any screen (e.g. the side drawer
// inside DashboardScreen) to switch the MainShell bottom-nav tab
// without a circular import between main.dart ↔ dashboard_screen.dart.
//
// Usage:
//   import 'package:crm_app/services/tab_notifier.dart';
//   tabNotifier.value = 1;   // switches to Leads tab

import 'package:flutter/foundation.dart';

/// 0 = Dashboard · 1 = Leads · 2 = Users
final tabNotifier = ValueNotifier<int>(0);