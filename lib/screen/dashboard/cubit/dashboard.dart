// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/dashboard/cubit/dashboard.dart            ║
// ╚══════════════════════════════════════════════════════════════╝

// ignore_for_file: unnecessary_cast

import 'dart:async' show unawaited;

import 'package:connectivity_plus/connectivity_plus.dart' show Connectivity, ConnectivityResult;
import 'package:crm_app/database/local_db.dart';
import 'package:crm_app/modals/followup_model.dart';
import 'package:crm_app/modals/modals.dart' show Lead;
import 'package:crm_app/screen/LeaderBoard/cubit/leaderBoard_cubit.dart';
import 'package:crm_app/screen/dashboard/ui/dashboard_screen.dart'
    show
        PipelineStage,
        DashboardLoading,
        DashboardState,
        DashboardSummary,
        DashboardInitial,
        DashboardLoaded,
        DashboardError,
        InvoiceRecord;
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:crm_app/utils/permission_helper.dart';
import 'package:dio/dio.dart'
    show DioExceptionType, DioException, Dio, BaseOptions, InterceptorsWrapper;
import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

class DashboardCubit extends Cubit<DashboardState> {
  static const _base = 'https://crm-backend-api.techzarinfo.cloud';

  late final Dio _dio;
  String? _cachedToken;
  final Map<String, double> _rateCache = {};

