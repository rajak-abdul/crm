import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/shareWidgets/pagination.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show LoadingState, ErrorState, EmptyState;
import 'package:crm_app/thems/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class RejectedDealsScreen extends StatefulWidget {
  const RejectedDealsScreen({super.key});

  @override
  State<RejectedDealsScreen> createState() => _RejectedDealsScreenState();
}

class _RejectedDealsScreenState extends State<RejectedDealsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  int _currentPage = 1;
int _pageSize = 5;
final List<int> _pageSizeOptions = [5, 10, 25];
  
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DealsCubit>().loadRejectedDeals(
            page: _currentPage,
            limit: _pageSize,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Search filters within the currently-loaded page only — the API
  // paginates server-side, so it can't match rejected deals sitting
  // on other pages.
  List<Deal> _filter(List<Deal> deals) {
    if (_search.isEmpty) return deals;

    final q = _search.toLowerCase();

    return deals.where((deal) {
      return deal.name.toLowerCase().contains(q) ||
          deal.phone.toLowerCase().contains(q) ||
          deal.companyName.toLowerCase().contains(q);
    }).toList();
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    context.read<DealsCubit>().loadRejectedDeals(
          page: page,
          limit: _pageSize,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        title: const Text(
          "Rejected Deals",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: BlocBuilder<DealsCubit, DealsState>(
        builder: (context, state) {
          if (state is DealsLoading) {
            return const LoadingState(message: "Loading rejected deals...");
          }

          if (state is DealsError) {
            return ErrorState(
              message: state.message,
              onRetry: () {
                context.read<DealsCubit>().loadRejectedDeals(
                      page: _currentPage,
                      limit: _pageSize,
                    );
              },
            );
          }

          if (state is! RejectedDealsLoaded) {
            return const SizedBox();
          }

          final deals = _filter(state.deals);

          return RefreshIndicator(
            onRefresh: () async {
              context.read<DealsCubit>().loadRejectedDeals(
                    page: _currentPage,
                    limit: _pageSize,
                  );
            },
            child: Column(
              children: [
                // Search Box
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _search = value.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search rejected deals...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                Expanded(
                  child: deals.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off,
                          message: "No rejected deals found",
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: deals.length,
                          itemBuilder: (context, index) {
                            return _RejectedDealCard(
                              deal: deals[index],
                              onDeleted: () {
                                // API returns fewer than a full page —
                                // if we just emptied the last page, step
                                // back one page instead of showing blank.
                                final remaining = state.deals.length - 1;
                                final nextPage =
                                    (remaining == 0 && _currentPage > 1)
                                        ? _currentPage - 1
                                        : _currentPage;
                                setState(() => _currentPage = nextPage);
                              },
                            );
                          },
                        ),
                ),

                if (state.totalDeals > _pageSize)
PaginationWidget(
  currentPage: state.currentPage,
  totalItems: state.totalDeals,
  pageSize: _pageSize,
  pageSizeOptions: _pageSizeOptions,
  onPageChanged: _goToPage,
  onPageSizeChanged: (size) {
    setState(() {
      _pageSize = size;
      _currentPage = 1;
    });

    context.read<DealsCubit>().loadRejectedDeals(
      page: 1,
      limit: size,
    );
  },
),              ],
            ),
          );
        },
      ),
    );
  }
}

class _RejectedDealCard extends StatelessWidget {
  final Deal deal;
  final VoidCallback onDeleted;

  const _RejectedDealCard({
    required this.deal,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.red.shade100,
                    child: Text(
                      deal.name.isEmpty ? '?' : deal.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deal.phone,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Rejected",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _confirmDelete(context),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _buildInfoRow(
              Icons.person_outline,
              "Company",
              deal.companyName.isEmpty ? "-" : deal.companyName,
            ),
            _buildInfoRow(
              Icons.person_outline,
              "Assignee",
              deal.assignTo.isEmpty ? "-" : deal.assignTo,
            ),
            _buildInfoRow(
              Icons.comment_outlined,
              "Reason",
              deal.rejectionReason.isEmpty ? "-" : deal.rejectionReason,
            ),
            _buildInfoRow(
              Icons.person_remove_alt_1,
              "Rejected By",
              deal.rejectedByName.isEmpty ? "-" : deal.rejectedByName,
            ),
            _buildInfoRow(
              Icons.event_busy,
              "Rejected At",
              deal.rejectedAt == null
                  ? "-"
                  : DateFormat("dd MMM yyyy • hh:mm a")
                      .format(deal.rejectedAt!),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Rejected Deal"),
        content: const Text(
          "Are you sure you want to permanently delete this rejected deal?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final cubit = context.read<DealsCubit>();
      final state = cubit.state;
      final page = state is RejectedDealsLoaded ? state.currentPage : 1;

      final ok = await cubit.deleteRejectedDeal(deal.id, page: page);
      if (ok) onDeleted();
    }
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}