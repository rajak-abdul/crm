class LeaderboardStats {
  final int totalSalespeople;
  final int activeSalespeople;
  final double avgConversionRate;
  final int totalLeads;
  final int totalConvertedLeads;
  final int cumulativeTotalLeads;
 
  const LeaderboardStats({
    required this.totalSalespeople,
    required this.activeSalespeople,
    required this.avgConversionRate,
    required this.totalLeads,
    required this.totalConvertedLeads,
    required this.cumulativeTotalLeads,
  });
 
  factory LeaderboardStats.fromJson(Map<String, dynamic> json) =>
      LeaderboardStats(
        totalSalespeople: json['totalSalespeople'] ?? 0,
        activeSalespeople: json['activeSalespeople'] ?? 0,
        avgConversionRate: (json['avgConversionRate'] ?? 0).toDouble(),
        totalLeads: json['totalLeads'] ?? 0,
        totalConvertedLeads: json['totalConvertedLeads'] ?? 0,
        cumulativeTotalLeads: json['cumulativeTotalLeads'] ?? 0,
      );
}
 
class DateRangeInfo {
  final String formatted;
  const DateRangeInfo({required this.formatted});
  factory DateRangeInfo.fromJson(Map<String, dynamic> json) =>
      DateRangeInfo(formatted: json['formatted'] ?? '');
}
 
class SalesPerson {
  final String id;
  final String name;
  final String email;
  final String avatar;
  final int totalLeads;
  final int convertedLeads;
  final double conversionRate;
  final String conversionDisplay;
  final int cumulativeTotalLeads;
  final int cumulativeConvertedLeads;
  final String cumulativeDisplay;
  final int streak;
  final int productiveDays;
  final String workHours;
  final String status;
  final String statusIcon;
  final bool isCurrentUser;
 
  const SalesPerson({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    required this.totalLeads,
    required this.convertedLeads,
    required this.conversionRate,
    required this.conversionDisplay,
    required this.cumulativeTotalLeads,
    required this.cumulativeConvertedLeads,
    required this.cumulativeDisplay,
    required this.streak,
    required this.productiveDays,
    required this.workHours,
    required this.status,
    required this.statusIcon,
    required this.isCurrentUser,
  });
 
  bool get isActive => status == 'active';
 
  String get allTimeInfo =>
      'All time: $cumulativeTotalLeads leads · $cumulativeDisplay';
 
  factory SalesPerson.fromJson(Map<String, dynamic> json) => SalesPerson(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        avatar: json['avatar'] ?? '',
        totalLeads: json['totalLeads'] ?? 0,
        convertedLeads: json['convertedLeads'] ?? 0,
        conversionRate: (json['conversionRate'] ?? 0).toDouble(),
        conversionDisplay: json['conversionDisplay'] ?? '0.0%',
        cumulativeTotalLeads: json['cumulativeTotalLeads'] ?? 0,
        cumulativeConvertedLeads: json['cumulativeConvertedLeads'] ?? 0,
        cumulativeDisplay: json['cumulativeDisplay'] ?? '0.0%',
        streak: json['streak'] ?? 0,
        productiveDays: json['productiveDays'] ?? 0,
        workHours: json['workHours'] ?? '—',
        status: json['status'] ?? 'inactive',
        statusIcon: json['statusIcon'] ?? '💤',
        isCurrentUser: json['isCurrentUser'] ?? false,
      );
}
 
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
 
  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) =>
      LeaderboardResponse(
        success: json['success'] ?? false,
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => SalesPerson.fromJson(e as Map<String, dynamic>))
            .toList(),
        stats: LeaderboardStats.fromJson(
            json['stats'] as Map<String, dynamic>? ?? {}),
        dateRange: DateRangeInfo.fromJson(
            json['dateRange'] as Map<String, dynamic>? ?? {}),
        userRole: json['userRole'] ?? '',
      );
}
