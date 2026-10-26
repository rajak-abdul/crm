class LeaderboardResponse {
  final bool success;
  final List<SalesPerson> data;
  final LeaderboardStats stats;
  final DateRangeInfo dateRange;
  final String userRole;

  const LeaderboardResponse({
    required this.success,
    required this.data,
    required this.stats,
    required this.dateRange,
    required this.userRole,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    return LeaderboardResponse(
      success: json['success'] as bool? ?? false,
      data: (json['data'] as List<dynamic>? ?? [])
          .map(
            (e) => SalesPerson.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      stats: LeaderboardStats.fromJson(
        Map<String, dynamic>.from(
          json['stats'] as Map? ?? {},
        ),
      ),
      dateRange: DateRangeInfo.fromJson(
        Map<String, dynamic>.from(
          json['dateRange'] as Map? ?? {},
        ),
      ),
      userRole: json['userRole'] as String? ?? '',
    );
  }
}

class LeaderboardStats {
  final int totalSalespeople;
  final int activeSalespeople;
  final double avgConversionRate;
  final int totalLeads;
  final int totalConvertedLeads;
  final int cumulativeTotalLeads;
  final int cumulativeConvertedLeads;

  const LeaderboardStats({
    required this.totalSalespeople,
    required this.activeSalespeople,
    required this.avgConversionRate,
    required this.totalLeads,
    required this.totalConvertedLeads,
    required this.cumulativeTotalLeads,
    required this.cumulativeConvertedLeads,
  });

  factory LeaderboardStats.fromJson(Map<String, dynamic> json) {
    return LeaderboardStats(
      totalSalespeople: json['totalSalespeople'] as int? ?? 0,
      activeSalespeople: json['activeSalespeople'] as int? ?? 0,
      avgConversionRate: _toDouble(json['avgConversionRate']),
      totalLeads: json['totalLeads'] as int? ?? 0,
      totalConvertedLeads: json['totalConvertedLeads'] as int? ?? 0,
      cumulativeTotalLeads: json['cumulativeTotalLeads'] as int? ?? 0,
      cumulativeConvertedLeads:
          json['cumulativeConvertedLeads'] as int? ?? 0,
    );
  }
}

class DateRangeInfo {
  final String start;
  final String end;
  final String formatted;

  const DateRangeInfo({
    required this.start,
    required this.end,
    required this.formatted,
  });

  factory DateRangeInfo.fromJson(Map<String, dynamic> json) {
    return DateRangeInfo(
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
      formatted: json['formatted'] as String? ?? '',
    );
  }
}

class SalesPerson {
  final String id;
  final String name;
  final String email;
  final String role;
  final String team;
  final String avatar;

  final int totalLeads;
  final int rawLeads;
  final int qualificationDeals;
  final int convertedLeads;

  final double conversionRate;
  final String conversionDisplay;

  final int cumulativeTotalLeads;
  final int cumulativeConvertedLeads;
  final double cumulativeConversionRate;
  final String cumulativeDisplay;

  final int streak;
  final int productiveDays;
  final String workHours;

  final String status;
  final String statusIcon;
  final String statusColor;

  final double performanceScore;
  final bool isCurrentUser;

  const SalesPerson({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.team,
    required this.avatar,
    required this.totalLeads,
    required this.rawLeads,
    required this.qualificationDeals,
    required this.convertedLeads,
    required this.conversionRate,
    required this.conversionDisplay,
    required this.cumulativeTotalLeads,
    required this.cumulativeConvertedLeads,
    required this.cumulativeConversionRate,
    required this.cumulativeDisplay,
    required this.streak,
    required this.productiveDays,
    required this.workHours,
    required this.status,
    required this.statusIcon,
    required this.statusColor,
    required this.performanceScore,
    required this.isCurrentUser,
  });

  bool get isActive => status.toLowerCase() == 'active';

  String get allTimeInfo =>
      'All time: $cumulativeTotalLeads leads · $cumulativeDisplay';

  factory SalesPerson.fromJson(Map<String, dynamic> json) {
    return SalesPerson(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      team: json['team'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      totalLeads: json['totalLeads'] as int? ?? 0,
      rawLeads: json['rawLeads'] as int? ?? 0,
      qualificationDeals: json['qualificationDeals'] as int? ?? 0,
      convertedLeads: json['convertedLeads'] as int? ?? 0,
      conversionRate: _toDouble(json['conversionRate']),
      conversionDisplay: json['conversionDisplay'] as String? ?? '0.0%',
      cumulativeTotalLeads:
          json['cumulativeTotalLeads'] as int? ?? 0,
      cumulativeConvertedLeads:
          json['cumulativeConvertedLeads'] as int? ?? 0,
      cumulativeConversionRate:
          _toDouble(json['cumulativeConversionRate']),
      cumulativeDisplay: json['cumulativeDisplay'] as String? ?? '0.0%',
      streak: json['streak'] as int? ?? 0,
      productiveDays: json['productiveDays'] as int? ?? 0,
      workHours: json['workHours'] as String? ?? '—',
      status: json['status'] as String? ?? 'inactive',
      statusIcon: json['statusIcon'] as String? ?? '💤',
      statusColor: json['statusColor'] as String? ?? '',
      performanceScore: _toDouble(json['performanceScore']),
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}