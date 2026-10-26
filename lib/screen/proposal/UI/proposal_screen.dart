import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/proposal/UI/create_proposal_screen.dart';
import 'package:crm_app/screen/proposal/UI/draft_proposal_list_screen.dart';
import 'package:crm_app/screen/proposal/UI/proposal_card.dart';
import 'package:crm_app/screen/proposal/cubit/draft_cubit.dart';
import 'package:crm_app/screen/proposal/cubit/proposal_cubit.dart';
import 'package:crm_app/screen/proposal/cubit/proposal_state.dart';
import 'package:crm_app/screen/proposal/modal/proposal_modal.dart';
import 'package:crm_app/shareWidgets/pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProposalListScreen extends StatefulWidget {
  const ProposalListScreen({super.key});

  @override
  State<ProposalListScreen> createState() =>
      _ProposalListScreenState();
}

class _ProposalListScreenState extends State<ProposalListScreen> {
  int currentPage = 1;
  int pageSize = 10;
  final List<int> pageSizeOptions = [10, 20, 50];

  final Set<String> _selectedProposalIds = {};
bool _isDeleting = false;

bool get _isSelectionMode => _selectedProposalIds.isNotEmpty;

void _toggleProposalSelection(String id) {
  setState(() {
    if (!_selectedProposalIds.add(id)) {
      _selectedProposalIds.remove(id);
    }
  });
}

void _clearProposalSelection() {
  setState(() => _selectedProposalIds.clear());
}
  
  
  final TextEditingController searchController =
      TextEditingController();
  String selectedFilter = 'all';
  DateTime? selectedFilterDate;

void _showStatusFilter(BuildContext context) {
  String? tempStatus = selectedFilter;
  DateTime? tempDate = selectedFilterDate;

  showModalBottomSheet(
    context: context,
  backgroundColor: const Color(0xfff1f1f1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(18),
      ),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Filter Proposals',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Filter by status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 7),

                  DropdownButtonFormField<String>(
                    value: tempStatus,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Select status',
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
      value: 'all',
      child: Text('All Status'),
    ),
                      DropdownMenuItem(
                        value: 'draft',
                        child: Text('Draft'),
                      ),
                      DropdownMenuItem(
                        value: 'sent',
                        child: Text('Sent'),
                      ),
                      DropdownMenuItem(
                        value: 'no reply',
                        child: Text('No reply'),
                      ),
                      DropdownMenuItem(
                        value: 'rejection',
                        child: Text('Rejection'),
                      ),
                      DropdownMenuItem(
                        value: 'success',
                        child: Text('Success'),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        tempStatus = value;
                      });
                    },
                  ),

                const SizedBox(height: 16),

const Text(
  'Filter by date',
  style: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  ),
),

const SizedBox(height: 7),

InkWell(
  onTap: () async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: tempDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setSheetState(() {
        tempDate = pickedDate;
      });
    }
  },
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      border: Border.all(
        color: const Color(0xffdddddd),
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            tempDate == null
                ? 'Select date'
                : '${tempDate!.day.toString().padLeft(2, '0')}/'
                  '${tempDate!.month.toString().padLeft(2, '0')}/'
                  '${tempDate!.year}',
            style: TextStyle(
              fontSize: 13,
              color: tempDate == null
                  ? Colors.grey
                  : Colors.black,
            ),
          ),
        ),
        const Icon(
          Icons.calendar_today_outlined,
          size: 18,
          color: Colors.grey,
        ),
      ],
    ),
  ),
),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              selectedFilter = 'all';
                              selectedFilterDate = null;
                            });

                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedFilter = tempStatus ?? 'all' ;
                              selectedFilterDate = tempDate;

                            });

                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProposalCubit>().getProposals(
      );
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       //backgroundColor: const Color(0xfff1f1f1),
appBar: AppBar(
  automaticallyImplyLeading: true,
  backgroundColor: const Color(0xfff1f1f1),
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  title: Text(
    _isSelectionMode
        ? '${_selectedProposalIds.length} selected'
        : 'Proposals',
  ),
  actions: [
    if (_isSelectionMode) ...[
      IconButton(
        tooltip: 'Delete selected',
        onPressed: _isDeleting ? null : _deleteSelectedProposals,
        icon: _isDeleting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
      ),
      IconButton(
        tooltip: 'Cancel selection',
        onPressed: _isDeleting ? null : _clearProposalSelection,
        icon: const Icon(Icons.close),
      ),
    ],
  ],
),

      body: SafeArea(
        child: Column(
          children: [

            // =========================================================
            // HEADER
            // =========================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                16,
                20,
                16,
                16,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  

 
                  const SizedBox(height: 14),

Row(
  children: [
    Expanded(
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            setState(() => currentPage = 1);
          },
          decoration: InputDecoration(
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      searchController.clear();
                      setState(() => currentPage = 1);
                    },
                  ),
            hintText: 'Search by title, email, or deal',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 23,
              color: Colors.grey,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(
                color: Color(0xffdddddd),
                width: .5,
              ),
            ),
          ),
        ),
      ),
    ),

    const SizedBox(width: 8),

