import 'package:crm_app/screen/invoice/modal/invoice_model.dart'
    show Invoice, InvoiceBreakdownItem;
import 'package:crm_app/shareWidgets/actitvity_timeline_ui.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart'
    show
        StatefulWidget,
        SingleTickerProviderStateMixin,
        TabController,
        State,
        BuildContext,
        Widget,
        BoxDecoration,
        EdgeInsets,
        Expanded,
        Icon,
        Text,
        SizedBox,
        TextStyle,
        BorderRadius,
        Radius,
        Container,
        FontWeight,
        Icons,
        Navigator,
        IconButton,
        Row,
        Padding,
        Tab,
        TabBar,
        ListView,
        TabBarView,
        Column,
        DraggableScrollableSheet,
        CrossAxisAlignment,
        Spacer,
        Color,
        Border,
        Divider;
import 'package:intl/intl.dart';

class InvoiceDetailsModal extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailsModal({super.key, 
    required this.invoice,
  });

  @override
  State<InvoiceDetailsModal> createState() => InvoiceDetailsModalState();
}

class InvoiceDetailsModalState extends State<InvoiceDetailsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  double convertFromInr(double amountInInr, double rate) {
  return amountInInr * rate;
}
String formatCurrency(double amount, String currency) {
  final symbol = switch (currency.toUpperCase()) {
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
    symbol: symbol,
    decimalDigits: 2,
  ).format(amount);
}

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmtDate(String raw) {
    if (raw.isEmpty) return "-";
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat("dd MMM yyyy").format(dt.toLocal());
  }

  /// "Tax" + "Percentage"/28 -> "Tax (28%)"; "Fixed Amount" -> "Tax (Fixed)";
  /// anything else (Zero Tax / No Discount) -> just the base label.
  String _rateLabel(String base, String type, double value) {
    if (type == 'Percentage') {
      final rate =
          value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
      return '$base ($rate%)';
    }
    if (type == 'Fixed Amount') {
      return '$base (Fixed)';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;

// Every figure in this sheet is shown in the invoice's own currency
// (inv.currency) — the currency it was actually issued and paid in.
final currency = inv.currency;

final subtotal = inv.price;
final tax = inv.taxAmount;
final discount = inv.discountAmount;
final total =
    (subtotal - discount + tax).clamp(0, double.infinity).toDouble();
final paid = inv.amountPaid;
// NOTE: inv.balanceDue subtracts amountPaid (original currency) from
// totalPreferredCurrencyValue (preferred currency), mixing currencies
// when they differ — so it's recomputed here from the original-currency
// total instead.
final due = (total - paid).clamp(0, double.infinity).toDouble();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.60,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              /// Header

              /// Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: "Details"),
                  Tab(text: "Activity"),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    /// DETAILS TAB
                    ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      children: [
_sectionTitle("Client Information"),
_infoCard([
  _info(
    "Client Name",
    inv.dealName.isNotEmpty ? inv.dealName : '-',
  ),
  _info(
    "Company",
    inv.companyName.isNotEmpty ? inv.companyName : '-',
  ),
  _info(
    "Billing Address",
    // "-" is what the API stores when none was entered.
    inv.billingAddress.trim().isNotEmpty && inv.billingAddress.trim() != '-'
        ? inv.billingAddress.trim()
        : '-',
  ),
]),
_sectionDivider(),
_sectionTitle("Invoice Information"),
_infoCard([
  _info(
    "Subtotal",
    formatCurrency(
      subtotal,
      currency,
    ),
  ),

  _info(
    _rateLabel(
      "Tax",
      inv.taxType,
      inv.taxValue,
    ),
    formatCurrency(
      tax,
      currency,
    ),
  ),

  _info(
    _rateLabel(
      "Discount",
      inv.discountType,
      inv.discountValue,
    ),
    formatCurrency(
      discount,
      currency,
    ),
  ),

  _info(
    "Total",
    formatCurrency(
      total,
      currency,
    ),
  ),

  _info(
    "Amount Paid",
    formatCurrency(
      paid,
      currency,
    ),
    valueColor: AppColors.success,
  ),

  _info(
    "Balance Due",
    formatCurrency(
      due,
      currency,
    ),
    valueColor: AppColors.danger,
  ),

  _info(
    "Issue Date",
    _fmtDate(inv.issueDate),
  ),

  _info(
    "Due Date",
    _fmtDate(inv.dueDate),
  ),
]),
// Item Breakdown last — built from the invoice's own lines; hidden
// (with its divider) when there are none.
if (inv.breakdown.isNotEmpty) ...[
  _sectionDivider(),
  _sectionTitle("Item Breakdown"),
  _breakdownCard(inv.breakdown, currency),
],
const SizedBox(height: 16),
                      ],
                    ),

                    /// ACTIVITY TAB — shared timeline, same as leads/deals
                    ActivityTimeline(
                      controller: controller,
                      subtitle: 'Recent activity and updates for this invoice',
                      emptyMessage: 'No activity yet',
                      activities: _activities(inv),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Created + each status change (or a single "updated" entry when there
  /// is no history), newest first like the lead/deal timelines.
  List<ActivityTimelineItem> _activities(Invoice inv) {
    String statusLabel(String s) => s
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');

    // createdBy / changedBy may be bare ObjectIds — only show real names.
    String? person(String raw) {
      final v = raw.trim();
      if (v.isEmpty || RegExp(r'^[a-f0-9]{24}$').hasMatch(v)) return null;
      return v;
    }

    final items = <ActivityTimelineItem>[
      ActivityTimelineItem(
        type: 'invoice_created',
        title: 'Invoice Created',
        description: formatCurrency(inv.price, inv.currency),
        performedBy: person(inv.createdBy),
        timestamp: inv.createdAt,
      ),
      if (inv.statusHistory.isEmpty)
        ActivityTimelineItem(
          type: 'invoice_updated',
          title: 'Invoice Updated',
          description: '',
          performedBy: person(inv.lastUpdatedBy),
          timestamp: inv.updatedAt,
        )
      else
        for (final h in inv.statusHistory)
          ActivityTimelineItem(
            type: 'status_changed',
            title: 'Status changed to ${statusLabel(h.status)}',
            description: h.amountPaid > 0
                ? '${formatCurrency(h.amountPaid, inv.currency)} paid'
                : '',
            performedBy: person(h.changedBy),
            timestamp: h.changedAt,
          ),
    ];
    items.sort((a, b) => (b.timestamp ?? DateTime(0))
        .compareTo(a.timestamp ?? DateTime(0)));
    return items;
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // AppColors.divider (#F1F5F9) vanishes on the sheet's #F8FAFC
  // background, so section breaks use a darker slate line.
  Widget _sectionDivider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFCBD5E1)),
      );

  /// Item Breakdown, phone-friendly: instead of the web's 4-column table,
  /// each line stacks name + amount over "HSN/SAC · days", then Subtotal.
  Widget _breakdownCard(List<InvoiceBreakdownItem> items, String currency) {
    String num(double v) =>
        v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.amount);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.label.isEmpty ? '-' : item.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatCurrency(item.amount, currency),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      'HSN/SAC: ${item.hsnSac.trim().isEmpty ? '-' : item.hsnSac.trim()}',
                      '${num(item.quantity)} ${item.quantity == 1 ? 'day' : 'days'}',
                    ].join('  ·  '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  formatCurrency(subtotal, currency),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _info(
  String title,
  String value, {
  Color? valueColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      // Multi-line values (e.g. billing address) keep the label at the top.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
}
