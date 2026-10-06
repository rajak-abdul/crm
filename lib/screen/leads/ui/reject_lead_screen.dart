import 'package:crm_app/modals/modals.dart';
import 'package:crm_app/screen/leads/cubit/lead_cubit.dart';
import 'package:crm_app/screen/leads/ui/lead_screen.dart';
import 'package:crm_app/shareWidgets/pagination.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show LoadingState, ErrorState, EmptyState;
import 'package:crm_app/thems/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class RejectedLeadsScreen extends StatefulWidget {
  const RejectedLeadsScreen({super.key});

  @override
  State<RejectedLeadsScreen> createState() =>
      _RejectedLeadsScreenState();
}

class _RejectedLeadsScreenState
    extends State<RejectedLeadsScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _search = '';
  int _currentPage = 1;
  int _pageSize = 5; 

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadCubit>().fetchRejectedLeads();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Lead> _filter(List<Lead> leads) {
    if (_search.isEmpty) return leads;

    final q = _search.toLowerCase();

    return leads.where((lead) {
      return lead.name.toLowerCase().contains(q) ||
          lead.phone.toLowerCase().contains(q) ||
          lead.companyName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        title: const Text(
          "Rejected Leads",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        
      ),

      body: BlocBuilder<LeadCubit, LeadState>(
        builder: (context, state) {

          if (state is LeadLoading) {
            return const LoadingState(
              message: "Loading rejected leads...",
            );
          }

          if (state is LeadError) {
            return ErrorState(
              message: state.message,
              onRetry: () {
                context.read<LeadCubit>()
                    .fetchRejectedLeads();
              },
            );
          }

          if (state is! LeadLoaded) {
            return const SizedBox();
          }

          final filteredLeads = _filter(state.leads);

final start = (_currentPage - 1) * _pageSize;
final end = (start + _pageSize) > filteredLeads.length
    ? filteredLeads.length
    : start + _pageSize;

final leads = filteredLeads.sublist(start, end);


          return RefreshIndicator(
  onRefresh: () async {
    await context.read<LeadCubit>().fetchRejectedLeads();
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
               _currentPage = 1;
            });
          },
          decoration: InputDecoration(
            hintText: "Search rejected leads...",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _search = '';
                        _currentPage = 1;
                      });
                    },
                  )
                : null,
          ),
        ),
      ),

      Expanded(
  child: leads.isEmpty
      ? const EmptyState(
          icon: Icons.search_off,
          message: "No rejected leads found",
        )
      : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: leads.length,
          itemBuilder: (context, index) {
            return _RejectedLeadCard(
              lead: leads[index],
            );
          },
        ),
),

PaginationWidget(
  currentPage: _currentPage,
  totalItems: filteredLeads.length,
  pageSize: _pageSize,
  pageSizeOptions: const [5, 10, 25],

  onPageChanged: (page) {
    setState(() {
      _currentPage = page;
    });
  },

  onPageSizeChanged: (size) {
    setState(() {
      _pageSize = size;
      _currentPage = 1;
    });
  },
),    ],
  ),
);
        },
      ),
    );
  }
}

class _RejectedLeadCard extends StatelessWidget {
  final Lead lead;

  const _RejectedLeadCard({
    required this.lead,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
          const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
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
          lead.name.isEmpty
              ? '?'
              : lead.name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              lead.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lead.phone,
              style: const TextStyle(
                color: Colors.grey,
              ),
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
      onTap: () {
        _confirmDelete(context, lead.id);
      },
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
  "companyName",
    lead.companyName.isEmpty ? "-" : lead.companyName,
),

_buildInfoRow(
  Icons.person_outline,
  "Asssignee",
    lead.assignTo.isEmpty ? "-" : lead.assignTo,
),

_buildInfoRow(
  Icons.comment_outlined,
  "Reason",
    lead.rejectionReason.isEmpty ? "-" : lead.rejectionReason,

),

_buildInfoRow(
  Icons.person_remove_alt_1,
  "Rejected By",
  lead.rejectedBy == null
      ? "-"
      : "${lead.rejectedBy!.firstName} ${lead.rejectedBy!.lastName}",
),

_buildInfoRow(
  Icons.event_busy,
  "Rejected At",
  lead.rejectedAt == null
      ? "-"
      : DateFormat("dd MMM yyyy • hh:mm a")
          .format(lead.rejectedAt!),
),

const SizedBox(height: 14),

// SizedBox(
//   width: double.infinity,
//   child: OutlinedButton.icon(
//     icon: const Icon(Icons.visibility),
//     label: const Text("View Details"),
//     onPressed: () {
//       showModalBottomSheet(
//         context: context,
//         isScrollControlled: true,
//         backgroundColor: Colors.transparent,
//         builder: (_) => LeadDetailSheet(
//           lead: lead,
//         ),
//       );
//     },
//   ),
// ),

          ],
        ),
      ),
    );
  }
  Future<void> _confirmDelete(
  BuildContext context,
  String id,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Delete Rejected Lead"),
      content: const Text(
        "Are you sure you want to permanently delete this rejected lead?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (confirm == true && context.mounted) {
    final err =
        await context.read<LeadCubit>().deleteLead(id);

    if (err != null) {
     // showApiSnack(context, err, isError: true);
    }
  }
}
  Widget _buildInfoRow(
  IconData icon,
  String title,
  String value,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.primary,
        ),
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
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
}