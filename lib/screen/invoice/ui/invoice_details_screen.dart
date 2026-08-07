import 'package:crm_app/screen/currency/currency_service.dart';
import 'package:crm_app/screen/invoice/modal/invoice_model.dart' show Invoice;
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
        Color;
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

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;

    final subtotal = CurrencyService.convert(
  inv.price,
  inv.currency,
);

final tax = CurrencyService.convert(
  inv.taxValue,
  inv.currency,
);

final discount = CurrencyService.convert(
  inv.discountValue,
  inv.currency,
);

final total = CurrencyService.convert(
  inv.total,
  inv.currency,
);

final paid = CurrencyService.convert(
  inv.amountPaid,
  inv.currency,
);

final due = CurrencyService.convert(
  inv.balanceDue,
  inv.currency,
);

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
                          _info("Client Name", inv.assignTo),
                          _info("Company", inv.dealName),
                          _info("Billing Address", inv.billingAddress),
                         _info("Client Tax ID", inv.clientTaxId),
                         _info("PO Number", inv.poNumber),
                        ]),
                        const SizedBox(height: 18),
                        _sectionTitle("Invoice Information"),
                        _infoCard([
                          _info(
                            "Subtotal",
                            formatCurrency(subtotal, inv.currency),
                          ),
                          _info(
                            "Tax",
                            formatCurrency(tax, inv.currency),
                          ),
                          _info(
                            "Discount",
                            formatCurrency(discount, inv.currency),
                          ),
                          _info(
                            "Total",
                            formatCurrency(total, inv.currency),
                          ),
                          _info(
  "Amount Paid",
  formatCurrency(paid, inv.currency),
  valueColor: AppColors.success,
),

_info(
  "Balance Due",
  formatCurrency(due, inv.currency),
  valueColor: AppColors.danger,
),
                          _info("Issue Date", _fmtDate(inv.issueDate)),
                          _info("Due Date", _fmtDate(inv.dueDate)),
                        ]),
                      ],
                    ),

                    /// ACTIVITY TAB
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _sectionTitle("Activity Timeline"),
                        const SizedBox(height: 6),
                        const Text(
                          "Updates and changes for this invoice",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _timelineCard(
                          "Invoice created",
                          _fmtDateTime(inv.createdAt.toString()),
                        ),
                        _timelineCard(
                          "Invoice updated",
                          _fmtDateTime(inv.updatedAt.toString()),
                        ),
                      ],
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

  String _fmtDateTime(String raw) {
    if (raw.isEmpty) return "-";

    final dt = DateTime.tryParse(raw);

    if (dt == null) return raw;

    return DateFormat(
      "d/M/yyyy, h:mm:ss a",
    ).format(dt.toLocal());
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
  Widget _timelineCard(String title, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