  DashboardCubit() : super(DashboardInitial()) {
    _dio = Dio(BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opt, handler) {
        if (_cachedToken != null && _cachedToken!.isNotEmpty) {
          opt.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        handler.next(opt);
      },
      onError: (err, handler) {
        if (err.response?.statusCode == 401) _cachedToken = null;
        handler.next(err);
      },
    ));
    _dio.interceptors.add(AuthInterceptor());
    _initToken();
  }

  Future<void> _initToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('token');
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════
  // LOAD DASHBOARD
  // ════════════════════════════════════════════════════════════

  Future<void> loadDashboard() async {
    if (isClosed) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    // ── Step 1: Show last-online data immediately ─────────────
    // If the user is offline or the fetch is slow, they still see
    // real data instead of a blank/loading screen.
    // await _tryEmitCachedDashboard(userId);

    // ── Step 2: Only show spinner if nothing is on screen yet ─
    if (state is! DashboardLoaded) emit(DashboardLoading());

    try {
      if (_cachedToken == null || _cachedToken!.isEmpty) await _initToken();
      await _setTenantBaseUrl();

      await PermissionHelper.load();

      final userName = prefs.getString('user_name') ?? '';
      final canViewAll = PermissionHelper.can('s');

      // Fetch everything in parallel
  final results = await Future.wait([
  _fetchLeads('/leads/getAllLead'),
  _safeLeads('/leads/recent'),

  // NEW: dashboard overview
  _fetchDashboardOverview(),

  _fetchSummary(),
  _fetchInvoices(),

  _fetchAllDealMaps(),
]);

final leadsResult =
    results[0] as ({List<Lead> leads, int? total});

final allLeadsRaw = leadsResult.leads;

final leadsTotalFromApi = leadsResult.total;

final recentLeadsRaw =
    results[1] as List<Lead>;

final overview =
    results[2] as Map<String, dynamic>;

// ─────────────────────────────────────────────
// OVERVIEW → SUMMARY → REVENUE BY CURRENCY
// ─────────────────────────────────────────────

Map<String, dynamic> overviewSummary = {};

if (overview['summary'] is Map) {
  overviewSummary = Map<String, dynamic>.from(
    overview['summary'] as Map,
  );
} else if (overview['data'] is Map &&
    (overview['data'] as Map)['summary'] is Map) {
  overviewSummary = Map<String, dynamic>.from(
    (overview['data'] as Map)['summary'] as Map,
  );
}

double totalRevenue = 0;
String preferredCurrency = 'INR';

final revenueByCurrency =
    overviewSummary['revenueByCurrency'];

debugPrint(
  '[Revenue DEBUG] summary keys=${overviewSummary.keys.toList()}',
);

debugPrint(
  '[Revenue DEBUG] revenueByCurrency=$revenueByCurrency',
);

if (revenueByCurrency is Map) {
  for (final entry in revenueByCurrency.entries) {
    final value = entry.value;

    if (value is! Map) continue;

    final currency =
        value['preferredCurrency']?.toString().trim();

    if (currency != null && currency.isNotEmpty) {
      preferredCurrency = currency;
    }

    final rawValue =
        value['preferredCurrencyValue'];

    final parsedValue =
        rawValue is num
            ? rawValue.toDouble()
            : double.tryParse(
                rawValue?.toString().replaceAll(',', '') ?? '0',
              ) ??
              0;

    totalRevenue += parsedValue;

    debugPrint(
      '[Revenue DEBUG] '
      'key=${entry.key} '
      'currency=$preferredCurrency '
      'preferredCurrencyValue=$parsedValue',
    );
  }
}

debugPrint(
  '[Revenue DEBUG] FINAL '
  'currency=$preferredCurrency '
  'totalRevenue=$totalRevenue',
);
final base =
    results[3] as DashboardSummary;

final invoices =
    results[4] as List<InvoiceRecord>;

final allDealRows =
    results[5] as List<Map<String, dynamic>>;
      final allLeads = canViewAll
          ? allLeadsRaw
          : allLeadsRaw.where((l) => l.assignedToId == userId).toList();
      final recentLeads = canViewAll
          ? recentLeadsRaw
          : recentLeadsRaw.where((l) => l.assignedToId == userId).toList();
      final todaysFollowUps =
          _buildTodaysFollowUps(allLeads, allDealRows); // ← ADD


      final pendingLeads = base.pendingLeads > 0
          ? base.pendingLeads
          : allLeads.where((l) => l.status != 'Converted').length;

      final scopedDeals = _scopeDealsForUser(
        allDealRows,
        canViewAll: canViewAll,
        userId: userId,
        userName: userName,
      );
      final pipeline = _buildPipelineFromDeals(scopedDeals);
      final dealMetrics = _dealMetricsForPeriod(
  scopedDeals,
  range: 'all',
  month: null,
  year: null,
  apiFallback: base,
  dealsFetched: allDealRows.isNotEmpty,
);
// ════════════════════════════════════════════════════════════
// DASHBOARD CARD VALUES FROM OVERVIEW API
// ════════════════════════════════════════════════════════════

final overviewTotalLeads =
    _getOverviewTotalLeads(overview);

final overviewDealsWon =
    _getOverviewDealsWon(overview);

final overviewPendingInvoices =
    _getOverviewPendingInvoices(overview);


debugPrint(
  '[Dashboard Cards] '
  'leads=$overviewTotalLeads, '
  'dealsWon=$overviewDealsWon, '
  'pendingInvoices=$overviewPendingInvoices, '
  'totalRevenue=$totalRevenue, '
  'currency=$preferredCurrency',
);
//
      Map<String, dynamic>? topPerformer;

try {
  final now = DateTime.now();

  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6));

  final end = DateTime(
    now.year,
    now.month,
    now.day,
  );

  final leaderboard = await LeaderboardService.fetchLeaderboard(
    token: _cachedToken ?? '',
    filterType: 'last7',
    startDate:
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}",
    endDate:
        "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}",
  );

  if (leaderboard.data.isNotEmpty) {
    if (canViewAll) {
      // Admin/manager view — show the actual #1 performer.
      leaderboard.data.sort(
        (a, b) => b.convertedLeads.compareTo(a.convertedLeads),
      );
      final top = leaderboard.data.first;
      topPerformer = {
        "name": top.name,
        "email": top.email,
        "conversionRate": top.conversionRate,
        "convertedLeads": top.convertedLeads,
        "totalLeads": top.totalLeads,
        "productiveDays": top.productiveDays,
      };
    } else {
      // Salesperson view — show their own stats, not the leaderboard's #1.
      final mine = _findOwnLeaderboardEntry(
        leaderboard.data,
        userId: userId,
        userName: userName,
      );
      if (mine != null) {
        topPerformer = {
          "name": mine.name,
          "email": mine.email,
          "conversionRate": mine.conversionRate,
          "convertedLeads": mine.convertedLeads,
          "totalLeads": mine.totalLeads,
          "productiveDays": mine.productiveDays,
        };
      }
    }
  }
} catch (_) {}
  final summary = DashboardSummary(
  totalLeads: overviewTotalLeads,

  totalDeals: dealMetrics.totalDeals,

  dealsWon: overviewDealsWon,

  pendingLeads: pendingLeads,

  pendingInvoices: overviewPendingInvoices,

  leadsChange: base.leadsChange,

  dealsChange: dealMetrics.dealsChange,

  paidRevenue: 0,

  unpaidRevenue: 0,

  totalRevenue: totalRevenue,

  preferredCurrency: preferredCurrency,
);
      // Default filter: last 7 days
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6));
      

      if (isClosed) return;

      final freshState = DashboardLoaded(
        topPerformer: topPerformer,
        allLeads: allLeads,
        recentLeads: recentLeads,
        summary: summary,
        pipeline: pipeline,
        invoices: invoices,
        todaysFollowUps: todaysFollowUps, // ← ADD
        allDealRows: allDealRows,
        filterRange: 'all',
        filterMonth: null,
        filterYear: null,
      );

      emit(freshState);

      // ── Step 3: Persist to DB — becomes the new offline snapshot
      unawaited(_persistDashboard(userId, freshState));
    } on DioException catch (e) {
      if (isClosed) return;
      // Don't overwrite cached data with an error screen
      if (state is! DashboardLoaded) emit(DashboardError(_dioMsg(e)));
    } catch (e) {
      if (isClosed) return;
      if (state is! DashboardLoaded) emit(DashboardError(e.toString()));
    }
  }

  Future<void> refresh() async {
  final result = await Connectivity().checkConnectivity();

  if (result == ConnectivityResult.none) {
    return;
  }

  if (state is! DashboardLoading) {
    await loadDashboard();
  }
}

// ════════════════════════════════════════════════════════════
// DASHBOARD OVERVIEW
// ════════════════════════════════════════════════════════════

Future<Map<String, dynamic>> _fetchDashboardOverview({
  String? start,
  String? end,
}) async {
  try {
    final res = await _dio.get(
      '/dashboard/overview',
      queryParameters: {
        'start': start ?? '',
        'end': end ?? '',
      },
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }

    return {};
  } catch (e) {
    debugPrint('[Dashboard Overview] $e');
    return {};
  }
}
// ════════════════════════════════════════════════════════════
// OVERVIEW CARD CALCULATIONS
// ════════════════════════════════════════════════════════════

List<dynamic> _extractOverviewList(
  Map<String, dynamic> overview,
  String key,
) {
  dynamic value = overview[key];

  // If the API wraps everything inside data
  if (value == null && overview['data'] is Map) {
    value = (overview['data'] as Map)[key];
  }

  // If the API wraps everything inside result
  if (value == null && overview['result'] is Map) {
    value = (overview['result'] as Map)[key];
  }

  if (value is List) {
    return value;
  }

  return <dynamic>[];
}


