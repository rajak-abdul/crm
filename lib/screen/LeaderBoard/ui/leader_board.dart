import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm_app/screen/LeaderBoard/cubit/leaderBoard_cubit.dart';
import 'package:crm_app/screen/LeaderBoard/modal/leaderBoard_modal.dart';
import 'package:crm_app/screen/LeaderBoard/utils/utils.dart';
import 'package:crm_app/screen/LeaderBoard/utils/utils.dart' as AppColors;
import 'package:flutter/material.dart';

class LeaderboardPage extends StatefulWidget {
  final String authToken;

  const LeaderboardPage({super.key, required this.authToken});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  // ── Filter state ──
  int _filterIndex = 2; // 0=Single Day  1=Date Range  2=All Time
  DateTime? _startDate;
  DateTime? _endDate;

  // ── Search ──
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Async state ──
  bool _isLoading = false;
  String? _error;
  LeaderboardResponse? _response;

  // Pagination
  static const int _kPageSize = 10;
  int _currentPage = 1;

  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData(); // loads "All Time" by default (filterIndex = 2)
    _watchInternet();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SalesPerson> _paginate(List<SalesPerson> filtered) {
    final start = (_currentPage - 1) * _kPageSize;

    if (start >= filtered.length) return [];

    final end = (start + _kPageSize).clamp(0, filtered.length);

    return filtered.sublist(start, end);
  }
  // ── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Guard: don't fetch if required dates are missing
    if (_filterIndex == 0 && _startDate == null)
      return; // Single Day needs a date
    if (_filterIndex == 1 && _startDate == null)
      return; // Range needs at least start

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? start, end, filterType;

      switch (_filterIndex) {
        case 0: // Single Day
          start = _startDate!.toIso8601String().split('T').first;
          end = start;
          filterType = 'single';
          break;
        case 1: // Date Range
          start = _startDate!.toIso8601String().split('T').first;
          end = _endDate?.toIso8601String().split('T').first ?? start;
          filterType = 'range';
          break;
        case 2: // All Time
          filterType = 'allTime';
          break;
      }

      final result = await LeaderboardService.fetchLeaderboard(
        token: widget.authToken,
        startDate: start,
        endDate: end,
        filterType: filterType,
        forceRefresh: forceRefresh,
      );