// FILTER
SizedBox(
  width: 44,
  height: 44,
  child: IconButton(
    padding: EdgeInsets.zero,
    onPressed: () {
      _showStatusFilter(context);
    },
    icon: const Icon(
      Icons.filter_alt_outlined,
      size: 30,
    ),
  ),
),

const SizedBox(width: 6),

// DRAFT PROPOSALS
Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: const Color(0xffe9e7e2),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Stack(
    children: [
      Center(
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => DraftProposalCubit(),
                  child: const DraftProposalListScreen(),
                ),
              ),
            );
          },
          icon: const Icon(
            Icons.description_outlined,
            size: 19,
            color: Colors.black87,
          ),
        ),
      ),

      Positioned(
        top: 7,
        right: 7,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ],
  ),
),

// CLEAR FILTER
if (selectedFilter != 'all' ||
    selectedFilterDate != null)
  Padding(
    padding: const EdgeInsets.only(left: 6),
    child: GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = 'all';
          selectedFilterDate = null;
        });
      },
      child: const Text(
        'Clear',
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  ),
  ],
)                ],
              ),
            ),

            // =========================================================
            // PROPOSAL LIST
            // =========================================================

            Expanded(
              child: BlocBuilder<
                  ProposalCubit,
                  ProposalState>(
                builder: (
                  context,
                  state,
                ) {

                  // ===================================================
                  // LOADING
                  // ===================================================

                  if (state
                      is ProposalLoading) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  // ===================================================
                  // ERROR
                  // ===================================================

                  if (state
                      is ProposalError) {
                    return Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(20),
                        child: Text(
                          state.message,
                          textAlign:
                              TextAlign.center,
                        ),
                      ),
                    );
                  }

                  // ===================================================
                  // LOADED
                  // ===================================================

                  if (state
                      is ProposalLoaded) {

                   final filter =
    selectedFilter.trim().toLowerCase();

final query =
    searchController.text.trim().toLowerCase();

final List<Proposal> proposals =
    state.proposals.where((proposal) {
  // ============================================================
  // SEARCH (title, email, deal)
  // ============================================================

  if (query.isNotEmpty &&
      ![
        proposal.title,
        proposal.email,
        proposal.dealTitle,
      ].any((field) => field.toLowerCase().contains(query))) {
    return false;
  }

  // ============================================================
  // STATUS FILTER
  // ============================================================

  final status =
      proposal.status.trim().toLowerCase();

  final matchesStatus =
      filter == 'all' ||
      status == filter;

  // ============================================================
  // FOLLOW-UP DATE FILTER
  // ============================================================

  bool matchesDate = true;

  if (selectedFilterDate != null &&
      proposal.followUpDate != null) {
    final proposalDate =
        proposal.followUpDate!;

    matchesDate =
        proposalDate.year ==
            selectedFilterDate!.year &&
        proposalDate.month ==
            selectedFilterDate!.month &&
        proposalDate.day ==
            selectedFilterDate!.day;
  }

  // If a date is selected but proposal has
  // no follow-up date, don't show it.
  if (selectedFilterDate != null &&
      proposal.followUpDate == null) {
    matchesDate = false;
  }

  return matchesStatus && matchesDate;
}).toList();


                    if (proposals.isEmpty) {
                      return const Center(
                        child: Text(
                          'No proposals found',
                        ),
                      );
                    }

final totalItems = proposals.length;

final totalPages =
    totalItems == 0 ? 1 : (totalItems / pageSize).ceil();

// Make sure current page is still valid after filtering
if (currentPage > totalPages) {
  currentPage = totalPages;
}

final startIndex = (currentPage - 1) * pageSize;

final endIndex = (startIndex + pageSize) > totalItems
    ? totalItems
    : startIndex + pageSize;

final paginatedProposals = startIndex >= totalItems
    ? <Proposal>[]
    : proposals.sublist(
        startIndex,
        endIndex,
      );

return Column(
  children: [
    Expanded(
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            selectedFilter = 'all';
            selectedFilterDate = null;
            currentPage = 1;
          });

          await context.read<ProposalCubit>().getProposals();
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            12,
            14,
            12,
            20,
          ),
          itemCount: paginatedProposals.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          
itemBuilder: (context, index) {
  final proposal = paginatedProposals[index];
  final isSelected =
      _selectedProposalIds.contains(proposal.id);

 
return GestureDetector(
  onLongPress: () => _toggleProposalSelection(proposal.id),
  onTap: () {
    if (_isSelectionMode) {
      _toggleProposalSelection(proposal.id);
    } else {
      
    }
  },
  child: ProposalCard(
    key: ValueKey(proposal.id),
    proposal: proposal,
    isSelected: isSelected,
    selectionMode: _isSelectionMode,
    onMorePressed: () {
      if (!_isSelectionMode) {
        _showActions(context, proposal);
      }
    },
  ),
);

},        ),
      ),
    ),

    // =========================================================
    // PAGINATION
    // =========================================================

    PaginationWidget(
      currentPage: currentPage,
      totalItems: totalItems,
      pageSize: pageSize,
      pageSizeOptions: pageSizeOptions,

      onPageChanged: (page) {
        setState(() {
          currentPage = page;
        });
      },

      onPageSizeChanged: (size) {
        setState(() {
          pageSize = size;
          currentPage = 1;
        });
      },
    ),
  ],
);                  }

                  // ===================================================
                  // INITIAL
                  // ===================================================

                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),

      // =============================================================
      // FAB
      // =============================================================

 floatingActionButton: Padding(
  padding: const EdgeInsets.only(bottom: 40), // Move FAB up by 40px
  child: SizedBox(
    width: 52,
    height: 52,
    child: FloatingActionButton(
      elevation: 4,
      onPressed: () async  {
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ProposalCubit(),
        ),
        BlocProvider(
          create: (_) => DealsCubit()..loadDeals(),
        ),
      ],
      child: const CreateProposalScreen(),
    ),
  ),
);

