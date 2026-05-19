// ╔══════════════════════════════════════════════════════════════╗
// ║               lib/screens/invoice_screen.dart                ║
// ║  All invoice data stored in local SQLite                     ║
// ║  Sales users fetched from GET /api/users/sales               ║
// ║  Deals fetched from GET /api/deals/getAll                    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/invoice/cubit/invoice_cubit.dart';
import 'package:crm_app/screen/invoice/modal/invoice_model.dart';
import 'package:crm_app/screen/invoice/ui/dealOption.dart';
import 'package:crm_app/screen/invoice/ui/invoice_details_screen.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show showApiSnack, LoadingState, ErrorState;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:crm_app/utils/permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════
abstract class InvoiceState extends Equatable {
  const InvoiceState();
  @override
  List<Object?> get props => [];
}

class InvoiceInitial extends InvoiceState {}

class InvoiceLoading extends InvoiceState {}

class InvoiceError extends InvoiceState {
  final String message;
  const InvoiceError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── InvoiceLoaded: change salesUsers from List<String> to List<SalesUser> ──
class InvoiceLoaded extends InvoiceState {
  final List<Invoice> invoices;
  final List<Invoice> recentInvoices;
  final List<Invoice> pendingInvoices;
  final List<SalesUser> salesUsers; // ← was List<String>
  final List<DealOption> deals;

  const InvoiceLoaded({
    required this.invoices,
    this.recentInvoices = const [],
    this.pendingInvoices = const [],
    required this.salesUsers,
    required this.deals,
  });

  InvoiceLoaded copyWithInvoices(List<Invoice> updated) => InvoiceLoaded(
        invoices: updated,
        recentInvoices: recentInvoices,
        pendingInvoices: pendingInvoices,
        salesUsers: salesUsers,
        deals: deals,
      );

  @override
  List<Object?> get props => [
        invoices,
        recentInvoices,
        pendingInvoices,
        salesUsers,
        deals,
      ];
}

// ══════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => InvoiceCubit()..load(),
        child: const _InvoiceView(),
      );
}

class _InvoiceView extends StatefulWidget {
  const _InvoiceView();
  @override
  State<_InvoiceView> createState() => _InvoiceViewState();
}

