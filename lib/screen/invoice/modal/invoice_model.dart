import 'package:intl/intl.dart';

class Invoice {
  final String id,
      invoiceNo,
      assignTo,
      issueDate,
      dueDate,
      status,
      taxType,
      discountType,
      dealId,
      dealName,
      notes,
      currency;
  final double price, taxValue, discountValue;
  final double? inrAmount, exchangeRate;
  final DateTime createdAt;
  final bool isLocal;

  const Invoice({
    required this.id,
    required this.invoiceNo,
    required this.assignTo,
    required this.issueDate,
    required this.dueDate,
    required this.status,
    required this.taxType,
    required this.taxValue,
    required this.discountType,
    required this.discountValue,
    required this.dealId,
    required this.dealName,
    required this.notes,
    required this.currency,
    required this.price,
    this.inrAmount,
    this.exchangeRate,
    required this.createdAt,
    this.isLocal = false,
  });

  // ── UI display values (Title case) ──────────────────────────────
  // API stores lowercase ("paid","unpaid") and "fixed"/"percentage"
  // We normalise on parse so the rest of the app never sees raw API strings.

  /// "paid" → "Paid", "unpaid" → "Unpaid", already cased → unchanged
  static String normaliseStatus(String s) {
    switch (s.toLowerCase().trim()) {
      case 'paid':
        return 'Paid';
      case 'unpaid':
        return 'Unpaid';
      default:
        return s.isEmpty ? 'Unpaid' : s;
    }
  }

  /// "fixed" → "Fixed Amount", "percentage" → "Percentage",
  /// "none"/"zero"/"" → fallback
  static String _normaliseTaxType(String s, String fallback) {
    switch (s.toLowerCase().trim()) {
      case 'percentage':
        return 'Percentage';
      case 'fixed':
        return 'Fixed Amount';
      case 'none':
      case 'zero':
      case 'no discount':
      case 'nodiscount':
      case '':
        return fallback;
      default:
        return s;
    }
  }

  /// For [Percentage], prefer explicit rate fields; if API only returns a computed
  /// amount in [amountKeys], convert it back to a percentage rate.
  static double _parseTaxOrDiscountValue({
    required Map<String, dynamic> j,
    required String type,
    required double price,
    required List<String> valueKeys,
    required List<String> amountKeys,
  }) {
    if (type != 'Percentage' && type != 'Fixed Amount') return 0;

    for (final k in valueKeys) {
      final v = _d(j[k]);
      if (v != null) return v;
    }

    for (final k in amountKeys) {
      final v = _d(j[k]);
      if (v == null || v == 0) continue;
      if (type == 'Percentage' && price > 0) {
        // API may return computed amount (e.g. 500) instead of rate (e.g. 10).
        if (v > 100 || v >= price * 0.5) {
          return (v / price * 100).clamp(0, 100);
        }
        return v;
      }
      return v;
    }

    return 0;
  }

  // ── Computed totals (tax on amount after discount, per API) ─────
  double get discountAmount {
    if (discountType == 'Percentage') return price * discountValue / 100;
    if (discountType == 'Fixed Amount') return discountValue;
    return 0;
  }

  double get taxAmount {
    final base = (price - discountAmount).clamp(0, double.infinity);
    if (taxType == 'Percentage') return base * taxValue / 100;
    if (taxType == 'Fixed Amount') return taxValue;
    return 0;
  }

  double get total =>
      (price - discountAmount + taxAmount).clamp(0, double.infinity);

  double get totalInInr {
    final ccy = currency.toUpperCase().trim();
    if (ccy == 'INR') return total;
    if (exchangeRate != null && exchangeRate! > 0) return total * exchangeRate!;
    if (inrAmount != null && inrAmount! > 0) return inrAmount!;
    return 0;
  }

  bool get hasBackendConversion =>
      (exchangeRate != null && exchangeRate! > 0) ||
      (inrAmount != null && inrAmount! > 0) ||
      currency.toUpperCase().trim() == 'INR';