if (result == true && mounted) {
  await context.read<ProposalCubit>().getProposals();
}

},
      child: const Icon(
        Icons.add,
        size: 30,
      ),
    ),
  ),
),
floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,   );
  }

  // ===============================================================
  // deleteSelectedProposals
  // ===============================================================

  Future<void> _deleteSelectedProposals() async {
  if (_selectedProposalIds.isEmpty || _isDeleting) return;

  final ids = List<String>.from(_selectedProposalIds);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete proposals?'),
      content: Text('Delete ${ids.length} selected proposal(s)?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !mounted) return;

  setState(() => _isDeleting = true);

  try {
    await context.read<ProposalCubit>().bulkDeleteProposals(
      proposalIds: ids,
    );

    if (!mounted) return;

    _clearProposalSelection();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ids.length} proposal(s) deleted')),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Delete failed: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _isDeleting = false);
    }
  }
}
  // ===============================================================
  // ACTIONS
  // ===============================================================

  void _showActions(
    BuildContext context,
    Proposal proposal,
  ) {
    showModalBottomSheet(
      context: context,

      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),

      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [

              ListTile(
                leading: const Icon(
                  Icons.visibility_outlined,
                ),

                title: const Text(
                  'View Proposal',
                ),

                onTap: () {
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                ),

                title: const Text(
                  'Edit Proposal',
                ),

                onTap: () {
                  Navigator.pop(context);
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),

                title: const Text(
                  'Delete Proposal',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),

                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}