// Total Leads = number of items inside leads
int _getOverviewTotalLeads(
  Map<String, dynamic> overview,
) {
  final leads = _extractOverviewList(overview, 'leads');

  return leads.length;
}


// Deals Won = number of items inside dealsWon whose stage is "Closed Won"
int _getOverviewDealsWon(
  Map<String, dynamic> overview,
) {
  final dealsWon = _extractOverviewList(overview, 'dealsWon');

  return dealsWon.where((item) {
    if (item is! Map) return false;
    final stage = item['stage']?.toString().toLowerCase().trim();
    return stage == 'closed won';
  }).length;
}


// Pending invoices = count invoices whose status is unpaid
int _getOverviewPendingInvoices(
  Map<String, dynamic> overview,
) {
  final invoices = _extractOverviewList(overview, 'invoices');

  int count = 0;

  for (final item in invoices) {
    if (item is! Map) continue;

    final status =
        item['status']?.toString().trim().toLowerCase();

    if (status == 'unpaid') {
      count++;
    }
  }

  return count;
}




  // ════════════════════════════════════════════════════════════
  // OFFLINE HELPERS
  // ════════════════════════════════════════════════════════════

  /// Emit whatever was last saved to the local DB for [userId].
  /// Called before every network fetch so the screen is never blank.
  Future<void> _tryEmitCachedDashboard(String userId) async {
    try {
      final cached = await LocalDb.instance.loadDashboard(userId: userId);
      if (cached == null || isClosed) return;
      emit(DashboardLoaded(
        topPerformer: null,
        allLeads: cached.recentLeads,
        recentLeads: cached.recentLeads,
        summary: cached.summary,
        pipeline: cached.pipeline,
        invoices: cached.invoices, // ← restored from cache (was const [])
        allDealRows: cached.allDealRows, // ← ADD (was missing, defaulted to [])
        filterRange: cached.filterRange,
        filterMonth: cached.filterMonth,
        filterYear: cached.filterYear,
      ));
    } catch (_) {}
  }

  /// Persist a fresh [DashboardLoaded] state to the local DB so it
  /// becomes the offline snapshot for the next session.
  Future<void> _persistDashboard(String userId, DashboardLoaded s) async {
    try {
      await LocalDb.instance.saveDashboard(
        userId: userId,
        summary: s.summary,
        pipeline: s.pipeline,
        recentLeads: s.recentLeads,
        invoices: s.invoices, // ← now persisted
        allDealRows: s.allDealRows,
        filterRange: s.filterRange,
        filterMonth: s.filterMonth,
        filterYear: s.filterYear,
      );
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════
  // PERIOD FILTER
  // ════════════════════════════════════════════════════════════
  Future<void> filterByPeriod({
    required String range,
    int? month,
    int? year,
  }) async {
    
    final cur = state;

    if (cur is! DashboardLoaded) return;

    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('user_id') ?? '';

    final userName = prefs.getString('user_name') ?? '';

    final canViewAll = PermissionHelper.can('s');

    double filteredTotalRevenue = cur.summary.totalRevenue;
String filteredPreferredCurrency =
    cur.summary.preferredCurrency;

    final scopedDeals = _scopeDealsForUser(
      cur.allDealRows,
      canViewAll: canViewAll,
      userId: userId,
      userName: userName,
    );

    final window = _periodWindow(
  range,
  month: month,
  year: year,
);

final filteredDealRows = scopedDeals.where((deal) {
  final date = _dealFilterDate(deal);
  return _dateInWindow(date, window);
}).toList();

    final dealMetrics = _dealMetricsForPeriod(
      scopedDeals,
      range: range,
      month: month,
      year: year,
      apiFallback: cur.summary,
      dealsFetched: cur.allDealRows.isNotEmpty,
    );


    final filteredPipeline = _buildPipelineFromDeals(
  filteredDealRows,
);


    List<InvoiceRecord> filtered = cur.invoices.where((inv) {
      return _dateInWindow(inv.issueDate, window);
    }).toList();

    

    List<Lead> leadsInRange = cur.allLeads.where((l) {
      return _dateInWindow(l.createdAt, window);
    }).toList();

  
// ─────────────────────────────────────────────
// FILTERED REVENUE FROM DASHBOARD OVERVIEW API
// ─────────────────────────────────────────────



String? revenueStart;
String? revenueEnd;

if (window != null) {
  revenueStart =
      '${window.start.year}-'
      '${window.start.month.toString().padLeft(2, '0')}-'
      '${window.start.day.toString().padLeft(2, '0')}';

  final endDay = window.endExclusive != null
      ? window.endExclusive!.subtract(
          const Duration(days: 1),
        )
      : DateTime.now();

  revenueEnd =
      '${endDay.year}-'
      '${endDay.month.toString().padLeft(2, '0')}-'
      '${endDay.day.toString().padLeft(2, '0')}';
}

// Get filtered summary from overview API
final filteredOverview = await _fetchDashboardOverview(
  start: revenueStart,
  end: revenueEnd,
);

final filteredOverviewSummary =
    filteredOverview['summary'] is Map
        ? Map<String, dynamic>.from(
            filteredOverview['summary'] as Map,
          )
        : <String, dynamic>{};

final filteredRevenueByCurrency =
    filteredOverviewSummary['revenueByCurrency'];

filteredTotalRevenue = 0;

if (filteredRevenueByCurrency is Map) {
  for (final value
      in filteredRevenueByCurrency.values) {
    if (value is Map) {
      final rawValue =
          value['preferredCurrencyValue'];

      final parsedValue = rawValue is num
          ? rawValue.toDouble()
          : double.tryParse(
                rawValue?.toString() ?? '0',
              ) ??
              0;

      filteredTotalRevenue += parsedValue;

      final currency =
          value['preferredCurrency']?.toString().trim();

      if (currency != null && currency.isNotEmpty) {
        filteredPreferredCurrency = currency;
      }
    }
  }
}

debugPrint(
  '[FILTER REVENUE] '
  'range=$range '
  'start=$revenueStart '
  'end=$revenueEnd '
  'currency=$filteredPreferredCurrency '
  'total=$filteredTotalRevenue',
);
    
    // Top Performer
    Map<String, dynamic>? topPerformer;

    try {
      String? startDate;
      String? endDate;

      String filterType = range;

      // TODAY
      if (range == 'today') {
        final now = DateTime.now();

        startDate =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

        endDate = startDate;
      }

      // YEAR
if (range == 'year' && year != null) {
  filterType = 'year';
  startDate = "$year-01-01";
  endDate = "$year-12-31";
}

      // MONTH
      if (range == 'month' && month != null && year != null) {
        filterType = 'month';

        startDate = "$year-${month.toString().padLeft(2, '0')}-01";

        final lastDay = DateTime(year, month + 1, 0).day;

        endDate = "$year-${month.toString().padLeft(2, '0')}-$lastDay";
      }

      final leaderboard = await LeaderboardService.fetchLeaderboard(
        token: _cachedToken ?? '',
        filterType: filterType,
        startDate: startDate,
        endDate: endDate,
      );

      if (leaderboard.data.isNotEmpty) {
  if (canViewAll) {
    leaderboard.data.sort(
      (a, b) => b.convertedLeads.compareTo(a.convertedLeads),
    );
    final top = leaderboard.data.first;
    topPerformer = {
      "name": top.name,
      "email": top.email,
      "conversionRate": top.conversionRate,
      "convertedLeads": top.convertedLeads,
      "totalLeads": top.totalLeads,
      "productiveDays": top.productiveDays,
    };
  } else {
    final mine = _findOwnLeaderboardEntry(
      leaderboard.data,
      userId: userId,
      userName: userName,
    );
    if (mine != null) {
      topPerformer = {
        "name": mine.name,
        "email": mine.email,
        "conversionRate": mine.conversionRate,
        "convertedLeads": mine.convertedLeads,
        "totalLeads": mine.totalLeads,
        "productiveDays": mine.productiveDays,
      };
    }
  }
}
    } catch (_) {}

    if (isClosed) return;

    emit(
      DashboardLoaded(
        topPerformer: topPerformer,
        allLeads: cur.allLeads,
        recentLeads: cur.recentLeads,
        summary: cur.summary.copyWith(
  totalLeads: leadsInRange.length,
  totalDeals: dealMetrics.totalDeals,
  dealsWon: dealMetrics.dealsWon,
  dealsChange: dealMetrics.dealsChange,
  totalRevenue: filteredTotalRevenue,
  preferredCurrency: filteredPreferredCurrency,


),
        pipeline: filteredPipeline,
invoices: filtered,
todaysFollowUps: cur.todaysFollowUps
    .where((f) => _dateInWindow(f.followUpDate, window))
    .toList(),


allDealRows: cur.allDealRows,
        filterRange: range,
        filterMonth: range == 'month' ? month : null,
        filterYear: (range == 'month' || range == 'year') ? year : null,
      ),
    );
  }

  List<PipelineStage> _buildPipelineFromDeals(
  List<Map<String, dynamic>> deals,
) {
  final stages = <String, PipelineStage>{};

  for (final deal in deals) {
    final rawStage = deal['stage']?.toString().trim();

    if (rawStage == null || rawStage.isEmpty) {
      continue;
    }

    final rawValue =
        deal['value'] ??
        deal['dealValue'] ??
        deal['amount'];

    final value = double.tryParse(
          rawValue
                  ?.toString()
                  .replaceAll(RegExp(r'[^\d.\-]'), '') ??
              '0',
        ) ??
        0;

    final currency =
        deal['currency']?.toString().trim();

    final key = rawStage.toLowerCase();

    final existing = stages[key];

    if (existing == null) {
      stages[key] = PipelineStage(
        stage: rawStage,
        count: 1,
        value: value,
        currency:
            currency != null && currency.isNotEmpty
                ? currency
                : 'INR',
      );
    } else {
      stages[key] = PipelineStage(
        stage: existing.stage,
        count: existing.count + 1,
        value: existing.value + value,
        currency: existing.currency,
      );
    }
  }

  return _mergePipelineByStage(
    _applyPipelineStageRules(
      stages.values.toList(),
    ),
  );
}

  // ════════════════════════════════════════════════════════════
  // DEALS
  // ════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> _fetchAllDealMaps() async {
    try {
      final res = await _dio.get('/deals/getAll');
      final body = res.data;
      List<dynamic> raw = [];
      if (body is List) {
        raw = body;
      } else if (body is Map) {
        for (final k in ['data', 'deals', 'result', 'records']) {
          if (body[k] is List) {
            raw = body[k] as List;
            break;
          }
        }
      }
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[Deals] getAll for dashboard: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _scopeDealsForUser(
    List<Map<String, dynamic>> rows, {
    required bool canViewAll,
    required String userId,
    required String userName,
  }) {
    if (canViewAll) return List<Map<String, dynamic>>.from(rows);
    return rows.where((m) => _dealAssignedToUser(m, userId, userName)).toList();
  }

  DateTime? _dealFilterDate(Map<String, dynamic> m) {
    for (final k in ['createdAt']) {
      final d = DateTime.tryParse((m[k] ?? '').toString());
      if (d != null) return d;
    }
    return null;
  }

  bool _isWonDealStage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return s == 'closedwon';
  }

  bool _dealDayInRange(
    DateTime? d, {
    required DateTime rangeStartDay,
    DateTime? rangeEndExclusiveDay,
  }) {
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(rangeStartDay)) return false;
    if (rangeEndExclusiveDay != null && !day.isBefore(rangeEndExclusiveDay)) {
      return false;
    }
    return true;
  }

  DateTime? _dealWonDate(Map<String, dynamic> m) =>
    DateTime.tryParse((m['wonAt'] ?? '').toString());

({int total, int won}) _dealCountsInRange(
  List<Map<String, dynamic>> deals, {
  required DateTime rangeStartDay,
  DateTime? rangeEndExclusiveDay,
}) {
  var total = 0, won = 0;
  for (final m in deals) {
    // "total" (created in this window) still uses createdAt.
    final createdDay = _dealFilterDate(m);
    if (_dealDayInRange(createdDay,
        rangeStartDay: rangeStartDay,
        rangeEndExclusiveDay: rangeEndExclusiveDay)) {
      total++;
    }

    // "won" now counts deals WON in this window, using wonAt when
    // present — falls back to stage+createdAt for older deals that
    // predate the backend populating wonAt.
    final wonDay = _dealWonDate(m);
    if (wonDay != null) {
      if (_dealDayInRange(wonDay,
          rangeStartDay: rangeStartDay,
          rangeEndExclusiveDay: rangeEndExclusiveDay)) {
        won++;
      }
    } else if (_isWonDealStage(m['stage']?.toString()) &&
        _dealDayInRange(createdDay,
            rangeStartDay: rangeStartDay,
            rangeEndExclusiveDay: rangeEndExclusiveDay)) {
      won++;
    }
  }
  return (total: total, won: won);
}

  double _percentChangeInt(int current, int previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100.0;
  }
  ({DateTime start, DateTime? endExclusive})? _periodWindow(
  String range, {
  int? month,
  int? year,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (range) {
    case 'all':
      return null; // no bound — everything matches
    case 'today':
      return (start: today, endExclusive: today.add(const Duration(days: 1)));
    case 'last7':
      return (start: today.subtract(const Duration(days: 6)), endExclusive: null);
    case 'year':
      final y = year ?? now.year;
      return (start: DateTime(y, 1, 1), endExclusive: DateTime(y + 1, 1, 1));
    case 'month':
      final m = month ?? now.month;
      final y = year ?? now.year;
      final start = DateTime(y, m, 1);
      final endEx = m == 12 ? DateTime(y + 1, 1, 1) : DateTime(y, m + 1, 1);
      return (start: start, endExclusive: endEx);
    default:
      return null;
  }
}

bool _dateInWindow(DateTime? d, ({DateTime start, DateTime? endExclusive})? window) {
  if (window == null) return true; // 'all' — everything passes
  if (d == null) return false;
  final day = DateTime(d.year, d.month, d.day);
  if (day.isBefore(window.start)) return false;
  if (window.endExclusive != null && !day.isBefore(window.endExclusive!)) return false;
  return true;
}

//===================
  ({int totalDeals, int dealsWon, double dealsChange}) _dealMetricsForPeriod(
    List<Map<String, dynamic>> scopedDeals, {
    required String range,
    int? month,
    int? year,
    required DashboardSummary apiFallback,
    required bool dealsFetched,
  }) {
    if (!dealsFetched) {
      return (
        totalDeals: apiFallback.totalDeals,
        dealsWon: apiFallback.dealsWon,
        dealsChange: apiFallback.dealsChange,
      );
    }

    final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

if (range == 'all') {
  final total = scopedDeals.length;
  final won = _totalWonDealsCount(scopedDeals);
  return (totalDeals: total, dealsWon: won, dealsChange: 0);
}

if (range == 'year') {
  final y = year ?? now.year;
  final curStart = DateTime(y, 1, 1);
  final curEndEx = DateTime(y + 1, 1, 1);
  final cur = _dealCountsInRange(scopedDeals,
      rangeStartDay: curStart, rangeEndExclusiveDay: curEndEx);
  final prevStart = DateTime(y - 1, 1, 1);
  final prevEndEx = DateTime(y, 1, 1);
  final prev = _dealCountsInRange(scopedDeals,
      rangeStartDay: prevStart, rangeEndExclusiveDay: prevEndEx);
  return (
    totalDeals: cur.total,
    dealsWon: cur.won,
    dealsChange: _percentChangeInt(cur.won, prev.won),
  );
}

if (range == 'today') {      final cur = _dealCountsInRange(
        scopedDeals,
        rangeStartDay: today,
        rangeEndExclusiveDay: today.add(const Duration(days: 1)),
      );

      final yesterday = today.subtract(const Duration(days: 1));

      final prev = _dealCountsInRange(
        scopedDeals,
        rangeStartDay: yesterday,
        rangeEndExclusiveDay: today,
      );

      return (
        totalDeals: cur.total,
        dealsWon: cur.won,
        dealsChange: _percentChangeInt(cur.won, prev.won),
      );
    } else if (range == 'last7') {
      final curStart = today.subtract(const Duration(days: 6));
      final cur = _dealCountsInRange(scopedDeals, rangeStartDay: curStart);
      final prevStart = today.subtract(const Duration(days: 13));
      final prevEndEx = today.subtract(const Duration(days: 6));
      final prev = _dealCountsInRange(scopedDeals,
          rangeStartDay: prevStart, rangeEndExclusiveDay: prevEndEx);
      return (
        totalDeals: cur.total,
        dealsWon: cur.won,
        dealsChange: _percentChangeInt(cur.won, prev.won),
      );
    }

    final m = month ?? now.month;
    final y = year ?? now.year;
    final curStart = DateTime(y, m, 1);
    final curEndEx = m == 12 ? DateTime(y + 1, 1, 1) : DateTime(y, m + 1, 1);
    final cur = _dealCountsInRange(scopedDeals,
        rangeStartDay: curStart, rangeEndExclusiveDay: curEndEx);
    final prevStart = DateTime(y, m - 1, 1);
    final prevEndEx = DateTime(y, m, 1);
    final prev = _dealCountsInRange(scopedDeals,
        rangeStartDay: prevStart, rangeEndExclusiveDay: prevEndEx);
    return (
      totalDeals: cur.total,
      dealsWon: cur.won,
      dealsChange: _percentChangeInt(cur.won, prev.won),
    );
  }

  // ════════════════════════════════════════════════════════════
  // REVENUE
  // ════════════════════════════════════════════════════════════

  Future<Map<String, double>> _fetchRatesForInvoices(
      List<InvoiceRecord> invoices) async {
    final currencies = invoices
        .map((i) => i.currency.toUpperCase().trim())
        .where((c) => c.isNotEmpty && c != 'INR')
        .toSet();
    if (currencies.isEmpty) return _rateCache;

    await Future.wait(currencies.map((ccy) async {
      if (_rateCache.containsKey(ccy)) return;
      try {
        final res = await _dio.get('/invoices/exchange-rate/$ccy');
        final rate = double.tryParse(res.data?['rate']?.toString() ?? '');
        if (rate != null && rate > 0) _rateCache[ccy] = rate;
      } catch (_) {}
    }));
    return _rateCache;
  }

  _RevenueResult _computeRevenue(
    List<InvoiceRecord> invoices, {
    Map<String, double> rates = const {},
  }) {
    double paid = 0, unpaid = 0;
    for (final inv in invoices) {
      final ccy = inv.currency.toUpperCase();
      double inrAmt = 0;

      if (ccy == 'INR') {
        inrAmt = inv.total;
      } else if (inv.status == 'paid') {
        if (inv.exchangeRate != null && inv.exchangeRate! > 0) {
          inrAmt = inv.total * inv.exchangeRate!;
        } else if (inv.inrAmount != null && inv.inrAmount! > 0) {
          inrAmt = inv.inrAmount!;
        } else if ((rates[ccy] ?? 0) > 0) {
          inrAmt = inv.total * rates[ccy]!;
        }
      } else {
        if (inv.exchangeRate != null && inv.exchangeRate! > 0) {
          inrAmt = inv.total * inv.exchangeRate!;
        } else if ((rates[ccy] ?? 0) > 0) {
          inrAmt = inv.total * rates[ccy]!;
        }
      }

      if (inv.status == 'paid') {
        paid += inrAmt;
      } else {
        unpaid += inrAmt;
      }
    }
    return _RevenueResult(paid: paid, unpaid: unpaid, total: paid + unpaid);
  }

  // ════════════════════════════════════════════════════════════
  // INVOICES
  // ════════════════════════════════════════════════════════════

  Future<List<InvoiceRecord>> _fetchInvoices() async {
    try {
      final res = await _dio.get('/invoices/getInvoice');
      final body = res.data;
      debugPrint('[Invoice] status=${res.statusCode}');

      List<dynamic> raw = [];
      if (body is List) {
        raw = body;
      } else if (body is Map) {
        for (final k in ['data', 'invoices', 'result', 'records', 'invoice']) {
          if (body[k] is List) {
            raw = body[k] as List;
            break;
          }
        }
        if (raw.isEmpty) {
          for (final v in (body as Map).values) {
            if (v is List) {
              raw = v;
              break;
            }
          }
        }
      }
      return raw
          .whereType<Map>()
          .map((e) => InvoiceRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[Invoice] error: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════
  // LEADS
  // ════════════════════════════════════════════════════════════

  Future<({List<Lead> leads, int? total})> _fetchLeads(String path) async {
  final res = await _dio.get(
    path,
    queryParameters: {'page': 1, 'limit': 100000}, // fetch the full set, not the default page
  );
  debugPrint('[Leads] $path  ${res.statusCode}');
  final leads = _parseLeadList(res.data);
  final total = _extractLeadsTotalCount(res.data);
  return (leads: leads, total: total);
}

  Future<List<Lead>> _safeLeads(String path) async {
    try {
      final res = await _dio.get(path);
      return _parseLeadList(res.data);
    } catch (_) {
      return <Lead>[];
    }
  }

  List<Lead> _parseLeadList(dynamic data) {
    List<dynamic> raw = [];
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      for (final k in ['data', 'leads', 'result', 'records']) {
        if (data[k] is List) {
          raw = data[k] as List;
          break;
        }
      }
    }
    final out = <Lead>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          final m = Map<String, dynamic>.from(item);
          final assignRaw = m['assignTo'] ?? m['assignedTo'];
          if (assignRaw is Map) {
            final fn = assignRaw['firstName']?.toString() ?? '';
            final ln = assignRaw['lastName']?.toString() ?? '';
            m['assignTo'] = '$fn $ln'.trim();
            m['assignedToId'] = assignRaw['_id']?.toString() ??
                assignRaw['id']?.toString() ??
                '';
          } else if (assignRaw != null) {
            m['assignTo'] = assignRaw.toString().trim();
          }
          if ((m['assignedToId'] == null ||
                  m['assignedToId'].toString().isEmpty) &&
              m['assignToId'] != null) {
            m['assignedToId'] = m['assignToId'].toString();
          }
          out.add(Lead.fromJson(m));
        } catch (_) {}
      }
    }
    return out;
  }

  // ======================================
  //  filter/merge helper
  // ======================================

  DateTime? _parseFollowUpDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  bool _isFollowUpToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  List<FollowUpItem> _buildTodaysFollowUps(
  List<Lead> leads,
  List<Map<String, dynamic>> deals,
) {
  final items = <FollowUpItem>[];

  for (final l in leads) {
    final d = _parseFollowUpDate(l.followUpDate);
    if (!_isFollowUpToday(d)) continue;
    items.add(FollowUpItem(
      type: FollowUpType.lead,
      title: l.name,
      subtitle: l.notes, // ← straight from API, no fallback text
      followUpDate: d!,
      id: l.id,
      phone: l.phone,
    ));
  }

  for (final m in deals) {
    final d = _parseFollowUpDate(m['followUpDate']);
    if (!_isFollowUpToday(d)) continue;
    final title = (m['leadName'] ??
            m['dealName'] ??
            m['title'] ??
            'Deal')
        .toString();

    final subtitle = (m['followUpComment'] ?? '').toString(); // ← straight from API

    final rawValue = m['value'] ?? m['dealValue'] ?? m['amount'];
    final value = rawValue != null
        ? double.tryParse(
            rawValue.toString().replaceAll(RegExp(r'[^\d.\-]'), ''))
        : null;

    items.add(FollowUpItem(
      type: FollowUpType.deal,
      title: title,
      subtitle: subtitle,
      followUpDate: d!,
      id: (m['_id'] ?? m['id'] ?? '').toString(),
      dealValue: value,
      currency: (m['currency'] ?? 'INR').toString(),
    ));
  }

  items.sort((a, b) => a.followUpDate.compareTo(b.followUpDate));
  return items;
}
  // ════════════════════════════════════════════════════════════
  // SUMMARY
  // ════════════════════════════════════════════════════════════

  Future<DashboardSummary> _fetchSummary() async {
    try {
      final res = await _dio.get('/dashboard/summary');
      final body = res.data;
      debugPrint('[Summary] ${res.statusCode}  body=$body');
      if (body is Map) {
        return DashboardSummary.fromSummaryJson(
            Map<String, dynamic>.from(body as Map));
      }
      return const DashboardSummary();
    } catch (e) {
      debugPrint('[Summary] error: $e');
      return const DashboardSummary();
    }
  }

  // ════════════════════════════════════════════════════════════
  // PIPELINE
  // ════════════════════════════════════════════════════════════

  bool _dealAssignedToUser(
    Map<String, dynamic> m,
    String userId,
    String userName,
  ) {
    final uid = userId.trim();
    final uname = userName.trim().toLowerCase();

    final assignRaw = m['assignTo'] ?? m['assignedTo'];
    if (assignRaw is Map) {
      final id =
          assignRaw['_id']?.toString() ?? assignRaw['id']?.toString() ?? '';
      if (id.isNotEmpty && uid.isNotEmpty && id == uid) return true;
      final fn = assignRaw['firstName']?.toString().trim() ?? '';
      final ln = assignRaw['lastName']?.toString().trim() ?? '';
      final combined = '$fn $ln'.trim().toLowerCase();
      if (uname.isNotEmpty && combined.isNotEmpty && combined == uname) {
        return true;
      }
    } else if (assignRaw != null && uname.isNotEmpty) {
      if (assignRaw.toString().trim().toLowerCase() == uname) return true;
    }

    final topId =
        m['assignToId']?.toString() ?? m['assignedToId']?.toString() ?? '';
    if (topId.isNotEmpty && uid.isNotEmpty && topId == uid) return true;

    return false;
  }
T? _findOwnLeaderboardEntry<T>(
  List<T> entries, {
  required String userId,
  required String userName,
}) {
  final uname = userName.trim().toLowerCase();
  for (final e in entries) {
    final dynamic d = e;
    final id = (d.id ?? d.userId ?? '').toString();
    final name = (d.name ?? '').toString().trim().toLowerCase();
    if (userId.isNotEmpty && id == userId) return e;
    if (uname.isNotEmpty && name == uname) return e;
  }
  return null;
}
  List<PipelineStage> _applyPipelineStageRules(List<PipelineStage> input) {
    var proposalCount = 0;
    var proposalValue = 0.0;
    var proposalCurrency = 'INR';
    var invoiceCount = 0;
    var invoiceValue = 0.0;
    var invoiceCurrency = 'INR';
    final kept = <PipelineStage>[];

    for (final s in input) {
      if (_pipelineStageRollsIntoProposalSentNegotiation(s.stage)) {
        proposalCount += s.count;
        proposalValue += s.value;
        if (s.currency.trim().isNotEmpty) proposalCurrency = s.currency;
        continue;
      }
      if (_isInvoiceSentPipelineStage(s.stage)) {
        invoiceCount += s.count;
        invoiceValue += s.value;
        if (s.currency.trim().isNotEmpty) invoiceCurrency = s.currency;
        continue;
      }
      kept.add(s);
    }

    if (proposalCount > 0 || proposalValue > 0) {
      kept.add(PipelineStage(
        stage: 'Proposal Sent-Negotiation',
        count: proposalCount,
        value: proposalValue,
        currency: proposalCurrency,
      ));
    }
    if (invoiceCount > 0 || invoiceValue > 0) {
      kept.add(PipelineStage(
        stage: 'Invoice Sent',
        count: invoiceCount,
        value: invoiceValue,
        currency: invoiceCurrency,
      ));
    }
    return kept;
  }

  String _pipelineStageKey(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  bool _pipelineStageRollsIntoProposalSentNegotiation(String raw) {
    final k = _pipelineStageKey(raw);
    if (k.isEmpty) return false;
    if (k == 'proposal' || k == 'negotiation') return true;
    if (k == 'proposalsent') return true;
    if (k.contains('proposal') &&
        k.contains('sent') &&
        k.contains('negotiation')) {
      return true;
    }
    if (k == 'proposalsentnegotiation') return true;
    if (k.contains('proposal') && k.contains('negotiation')) return true;
    return false;
  }

  bool _isInvoiceSentPipelineStage(String raw) {
    final k = _pipelineStageKey(raw);
    return k == 'invoicesent' || (k.contains('invoice') && k.contains('sent'));
  }

  int _pipelineFunnelIndex(String stage) {
    const ordered = [
      'Qualification',
      'Proposal Sent-Negotiation',
      'Invoice Sent',
      'Closed Won',
      'Closed Lost',
    ];
    final t = stage.trim().toLowerCase();
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].toLowerCase() == t) return i;
    }
    return 100;
  }

  int _comparePipelineStages(PipelineStage a, PipelineStage b) {
    final oa = _pipelineFunnelIndex(a.stage);
    final ob = _pipelineFunnelIndex(b.stage);
    if (oa != ob) return oa.compareTo(ob);
    return b.count.compareTo(a.count);
  }

  List<PipelineStage> _mergePipelineByStage(List<PipelineStage> input) {
    final merged = <String, PipelineStage>{};
    for (final s in input) {
      final key = s.stage.trim().toLowerCase();
      final prev = merged[key];
      if (prev == null) {
        merged[key] = s;
      } else {
        merged[key] = PipelineStage(
          stage: prev.stage,
          count: prev.count + s.count,
          value: prev.value + s.value,
          currency: prev.currency.isNotEmpty ? prev.currency : s.currency,
        );
      }
    }
    return merged.values.toList()..sort(_comparePipelineStages);
  }

  Future<void> _setTenantBaseUrl() async {
  final prefs = await SharedPreferences.getInstance();

  final tenantSlug =
      prefs.getString('tenant_slug') ??
      prefs.getString('slug') ??
      '';

  if (tenantSlug.trim().isEmpty) {
    throw Exception('Tenant slug not found');
  }

  _dio.options.baseUrl =
      'https://crm-backend-api.techzarinfo.cloud/'
      '${tenantSlug.trim()}/api';

  debugPrint(
    '[Dashboard] Base URL = ${_dio.options.baseUrl}',
  );
}
  // deal helper

  int _totalWonDealsCount(List<Map<String, dynamic>> deals) =>
    deals.where((m) => _isWonDealStage(m['stage']?.toString())).length;

  // ════════════════════════════════════════════════════════════
  // ERROR HELPER
  // ════════════════════════════════════════════════════════════

  String _dioMsg(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout =>
          'Connection timed out.',
        DioExceptionType.connectionError => 'No internet connection.',
        DioExceptionType.badResponse =>
          'Server error (${e.response?.statusCode}).',
        _ => 'Something went wrong.',
      };
}