      if (mounted) setState(() => _response = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Derived ───────────────────────────────────────────────────────────────────

List<SalesPerson> get _filtered {
  final role = _response?.userRole ?? '';
  List<SalesPerson> list = _response?.data ?? [];

  // If salesman → show only current user
  if (role != 'admin') {
    list = list.where((p) => p.isCurrentUser == true).toList();
  }

  if (_searchQuery.isEmpty) return list;

  final q = _searchQuery.toLowerCase();

  return list.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.email.toLowerCase().contains(q),
  ).toList();
}
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _filtered.isNotEmpty
          ? _PaginationBar(
              page: _currentPage,
              totalPages: (_filtered.length / _kPageSize).ceil().clamp(1, 999),
              totalItems: _filtered.length,
              pageSize: _kPageSize,
              onPrev: _currentPage > 1
                  ? () => setState(() {
                        _currentPage--;
                      })
                  : null,
              onNext: _currentPage < (_filtered.length / _kPageSize).ceil()
                  ? () => setState(() {
                        _currentPage++;
                      })
                  : null,
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: orange,
          onRefresh: () => _loadData(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildKpiGrid()),
              SliverToBoxAdapter(child: _buildSectionTitle()),
              SliverToBoxAdapter(child: _buildFilterRow()),
              SliverToBoxAdapter(child: _buildDateRow()),
              SliverToBoxAdapter(child: _buildSearch()),
              _buildBody(),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final members = _paginate(_filtered);

    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: orange),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildError(),
      );
    }

    if (members.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _buildCard(
          members[i],
          ((_currentPage - 1) * _kPageSize) + i + 1,
        ),
        childCount: members.length,
      ),
    );
  }
  // ── Header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final role = _response?.userRole ?? '';
    final dateLabel = _response?.dateRange.formatted ?? '';

    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded,
                color: textPrimary, size: 24),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Leaderboard',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _pill(
                      dateLabel.isNotEmpty ? dateLabel : 'All Time',
                      bg: const Color(0xFFF3F4F6),
                      fg: textSecondary,
                    ),
                    if (role == 'admin')
                      _pill(
                        '👁  Admin View – All Salespeople',
                        bg: const Color(0xFFF3E8FF),
                        fg: purple,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 18,
            backgroundColor: orange,
            child: Text('U',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, {required Color bg, required Color fg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
      );

  // ── KPI Grid ──────────────────────────────────────────────────────────────────

  Widget _buildKpiGrid() {
    final s = _response?.stats;
    final dateLabel = _response?.dateRange.formatted ?? '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: [
          _kpiCard(
              'Active Salespeople',
              s != null ? '${s.activeSalespeople}' : '—',
              s != null ? 'Out of ${s.totalSalespeople} total' : '—',
              Icons.group_outlined,
              orange),
          _kpiCard(
              'Conversion Rate',
              s != null ? '${s.avgConversionRate.toStringAsFixed(1)}%' : '—',
              dateLabel,
              Icons.gps_fixed_rounded,
              green),
          _kpiCard('Total Leads', s != null ? '${s.totalLeads}' : '—',
              dateLabel, Icons.radar_rounded, const Color(0xFF06B6D4)),
          _kpiCard(
              'Converted Leads',
              s != null ? '${s.totalConvertedLeads}' : '—',
              'Deals with Lead ID',
              Icons.trending_up_rounded,
              purple),
        ],
      ),
    );
  }

  Widget _kpiCard(
      String title, String value, String sub, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(icon, size: 18, color: accent),
            ],
          ),
          const SizedBox(height: 6),
          _isLoading
              ? Container(
                  width: 40,
                  height: 26,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6)))
              : Text(value,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -1)),
          const Spacer(),
          Text(sub,
              style: const TextStyle(fontSize: 9.5, color: textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Section Title ─────────────────────────────────────────────────────────────

  Widget _buildSectionTitle() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Performance Data',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.3)),
            if (_response != null)
              Text('${_filtered.length} members',
                  style: const TextStyle(fontSize: 12, color: textSecondary)),
          ],
        ),
      );

  // ── Filter Row ────────────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    final labels = ['Single Day', 'Date Range', 'All Time'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: List.generate(3, (i) {
            final selected = _filterIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_filterIndex == i) return;
                  setState(() {
                    _filterIndex = i;
                    // Reset dates when switching filter type
                    _startDate = null;
                    _endDate = null;
                  });
                  // All Time loads immediately; others wait for date selection
                  if (i == 2) _loadData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: selected ? surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1))
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(labels[i],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? orange : textSecondary)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Date Row ──────────────────────────────────────────────────────────────────

  Widget _buildDateRow() {
    // Hide date pickers for "All Time"
    if (_filterIndex == 2) return const SizedBox.shrink();

    final showEnd = _filterIndex == 1; // Date Range needs end date
    final needsEndDate = showEnd && _startDate != null && _endDate == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(true),
                  child: _dateField(
                    _startDate != null
                        ? '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}'
                        : (_filterIndex == 0 ? 'Pick a day' : 'Start date'),
                    highlight: _startDate != null,
                  ),
                ),
              ),
              if (showEnd) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→',
                      style: TextStyle(color: textSecondary, fontSize: 16)),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(false),
                    child: _dateField(
                      _endDate != null
                          ? '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'
                          : 'End date',
                      highlight: _endDate != null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Hint shown while waiting for end date
        if (needsEndDate)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Now pick an end date to apply the filter',
              style: TextStyle(fontSize: 11, color: orange),
            ),
          ),
      ],
    );
  }

  Widget _dateField(String label, {bool highlight = false}) => Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFFF7ED) : surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight ? orange : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 14, color: highlight ? orange : textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: highlight ? orange : textSecondary,
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.normal)),
        ]),
      );

  // ── Date Picker ───────────────────────────────────────────────────────────────

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: const ColorScheme.light(primary: orange)),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() => isStart ? _startDate = picked : _endDate = picked);

    // Single Day  → load immediately after picking
    // Date Range  → load only when BOTH dates are selected
    final shouldLoad = _filterIndex == 0 ||
        (_filterIndex == 1 && _startDate != null && _endDate != null);

    if (shouldLoad) _loadData();
  }

  // ── Search ────────────────────────────────────────────────────────────────────

  Widget _buildSearch() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB))),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search members...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    prefixIcon:
                        Icon(Icons.search, size: 18, color: textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _loadData(forceRefresh: true),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB))),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            color: orange, strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded,
                        size: 18, color: textSecondary),
              ),
            ),
          ],
        ),
      );

  // ── Error State ───────────────────────────────────────────────────────────────

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: textSecondary),
              const SizedBox(height: 12),
              const Text('Failed to load leaderboard',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: textPrimary)),
              const SizedBox(height: 6),
              Text(_error ?? '',
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () => _loadData(forceRefresh: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  // ── Salesperson Card ──────────────────────────────────────────────────────────

  Widget _buildCard(SalesPerson p, int rank) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: p.isCurrentUser ? const Color(0xFFFFF7ED) : surface,
          borderRadius: BorderRadius.circular(16),
          border: p.isCurrentUser
              ? Border.all(color: orange.withOpacity(0.3))
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _rankBadge(rank),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _avatarColor(p.avatar),
                    child: Text(
                      p.avatar.isNotEmpty ? p.avatar[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(p.name.trim(),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (p.isCurrentUser) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                    color: orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text('You',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: orange,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                        Text(p.email,
                            style: const TextStyle(
                                fontSize: 11, color: textSecondary)),
                        const SizedBox(height: 2),
                        Text(p.allTimeInfo,
                            style: const TextStyle(
                                fontSize: 10,
                                color: purple,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  _statusBadge(p),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat('Conversion', p.conversionDisplay),
                  _stat('Total Leads', '${p.totalLeads}'),
                  _stat('Converted', '${p.convertedLeads}',
                      valueColor: p.convertedLeads > 0 ? green : textPrimary),
                  _stat('Work Hrs', p.workHours, isSmallValue: true),
                  _stat('Active Days', '${p.productiveDays}d'),
                ],
              ),
              if (p.streak > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text('${p.streak} day streak',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E))),
                    ],
                  ),
                ),
              ],
              if (p.conversionRate > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (p.conversionRate / 100).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: const AlwaysStoppedAnimation<Color>(green),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Color _avatarColor(String initial) {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFDC2626),
      Color(0xFFD97706),
      Color(0xFF0891B2),
      Color(0xFFDB2777),
    ];
    if (initial.isEmpty) return colors[0];
    return colors[initial.codeUnitAt(0) % colors.length];
  }

  Widget _rankBadge(int rank) {
    Color bg;
    Color fg = Colors.white;
    if (rank == 1) {
      bg = orange;
    } else if (rank == 2) {
      bg = const Color(0xFF9CA3AF);
    } else if (rank == 3) {
      bg = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = textSecondary;
    }

    return Container(
      width: 32,
      height: 32,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      alignment: Alignment.center,
      child: Text('$rank',
          style:
              TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }

  Widget _statusBadge(SalesPerson p) {
    final bool isStar =
        p.convertedLeads > 0 || p.conversionRate > 20 || p.productiveDays > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isStar ? const Color(0xFFFFF3CD) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isStar) ...[
            const Text(
              "⭐",
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            isStar ? "Star" : "Inactive",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isStar ? const Color(0xFF92400E) : textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    String value, {
    Color valueColor = textPrimary,
    bool isSmallValue = false,
  }) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: textSecondary),
                maxLines: 1),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: isSmallValue ? 7 : 13,
                    fontWeight: FontWeight.w700,
                    color: valueColor)),
          ],
        ),
      );

  void _watchInternet() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none && mounted) {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      }
    });
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 48, color: textSecondary),
              SizedBox(height: 12),
              Text('No members found',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: textPrimary)),
              SizedBox(height: 4),
              Text('Try adjusting your search or date range.',
                  style: TextStyle(fontSize: 12, color: textSecondary)),
            ],
          ),
        ),
      );
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final int start = totalItems == 0 ? 0 : ((page - 1) * pageSize) + 1;

    final int end =
        (page * pageSize) > totalItems ? totalItems : (page * pageSize);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$start-$end of $totalItems',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '$page / $totalPages',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
