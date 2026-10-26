import 'package:intl/intl.dart';

/// One entry from the API's `statusHistory` — tracks each status change
/// (e.g. unpaid → partially_paid) along with who made it and when.
class InvoiceStatusHistoryItem {
  final String id;
  final String status;
  final double amountPaid;
  final DateTime? changedAt;
  final String changedBy;

  const InvoiceStatusHistoryItem({
    required this.id,
    required this.status,
    required this.amountPaid,
    this.changedAt,
    required this.changedBy,
  });

  factory InvoiceStatusHistoryItem.fromJson(Map<String, dynamic> j) =>
      InvoiceStatusHistoryItem(
        id: (j['_id'] ?? '').toString(),
        status: Invoice.normaliseStatus((j['status'] ?? '').toString()),
        amountPaid: (j['amountPaid'] is num)
            ? (j['amountPaid'] as num).toDouble()
            : double.tryParse((j['amountPaid'] ?? '0').toString()) ?? 0,
        changedAt: j['changedAt'] != null
            ? DateTime.tryParse(j['changedAt'].toString())
            : null,
        changedBy: (j['changedBy'] ?? '').toString(),
      );
}

/// One line from the API's `breakdown` — itemised lines (label, HSN/SAC,
/// quantity, amount) that make up the invoice subtotal.
class InvoiceBreakdownItem {
  final String id;
  final String label;
  final double amount;
  final String hsnSac;
  final double quantity;

  const InvoiceBreakdownItem({
    this.id = '',
    required this.label,
    required this.amount,
    this.hsnSac = '',
    this.quantity = 1,
  });

  factory InvoiceBreakdownItem.fromJson(Map<String, dynamic> j) =>
      InvoiceBreakdownItem(
        id: (j['_id'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        amount: Invoice._d(j['amount']) ?? 0,
        hsnSac: (j['hsnSac'] ?? '').toString(),
        quantity: Invoice._d(j['quantity']) ?? 1,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) '_id': id,
        'label': label,
        'amount': amount,
        'hsnSac': hsnSac,
        'quantity': quantity,
      };
}

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
  final DateTime updatedAt;
  final bool isLocal;
  final double amountPaid;
  final DateTime? paidAt;
  final DateTime? emailSentAt;

  final String preferredCurrency;
  final double preferredCurrencyValue;

  final String billingAddress;
  final String clientTaxId;
  final String poNumber;
  final String clientState;

  final List<dynamic> customFields;

  // Deal information
  final String dealPhone;
  final String dealEmail;
  final String companyName;
  final String dealAddress;
  final String dealCountry;
  final String dealValue;
  final String dealStage;

  final List<InvoiceStatusHistoryItem> statusHistory;
  final DateTime? lastReminderAt;
  final double totalPreferredCurrencyValue;
  final String createdBy;
  final String lastUpdatedBy;

  // Assignee identity (assignTo._id / assignTo.email) — [assignTo] holds
  // only the display name.
  final String assignToId;
  final String assignToEmail;

  // Server-computed amounts, all in the invoice's own [currency].
  // `total` arrives as a String (e.g. "11500").
  final double apiSubtotal;
  final double apiDiscount;
  final double apiTax;
  final double apiTotal;

  // Itemised lines and the column label used for quantity ("Qty", "Hours").
  final List<InvoiceBreakdownItem> breakdown;
  final String quantityLabel;

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
    required this.updatedAt,
    this.isLocal = false,
    required this.amountPaid,
    this.paidAt,
    this.emailSentAt,
    required this.preferredCurrency,
    required this.preferredCurrencyValue,
    required this.billingAddress,
    required this.clientTaxId,
    required this.poNumber,
    required this.clientState,
    required this.customFields,
    required this.dealPhone,
    required this.dealEmail,
    required this.companyName,
    required this.dealAddress,
    required this.dealCountry,
    this.dealValue = '',
    this.dealStage = '',
    this.statusHistory = const [],
    this.lastReminderAt,
    this.totalPreferredCurrencyValue = 0,
    this.createdBy = '',
    this.lastUpdatedBy = '',
    this.assignToId = '',
    this.assignToEmail = '',
    this.apiSubtotal = 0,
    this.apiDiscount = 0,
    this.apiTax = 0,
    this.apiTotal = 0,
    this.breakdown = const [],
    this.quantityLabel = '',
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