// ════════════════════════════════════════════════════════════
// INTERNAL HELPERS
// ════════════════════════════════════════════════════════════


class _RevenueResult {
  final double paid, unpaid, total;
  const _RevenueResult({
    required this.paid,
    required this.unpaid,
    required this.total,
  });
}
// ===========================
// Leads total count extractor
// ==========================
int? _extractLeadsTotalCount(dynamic raw) {
  if (raw is! Map) return null;
  for (final k in ['totalLeads', 'total', 'totalCount', 'totalRecords', 'count']) {
    final v = raw[k];
    if (v is num) return v.toInt();
  }
  return null;
}
// ════════════════════════════════════════════════════════════
// copyWith extension on DashboardSummary
// ════════════════════════════════════════════════════════════
extension DashboardSummaryX on DashboardSummary {
  DashboardSummary copyWith({
    int? totalLeads,
    int? totalDeals,
    int? dealsWon,
    int? pendingLeads,
    int? pendingInvoices,
    double? leadsChange,
    double? dealsChange,
    double? paidRevenue,
    double? unpaidRevenue,
    double? totalRevenue,
    String? preferredCurrency,
  }) =>
      DashboardSummary(
        totalLeads: totalLeads ?? this.totalLeads,
        totalDeals: totalDeals ?? this.totalDeals,
        dealsWon: dealsWon ?? this.dealsWon,
        pendingLeads: pendingLeads ?? this.pendingLeads,
        pendingInvoices:
            pendingInvoices ?? this.pendingInvoices,
        leadsChange: leadsChange ?? this.leadsChange,
        dealsChange: dealsChange ?? this.dealsChange,
        paidRevenue: paidRevenue ?? this.paidRevenue,
        unpaidRevenue: unpaidRevenue ?? this.unpaidRevenue,
        totalRevenue: totalRevenue ?? this.totalRevenue,
        preferredCurrency:
            preferredCurrency ?? this.preferredCurrency,
      );
}