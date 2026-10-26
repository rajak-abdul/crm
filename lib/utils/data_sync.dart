// ╔══════════════════════════════════════════════════════════════╗
// ║                  lib/utils/data_sync.dart                    ║
// ║  Keeps the bottom-nav tabs (Dashboard / Leads / Deals) fresh  ║
// ║  without reloading them on every tap.                         ║
// ╚══════════════════════════════════════════════════════════════╝
//
// • [shellActiveTab]      — which bottom-nav tab is showing (MainShell sets it).
// • [DataSync]            — "leads / deals changed at <time>"; marked by
//                           [DataSyncInterceptor] after any successful
//                           create / edit / delete / convert request.
// • [TabRefreshScope]     — wraps a tab; silently reloads it when it becomes
//                           active and its data is older than [DataSync.maxAge]
//                           or something changed since it last loaded.
// • [SessionCache]        — /users/me and /users/sales shared by every module
//                           for [SessionCache.ttl], keyed by the login token.

import 'dart:async';

import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data shown by a bottom-nav tab.
enum SyncArea { dashboard, leads, deals }

/// Index of the bottom-nav tab on screen (0 Dashboard, 1 Leads, 2 Deals).
final ValueNotifier<int> shellActiveTab = ValueNotifier<int>(0);

/// Records when each area's data last changed on the server (as far as
/// this app knows) and notifies listeners.
class DataSync extends ChangeNotifier {
  DataSync._();
  static final DataSync instance = DataSync._();

  /// A tab whose data is older than this reloads when you return to it.
  static const Duration maxAge = Duration(minutes: 2);

  final Map<SyncArea, DateTime> _changedAt = {};

  DateTime? changedAt(SyncArea area) => _changedAt[area];

  void markChanged(Iterable<SyncArea> areas) {
    if (areas.isEmpty) return;
    final now = DateTime.now();
    for (final a in areas) {
      _changedAt[a] = now;
    }
    notifyListeners();
  }

  /// On logout — the next user starts clean.
  void reset() => _changedAt.clear();
}

/// Add to a module's Dio: any successful non-GET request to a leads/deals
/// endpoint marks the tabs that show that data as changed.
class DataSyncInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final req = response.requestOptions;
    final ok = (response.statusCode ?? 200) < 400;
    if (ok && req.method.toUpperCase() != 'GET') {
      DataSync.instance.markChanged(areasForPath(req.uri.path));
    }
    handler.next(response);
  }

  /// Which tabs a change to [path] affects.
  @visibleForTesting
  static Set<SyncArea> areasForPath(String path) {
    final p = path.toLowerCase();
    final areas = <SyncArea>{};
    if (p.contains('/leads')) {
      areas
        ..add(SyncArea.dashboard)
        ..add(SyncArea.leads);
      // Converting a lead creates a deal.
      if (p.contains('convert')) areas.add(SyncArea.deals);
    }
    if (p.contains('/deals') || p.contains('/lost-deals')) {
      areas
        ..add(SyncArea.dashboard)
        ..add(SyncArea.deals);
    }
    return areas;
  }
}

/// Wraps one bottom-nav tab (inside its BlocProvider). While the tab is
/// on screen it reloads silently via [onRefresh] when:
///   • you switch to it and its data is older than [DataSync.maxAge], or
///   • its area changed after it last loaded (checked on switch, and
///     ~2.5 s after a change while it's showing — long enough for the
///     cubit's own reload after its own save to land first).
/// [tabIndex] null = not a bottom-nav tab (e.g. pushed from the drawer):
/// the scope does nothing.
class TabRefreshScope<C extends StateStreamable<S>, S> extends StatefulWidget {
  const TabRefreshScope({
    super.key,
    required this.area,
    required this.tabIndex,
    required this.isLoaded,
    required this.onRefresh,
    required this.child,
  });

  final SyncArea area;
  final int? tabIndex;
  final bool Function(S state) isLoaded;
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<TabRefreshScope<C, S>> createState() => _TabRefreshScopeState<C, S>();
}

class _TabRefreshScopeState<C extends StateStreamable<S>, S>
    extends State<TabRefreshScope<C, S>> {
  /// When the cubit last emitted loaded data (null = first load running).
  DateTime? _loadedAt;
  bool _refreshing = false;
  Timer? _debounce;

  bool get _isActive =>
      widget.tabIndex != null && shellActiveTab.value == widget.tabIndex;

  @override
  void initState() {
    super.initState();
    if (widget.isLoaded(context.read<C>().state)) _loadedAt = DateTime.now();
    shellActiveTab.addListener(_onTabChanged);
    DataSync.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    shellActiveTab.removeListener(_onTabChanged);
    DataSync.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (_isActive) _check(includeStale: true);
  }

  void _onDataChanged() {
    if (!_isActive) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 2500),
        () => _check(includeStale: false));
  }

  void _check({required bool includeStale}) {
    final loadedAt = _loadedAt;
    if (!mounted || !_isActive || _refreshing || loadedAt == null) return;

    final changed = DataSync.instance.changedAt(widget.area);
    final dirty = changed != null && changed.isAfter(loadedAt);
    final stale = includeStale &&
        DateTime.now().difference(loadedAt) > DataSync.maxAge;
    if (!dirty && !stale) return;

    debugPrint('[TabRefresh] ${widget.area.name}: '
        '${dirty ? 'changed' : 'stale'} → silent reload');
    _refreshing = true;
    widget.onRefresh().catchError((Object e) {
      debugPrint('[TabRefresh] ${widget.area.name} failed: $e');
    }).whenComplete(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) => BlocListener<C, S>(
        listener: (_, state) {
          if (widget.isLoaded(state)) _loadedAt = DateTime.now();
        },
        child: widget.child,
      );
}

/// /users/me and /users/sales, fetched once and shared by every module for
/// [ttl] — instead of each tab/cubit asking at startup. Keyed by the login
/// token, so a different user never gets the previous user's data; a
/// failed request isn't kept (the next call retries).
class SessionCache {
  SessionCache._();

  static const Duration ttl = Duration(minutes: 2);
  static const _host = 'https://crm-backend-api.techzarinfo.cloud';

  static final Map<String, ({DateTime at, Future<dynamic> data})> _entries =
      {};

  /// Raw response body of GET /{tenant}/api/users/me.
  static Future<dynamic> usersMe() => _get('/users/me');

  /// Raw response body of GET /{tenant}/api/users/sales.
  static Future<dynamic> salesUsers() => _get('/users/sales');

  static void clear() => _entries.clear();

  static Future<dynamic> _get(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final slug = (prefs.getString('tenant_slug') ??
            prefs.getString('tenantSlug') ??
            '')
        .trim();
    final key = '$token|$slug|$path';

    final hit = _entries[key];
    if (hit != null && DateTime.now().difference(hit.at) < ttl) {
      return hit.data;
    }

    final future = _fetch(path, token: token, slug: slug);
    _entries[key] = (at: DateTime.now(), data: future);
    try {
      return await future;
    } catch (_) {
      if (identical(_entries[key]?.data, future)) _entries.remove(key);
      rethrow;
    }
  }

  static Future<dynamic> _fetch(
    String path, {
    required String token,
    required String slug,
  }) async {
    // Tenant-scoped like every other endpoint; the slug-less URL fails.
    final dio = Dio(BaseOptions(
      baseUrl: slug.isEmpty ? '$_host/api' : '$_host/$slug/api',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ))
      ..interceptors.add(AuthInterceptor());
    final res = await dio.get(
      path,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return res.data;
  }
}
