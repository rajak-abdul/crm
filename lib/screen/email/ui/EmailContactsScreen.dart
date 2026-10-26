import 'dart:math' as math;

import 'package:crm_app/screen/email/cubit/email_cubit.dart';
import 'package:crm_app/screen/email/cubit/email_history_cubit.dart';
import 'package:crm_app/screen/email/cubit/email_state.dart';
import 'package:crm_app/screen/email/cubit/email_template_cubit.dart';
import 'package:crm_app/screen/email/cubit/scheduled_email_cubit.dart';
import 'package:crm_app/screen/email/ui/create_email_screen.dart';
import 'package:crm_app/screen/email/ui/view_email_screen.dart';
import 'package:crm_app/shareWidgets/pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:crm_app/screen/email/modal/email_modal.dart';

class EmailContactsScreen extends StatefulWidget {
  const EmailContactsScreen({super.key});

  @override
  State<EmailContactsScreen> createState() => _EmailContactsScreenState();
}

class _EmailContactsScreenState extends State<EmailContactsScreen> {
  void _showContactDetails(EmailContact contact) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _buildContactDetailSheet(contact);
    },
  );
}
 // Pagination for the email Campaign
List<EmailContact> _getPaginatedContacts(
  List<EmailContact> contacts,
) {
  final filteredContacts = _filterContacts(contacts);

  final startIndex = (_currentPage - 1) * _pageSize;

  if (startIndex >= filteredContacts.length) {
    return [];
  }

  final endIndex = math.min(
    startIndex + _pageSize,
    filteredContacts.length,
  );

  return filteredContacts.sublist(startIndex, endIndex);
}

  final TextEditingController _searchController = TextEditingController();

  bool _selectionMode = false;
  final Set<String> _selectedContactIds = {};

  // Contacts seen on any page, so selections made on earlier pages
  // can still be sent after paging away from them.
  final Map<String, EmailContact> _knownContacts = {};

  String _selectedFilter = 'All';
  String _sortType = 'Recent';
  int _currentPage = 1;
  int _pageSize = 10;
  final List<int> _pageSizeOptions = [
    5,
    10,
    25,
  ];