class _InvoiceViewState extends State<_InvoiceView> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  String _statusFilter = 'All Status';
  DateTime? _selectedDate;
  static const _statuses = ['All Status', 'Paid', 'Unpaid'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseInvoiceDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso.toLocal();
    try {
      return DateFormat('dd MMM yyyy').parse(trimmed);
    } catch (_) {
      return null;
    }
  }

  List<Invoice> _filtered(List<Invoice> all) {
    final q = _q.toLowerCase();
    return all.where((inv) {
      final matchQ = _q.isEmpty ||
          inv.invoiceNo.toLowerCase().contains(q) ||
          inv.assignTo.toLowerCase().contains(q) ||
          inv.dealName.toLowerCase().contains(q);
      final matchStatus =
          _statusFilter == 'All Status' || inv.status == _statusFilter;
      bool matchDate = true;
      if (_selectedDate != null) {
        final d = _parseInvoiceDate(inv.issueDate);
        if (d != null) {
          final sameDay = d.year == _selectedDate!.year &&
              d.month == _selectedDate!.month &&
              d.day == _selectedDate!.day;
          matchDate = sameDay;
        } else {
          matchDate = false;
        }
      }
      return matchQ && matchStatus && matchDate;
    }).toList();
  }

  void _openCreate(InvoiceLoaded s) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: context.read<InvoiceCubit>(),
          child: _InvoiceFormModal(
            salesUsers: s.salesUsers,
            deals: s.deals,
            onSave: (data) async {
              final err =
                  await context.read<InvoiceCubit>().createInvoice(data);

              if (!mounted) return;

              if (err != null) {
                // show error inside modal
                showApiSnack(context, err, isError: true);
                return;
              }

              Navigator.pop(context);

              showApiSnack(context, 'Invoice created successfully');
            },
          ),
        ),
      );

  void _openEdit(Invoice inv, InvoiceLoaded s) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: context.read<InvoiceCubit>(),
          child: _InvoiceFormModal(
            existing: inv,
            salesUsers: s.salesUsers,
            deals: s.deals,
            onSave: (data) async {
              final err = await context.read<InvoiceCubit>().updateInvoice(
                    inv.id,
                    data,
                  );

              if (!mounted) return;

              if (err != null) {
                // show error inside modal
                showApiSnack(context, err, isError: true);
                return;
              }

              Navigator.pop(context);

              showApiSnack(context, 'Invoice updated');
            },
          ),
        ),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocBuilder<InvoiceCubit, InvoiceState>(
        builder: (ctx, state) {
          if (state is InvoiceLoading)
            return const LoadingState(message: 'Loading invoices…');
          if (state is InvoiceError) {
            return ErrorState(
              message: state.message,
              onRetry: () => ctx.read<InvoiceCubit>().load(),
            );
          }
          if (state is InvoiceLoaded) {
            final filtered = _filtered(state.invoices);
            return Column(
              children: [
                _SummaryCarousel(
                  invoices: filtered,
                  pendingInvoices:
                      filtered.where((e) => e.status == 'Unpaid').toList(),
                  recentInvoices: filtered,
                ),

                // Date filter
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: (_selectedDate != null)
                            ? AppColors.primaryLight
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_selectedDate != null)
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                            color: (_selectedDate != null)
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat(
                                      'dd MMM yyyy',
                                    ).format(_selectedDate!)
                                  : 'Filter by date',
                              style: TextStyle(
                                fontSize: 13,
                                color: (_selectedDate != null)
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: (_selectedDate != null)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (_selectedDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _selectedDate = null),
                              child: const Icon(
                                Icons.close,
                                size: 15,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FDrop(
                          value: _statusFilter,
                          items: _statuses,
                          icon: Icons.info_outline,
                          onChanged: (v) => setState(() => _statusFilter = v),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _q = v),
                            decoration: InputDecoration(
                              hintText: 'Search invoice # or deal name…',
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 17,
                                color: AppColors.textSecondary,
                              ),
                              suffixIcon: _q.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 15),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _q = '');
                                      },
                                    )
                                  : null,
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (PermissionHelper.can('users_roles'))
                        SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: () => _openCreate(state),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              'Create',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.divider),

                // Count row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${filtered.length} invoice${filtered.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (_q.isNotEmpty ||
                          _statusFilter != 'All Status' ||
                          _selectedDate != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _q = '';
                            _searchCtrl.clear();
                            _statusFilter = 'All Status';
                            _selectedDate = null;
                          }),
                          child: const Text(
                            'Clear all',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Invoice list
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 52,
                                color: AppColors.textHint,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'No invoices found',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _InvoiceCard(
                            invoice: filtered[i],
                            onEdit: () => _openEdit(filtered[i], state),
                            onDelete: () => _confirmDelete(ctx, filtered[i].id),
                            onDownload: () => _downloadPdf(ctx, filtered[i]),
                            onSendEmail: () => _sendEmail(ctx, filtered[i]),
                          ),
                        ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, String id) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Invoice'),
        content: const Text('This invoice will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      await ctx.read<InvoiceCubit>().deleteInvoice(id);
      if (mounted) showApiSnack(context, 'Invoice deleted');
    }
  }

  Future<void> _downloadPdf(BuildContext ctx, Invoice inv) async {
    if (inv.isLocal) {
      showApiSnack(
        context,
        'PDF only available after invoice is synced to server.',
        isError: true,
      );
      return;
    }
    showApiSnack(context, 'Downloading invoice PDF...');
    final err = await ctx.read<InvoiceCubit>().downloadInvoicePdf(
          inv.id,
          fileName: inv.invoiceNo,
        );
    if (!mounted) return;
    if (err == null) {
      showApiSnack(context, 'Invoice saved to Downloads');
    } else {
      showApiSnack(context, 'Download failed: $err', isError: true);
    }
  }

  Future<void> _sendEmail(BuildContext ctx, Invoice inv) async {
    if (inv.isLocal) {
      showApiSnack(
        context,
        'Sync invoice before sending email.',
        isError: true,
      );
      return;
    }
    final err = await ctx.read<InvoiceCubit>().sendEmail(inv.id);
    if (!mounted) return;
    if (err == null) {
      showApiSnack(context, 'Invoice email sent successfully');
    } else {
      showApiSnack(context, 'Failed to send email: $err', isError: true);
    }
  }
}

