// ╔══════════════════════════════════════════════════════════════╗
// ║         lib/screen/dashboard/cubit/dashboard.dart            ║
// ╚══════════════════════════════════════════════════════════════╝

// ignore_for_file: unnecessary_cast

import 'package:crm_app/modals/modals.dart' show Lead;
import 'package:crm_app/utils/permission_helper.dart';
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
import 'package:dio/dio.dart'
    show DioExceptionType, DioException, Dio, BaseOptions, InterceptorsWrapper;
import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

class DashboardCubit extends Cubit<DashboardState> {
  static const _base = 'https://sales.stagingzar.com/api';

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
    _initToken();
  }

  Future<void> _initToken() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('token');
    } catch (_) {}
  }

  Future<void> loadDashboard() async {
    if (isClosed) return;
    emit(DashboardLoading());
    try {
      if (_cachedToken == null || _cachedToken!.isEmpty) await _initToken();

      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('user_id') ?? '';
      final userName = prefs.getString('user_name') ?? '';
      final canViewAll = PermissionHelper.can('admin_access');

      // Fetch everything in parallel for speed
      final results = await Future.wait([
        _fetchLeads('/leads/getAllLead'),
        _safeLeads('/leads/recent'),
        _fetchSummary(),
        _fetchInvoices(),
        _fetchPipelineResolved(
          canViewAll: canViewAll,
          userId: currentUserId,
          userName: userName,
        ),
        _fetchAllDealMaps(),
      ]);

      final allLeadsRaw    = results[0]  as List<Lead>;
      final recentLeadsRaw = results[1]  as List<Lead>;
      final base        = results[2]  as DashboardSummary;
      final invoices    = results[3]  as List<InvoiceRecord>;
      final pipeline    = results[4]  as List<PipelineStage>;
      final allDealRows = results[5]  as List<Map<String, dynamic>>;

      final allLeads = canViewAll
          ? allLeadsRaw
          : allLeadsRaw
              .where((l) => l.assignedToId == currentUserId)
              .toList();
      final recentLeads = canViewAll
          ? recentLeadsRaw
          : recentLeadsRaw
              .where((l) => l.assignedToId == currentUserId)
              .toList();

      // Compute revenue in INR using invoice exchangeRate, then API fallback rate.
      final allRates = await _fetchRatesForInvoices(invoices);
      final revenue = _computeRevenue(invoices, rates: allRates);

      // Pending leads: prefer API; fallback = leads that aren't Converted
      final pendingLeads = base.pendingLeads > 0
          ? base.pendingLeads
          : allLeads.where((l) => l.status != 'Converted').length;

      final scopedDeals = _scopeDealsForUser(
        allDealRows,
        canViewAll: canViewAll,
        userId: currentUserId,
        userName: userName,
      );

      final dealMetricsLast7 = _dealMetricsForPeriod(
        scopedDeals,
        range: 'last7',
        month: null,
        year: null,
        apiFallback: base,
        dealsFetched: allDealRows.isNotEmpty,
      );

      final summary = DashboardSummary(
        totalLeads:    canViewAll
            ? (base.totalLeads > 0 ? base.totalLeads : allLeads.length)
            : allLeads.length,
        totalDeals:    dealMetricsLast7.totalDeals,
        dealsWon:      dealMetricsLast7.dealsWon,
        pendingLeads:  pendingLeads,
        leadsChange:   base.leadsChange,
        dealsChange:   dealMetricsLast7.dealsChange,
        paidRevenue:   revenue.paid,
        unpaidRevenue: revenue.unpaid,
        totalRevenue:  revenue.total,
      );

      if (isClosed) return;

      // Default filter: last 7 days
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6));
      final last7DayInvoices = invoices.where((inv) {
        final d = inv.issueDate;
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        return !day.isBefore(start);
      }).toList();
      final rangeRates = await _fetchRatesForInvoices(last7DayInvoices);
      final currentRangeRevenue = _computeRevenue(last7DayInvoices, rates: rangeRates);

      emit(DashboardLoaded(
        allLeads:    allLeads,
        recentLeads: recentLeads,
        summary:     summary.copyWith(
          paidRevenue:   currentRangeRevenue.paid,
          unpaidRevenue: currentRangeRevenue.unpaid,
          totalRevenue:  currentRangeRevenue.total,
        ),
        pipeline:    pipeline,
        invoices:    invoices,     // store full list for re-filtering
        allDealRows: allDealRows,
        filterRange: 'last7',
        filterMonth: null,
        filterYear:  null,
      ));
    } on DioException catch (e) {
      if (isClosed) return;
      emit(DashboardError(_dioMsg(e)));
    } catch (e) {
      if (isClosed) return;
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> refresh() async {
    if (state is! DashboardLoading) await loadDashboard();
  }

  // ── Revenue filter: recompute from cached invoices ──────────
  Future<void> filterByPeriod({String range = 'last7', int? month, int? year}) async {
    final cur = state;
    if (cur is! DashboardLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id') ?? '';
    final userName = prefs.getString('user_name') ?? '';
    final canViewAll = PermissionHelper.can('admin_access');
    final scopedDeals = _scopeDealsForUser(
      cur.allDealRows,
      canViewAll: canViewAll,
      userId: currentUserId,
      userName: userName,
    );
    final dealMetrics = _dealMetricsForPeriod(
      scopedDeals,
      range: range,
      month: month,
      year: year,
      apiFallback: cur.summary,
      dealsFetched: cur.allDealRows.isNotEmpty,
    );

    List<InvoiceRecord> filtered = cur.invoices;
    if (range == 'last7') {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6));
      filtered = cur.invoices.where((inv) {
        final d = inv.issueDate;
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        return !day.isBefore(start);
      }).toList();
    } else if (month != null || year != null) {
      filtered = cur.invoices.where((inv) {
        final d = inv.issueDate;
        if (d == null) return false;
        if (month != null && d.month != month) return false;
        if (year  != null && d.year  != year)  return false;
        return true;
      }).toList();
    }

    final rates = await _fetchRatesForInvoices(filtered);
    final revenue = _computeRevenue(filtered, rates: rates);

    emit(DashboardLoaded(
      allLeads:    cur.allLeads,
      recentLeads: cur.recentLeads,
      summary:     cur.summary.copyWith(
        paidRevenue:   revenue.paid,
        unpaidRevenue: revenue.unpaid,
        totalRevenue:  revenue.total,
        totalDeals:    dealMetrics.totalDeals,
        dealsWon:      dealMetrics.dealsWon,
        dealsChange:   dealMetrics.dealsChange,
      ),
      pipeline:    cur.pipeline,
      invoices:    cur.invoices,   // keep original full list for re-filtering
      allDealRows: cur.allDealRows,
      filterRange: range,
      filterMonth: range == 'month' ? month : null,
      filterYear:  range == 'month' ? year : null,
    ));
  }

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
    return rows
        .where((m) => _dealAssignedToUser(m, userId, userName))
        .toList();
  }

  DateTime? _dealFilterDate(Map<String, dynamic> m) {
    for (final k in [
      'closedAt',
      'wonAt',
      'dealClosedAt',
      'updatedAt',
      'createdAt',
    ]) {
      final d = DateTime.tryParse((m[k] ?? '').toString());
      if (d != null) return d;
    }
    return null;
  }

  bool _isWonDealStage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (s.contains('lost')) return false;
    if (s == 'closedwon') return true;
    if (s.contains('closed') && s.contains('won')) return true;
    return s.contains('won');
  }

  bool _dealDayInRange(
    DateTime? d, {
    required DateTime rangeStartDay,
    DateTime? rangeEndExclusiveDay,
  }) {
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(rangeStartDay)) return false;
    if (rangeEndExclusiveDay != null &&
        !day.isBefore(rangeEndExclusiveDay)) {
      return false;
    }
    return true;
  }

  ({int total, int won}) _dealCountsInRange(
    List<Map<String, dynamic>> deals, {
    required DateTime rangeStartDay,
    DateTime? rangeEndExclusiveDay,
  }) {
    var total = 0;
    var won = 0;
    for (final m in deals) {
      final d = _dealFilterDate(m);
      if (!_dealDayInRange(
        d,
        rangeStartDay: rangeStartDay,
        rangeEndExclusiveDay: rangeEndExclusiveDay,
      )) {
        continue;
      }
      total++;
      if (_isWonDealStage(m['stage']?.toString())) won++;
    }
    return (total: total, won: won);
  }

  double _percentChangeInt(int current, int previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100.0;
  }

  ({
    int totalDeals,
    int dealsWon,
    double dealsChange,
  }) _dealMetricsForPeriod(
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

    if (range == 'last7') {
      final curStart = today.subtract(const Duration(days: 6));
      final cur = _dealCountsInRange(
        scopedDeals,
        rangeStartDay: curStart,
        rangeEndExclusiveDay: null,
      );
      final prevStart = today.subtract(const Duration(days: 13));
      final prevEndEx = today.subtract(const Duration(days: 6));
      final prev = _dealCountsInRange(
        scopedDeals,
        rangeStartDay: prevStart,
        rangeEndExclusiveDay: prevEndEx,
      );
      return (
        totalDeals: cur.total,
        dealsWon: cur.won,
        dealsChange: _percentChangeInt(cur.won, prev.won),
      );
    }

    final m = month ?? now.month;
    final y = year ?? now.year;
    final curMonthStart = DateTime(y, m, 1);
    final curMonthEndEx =
        m == 12 ? DateTime(y + 1, 1, 1) : DateTime(y, m + 1, 1);
    final cur = _dealCountsInRange(
      scopedDeals,
      rangeStartDay: curMonthStart,
      rangeEndExclusiveDay: curMonthEndEx,
    );

    final prevMonthStart = DateTime(y, m - 1, 1);
    final prevMonthEndEx = DateTime(y, m, 1);
    final prev = _dealCountsInRange(
      scopedDeals,
      rangeStartDay: prevMonthStart,
      rangeEndExclusiveDay: prevMonthEndEx,
    );

    return (
      totalDeals: cur.total,
      dealsWon: cur.won,
      dealsChange: _percentChangeInt(cur.won, prev.won),
    );
  }

  Future<Map<String, double>> _fetchRatesForInvoices(List<InvoiceRecord> invoices) async {
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
        if (rate != null && rate > 0) {
          _rateCache[ccy] = rate;
        }
      } catch (_) {}
    }));
    return _rateCache;
  }

  // ── Invoice fetching ────────────────────────────────────────
  Future<List<InvoiceRecord>> _fetchInvoices() async {
    try {
      final res  = await _dio.get('/invoices/getInvoice');
      final body = res.data;
      debugPrint('[Invoice] status=${res.statusCode}');

      List<dynamic> raw = [];
      if (body is List) {
        raw = body;
      } else if (body is Map) {
        for (final k in ['data', 'invoices', 'result', 'records', 'invoice']) {
          if (body[k] is List) { raw = body[k] as List; break; }
        }
        if (raw.isEmpty) {
          for (final v in (body as Map).values) {
            if (v is List) { raw = v; break; }
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

  // ── Revenue computation for dashboard totals ────────────────
  // Rules:
  //   1) INR invoices use their own total amount.
  //   2) Non-INR paid invoices use total * exchangeRate.
  //      (fallback to inrAmount if present)
  //   3) Non-INR unpaid invoices only use exchangeRate when available;
  //      otherwise contribute 0 (backend usually sends null).
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
          // Some paid records already include converted INR amount.
          inrAmt = inv.inrAmount!;
        } else if ((rates[ccy] ?? 0) > 0) {
          inrAmt = inv.total * rates[ccy]!;
        }
      } else {
        // For unpaid non-INR, keep 0 when exchangeRate is unavailable.
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

    return _RevenueResult(
      paid:   paid,
      unpaid: unpaid,
      total:  paid + unpaid,
    );
  }

  // ── Leads ───────────────────────────────────────────────────
  Future<List<Lead>> _fetchLeads(String path) async {
    final res = await _dio.get(path);
    debugPrint('[Leads] $path  ${res.statusCode}');
    return _parseLeadList(res.data);
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
        if (data[k] is List) { raw = data[k] as List; break; }
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
            m['assignedToId'] =
                assignRaw['_id']?.toString() ??
                assignRaw['id']?.toString() ??
                '';
          } else if (assignRaw != null) {
            m['assignTo'] = assignRaw.toString().trim();
          }
          if ((m['assignedToId'] == null || m['assignedToId'].toString().isEmpty) &&
              m['assignToId'] != null) {
            m['assignedToId'] = m['assignToId'].toString();
          }
          out.add(Lead.fromJson(m));
        } catch (_) {}
      }
    }
    return out;
  }

  // ── Summary ──────────────────────────────────────────────────
  Future<DashboardSummary> _fetchSummary() async {
    try {
      final res  = await _dio.get('/dashboard/summary');
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

  // ── Pipeline ─────────────────────────────────────────────────
  /// Admins use `/dashboard/pipeline` (org-wide). Sales users aggregate their
  /// own deals from `/deals/getAll` because many backends return an empty
  /// pipeline when `userId` is passed or do not filter that endpoint.
  Future<List<PipelineStage>> _fetchPipelineResolved({
    required bool canViewAll,
    required String userId,
    required String userName,
  }) async {
    if (!canViewAll) {
      final fromDeals =
          await _pipelineFromAssignedDeals(userId, userName);
      if (fromDeals.isNotEmpty) return fromDeals;
      // No matching deals from aggregation: try API (JWT-scoped / userId).
      final scoped = await _fetchPipelineApi(userId: userId);
      if (scoped.isNotEmpty) return scoped;
      // Do NOT fall back to org-wide pipeline for sales users.
      return <PipelineStage>[];
    }
    return _fetchPipelineApi(userId: null);
  }

  Future<List<PipelineStage>> _pipelineFromAssignedDeals(
    String userId,
    String userName,
  ) async {
    final uid = userId.trim();
    if (uid.isEmpty && userName.trim().isEmpty) return [];
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
      final perStage = <PipelineStage>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        if (!_dealAssignedToUser(m, uid, userName)) continue;
        final stage = m['stage']?.toString().trim();
        if (stage == null || stage.isEmpty) continue;
        double val = 0;
        final rv = m['value'] ?? m['dealValue'] ?? m['amount'];
        if (rv != null) {
          val = double.tryParse(
                rv.toString().replaceAll(RegExp(r'[^\d.\-]'), ''),
              ) ??
              0;
        }
        final ccy = m['currency']?.toString().trim();
        perStage.add(PipelineStage(
          stage: stage,
          count: 1,
          value: val,
          currency: (ccy != null && ccy.isNotEmpty) ? ccy : 'INR',
        ));
      }
      if (perStage.isEmpty) return [];
      return _mergePipelineByStage(_applyPipelineStageRules(perStage));
    } catch (e) {
      debugPrint('[Pipeline] deals aggregation: $e');
      return [];
    }
  }

  bool _dealAssignedToUser(
    Map<String, dynamic> m,
    String userId,
    String userName,
  ) {
    final uid = userId.trim();
    final uname = userName.trim().toLowerCase();

    final assignRaw = m['assignTo'] ?? m['assignedTo'];
    if (assignRaw is Map) {
      final id = assignRaw['_id']?.toString() ??
          assignRaw['id']?.toString() ??
          '';
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

    final topId = m['assignToId']?.toString() ??
        m['assignedToId']?.toString() ??
        '';
    if (topId.isNotEmpty && uid.isNotEmpty && topId == uid) return true;

    return false;
  }

  /// Optional [userId] query for backends that support per-user pipeline.
  Future<List<PipelineStage>> _fetchPipelineApi({String? userId}) async {
    try {
      final query = <String, dynamic>{};
      if (userId != null && userId.trim().isNotEmpty) {
        query['userId'] = userId.trim();
      }
      final res = await _dio.get(
        '/dashboard/pipeline',
        queryParameters: query.isEmpty ? null : query,
      );
      final body = res.data;

      // Exact API shape (as shared):
      // [
      //   { "stage": "...", "leads": 4 },
      //   ...
      // ]
      if (body is List) {
        final direct = <PipelineStage>[];
        for (final e in body) {
          if (e is Map) {
            try {
              final row = Map<String, dynamic>.from(e);
              final stage = PipelineStage.fromJson(row);
              if (stage.stage.trim().isNotEmpty) {
                direct.add(stage);
              }
            } catch (err) {
              debugPrint('[Pipeline] direct parse err: $err');
            }
          }
        }
        if (direct.isNotEmpty) {
          debugPrint('[Pipeline] direct rows=${direct.length}');
          return _mergePipelineByStage(_applyPipelineStageRules(direct));
        }
      }

      final rows = _extractPipelineRows(body);
      debugPrint('[Pipeline] rows extracted=${rows.length}');
      if (rows.isNotEmpty) {
        debugPrint('[Pipeline] first row sample=${rows.first}');
      } else {
        debugPrint('[Pipeline] raw body type=${body.runtimeType} body=$body');
      }

      final out = <PipelineStage>[];
      for (final row in rows) {
        try {
          final stage = PipelineStage.fromJson(row);
          if (stage.stage.trim().isNotEmpty) {
            out.add(stage);
          }
        } catch (err) {
          debugPrint('[Pipeline] parse err: $err');
        }
      }

      final finalList =
          _mergePipelineByStage(_applyPipelineStageRules(out));
      debugPrint('[Pipeline] final stages=${finalList.length}');
      return finalList;
    } catch (e) {
      debugPrint('[Pipeline] API error: $e');
      return <PipelineStage>[];
    }
  }

  /// Normalizes pipeline buckets so proposal/negotiation stays distinct.
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
    if (k.contains('proposal') && k.contains('sent') && k.contains('negotiation')) {
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
    final out = merged.values.toList()..sort(_comparePipelineStages);
    return out;
  }

  List<Map<String, dynamic>> _extractPipelineRows(dynamic node,
      {String? parentKey}) {
    final out = <Map<String, dynamic>>[];
    const metricKeys = {
      'count',
      'dealCount',
      'deals',
      'total',
      'totalDeals',
      'value',
      'totalValue',
      'amount',
      'dealValue',
      'revenue',
    };

    bool looksLikeRow(Map<String, dynamic> m) {
      final hasStage = m['stage'] != null ||
          m['stageName'] != null ||
          m['_id'] != null ||
          m['name'] != null ||
          m['label'] != null;
      final hasMetrics = m['count'] != null ||
          m['dealCount'] != null ||
          m['deals'] != null ||
          m['total'] != null ||
          m['totalDeals'] != null ||
          m['value'] != null ||
          m['totalValue'] != null ||
          m['amount'] != null ||
          m['dealValue'] != null ||
          m['items'] is List ||
          m['leads'] is List ||
          m['records'] is List;
      return hasStage && (hasMetrics || m.length <= 3);
    }

    if (node is List) {
      for (final e in node) {
        out.addAll(_extractPipelineRows(e, parentKey: parentKey));
      }
      return out;
    }

    if (node is Map) {
      final m = Map<String, dynamic>.from(node);
      if (looksLikeRow(m)) {
        out.add(m);
      }

      for (final entry in m.entries) {
        final k = entry.key.toString();
        final v = entry.value;

        if (v is Map) {
          final vm = Map<String, dynamic>.from(v);
          if (!looksLikeRow(vm)) {
            // Handle object-shape: { Qualified: {count: 3, value: 1000} }
            final hasMetricsOnly = vm['count'] != null ||
                vm['dealCount'] != null ||
                vm['deals'] != null ||
                vm['total'] != null ||
                vm['totalDeals'] != null ||
                vm['value'] != null ||
                vm['totalValue'] != null ||
                vm['amount'] != null ||
                vm['dealValue'] != null;
            if (hasMetricsOnly) {
              out.add({'stage': k, ...vm});
            }
          }
          out.addAll(_extractPipelineRows(v, parentKey: k));
        } else if (v is List) {
          // Handle map-of-stage-to-list shape:
          // { "Qualification": [ ... ], "Closed Won": [ ... ] }
          if (!metricKeys.contains(k)) {
            out.add({'stage': k, 'count': v.length});
          }
          out.addAll(_extractPipelineRows(v, parentKey: k));
        } else if (v is num && !metricKeys.contains(k)) {
          // Handle numeric stage maps at any nesting level:
          // { Qualified: 3, Negotiation: 2 }
          // { data: { Qualified: 3, Negotiation: 2 } }
          out.add({'stage': k, 'count': v});
        }
      }
    }

    return out;
  }

  String _dioMsg(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout  => 'Connection timed out.',
        DioExceptionType.connectionError => 'No internet connection.',
        DioExceptionType.badResponse =>
          'Server error (${e.response?.statusCode}).',
        _ => 'Something went wrong.',
      };
}