@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    final cubit = context.read<EmailContactsCubit>();

    // Fetch only when the screen is opened for the first time.
    if (cubit.state is! EmailContactsSuccess &&
        cubit.state is! EmailContactsLoading) {
      _loadPage(1);
    }
  });
}

  void _loadPage(int page) {
  if (page < 1) return;

  setState(() {
    _currentPage = page;
  });

  context.read<EmailContactsCubit>().getEmailContacts(
        page: page,
        limit: _pageSize,
      );
}

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSelectedContacts() {
  setState(() {
    _selectedContactIds.clear();
  });
}

  List<EmailContact> _filterContacts(List<EmailContact> contacts) {
    final search = _searchController.text.trim().toLowerCase();

    return contacts.where((contact) {
      bool matchesType = true;

      if (_selectedFilter == 'Leads') {
        matchesType = contact.type.toLowerCase() == 'lead';
      } else if (_selectedFilter == 'Deals') {
        matchesType = contact.type.toLowerCase() == 'deal';
      }

      final matchesSearch = search.isEmpty ||
          contact.name.toLowerCase().contains(search) ||
          contact.email.toLowerCase().contains(search) ||
          contact.company.toLowerCase().contains(search);

      return matchesType && matchesSearch;
    }).toList();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),

  body: Stack(
    children: [
      SafeArea(
      child: BlocBuilder<EmailContactsCubit, EmailContactsState>(
        builder: (context, state) {
          if (state is EmailContactsLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is EmailContactsError) {
            return _buildError(state.message);
          }

          if (state is EmailContactsSuccess) {
            for (final contact in state.contacts) {
              _knownContacts[contact.id] = contact;
            }

            // Search and the Leads/Deals chips filter within the
            // currently-loaded page only.
            final allFilteredContacts = _filterContacts(state.contacts);

final paginatedContacts = _getPaginatedContacts(
  state.contacts,
);

            final isFiltering = _selectedFilter != 'All' ||
                _searchController.text.trim().isNotEmpty;

            return Column(
              children: [
                _selectionMode
    ? _buildSelectionHeader()
    : _buildHeader(state),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(
                      bottom: 20,
                    ),
                    children: [
                      _buildSummaryCard(state),

                      _buildSearch(),

                      _buildFilters(),

                      _buildContactHeader(
                        isFiltering
                            ? allFilteredContacts.length
                            : state.total,
                      ),

                      _buildContactsList(
                        paginatedContacts,
                      ),
                    ],
                  ),
                ),

                PaginationWidget(
  currentPage: _currentPage,
  totalItems: allFilteredContacts.length,
  pageSize: _pageSize,
  pageSizeOptions: _pageSizeOptions,
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
),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    ),


      // =========================
      // SEND FAB
      // =========================
Positioned(
  right: 16,
  bottom: 90,
  child: BlocBuilder<EmailContactsCubit, EmailContactsState>(
    builder: (context, state) {
      if (state is! EmailContactsSuccess) {
        return const SizedBox.shrink();
      }

      return SizedBox(
        width: 52,
        height: 52,
        child: _buildSendButton(),
      );
    },
  ),
),    ],
  ),
);

    
}
  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader(EmailContactsSuccess state) {
  // Replace this with your actual scheduled email count.
  const int scheduledCount = 3;

  return Container(
    padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
    decoration: const BoxDecoration(
      color: Color(0xFFF8F8FA),
      border: Border(
        bottom: BorderSide(
          color: Color(0xFFE5E5E7),
          width: 0.5,
        ),
      ),
    ),
    child: Row(
      children: [
        // ============================================================
        // BACK BUTTON
        // ============================================================
        IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(
            Icons.arrow_back,
            size: 22,
            color: Color(0xFF66666E),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),

        const SizedBox(width: 4),

        // ============================================================
        // TITLE
        // ============================================================
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email Campaign',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${state.leadCount} leads reachable',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF77777F),
                ),
              ),
            ],
          ),
        ),

        // ============================================================
        // SCHEDULED BUTTON
        // ============================================================
        InkWell(
         onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: context.read<EmailHistoryCubit>(),
            ),

            BlocProvider<ScheduledEmailCubit>(
              create: (_) => ScheduledEmailCubit()
                ..getScheduledEmails(),
            ),
          ],
          child: const ViewEmailScreen(initialTab: 0),
        ),
      ),
    );
  },

          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFD8E8FF),
                width: 0.7,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Calendar icon
                 Icon(
                  Icons.mark_email_read_outlined,
                  size: 18,
                  color: Color(0xFF3978D6),
                ),

                 SizedBox(width: 6),

                // Scheduled text
                 Text(
                  'Email Activity',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3978D6),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

      ],
    ),
  );
}

  // ------------------------------------------------------------
  // SUMMARY CARD
  // ------------------------------------------------------------

  Widget _buildSummaryCard(EmailContactsSuccess state) {
    final total = state.total;
    final leads = state.leadCount;
    final deals = state.dealCount;
    final weeklyGrowth = _calculateWeeklyGrowth(
  state.contacts,
);

final leadGrowth = weeklyGrowth['leads'] ?? 0.0;
final dealGrowth = weeklyGrowth['deals'] ?? 0.0;
    final leadPercentage =
        total == 0 ? 0.0 : (leads / total) * 100;

    final dealPercentage =
        total == 0 ? 0.0 : (deals / total) * 100;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E5E7),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          _buildCircularChart(
            total: total,
            leads: leads,
            deals: deals,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                _buildSummaryRow(
                  dotColor: const Color(0xFF1D9E75),
                  title: 'Leads',
                  count: leads,
                  percentage: leadPercentage,
                ),
                const SizedBox(height: 10),
                _buildSummaryRow(
                  dotColor: const Color(0xFF7F77DD),
                  title: 'Deals',
                  count: deals,
                  percentage: dealPercentage,
                ),
                const SizedBox(height: 10),
                Container(
                  height: 0.5,
                  color: const Color(0xFFE5E5E7),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    
                    Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      children: [
        Icon(
          leadGrowth >= 0
              ? Icons.trending_up
              : Icons.trending_down,
          size: 14,
          color: leadGrowth >= 0
              ? const Color(0xFF1D9E75)
              : const Color(0xFFE24B4A),
        ),
        const SizedBox(width: 6),
        Text(
          '${leadGrowth >= 0 ? '+' : ''}'
          '${leadGrowth.toStringAsFixed(1)}% Leads this week',
          style: TextStyle(
            fontSize: 11,
            color: leadGrowth >= 0
                ? const Color(0xFF1D9E75)
                : const Color(0xFFE24B4A),
          ),
        ),
      ],
    ),

    const SizedBox(height: 6),

    Row(
      children: [
        Icon(
          dealGrowth >= 0
              ? Icons.trending_up
              : Icons.trending_down,
          size: 14,
          color: dealGrowth >= 0
              ? const Color(0xFF7F77DD)
              : const Color(0xFFE24B4A),
        ),
        const SizedBox(width: 6),
        Text(
          '${dealGrowth >= 0 ? '+' : ''}'
          '${dealGrowth.toStringAsFixed(1)}% Deals this week',
          style: TextStyle(
            fontSize: 11,
            color: dealGrowth >= 0
                ? const Color(0xFF7F77DD)
                : const Color(0xFFE24B4A),
          ),
        ),
      ],
    ),
  ],
),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularChart({
    required int total,
    required int leads,
    required int deals,
  }) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _ContactsChartPainter(
          total: total,
          leads: leads,
          deals: deals,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatNumber(total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF202124),
                ),
              ),
              const Text(
                'contacts',
                style: TextStyle(
                  fontSize: 9,
                  color: Color(0xFF9999A1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required Color dotColor,
    required String title,
    required int count,
    required double percentage,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF303038),
            ),
          ),
        ),
        Text(
          _formatNumber(count),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF202124),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            '${percentage.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF9999A1),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
  controller: _searchController,

  onChanged: (value) {
    setState(() {});
  },

  style: const TextStyle(
    fontSize: 13,
  ),
  decoration: InputDecoration(
    hintText: 'Search contacts',
    hintStyle: const TextStyle(
      fontSize: 13,
      color: Color(0xFF9999A1),
    ),
    prefixIcon: const Icon(
      Icons.search,
      size: 17,
      color: Color(0xFF9999A1),
    ),
    suffixIcon: _searchController.text.isNotEmpty
        ? IconButton(
            onPressed: () {
              _searchController.clear();

              setState(() {});
            },
            icon: const Icon(
              Icons.close,
              size: 16,
            ),
          )
        : null,
    filled: true,
    fillColor: const Color(0xFFF1F1F4),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  ),
)
    );
  }

  // ------------------------------------------------------------
  // FILTERS
  // ------------------------------------------------------------

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          _buildFilterChip('All'),
          const SizedBox(width: 8),
          _buildFilterChip('Leads'),
          const SizedBox(width: 8),
          _buildFilterChip('Deals'),
          const Spacer(),
          InkWell(
            onTap: _showFilterSheet,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 15,
                    color: Color(0xFF66666E),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF66666E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String title) {
    final selected = _selectedFilter == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF303030)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(
                  color: const Color(0xFFD0D0D5),
                  width: 0.5,
                ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: selected
                ? Colors.white
                : const Color(0xFF66666E),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CONTACT HEADER
  // ------------------------------------------------------------

  Widget _buildContactHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Text(
            '${_formatNumber(count)} contacts',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9999A1),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: _showSortSheet,
            child: Row(
              children: [
                Text(
                  'Sort: $_sortType',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF625DCE),
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 14,
                  color: Color(0xFF625DCE),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // CONTACT LIST
  // ------------------------------------------------------------

  Widget _buildContactsList(List<EmailContact> contacts) {
    if (contacts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(
          top: 60,
          left: 20,
          right: 20,
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.people_outline,
                size: 42,
                color: Color(0xFFB0B0B5),
              ),
              SizedBox(height: 10),
              Text(
                'No contacts found',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF77777F),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        children: contacts.map(_buildContactCard).toList(),
      ),
    );
  }

Widget _buildContactCard(EmailContact contact) {
  final status = contact.status.trim();

  final isConverted = status.toLowerCase() == 'converted';
  final isRejected = status.toLowerCase() == 'rejected';

  final Color accentColor = isConverted
      ? const Color(0xFF1D9E75)
      : isRejected
          ? const Color(0xFFE24B4A)
          : const Color(0xFF7F77DD);

  final Color avatarBackground = isRejected
    ? const Color(0xFFFFEAEA) // mild red
    : isConverted
        ? const Color(0xFFE8F5F0) // mild green
        : const Color(0xFFFFF3DD);

final Color avatarText = isRejected
    ? const Color(0xFFE24B4A) // red
    : isConverted
        ? const Color(0xFF1D9E75) // green
        : const Color(0xFFB7791F);
  final bool isSelected =
      _selectedContactIds.contains(contact.id);

  return GestureDetector(
    behavior: HitTestBehavior.opaque,

    // Long press starts selection mode
    onLongPress: () {
      setState(() {
        _selectionMode = true;
        _selectedContactIds.add(contact.id);
      });
    },

    // Tap the card to select/unselect
    onTap: () {
  // Normal mode → open contact details
  if (!_selectionMode) {
    _showContactDetails(contact);
    return;
  }

  // Selection mode → select / unselect contact
  setState(() {
    if (isSelected) {
      _selectedContactIds.remove(contact.id);
    } else {
      _selectedContactIds.add(contact.id);
    }

    // Exit selection mode when nothing is selected
    if (_selectedContactIds.isEmpty) {
      _selectionMode = false;
    }
  });
},

    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFF0F9FF)
            : Colors.white,

        borderRadius: BorderRadius.circular(14),

        // IMPORTANT:
        // Use a single border color so borderRadius works.
        border: isSelected
            ? Border.all(
                color: const Color(0xFFB9E5FF),
                width: 1,
              )
            : Border.all(
                color: Colors.transparent,
                width: 1,
              ),
      ),

      child: Row(
        children: [
          // CHECKBOX
          if (_selectionMode) ...[
            SizedBox(
              width: 30,
              height: 30,
              child: Checkbox(
                value: isSelected,

                // Checkbox itself handles selection.
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedContactIds.add(contact.id);
                    } else {
                      _selectedContactIds.remove(contact.id);
                    }

                    if (_selectedContactIds.isEmpty) {
                      _selectionMode = false;
                    }
                  });
                },

                activeColor: const Color(0xFF625DCE),
                checkColor: Colors.white,

                side: const BorderSide(
                  color: Color(0xFF9999A1),
                  width: 1.2,
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),

                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
              ),
            ),

            const SizedBox(width: 6),
          ],

          // AVATAR
          _buildAvatar(
            contact.name,
            avatarBackground,
            avatarText,
          ),

          const SizedBox(width: 11),

          // NAME + EMAIL/PHONE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name.isEmpty
                      ? 'Unnamed'
                      : contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF202124),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _contactSubtitle(contact),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF77777F),
                  ),
                ),
              ],
            ),
          ),

          // STATUS
          if (status.isNotEmpty) ...[
            const SizedBox(width: 8),
            _buildStatus(status),
          ],

          // CHEVRON ONLY IN NORMAL MODE
          if (!_selectionMode) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: Color(0xFF9999A1),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildSelectionHeader() {
  return Container(
    height: 54,
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(
        bottom: BorderSide(
          color: Color(0xFFE5E5E7),
          width: 0.5,
        ),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _selectionMode = false;
              _selectedContactIds.clear();
            });
          },
          icon: const Icon(
            Icons.close,
            size: 21,
            color: Color(0xFF66666E),
          ),
        ),

        const SizedBox(width: 4),

        Text(
          '${_selectedContactIds.length} selected',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF202124),
          ),
        ),

        const Spacer(),

        TextButton(
          onPressed: () {
            setState(() {
              _selectedContactIds.clear();
              _selectionMode = false;
            });
          },
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF625DCE),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildAvatar(
    String name,
    Color background,
    Color textColor,
  ) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStatus(String status) {
    final lower = status.toLowerCase();

    Color background;
    Color foreground;

    if (lower == 'converted') {
      background = const Color(0xFFE4F5EF);
      foreground = const Color(0xFF1D9E75);
    } else if (lower == 'rejected') {
      background = const Color(0xFFFDE8E8);
      foreground = const Color(0xFFE24B4A);
    } else {
      background = const Color(0xFFF0EEFF);
      foreground = const Color(0xFF625DCE);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          color: foreground,
        ),
      ),
    );
  }

  String _contactSubtitle(EmailContact contact) {
    if (contact.email.isNotEmpty && contact.company.isNotEmpty) {
      return '${contact.email} · ${contact.company}';
    }

    if (contact.email.isNotEmpty) {
      return contact.email;
    }

    if (contact.company.isNotEmpty) {
      return contact.company;
    }

    if (contact.phone.isNotEmpty) {
      return contact.phone;
    }

    return 'No contact information';
  }

  // ------------------------------------------------------------
  // SEND BUTTON
  // ------------------------------------------------------------

  Widget _buildSendButton() {
  return FloatingActionButton(
    onPressed: () async {
      final state = context.read<EmailContactsCubit>().state;

      if (state is! EmailContactsSuccess) {
        return;
      }

      // Selections can span pages, so look them up in the cache
      // rather than only the currently-loaded page.
      final selectedContacts = _selectedContactIds
          .map((id) => _knownContacts[id])
          .whereType<EmailContact>()
          .toList();

      if (selectedContacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one contact'),
          ),
        );
        return;
      }

      final result =await Navigator.of(
  context,
  rootNavigator: true,
).push(
  MaterialPageRoute(
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider<EmailTemplateCubit>(
          create: (_) => EmailTemplateCubit()
            ..getEmailTemplates(),
        ),
      ],
      child: CreateEmailScreen(
        recipients: selectedContacts,
      ),
    ),
  ),
);