    case 'partially_paid':
    case 'partially paid':
      return 'Partially Paid';

    default:
      return s;
  }
}

  /// "fixed" → "Fixed Amount", "percentage" → "Percentage",
  /// "none"/"zero"/"" → fallback
  static String _normaliseTaxType(String s, String fallback) {
  switch (s.toLowerCase().trim()) {
    case 'percentage':
    case 'percent':
      return 'Percentage';

    case 'fixed':
    case 'fixed amount':
    case 'fixed_amount':
      return 'Fixed Amount';

    case 'none':
    case 'zero':
    case 'zero tax':
    case '':
      return fallback;

    default:
      return fallback;
  }
}

  static double _parseTaxOrDiscountValue({
  required Map<String, dynamic> j,
  required String type,
  required double price,
  required List<String> valueKeys,
  required List<String> amountKeys,
}) {
  if (type != 'Percentage' && type != 'Fixed Amount') {
    return 0;
  }

  // IMPORTANT:
  // Always prefer the actual API value field.
  //
  // Percentage:
  //   taxValue = 18  -> 18%
  //
  // Fixed Amount:
  //   taxValue = 30488.64 -> ₹30,488.64
  //
  // Do NOT convert it using price or tax amount.
  double? fromValueKeys;
  for (final key in valueKeys) {
    final value = _d(j[key]);

    if (value != null) {
      fromValueKeys = value;
      break;
    }
  }

  // The API has been observed to persist taxValue/discountValue as 0
  // even when a real rate was set on that invoice, while the sibling
  // amount field (tax/discount) still carries the true figure — so a
  // zero from valueKeys isn't trusted outright when amountKeys has a
  // nonzero signal to fall back on.
  if (fromValueKeys != null && fromValueKeys != 0) {
    return fromValueKeys;
  }

  for (final key in amountKeys) {
    final value = _d(j[key]);

    if (value != null && value != 0) {
      return value;
    }
  }

  return fromValueKeys ?? 0;
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

  double get total => totalPreferredCurrencyValue;

  double get totalInInr => totalPreferredCurrencyValue;

  bool get hasBackendConversion =>
      (exchangeRate != null && exchangeRate! > 0) ||
      (inrAmount != null && inrAmount! > 0) ||
      currency.toUpperCase().trim() == 'INR';

  /// Remaining balance after what's been paid so far.
  double get balanceDue => (total - amountPaid).clamp(0, double.infinity);

  /// Invoice total in its own [currency] (price − discount + tax).
  /// [total] is the *preferred*-currency value — don't compare it with
  /// [amountPaid], which is in [currency].
  double get originalTotal =>
      (price - discountAmount + taxAmount).clamp(0, double.infinity).toDouble();

  /// The backend's locked conversion rate into [target] (from
  /// totalPreferredCurrencyValue), or null when it wasn't saved in
  /// [target] — e.g. the account currency changed after it was stored.
  double? savedRateTo(String target) {
    if (preferredCurrency.trim().toUpperCase() !=
        target.trim().toUpperCase()) {
      return null;
    }
    if (totalPreferredCurrencyValue <= 0 || originalTotal <= 0) return null;
    return totalPreferredCurrencyValue / originalTotal;
  }

  /// Status "paid", or paid ≥ the original-currency total.
  bool get isFullyPaid =>
      status.trim().toLowerCase() == 'paid' ||
      (originalTotal > 0 && amountPaid >= originalTotal - 0.005);

  // ── Helpers ─────────────────────────────────────────────────────
  static String _s(dynamic v, [String fb = '']) =>
      v == null ? fb : v.toString();
  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', ''));
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
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
        updatedAt: m['updatedAt'] != null
            ? DateTime.tryParse(m['updatedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        isLocal: (m['isLocal'] as int? ?? 0) == 1,
        amountPaid: _d(m['amountPaid']) ?? 0,
        paidAt: _dt(m['paidAt']),
        emailSentAt: _dt(m['emailSentAt']),
        preferredCurrency: _s(m['preferredCurrency'], _s(m['currency'], 'INR')),
        preferredCurrencyValue: _d(m['preferredCurrencyValue']) ?? 0,
        billingAddress: _s(m['billingAddress']),
        clientTaxId: _s(m['clientTaxId']),
        poNumber: _s(m['poNumber']),
        clientState: _s(m['clientState']),
        customFields: (m['customFields'] is List) ? m['customFields'] as List : const [],
        dealPhone: _s(m['dealPhone']),
        dealEmail: _s(m['dealEmail']),
        companyName: _s(m['companyName']),
        dealAddress: _s(m['dealAddress']),
        dealCountry: _s(m['dealCountry']),
        dealValue: _s(m['dealValue']),
        dealStage: _s(m['dealStage']),
        lastReminderAt: _dt(m['lastReminderAt']),
        totalPreferredCurrencyValue:
            _d(m['totalPreferredCurrencyValue']) ?? 0,
        createdBy: _s(m['createdBy']),
        lastUpdatedBy: _s(m['lastUpdatedBy']),
        assignToId: _s(m['assignToId']),
        assignToEmail: _s(m['assignToEmail']),
        apiSubtotal: _d(m['apiSubtotal']) ?? 0,
        apiDiscount: _d(m['apiDiscount']) ?? 0,
        apiTax: _d(m['apiTax']) ?? 0,
        apiTotal: _d(m['apiTotal']) ?? 0,
        breakdown: _parseBreakdown(m['breakdown']),
        quantityLabel: _s(m['quantityLabel']),
      );

  static List<InvoiceBreakdownItem> _parseBreakdown(dynamic v) => v is List
      ? v
          .whereType<Map>()
          .map((e) =>
              InvoiceBreakdownItem.fromJson(Map<String, dynamic>.from(e)))
          .toList()
      : const [];

  // ── fromJson (API response) ──────────────────────────────────────
  factory Invoice.fromJson(Map<String, dynamic> j) {
    // assignTo — may be missing, a string, or an object
    String assignTo = '';
    String assignToId = '';
    String assignToEmail = '';
    final rawUser = j['assignedTo'] ?? j['assignTo'] ?? j['assigned_to'];
    if (rawUser is Map) {
      final fn = rawUser['firstName']?.toString().trim() ?? '';
      final ln = rawUser['lastName']?.toString().trim() ?? '';
      assignTo = '$fn $ln'.trim();
      assignToId = _s(rawUser['_id'] ?? rawUser['id']).trim();
      assignToEmail = _s(rawUser['email']).trim();
    } else if (rawUser != null) {
      assignTo = rawUser.toString().trim();
    }

    // deal — from items[0].deal or top-level dealId/dealName
    String dealId = '';
    String dealName = '';
    String dealPhone = '';
    String dealEmail = '';
    String companyName = '';
    String dealAddress = '';
    String dealCountry = '';
    String dealValue = '';
    String dealStage = '';

    final items = j['items'];
    if (items is List && items.isNotEmpty && items.first is Map) {
      final firstItem = items.first as Map;
      final rawDeal = firstItem['deal'];
      if (rawDeal is Map) {
        dealId = _s(rawDeal['_id'] ?? rawDeal['id']);
        dealName =
            _s(rawDeal['dealName'] ?? rawDeal['name'] ?? rawDeal['title']);
        dealPhone = _s(rawDeal['phoneNumber'] ?? rawDeal['phone']);
        dealEmail = _s(rawDeal['email']);
        companyName = _s(rawDeal['companyName'] ?? rawDeal['company']);
        dealAddress = _s(rawDeal['address']);
        dealCountry = _s(rawDeal['country']);
        dealValue = _s(rawDeal['value']);
        dealStage = _s(rawDeal['stage']);
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
        dealPhone = _s(rawDeal['phoneNumber'] ?? rawDeal['phone']);
        dealEmail = _s(rawDeal['email']);
        companyName = _s(rawDeal['companyName'] ?? rawDeal['company']);
        dealAddress = _s(rawDeal['address']);
        dealCountry = _s(rawDeal['country']);
        dealValue = _s(rawDeal['value']);
        dealStage = _s(rawDeal['stage']);
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
    final disVal = _parseTaxOrDiscountValue(
      j: j,
      type: discountType,
      price: price,
      valueKeys: ['discountValue', 'discount_value'],
      amountKeys: ['discount'],
    );

    // The API only persists the computed 'tax' amount, not the rate the
    // user entered — so for a Percentage tax type, back the rate out of
    // the amount using the same inverse math the cubit uses to compute
    // it (tax = taxableBase * rate / 100).
    final rawTax = _d(j['tax']) ?? 0;
    double taxVal;
    if (taxType == 'Percentage') {
      final discountAmountForTax = discountType == 'Percentage'
          ? price * disVal / 100
          : discountType == 'Fixed Amount'
              ? disVal
              : 0.0;
      final taxableBase =
          (price - discountAmountForTax).clamp(0, double.infinity);
      taxVal = taxableBase > 0 ? (rawTax / taxableBase * 100) : 0;
    } else if (taxType == 'Fixed Amount') {
      taxVal = rawTax;
    } else {
      taxVal = 0;
    }

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
      updatedAt: j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isLocal: false,
      amountPaid: _d(j['amountPaid']) ?? 0,
      paidAt: _dt(j['paidAt']),
      emailSentAt: _dt(j['emailSentAt']),
      preferredCurrency: _s(j['preferredCurrency'], currency),
      preferredCurrencyValue: _d(j['preferredCurrencyValue']) ?? 0,
      billingAddress: _s(j['billingAddress']),
      clientTaxId: _s(j['clientTaxId']),
      poNumber: _s(j['poNumber']),
      clientState: _s(j['clientState']),
      customFields: (j['customFields'] is List) ? j['customFields'] as List : const [],
      dealPhone: dealPhone,
      dealEmail: dealEmail,
      companyName: companyName,
      dealAddress: dealAddress,
      dealCountry: dealCountry,
      dealValue: dealValue,
      dealStage: dealStage,
      statusHistory: (j['statusHistory'] is List)
          ? (j['statusHistory'] as List)
              .whereType<Map>()
              .map((m) =>
                  InvoiceStatusHistoryItem.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      lastReminderAt: _dt(j['lastReminderAt']),
      totalPreferredCurrencyValue:
          _d(j['totalPreferredCurrencyValue']) ?? 0,
      createdBy: _s(j['createdBy']),
      lastUpdatedBy: _s(j['lastUpdatedBy']),
      assignToId: assignToId,
      assignToEmail: assignToEmail,
      apiSubtotal: _d(j['subtotal']) ?? 0,
      apiDiscount: _d(j['discount']) ?? 0,
      apiTax: rawTax,
      apiTotal: serverTotal,
      breakdown: _parseBreakdown(j['breakdown']),
      quantityLabel: _s(j['quantityLabel']),
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
        'amountPaid': amountPaid,
        'paidAt': paidAt?.toIso8601String(),
        'emailSentAt': emailSentAt?.toIso8601String(),
        'preferredCurrency': preferredCurrency,
        'preferredCurrencyValue': preferredCurrencyValue,
        'billingAddress': billingAddress,
        'clientTaxId': clientTaxId,
        'poNumber': poNumber,
        'clientState': clientState,
        'customFields': customFields,
        'dealPhone': dealPhone,
        'dealEmail': dealEmail,
        'companyName': companyName,
        'dealAddress': dealAddress,
        'dealCountry': dealCountry,
        'dealValue': dealValue,
        'dealStage': dealStage,
        'lastReminderAt': lastReminderAt?.toIso8601String(),
        'totalPreferredCurrencyValue': totalPreferredCurrencyValue,
        'createdBy': createdBy,
        'lastUpdatedBy': lastUpdatedBy,
        'assignToId': assignToId,
        'assignToEmail': assignToEmail,
        'apiSubtotal': apiSubtotal,
        'apiDiscount': apiDiscount,
        'apiTax': apiTax,
        'apiTotal': apiTotal,
        'breakdown': breakdown.map((b) => b.toJson()).toList(),
        'quantityLabel': quantityLabel,
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
    double? amountPaid,
    DateTime? paidAt,
    DateTime? emailSentAt,
    String? preferredCurrency,
    double? preferredCurrencyValue,
    String? billingAddress,
    String? clientTaxId,
    String? poNumber,
    String? clientState,
    List<dynamic>? customFields,
    String? dealPhone,
    String? dealEmail,
    String? companyName,
    String? dealAddress,
    String? dealCountry,
    String? dealValue,
    String? dealStage,
    List<InvoiceStatusHistoryItem>? statusHistory,
    DateTime? lastReminderAt,
    double? totalPreferredCurrencyValue,
    String? createdBy,
    String? lastUpdatedBy,
    String? assignToId,
    String? assignToEmail,
    double? apiSubtotal,
    double? apiDiscount,
    double? apiTax,
    double? apiTotal,
    List<InvoiceBreakdownItem>? breakdown,
    String? quantityLabel,
  }) =>
      Invoice(
        id: id,
        invoiceNo: invoiceNo,
        createdAt: createdAt,
        updatedAt: updatedAt,
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
        amountPaid: amountPaid ?? this.amountPaid,
        paidAt: paidAt ?? this.paidAt,
        emailSentAt: emailSentAt ?? this.emailSentAt,
        preferredCurrency: preferredCurrency ?? this.preferredCurrency,
        preferredCurrencyValue:
            preferredCurrencyValue ?? this.preferredCurrencyValue,
        billingAddress: billingAddress ?? this.billingAddress,
        clientTaxId: clientTaxId ?? this.clientTaxId,
        poNumber: poNumber ?? this.poNumber,
        clientState: clientState ?? this.clientState,
        customFields: customFields ?? this.customFields,
        dealPhone: dealPhone ?? this.dealPhone,
        dealEmail: dealEmail ?? this.dealEmail,
        companyName: companyName ?? this.companyName,
        dealAddress: dealAddress ?? this.dealAddress,
        dealCountry: dealCountry ?? this.dealCountry,
        dealValue: dealValue ?? this.dealValue,
        dealStage: dealStage ?? this.dealStage,
        statusHistory: statusHistory ?? this.statusHistory,
        lastReminderAt: lastReminderAt ?? this.lastReminderAt,
        totalPreferredCurrencyValue:
            totalPreferredCurrencyValue ?? this.totalPreferredCurrencyValue,
        createdBy: createdBy ?? this.createdBy,
        lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
        assignToId: assignToId ?? this.assignToId,
        assignToEmail: assignToEmail ?? this.assignToEmail,
        apiSubtotal: apiSubtotal ?? this.apiSubtotal,
        apiDiscount: apiDiscount ?? this.apiDiscount,
        apiTax: apiTax ?? this.apiTax,
        apiTotal: apiTotal ?? this.apiTotal,
        breakdown: breakdown ?? this.breakdown,
        quantityLabel: quantityLabel ?? this.quantityLabel,
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