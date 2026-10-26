// lib/screen/invoice/ui/item_breakdown_section.dart
//
// "Item Breakdown" body for the invoice form — optional itemised lines
// (name, HSN/SAC, quantity, amount) that must add up to the deal amount.
// The form owns the rows; this widget only renders them and reports edits.

import 'package:crm_app/screen/invoice/modal/invoice_model.dart'
    show InvoiceBreakdownItem;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const kQuantityLabels = ['Hours', 'Qty', 'Days'];

/// Editable state for one breakdown line in the invoice form.
class InvoiceBreakdownRow {
  final String id;
  final labelCtrl = TextEditingController();
  final hsnCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  InvoiceBreakdownRow({this.id = ''});

  factory InvoiceBreakdownRow.fromItem(InvoiceBreakdownItem item) {
    final row = InvoiceBreakdownRow(id: item.id);
    row.labelCtrl.text = item.label;
    row.hsnCtrl.text = item.hsnSac;
    row.qtyCtrl.text = item.quantity == 0 ? '' : _trimNum(item.quantity);
    row.amountCtrl.text = item.amount == 0 ? '' : _trimNum(item.amount);
    return row;
  }

  String get label => labelCtrl.text.trim();
  String get hsnSac => hsnCtrl.text.trim();
  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get amount => double.tryParse(amountCtrl.text.trim()) ?? 0;

  /// Nothing typed at all — dropped on save instead of failing validation.
  bool get isBlank =>
      label.isEmpty && hsnSac.isEmpty && quantity == 0 && amount == 0;
  bool get isComplete => label.isNotEmpty && amount > 0;

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) '_id': id,
        'label': label,
        'amount': amount,
        'hsnSac': hsnSac,
        'quantity': quantity == 0 ? 1 : quantity,
      };

  void dispose() {
    labelCtrl.dispose();
    hsnCtrl.dispose();
    qtyCtrl.dispose();
    amountCtrl.dispose();
  }
}

/// Sum of all non-blank rows.
double breakdownTotal(List<InvoiceBreakdownRow> rows) =>
    rows.where((r) => !r.isBlank).fold(0.0, (s, r) => s + r.amount);

bool breakdownBalanced(List<InvoiceBreakdownRow> rows, double dealAmount) =>
    dealAmount > 0 && (breakdownTotal(rows) - dealAmount).abs() < 0.005;