if (result == true && mounted) {
  setState(() {
    _selectedContactIds.clear();
    _selectionMode = false;
  });
}
    },
    elevation: 5,
    backgroundColor: const Color(0xFF303030),
    child: const Icon(
      Icons.send_rounded,
      size: 20,
      color: Colors.white,
    ),
  );
}


  // ------------------------------------------------------------
  // FILTER SHEET
  // ------------------------------------------------------------

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter contacts',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('All contacts'),
                  trailing: _selectedFilter == 'All'
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'All';
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text('Leads'),
                  trailing: _selectedFilter == 'Leads'
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Leads';
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text('Deals'),
                  trailing: _selectedFilter == 'Deals'
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Deals';
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // SORT SHEET
  // ------------------------------------------------------------

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sort contacts',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ...[
                  'Recent',
                  'Name',
                  'Email',
                ].map(
                  (value) => ListTile(
                    title: Text(value),
                    trailing: _sortType == value
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () {
                      setState(() {
                        _sortType = value;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // ERROR
  // ------------------------------------------------------------

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 45,
              color: Color(0xFFE24B4A),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF66666E),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _loadPage(_currentPage);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }

    if (number >= 1000) {
      return number
          .toString()
          .replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (match) => ',',
          );
    }

    return number.toString();
  }

  // helper 
  Map<String, double> _calculateWeeklyGrowth(
  List<EmailContact> contacts,
) {
  final now = DateTime.now();

  final today = DateTime(
    now.year,
    now.month,
    now.day,
  );

  // Monday of current week
  final currentWeekStart = today.subtract(
    Duration(days: today.weekday - 1),
  );

  // Monday of previous week
  final previousWeekStart =
      currentWeekStart.subtract(const Duration(days: 7));

  int thisWeekLeads = 0;
  int lastWeekLeads = 0;

  int thisWeekDeals = 0;
  int lastWeekDeals = 0;

  for (final contact in contacts) {
    if (contact.createdAt == null) continue;

    final date = contact.createdAt!.toLocal();

    final type = contact.type.trim().toLowerCase();

    final isThisWeek =
        !date.isBefore(currentWeekStart) &&
        date.isBefore(today.add(const Duration(days: 1)));

    final isLastWeek =
        !date.isBefore(previousWeekStart) &&
        date.isBefore(currentWeekStart);

    if (type == 'lead') {
      if (isThisWeek) {
        thisWeekLeads++;
      } else if (isLastWeek) {
        lastWeekLeads++;
      }
    }

    if (type == 'deal') {
      if (isThisWeek) {
        thisWeekDeals++;
      } else if (isLastWeek) {
        lastWeekDeals++;
      }
    }
  }

  double growth(int current, int previous) {
    if (previous == 0) {
      return current > 0 ? 100.0 : 0.0;
    }

    return ((current - previous) / previous) * 100;
  }

  return {
    'leads': growth(thisWeekLeads, lastWeekLeads),
    'deals': growth(thisWeekDeals, lastWeekDeals),
  };
}
// Helper
Widget _buildContactChip({
  required IconData icon,
  required String label,
  required Color backgroundColor,
  required Color textColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 9,
      vertical: 5,
    ),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [

        Icon(
          icon,
          size: 12,
          color: textColor,
        ),

        const SizedBox(width: 5),

        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget _buildContactDetailRow({
  required IconData icon,
  required String label,
  required String value,
  required Color iconBackground,
  required Color iconColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
    child: Row(
      children: [

        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconBackground,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 15,
            color: iconColor,
          ),
        ),

        const SizedBox(width: 12),

        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF222222),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildDivider() {
  return Container(
    height: 0.5,
    margin: const EdgeInsets.only(
      left: 58,
    ),
    color: Colors.grey.shade200,
  );
}

String _getMonthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return months[month - 1];
}

String _capitalize(String value) {
  if (value.isEmpty) return value;

  return value[0].toUpperCase() +
      value.substring(1).toLowerCase();
}

Widget _buildContactDetailSheet(EmailContact contact) {
  final typeLower = contact.type.trim().toLowerCase();
  final statusLower = contact.status.trim().toLowerCase();

  final bool isRejected = statusLower == 'rejected';
  final bool isConverted = statusLower == 'converted';

  // Status has priority over type.
  final Color accentColor;
  final Color lightColor;

  if (isRejected) {
    // Rejected → red
    accentColor = const Color(0xFFE24B4A);
    lightColor = const Color(0xFFFFEAEA);
  } else if (isConverted) {
    // Converted → green
    accentColor = const Color(0xFF1D9E75);
    lightColor = const Color(0xFFE8F5F0);
  } else if (typeLower == 'lead') {
    // Lead → purple
    accentColor = const Color(0xFF625DCE);
    lightColor = const Color(0xFFF0EEFF);
  } else if (typeLower == 'deal') {
    // Deal → purple
    accentColor = const Color(0xFF7F77DD);
    lightColor = const Color(0xFFF0EEFF);
  } else {
    // Email / other
    accentColor = const Color(0xFF5B6FD8);
    lightColor = const Color(0xFFF0F2FF);
  }
    
  final name = contact.name.trim().isNotEmpty
      ? contact.name.trim()
      : 'Unnamed';

  final email = contact.email.trim().isNotEmpty
      ? contact.email.trim()
      : 'No email';

  final phone = contact.phone.trim().isNotEmpty
      ? contact.phone.trim()
      : 'Not available';

  final company = contact.company.trim().isNotEmpty
      ? contact.company.trim()
      : 'Not available';

  final source = contact.source.trim().isNotEmpty
      ? contact.source.trim()
      : 'Not available';

  final type = contact.type.trim().isNotEmpty
      ? contact.type.trim()
      : 'Contact';

  final status = contact.status.trim().isNotEmpty
      ? contact.status.trim()
      : 'Unknown';

  final initial = name.isNotEmpty
      ? name.substring(0, 1).toLowerCase()
      : '?';

  String createdDate = 'Not available';

  if (contact.createdAt != null) {
    final date = contact.createdAt!.toLocal();

    createdDate =
        '${date.day.toString().padLeft(2, '0')} '
        '${_getMonthName(date.month)} '
        '${date.year}';
  }

  return Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(
                  top: 8,
                  bottom: 8,
                ),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16,
              ),
              child: Row(
                children: [

                  // Avatar
   Container(
  width: 52,
  height: 52,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: lightColor,
    border: Border.all(
      color: accentColor,
      width: 2,
    ),
  ),
  alignment: Alignment.center,
  child: Text(
    initial,
    style: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w500,
      color: accentColor,
    ),
  ),
),

                  const SizedBox(width: 12),

                  // Name + email
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF202124),
                          ),
                        ),

                        const SizedBox(height: 3),

                        Row(
                          children: [

                            Icon(
                              Icons.mail_outline,
                              size: 13,
                              color: accentColor,
                            ),

                            const SizedBox(width: 6),

                            Expanded(
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Close
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF77777F),
                    ),
                  ),
                ],
              ),
            ),

            // Type + Status
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                18,
              ),
              child: Row(
  children: [
    _buildContactChip(
      icon: typeLower == 'deal'
          ? Icons.handshake_outlined
          : typeLower == 'lead'
              ? Icons.person_outline
              : Icons.email_outlined,
      label: _capitalize(type),
      backgroundColor: lightColor,
      textColor: accentColor,
    ),

    const SizedBox(width: 8),

    _buildContactChip(
      icon: isRejected
          ? Icons.cancel_outlined
          : isConverted
              ? Icons.check_circle_outline
              : Icons.circle_outlined,
      label: _capitalize(status),
      backgroundColor: lightColor,
      textColor: accentColor,
    ),
  ],
),
            ),

            // Contact details
            const Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                8,
              ),
              child: Text(
                'Contact details',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9999A1),
                ),
              ),
            ),

            // Details card
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE5E5E7),
                  width: 0.7,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [

                    _buildContactDetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: phone,
                      iconBackground:
                          const Color(0xFFE8F5F0),
                      iconColor:
                          const Color(0xFF1D9E75),
                    ),

                    _buildDivider(),

                    _buildContactDetailRow(
                      icon: Icons.business_outlined,
                      label: 'Company',
                      value: company,
                      iconBackground:
                          const Color(0xFFF0EEFF),
                      iconColor:
                          const Color(0xFF625DCE),
                    ),

                    _buildDivider(),

                    _buildContactDetailRow(
                      icon: Icons.alt_route,
                      label: 'Source',
                      value: source,
                      iconBackground:
                          const Color(0xFFFFF3DD),
                      iconColor:
                          const Color(0xFFB7791F),
                    ),

                    _buildDivider(),

                    _buildContactDetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created',
                      value: createdDate,
                      iconBackground:
                          const Color(0xFFF1F1F4),
                      iconColor:
                          const Color(0xFF77777F),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

}

// ============================================================
// CIRCULAR CHART PAINTER
// ============================================================

class _ContactsChartPainter extends CustomPainter {
  final int total;
  final int leads;
  final int deals;

  _ContactsChartPainter({
    required this.total,
    required this.leads,
    required this.deals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = size.width * 0.42;

    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFE5E5E7);

    canvas.drawCircle(
      center,
      radius,
      backgroundPaint,
    );

    if (total <= 0) {
      return;
    }

    final leadsPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1D9E75);

    final dealsPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7F77DD);

    final leadsSweep =
        (leads / total) * math.pi * 2;

    final dealsSweep =
        (deals / total) * math.pi * 2;

    const startAngle = -math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
      startAngle,
      leadsSweep,
      false,
      leadsPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(
        center: center,
        radius: radius,
      ),
      startAngle + leadsSweep,
      dealsSweep,
      false,
      dealsPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _ContactsChartPainter oldDelegate,
  ) {
    return oldDelegate.total != total ||
        oldDelegate.leads != leads ||
        oldDelegate.deals != deals;
  }

}