// ══════════════════════════════════════════════════════════════
// FINANCIAL SUMMARY CAROUSEL
// ══════════════════════════════════════════════════════════════
class _SummaryCarousel extends StatefulWidget {
  final List<Invoice> invoices;
  final List<Invoice> pendingInvoices;
  final List<Invoice> recentInvoices;
  const _SummaryCarousel({
    required this.invoices,
    required this.pendingInvoices,
    required this.recentInvoices,
  });
  @override
  State<_SummaryCarousel> createState() => _SummaryCarouselState();
}

class _SummaryCarouselState extends State<_SummaryCarousel> {
  int _page = 0;

  Map<String, dynamic> get _summary {
    int totalCount = widget.invoices.length;
    int paidCount = 0;
    int unpaidCount = 0;
    double totalValue = 0;
    double paidValue = 0;
    double unpaidValue = 0;

    for (final inv in widget.invoices) {
      final inrValue = inv.totalInInr;
      totalValue += inrValue;
      if (inv.status == 'Paid') {
        paidCount++;
        paidValue += inrValue;
      } else {
        unpaidCount++;
        unpaidValue += inrValue;
      }
    }
    return {
      'totalCount': totalCount,
      'paidCount': paidCount,
      'unpaidCount': unpaidCount,
      'totalValue': totalValue,
      'paidValue': paidValue,
      'unpaidValue': unpaidValue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final slides = [
      {
        'title': 'Total Invoices',
        'count': s['totalCount'] as int,
        'value': s['totalValue'] as double,
        'colors': [const Color(0xFF1D4ED8), const Color(0xFF0EA5E9)],
      },
      {
        'title': 'Paid Invoices',
        'count': s['paidCount'] as int,
        'value': s['paidValue'] as double,
        'colors': [const Color(0xFF047857), const Color(0xFF10B981)],
      },
      {
        'title': 'Unpaid Invoices',
        'count': s['unpaidCount'] as int,
        'value': s['unpaidValue'] as double,
        'colors': [const Color(0xFFD97706), const Color(0xFFF59E0B)],
      },
    ];
    return Column(
      children: [
        SizedBox(
          height: 132,
          child: PageView.builder(
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SummaryCard(slide: slides[i]),
          ),
        ),
        if (slides.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> slide;
  const _SummaryCard({required this.slide});

  String _fmt(double v) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: 2,
    ).format(v);
  }

  @override
  Widget build(BuildContext context) {
    final title = slide['title'] as String? ?? 'Invoices';
    final count = (slide['count'] as int?) ?? 0;
    final value = (slide['value'] as double?) ?? 0;
    final colors = (slide['colors'] as List<Color>?) ??
        [const Color(0xFF1D4ED8), const Color(0xFF0EA5E9)];
    return _gradientCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.assessment_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: Colors.white.withOpacity(0.22),
          ),
          Row(
            children: [
              Expanded(child: _metric('Count', '$count', alignStart: true)),
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withOpacity(0.22),
              ),
              Expanded(
                child: _metric(
                  'Total (INR)',
                  '₹${_fmt(value)}',
                  alignStart: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, {required bool alignStart}) {
    return Column(
      crossAxisAlignment:
          alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.82),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.98),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientCard({required List<Color> colors, required Widget child}) =>
      Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

// ══════════════════════════════════════════════════════════════
// INVOICE CARD
// ══════════════════════════════════════════════════════════════
class _InvoiceCard extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onEdit, onDelete, onDownload, onSendEmail;
  const _InvoiceCard({
    required this.invoice,
    required this.onEdit,
    required this.onDelete,
    required this.onDownload,
    required this.onSendEmail,
  });
  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _expanded = false;

  Color get _statusColor => switch (widget.invoice.status) {
        'Paid' => AppColors.success,
        'Unpaid' => AppColors.warning,
        _ => AppColors.textSecondary,
      };

  IconData get _statusIcon => switch (widget.invoice.status) {
        'Paid' => Icons.check_circle_outline,
        'Unpaid' => Icons.access_time_outlined,
        _ => Icons.receipt_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => InvoiceDetailsModal(invoice: inv),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      inv.invoiceNo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.dealName.isNotEmpty ? inv.dealName : 'No Deal',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          inv.assignTo.isNotEmpty ? inv.assignTo : 'Unassigned',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmtTotal(inv),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _fmtInrExact(inv),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _StatusBadge(
                        status: inv.status,
                        color: _statusColor,
                        icon: _statusIcon,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Flexible(
                    child: _MetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: 'Issued',
                      value: _fmtDate(inv.issueDate),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: _MetaChip(
                      icon: Icons.event_outlined,
                      label: 'Due',
                      value: _fmtDate(inv.dueDate),
                      valueColor: inv.status != 'Paid'
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Actions',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: _expanded
                  ? Container(
                      decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: AppColors.divider)),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: widget.onEdit,
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              label: const Text(
                                'Edit',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.divider,
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: widget.onDownload,
                              icon:
                                  const Icon(Icons.download_outlined, size: 15),
                              label: const Text(
                                'PDF',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.success,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.divider,
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: widget.onSendEmail,
                              icon: const Icon(Icons.send_outlined, size: 15),
                              label: const Text(
                                ' Send mail',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: AppColors.divider,
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: widget.onDelete,
                              icon: const Icon(Icons.delete_outline, size: 15),
                              label: const Text(
                                'Delete',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  String _fmtTotal(Invoice inv) {
    final sym = switch (inv.currency.toUpperCase()) {
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' || 'CNY' => '¥',
      'AED' => 'د.إ ',
      'SAR' => '﷼ ',
      _ => '₹',
    };

    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: sym,
      decimalDigits: 2,
    ).format(inv.total);
  }

  String _fmtInrExact(Invoice inv) {
    if (!inv.hasBackendConversion) return '₹—';
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(inv.totalInInr);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  final IconData icon;
  const _StatusBadge({
    required this.status,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
}

// ══════════════════════════════════════════════════════════════
// CREATE / EDIT INVOICE MODAL
// ══════════════════════════════════════════════════════════════
class _InvoiceFormModal extends StatefulWidget {
  final Invoice? existing;
  final List<SalesUser> salesUsers; // ← was List<String>
  final List<DealOption> deals;
  final void Function(Map<String, dynamic>) onSave;
  const _InvoiceFormModal({
    this.existing,
    required this.salesUsers,
    required this.deals,
    required this.onSave,
  });
  @override
  State<_InvoiceFormModal> createState() => _InvoiceFormModalState();
}

class _InvoiceFormModalState extends State<_InvoiceFormModal> {
  final _priceCtrl = TextEditingController();
  final _taxValCtrl = TextEditingController();
  final _disValCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  SalesUser? _selectedUser; // ← replaces _assignTo + _assignToId
  String _issueDate = '';
  String _dueDate = '';
  String _status = 'Unpaid';
  String _taxType = 'Zero Tax';
  String _discountType = 'No Discount';
  String _currency = '';
  DealOption? _selectedDeal;
  final bool _saving = false;
  //
  String? _assignToError;
  String? _issueDateError;
  String? _dueDateError;
  String? _dealError;
  String? _priceError;
  //
  static const _statuses = ['Paid', 'Unpaid'];
  static const _taxTypes = ['Zero Tax', 'Percentage', 'Fixed Amount'];
  static const _discountTypes = ['No Discount', 'Fixed Amount', 'Percentage'];
  static const _currencies = [
    'INR',
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'CNY',
    'AUD',
    'CAD',
    'CHF',
    'MYR',
    'AED',
    'SGD',
    'ZAR',
    'SAR',
  ];

  bool get _isEdit => widget.existing != null;

  String _sanitizeCurrency(String raw) {
    final trimmed = raw.trim().toUpperCase();

    if (trimmed.isEmpty) return _currency;

    if (_currencies.contains(trimmed)) return trimmed;

    for (final code in _currencies) {
      if (trimmed.contains(code)) return code;
    }

    return _currency;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      // Try to match existing assignTo name back to a SalesUser
      if (e.assignTo.isNotEmpty) {
        try {
          _selectedUser = widget.salesUsers.firstWhere(
            (u) => u.name == e.assignTo,
          );
        } catch (_) {
          // Not found in list — create a stub so the name still displays
          _selectedUser = SalesUser('', e.assignTo);
        }
      }
      _issueDate = e.issueDate;
      _dueDate = e.dueDate;
      _status = e.status;
      _taxType = e.taxType;
      _discountType = e.discountType;
      _currency = _sanitizeCurrency(e.currency);
      _priceCtrl.text = e.price == 0 ? '' : e.price.toStringAsFixed(2);
      _taxValCtrl.text = e.taxValue == 0 ? '' : e.taxValue.toStringAsFixed(2);
      _disValCtrl.text =
          e.discountValue == 0 ? '' : e.discountValue.toStringAsFixed(2);
      _notesCtrl.text = e.notes;
      if (e.dealId.isNotEmpty) {
        try {
          _selectedDeal = widget.deals.firstWhere((d) => d.id == e.dealId);
        } catch (_) {}
      }
    }
  }

  /// [DropdownButton] requires [value] to be one of the [items] instances. After
  /// the cubit refetches deals, the list holds new [DealOption] objects; this
  /// re-binds the selection by [DealOption.id].
  DealOption? get _dealForDropdown {
    final s = _selectedDeal;
    if (s == null) return null;
    for (final d in widget.deals) {
      if (d == s) return d;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant _InvoiceFormModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDeal == null) return;
    final resolved = _dealForDropdown;
    if (resolved == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectedDeal != null &&
            !widget.deals.any((d) => d == _selectedDeal)) {
          setState(() => _selectedDeal = null);
        }
      });
    } else if (!identical(_selectedDeal, resolved)) {
      setState(() => _selectedDeal = resolved);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _taxValCtrl.dispose();
    _disValCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _price => double.tryParse(_priceCtrl.text) ?? 0;
  double get _taxVal => double.tryParse(_taxValCtrl.text) ?? 0;
  double get _disVal => double.tryParse(_disValCtrl.text) ?? 0;

  double get _discountAmount {
    if (_discountType == 'Percentage') return _price * _disVal / 100;
    if (_discountType == 'Fixed Amount') return _disVal;
    return 0;
  }

  double get _taxAmount {
    final base = (_price - _discountAmount).clamp(0, double.infinity);
    if (_taxType == 'Percentage') return base * _taxVal / 100;
    if (_taxType == 'Fixed Amount') return _taxVal;
    return 0;
  }

  double get _total =>
      (_price - _discountAmount + _taxAmount).clamp(0, double.infinity);

  String _fmtCur(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(2)}K';
    return v.toStringAsFixed(2);
  }

  void _save() {
    setState(() {
      _assignToError = _selectedUser == null ? 'Assign To is required' : null;

      _issueDateError = _issueDate.isEmpty ? 'Issue Date is required' : null;

      _dueDateError = _dueDate.isEmpty ? 'Due Date is required' : null;

      _dealError = _selectedDeal == null ? 'Select a Deal' : null;

      _priceError = _priceCtrl.text.trim().isEmpty ? 'Price is required' : null;
    });

    if (_assignToError != null ||
        _issueDateError != null ||
        _dueDateError != null ||
        _dealError != null ||
        _priceError != null) {
      return;
    }

    print("FINAL PRICE => $_price");
    print("FINAL CURRENCY => $_currency");
    print("SELECTED DEAL => ${_selectedDeal?.name}");
    widget.onSave({
      'assignTo': _selectedUser!.name, // display name (for local DB / UI)
      'assignToId': _selectedUser!.id, // ← _id sent to API
      'issueDate': _issueDate,
      'dueDate': _dueDate,
      'status': _status,
      'taxType': _taxType,
      'taxValue': _taxVal,
      'discountType': _discountType,
      'discountValue': _disVal,
      'dealId': _selectedDeal!.id,
      'dealName': _selectedDeal!.name,
      'dealRequirement': _selectedDeal!.requirement,
      // Use the Price field (user may override deal value after selection).
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
      'notes': _notesCtrl.text.trim(),
      'currency': _currency,
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickDate(bool isIssue) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final s = DateFormat('dd MMM yyyy').format(picked);
      setState(() {
        if (isIssue) {
          _issueDate = s;
        } else {
          _dueDate = s;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Build name-only list for the dropdown display ──
    final selectedUserId = _selectedUser?.id;

    final dropdownUsers = widget.salesUsers;
    return DraggableScrollableSheet(
      initialChildSize: 0.97,
      maxChildSize: 0.99,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit Invoice' : 'Create New Invoice',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _isEdit
                              ? 'Update invoice details'
                              : 'Fill in invoice details below',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.divider,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                children: [
                  const _SecHeader(
                    title: 'Basic Information',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 14),

                  const _FieldLabel('Assign To (Sales User)', required: true),
                  const SizedBox(height: 6),

                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _assignToError != null
                            ? AppColors.danger
                            : AppColors.border,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SalesUser>(
                        value: _selectedUser,
                        isExpanded: true,
                        hint: const Text(
                          "Select User",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textHint,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        items: dropdownUsers.map((user) {
                          return DropdownMenuItem<SalesUser>(
                            value: user,
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (user) {
                          setState(() {
                            _selectedUser = user;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_assignToError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3, left: 4),
                      child: Text(
                        _assignToError!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // ── Rest of the form is identical to original ──
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Issue Date', required: true),
                            const SizedBox(height: 6),
                            _DateTile(
                              value:
                                  _issueDate.isEmpty ? 'Pick date' : _issueDate,
                              onTap: () => _pickDate(true),
                            ),
                            if (_issueDateError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Text(
                                  _issueDateError!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Due Date', required: true),
                            const SizedBox(height: 6),
                            _DateTile(
                              value: _dueDate.isEmpty ? 'Pick date' : _dueDate,
                              onTap: () => _pickDate(false),
                            ),
                            if (_dueDateError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Text(
                                  _dueDateError!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const _FieldLabel('Status'),
                  const SizedBox(height: 6),
                  _FullDrop(
                    value: _status,
                    items: _statuses,
                    icon: Icons.info_outline,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  const SizedBox(height: 22),

                  // Row(children: [
                  //   const Expanded(
                  //       child: Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //         const _FieldLabel('Tax Type'),
                  //         const SizedBox(height: 6),
                  //         _FullDrop(
                  //             value: _taxType,
                  //             items: _taxTypes,
                  //             icon: Icons.percent_outlined,
                  //             onChanged: (v) => setState(() {
                  //                   _taxType = v;
                  //                   _taxValCtrl.clear();
                  //                 })),
                  //       ])),
                  //   if (_taxType != 'Zero Tax') ...[
                  //     const SizedBox(width: 12),
                  //     Expanded(
                  //         child: Column(
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //           _FieldLabel(_taxType == 'Percentage'
                  //               ? 'Tax %'
                  //               : 'Tax Amount'),
                  //           const SizedBox(height: 6),
                  //           _tfNum(_taxValCtrl, '0'),
                  //         ])),
                  //   ],
                  // ]),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Discount Type'),
                            const SizedBox(height: 6),
                            _FullDrop(
                              value: _discountType,
                              items: _discountTypes,
                              icon: Icons.local_offer_outlined,
                              onChanged: (v) => setState(() {
                                _discountType = v;
                                _disValCtrl.clear();
                              }),
                            ),
                          ],
                        ),
                      ),
                      if (_discountType != 'No Discount') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(
                                _discountType == 'Percentage'
                                    ? 'Discount %'
                                    : 'Discount Amt',
                              ),
                              const SizedBox(height: 6),
                              _tfNum(_disValCtrl, '0'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),

                  const _SecHeader(
                    title: 'Deal Information',
                    icon: Icons.handshake_outlined,
                  ),
                  const SizedBox(height: 14),

                  const _FieldLabel('Select Deal', required: true),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _dealError != null
                            ? AppColors.danger
                            : AppColors.border,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<DealOption>(
                        value: _dealForDropdown,
                        isExpanded: true,
                        isDense: true,
                        hint: const Row(
                          children: [
                            Icon(
                              Icons.handshake_outlined,
                              size: 14,
                              color: AppColors.textHint,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Select Deal',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        items: widget.deals
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.handshake_outlined,
                                      size: 14,
                                      color: AppColors.textHint,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        d.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (d) => setState(() {
                          _selectedDeal = d;
                          if (d != null) {
                            // Auto-fill from selected deal value, then user can edit manually.
                            print("DEAL VALUE => ${d.value}");
                            print("DEAL CURRENCY => ${d.currency}");

                            _priceCtrl.text = d.value.toStringAsFixed(2);
                            _currency = _sanitizeCurrency(d.currency);

                            print("PRICE CTRL => ${_priceCtrl.text}");
                          }
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_selectedDeal != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deal Value: ${_symFor(_sanitizeCurrency(_selectedDeal?.currency ?? 'INR'))}${(_selectedDeal?.value ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Requirement: ${(_selectedDeal?.requirement ?? '').trim().isEmpty ? '-' : (_selectedDeal?.requirement ?? '')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  const _FieldLabel('Price', required: true),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 90,
                        height: 48,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          _currency,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _tfNum(
                          _priceCtrl,
                          '0.00',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _TotalRow(
                          label: 'Price',
                          value: _price,
                          currency: _currency,
                        ),
                        if (_taxAmount != 0)
                          _TotalRow(
                            label: 'Tax',
                            value: _taxAmount,
                            currency: _currency,
                            isAdd: true,
                          ),
                        if (_discountAmount != 0)
                          _TotalRow(
                            label: 'Discount',
                            value: _discountAmount,
                            currency: _currency,
                            isAdd: false,
                          ),
                        const Divider(height: 16, color: AppColors.divider),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${_symFor(_currency)}${_fmtCur(_total)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  const _FieldLabel('Notes'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Any additional notes or payment instructions…',
                      contentPadding: const EdgeInsets.all(14),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 16),
                          label: Text(
                            _saving
                                ? 'Saving…'
                                : (_isEdit
                                    ? 'Update Invoice'
                                    : 'Create Invoice'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tfNum(
    TextEditingController c,
    String hint, {
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      );
}

class _TotalRow extends StatelessWidget {
  final String label, currency;
  final double value;
  final bool isAdd;
  const _TotalRow({
    required this.label,
    required this.value,
    required this.currency,
    this.isAdd = true,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            Text(
              '${isAdd ? '+' : '-'}${_symFor(currency)}${value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}K' : value.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isAdd ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
        ),
      );
}

class _DateTile extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _DateTile({required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: value.contains('Pick')
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
}

class _FDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final void Function(String) onChanged;
  const _FDrop({
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });
  bool get _active => value != items.first;
  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _active ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: _active ? AppColors.primary : AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isExpanded: true,
            isDense: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: _active ? AppColors.primary : AppColors.textSecondary,
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: _active ? FontWeight.w600 : FontWeight.w400,
              color: _active ? AppColors.primary : AppColors.textSecondary,
            ),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Row(
                      children: [
                        Icon(icon, size: 13, color: AppColors.textHint),
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text(e, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
}

class _FullDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final void Function(String) onChanged;
  const _FullDrop({
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isExpanded: true,
            isDense: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Row(
                      children: [
                        Icon(icon, size: 14, color: AppColors.textHint),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(e, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
}

class _SecHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SecHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          children: required
              ? [
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ]
              : [],
        ),
      );
}

String _symFor(String cur) => switch (cur) {
      'INR' => '₹',
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      'CNY' => '¥',
      'AUD' => 'A\$',
      'CAD' => 'C\$',
      'CHF' => 'CHF',
      'MYR' => 'RM',
      'AED' => 'د.إ',
      'SGD' => 'S\$',
      'ZAR' => 'R',
      'SAR' => '﷼',
      _ => '₹',
    };