// Internal helper — not exported
class _RevenueResult {
  final double paid, unpaid, total;
  const _RevenueResult({
    required this.paid,
    required this.unpaid,
    required this.total,
  });
}

// ══════════════════════════════════════════════════════════════
// copyWith extension on DashboardSummary
// ══════════════════════════════════════════════════════════════
extension DashboardSummaryX on DashboardSummary {
  DashboardSummary copyWith({
    int?    totalLeads,
    int?    totalDeals,
    int?    dealsWon,
    int?    pendingLeads,
    double? leadsChange,
    double? dealsChange,
    double? paidRevenue,
    double? unpaidRevenue,
    double? totalRevenue,
  }) =>
      DashboardSummary(
        totalLeads:    totalLeads    ?? this.totalLeads,
        totalDeals:    totalDeals    ?? this.totalDeals,
        dealsWon:      dealsWon      ?? this.dealsWon,
        pendingLeads:  pendingLeads  ?? this.pendingLeads,
        leadsChange:   leadsChange   ?? this.leadsChange,
        dealsChange:   dealsChange   ?? this.dealsChange,
        paidRevenue:   paidRevenue   ?? this.paidRevenue,
        unpaidRevenue: unpaidRevenue ?? this.unpaidRevenue,
        totalRevenue:  totalRevenue  ?? this.totalRevenue,
      );
}