  // ── Helpers ─────────────────────────────────────────────────────
  static String _s(dynamic v, [String fb = '']) =>
      v == null ? fb : v.toString();
  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', ''));
  }

  // ── fromMap (local SQLite) ───────────────────────────────────────
  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
        id: _s(m['id']),
        invoiceNo: _s(m['invoiceNo'], 'INV-???'),
        assignTo: _s(m['assignTo']),
        issueDate: _s(m['issueDate']),
        dueDate: _s(m['dueDate']),
        status: normaliseStatus(_s(m['status'], 'Unpaid')),
        taxType: _s(m['taxType'], 'Zero Tax'),
        taxValue: _d(m['taxValue']) ?? 0,
        discountType: _s(m['discountType'], 'No Discount'),
        discountValue: _d(m['discountValue']) ?? 0,
        dealId: _s(m['dealId']),
        dealName: _s(m['dealName']),
        notes: _s(m['notes']),
        currency: _s(m['currency'], 'INR'),
        price: _d(m['price']) ?? 0,
        inrAmount: _d(m['inrAmount']),
        exchangeRate: _d(m['exchangeRate']),
        createdAt: m['createdAt'] != null
            ? DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        isLocal: (m['isLocal'] as int? ?? 0) == 1,
      );

  // ── fromJson (API response) ──────────────────────────────────────
  factory Invoice.fromJson(Map<String, dynamic> j) {
    // assignTo — may be missing, a string, or an object
    String assignTo = '';
    final rawUser = j['assignedTo'] ?? j['assignTo'] ?? j['assigned_to'];
    if (rawUser is Map) {
      final fn = rawUser['firstName']?.toString().trim() ?? '';
      final ln = rawUser['lastName']?.toString().trim() ?? '';
      assignTo = '$fn $ln'.trim();
    } else if (rawUser != null) {
      assignTo = rawUser.toString().trim();
    }

    // deal — from items[0].deal or top-level dealId/dealName
    String dealId = '';
    String dealName = '';
    final items = j['items'];
    if (items is List && items.isNotEmpty && items.first is Map) {
      final firstItem = items.first as Map;
      final rawDeal = firstItem['deal'];
      if (rawDeal is Map) {
        dealId = _s(rawDeal['_id'] ?? rawDeal['id']);
        dealName =
            _s(rawDeal['dealName'] ?? rawDeal['name'] ?? rawDeal['title']);
      } else if (rawDeal != null) {
        dealId = rawDeal.toString();
      }
    }
    // fallback to top-level deal fields
    if (dealId.isEmpty) {
      final rawDeal = j['deal'] ?? j['dealInfo'];
      if (rawDeal is Map) {
        dealId = _s(rawDeal['_id'] ?? rawDeal['id']);
        dealName =
            _s(rawDeal['dealName'] ?? rawDeal['name'] ?? rawDeal['title']);
      } else {
        dealId = _s(j['dealId'] ?? j['deal_id'] ?? '');
        dealName = _s(j['dealName'] ?? j['deal_name'] ?? '');
      }
    }

    // price — prefer concrete item amount first, then invoice totals.
    // This handles APIs that return total="0" while item.amount carries the real value.
    double price = 0;
    if (items is List && items.isNotEmpty && items.first is Map) {
      final first = items.first as Map;
      final v = first['amount'] ?? first['price'];
      price = _d(v) ?? 0;
    }
    if (price == 0) {
      for (final k in [
        'totalAmount',
        'subtotal',
        'amount',
        'price',
        'invoiceAmount',
        'total'
      ]) {
        final v = _d(j[k]);
        if (v != null && v != 0) {
          price = v;
          break;
        }
      }
    }

    // total — API sends total as a String e.g. "420", "0"
    // We recompute locally from price+tax-discount, but read server total as fallback
    double serverTotal = 0;
    final rawTotal = j['total'];
    if (rawTotal != null) serverTotal = _d(rawTotal) ?? 0;
    // If price is still 0 but server total is set, use server total as price
    if (price == 0 && serverTotal > 0) price = serverTotal;

    // taxType / discountType — API sends "fixed" / "percentage"
    final taxType = _normaliseTaxType(
      _s(j['taxType'] ?? j['tax_type']),
      'Zero Tax',
    );
    final discountType = _normaliseTaxType(
      _s(j['discountType'] ?? j['discount_type']),
      'No Discount',
    );

    // tax / discount values — parse type first so % rate is not confused with amount
    final taxVal = _parseTaxOrDiscountValue(
      j: j,
      type: taxType,
      price: price,
      valueKeys: ['taxValue', 'tax_value'],
      amountKeys: ['tax'],
    );
    final disVal = _parseTaxOrDiscountValue(
      j: j,
      type: discountType,
      price: price,
      valueKeys: ['discountValue', 'discount_value'],
      amountKeys: ['discount'],
    );

    // ── invoicenumber — API uses lowercase 'invoicenumber' ──
    final invoiceNo = _s(
      j['invoicenumber'] ?? // ← real API field  ✓
          j['invoiceNumber'] ??
          j['invoiceNo'] ??
          j['invoice_no'] ??
          j['number'] ??
          j['invoiceId'],
      'INV-???',
    );

    final currency = _s(j['currency'] ?? j['currencyCode'], 'INR');
    final inrAmount = _d(j['inrAmount']);
    final exchangeRate = _d(j['exchangeRate']);

    return Invoice(
      id: _s(j['_id'] ?? j['id']),
      invoiceNo: invoiceNo,
      assignTo: assignTo,
      issueDate: _fmtRawDate(
          j['issueDate'] ?? j['issue_date'] ?? j['createdAt'] ?? ''),
      dueDate: _fmtRawDate(j['dueDate'] ?? j['due_date'] ?? ''),
      // ← normalise status: "paid" → "Paid", "unpaid" → "Unpaid"
      status: normaliseStatus(_s(j['status'] ?? j['paymentStatus'], 'Unpaid')),
      taxType: taxType,
      taxValue: taxVal,
      discountType: discountType,
      discountValue: disVal,
      dealId: dealId,
      dealName: dealName,
      // ← API uses "note" not "notes"
      notes: _s(j['notes'] ?? j['note'] ?? j['description']),
      currency: currency,
      price: price,
      inrAmount: inrAmount,
      exchangeRate: exchangeRate,
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isLocal: false,
    );
  }

  Map<String, dynamic> toSaveMap() => {
        'assignTo': assignTo,
        'issueDate': issueDate,
        'dueDate': dueDate,
        'status': status,
        'taxType': taxType,
        'taxValue': taxValue,
        'discountType': discountType,
        'discountValue': discountValue,
        'dealId': dealId,
        'dealName': dealName,
        'price': price,
        'notes': notes,
        'currency': currency,
      };

  Invoice copyWith({
    String? assignTo,
    String? issueDate,
    String? dueDate,
    String? status,
    String? taxType,
    double? taxValue,
    String? discountType,
    double? discountValue,
    String? dealId,
    String? dealName,
    double? price,
    String? notes,
    String? currency,
    double? inrAmount,
    double? exchangeRate,
    bool? isLocal,
  }) =>
      Invoice(
        id: id,
        invoiceNo: invoiceNo,
        createdAt: createdAt,
        isLocal: isLocal ?? this.isLocal,
        assignTo: assignTo ?? this.assignTo,
        issueDate: issueDate ?? this.issueDate,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        taxType: taxType ?? this.taxType,
        taxValue: taxValue ?? this.taxValue,
        discountType: discountType ?? this.discountType,
        discountValue: discountValue ?? this.discountValue,
        dealId: dealId ?? this.dealId,
        dealName: dealName ?? this.dealName,
        price: price ?? this.price,
        notes: notes ?? this.notes,
        currency: currency ?? this.currency,
        inrAmount: inrAmount ?? this.inrAmount,
        exchangeRate: exchangeRate ?? this.exchangeRate,
      );
}

String _fmtRawDate(dynamic v) {
  if (v == null) return '';
  final s = v.toString().trim();
  if (s.isEmpty) return '';
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  return DateFormat('dd MMM yyyy').format(dt.toLocal());
}