String _trimNum(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

String _money(String sym, double v) =>
    '$sym${NumberFormat('#,##,##0.00', 'en_IN').format(v)}';

/// Header pill for the accordion: "3 items", green once balanced.
class BreakdownCountPill extends StatelessWidget {
  final List<InvoiceBreakdownRow> rows;
  final double dealAmount;
  const BreakdownCountPill({
    super.key,
    required this.rows,
    required this.dealAmount,
  });

  @override
  Widget build(BuildContext context) {
    final count = rows.where((r) => !r.isBlank).length;
    if (count == 0) return const SizedBox.shrink();
    final ok = breakdownBalanced(rows, dealAmount);
    return _Pill(
      text: '$count item${count == 1 ? '' : 's'}',
      fg: ok ? AppColors.success : AppColors.warning,
      bg: ok ? AppColors.successLight : AppColors.warningLight,
    );
  }
}

class ItemBreakdownSection extends StatefulWidget {
  final List<InvoiceBreakdownRow> rows;
  final String quantityLabel;

  /// Items must add up to exactly this; amounts are capped so the total
  /// can never go over it.
  final double dealAmount;
  final String currencyCode;
  final String currencySymbol;
  final String? error;
  final VoidCallback onAdd;
  final ValueChanged<InvoiceBreakdownRow> onRemove;
  final ValueChanged<String> onQuantityLabelChanged;

  /// Any field edit — lets the form rebuild totals and the header pill.
  final VoidCallback onChanged;

  const ItemBreakdownSection({
    super.key,
    required this.rows,
    required this.quantityLabel,
    required this.dealAmount,
    required this.currencyCode,
    required this.currencySymbol,
    required this.onAdd,
    required this.onRemove,
    required this.onQuantityLabelChanged,
    required this.onChanged,
    this.error,
  });

  @override
  State<ItemBreakdownSection> createState() => _ItemBreakdownSectionState();
}

class _ItemBreakdownSectionState extends State<ItemBreakdownSection> {
  InvoiceBreakdownRow? _open;

  List<String> get _labels => [
        ...kQuantityLabels,
        if (!kQuantityLabels.contains(widget.quantityLabel)) widget.quantityLabel,
      ];

  void _add() {
    widget.onAdd();
    setState(() => _open = widget.rows.last);
  }

  /// Most this row can take without the items total passing the deal amount.
  double _maxFor(InvoiceBreakdownRow row) {
    final others = breakdownTotal(widget.rows) - (row.isBlank ? 0 : row.amount);
    return (widget.dealAmount - others).clamp(0, double.infinity).toDouble();
  }

  /// Pulls an over-typed amount back down to what's left of the deal amount.
  void _capAmount(InvoiceBreakdownRow row) {
    if (widget.dealAmount <= 0) return;
    final max = _maxFor(row);
    if (row.amount <= max + 0.005) return;
    final text = max == 0 ? '' : _trimNum(max);
    row.amountCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Optional. Split the deal amount into parts — items must add up '
          'to the deal amount exactly.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quantity shows',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Segmented(
              options: _labels,
              value: widget.quantityLabel,
              onChanged: widget.onQuantityLabelChanged,
            ),
          ],
        ),
        if (rows.isNotEmpty) const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++) ...[
          _ItemTile(
            index: i + 1,
            row: rows[i],
            open: identical(_open, rows[i]),
            quantityLabel: widget.quantityLabel,
            currencyCode: widget.currencyCode,
            currencySymbol: widget.currencySymbol,
            onToggle: () => setState(
              () => _open = identical(_open, rows[i]) ? null : rows[i],
            ),
            onDone: () => setState(() => _open = null),
            onRemove: () {
              final row = rows[i];
              if (identical(_open, row)) _open = null;
              widget.onRemove(row);
            },
            onChanged: widget.onChanged,
            maxAmount: widget.dealAmount > 0 ? _maxFor(rows[i]) : null,
            onAmountChanged: () => _capAmount(rows[i]),
          ),
          if (i < rows.length - 1) const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Add Item',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
        ),
        if (rows.any((r) => !r.isBlank))
          _Summary(
            total: breakdownTotal(rows),
            dealAmount: widget.dealAmount,
            symbol: widget.currencySymbol,
          ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text(
              widget.error!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.danger,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Quantity unit picker (Hours / Qty / Days) ─────────────────────
class _Segmented extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _Segmented({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              GestureDetector(
                onTap: () => onChanged(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: o == value ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: o == value
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    o,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: o == value
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

// ── One collapsible item ──────────────────────────────────────────
class _ItemTile extends StatelessWidget {
  final int index;
  final InvoiceBreakdownRow row;
  final bool open;
  final String quantityLabel;
  final String currencyCode;
  final String currencySymbol;
  final VoidCallback onToggle;
  final VoidCallback onDone;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  /// Most this item's amount can be (null when there's no deal amount).
  final double? maxAmount;
  final VoidCallback onAmountChanged;

  const _ItemTile({
    required this.maxAmount,
    required this.onAmountChanged,
    required this.index,
    required this.row,
    required this.open,
    required this.quantityLabel,
    required this.currencyCode,
    required this.currencySymbol,
    required this.onToggle,
    required this.onDone,
    required this.onRemove,
    required this.onChanged,
  });

  /// "8 hrs", "1 day", "Qty 2".
  String _qtyText(double q) {
    final n = _trimNum(q);
    return switch (quantityLabel) {
      'Hours' => '$n ${q == 1 ? 'hr' : 'hrs'}',
      'Days' => '$n ${q == 1 ? 'day' : 'days'}',
      _ => '$quantityLabel $n',
    };
  }

  String get _subtitle {
    if (!row.isComplete) return open ? 'Fill in details' : 'Tap to fill';
    final parts = <String>[
      if (row.hsnSac.isNotEmpty)
        '${row.hsnSac.startsWith('99') ? 'SAC' : 'HSN'} ${row.hsnSac}',
      if (row.quantity > 0) _qtyText(row.quantity),
    ];
    return parts.isEmpty ? 'No HSN / SAC' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final amount = row.amount;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: open
              ? AppColors.primary.withOpacity(0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: open ? AppColors.primaryLight : AppColors.divider,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: open
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.label.isEmpty ? 'Untitled item' : row.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: row.label.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
                            fontStyle: row.label.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: row.label.isEmpty
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (!open && !row.isComplete) ...[
                              const SizedBox(width: 4),
                              const _Pill(
                                text: 'Incomplete',
                                fg: AppColors.warning,
                                bg: AppColors.warningLight,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _money(currencySymbol, amount)
                        .replaceAll(RegExp(r'\.00$'), ''),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: amount > 0 ? FontWeight.w700 : FontWeight.w500,
                      color: amount > 0
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: open ? _editor() : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _editor() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(
              'Item name',
              row.labelCtrl,
              hint: 'e.g. Frontend Development',
              capitalization: TextCapitalization.sentences,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    'HSN / SAC',
                    row.hsnCtrl,
                    hint: '998314',
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    quantityLabel,
                    row.qtyCtrl,
                    hint: '0',
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true),
                    formatters: [_decimal],
                  ),
                ),
              ],
            ),
            _field(
              'Amount',
              row.amountCtrl,
              hint: '0.00',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              formatters: [_decimal],
              prefix: currencyCode,
              helper: maxAmount == null
                  ? null
                  : 'Up to ${_money(currencySymbol, maxAmount!)} available',
              onFieldChanged: () {
                onAmountChanged();
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text(
                    'Remove',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  static final _decimal =
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.none,
    String? prefix,
    String? helper,
    VoidCallback? onFieldChanged,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            inputFormatters: formatters,
            textCapitalization: capitalization,
            onChanged: (_) => (onFieldChanged ?? onChanged)(),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              helperText: helper,
              helperStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              hintStyle:
                  const TextStyle(fontSize: 14, color: AppColors.textHint),
              prefixIcon: prefix == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 12, right: 6),
                      child: Text(
                        prefix,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: AppColors.surface,
              border: border(AppColors.border),
              enabledBorder: border(AppColors.border),
              focusedBorder: border(AppColors.primary, 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Items total vs price ──────────────────────────────────────────
class _Summary extends StatelessWidget {
  final double total;
  final double dealAmount;
  final String symbol;
  const _Summary({
    required this.total,
    required this.dealAmount,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final price = dealAmount;
    final diff = price - total;
    final balanced = price > 0 && diff.abs() < 0.005;
    final over = diff < -0.005;
    final color = balanced
        ? AppColors.success
        : over
            ? AppColors.danger
            : AppColors.warning;
    final progress = price > 0 ? (total / price).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Items / Deal amount',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _money(symbol, total),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${_money(symbol, price)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          _Pill(
            text: balanced
                ? '✓ Fully allocated'
                : over
                    ? '${_money(symbol, -diff)} over the deal amount'
                    : '${_money(symbol, diff)} still to allocate',
            fg: color,
            bg: balanced
                ? AppColors.successLight
                : over
                    ? AppColors.dangerLight
                    : AppColors.warningLight,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final bool compact;
  const _Pill({
    required this.text,
    required this.fg,
    required this.bg,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1)
            : const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      );
}
