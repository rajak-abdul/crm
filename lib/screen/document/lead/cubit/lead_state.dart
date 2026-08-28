import 'package:crm_app/modals/modals.dart';
import 'package:equatable/equatable.dart';

enum LeadsStatus {
  initial,
  loading,
  loadingMore,
  loaded,
  error,
}

class LeadsState extends Equatable {
  final LeadsStatus status;
  final List<Lead> leads;
  final int currentPage;
  final int totalPages;
  final int totalLeads;
  final String searchQuery;
  final String? errorMessage;

  const LeadsState({
    this.status = LeadsStatus.initial,
    this.leads = const [],
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalLeads = 0,
    this.searchQuery = '',
    this.errorMessage,
  });

  bool get hasMore => currentPage < totalPages;

  LeadsState copyWith({
    LeadsStatus? status,
    List<Lead>? leads,
    int? currentPage,
    int? totalPages,
    int? totalLeads,
    String? searchQuery,
    String? errorMessage,
  }) {
    return LeadsState(
      status: status ?? this.status,
      leads: leads ?? this.leads,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalLeads: totalLeads ?? this.totalLeads,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        leads,
        currentPage,
        totalPages,
        totalLeads,
        searchQuery,
        errorMessage,
      ];
}