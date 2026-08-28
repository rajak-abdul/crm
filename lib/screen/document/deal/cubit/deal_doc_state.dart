import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:equatable/equatable.dart';
import 'package:crm_app/modals/modals.dart';

enum DealDocStatus {
  initial,
  loading,
  loaded,
  error,
}

class DealDocState extends Equatable {
  final DealDocStatus status;
  final List<Deal> deals;
  final int currentPage;
  final int totalPages;
  final int totalDeals;
  final String searchQuery;
  final String? errorMessage;

  const DealDocState({
    this.status = DealDocStatus.initial,
    this.deals = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalDeals = 0,
    this.searchQuery = '',
    this.errorMessage,
  });

  bool get hasMore => currentPage < totalPages;

  DealDocState copyWith({
    DealDocStatus? status,
    List<Deal>? deals,
    int? currentPage,
    int? totalPages,
    int? totalDeals,
    String? searchQuery,
    String? errorMessage,
  }) {
    return DealDocState(
      status: status ?? this.status,
      deals: deals ?? this.deals,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalDeals: totalDeals ?? this.totalDeals,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        deals,
        currentPage,
        totalPages,
        totalDeals,
        searchQuery,
        errorMessage,
      ];
}