// ══════════════════════════════════════════════════════════════
// ATTACHMENT MODEL
// ══════════════════════════════════════════════════════════════
class Attachment {
  final String name;
  final String path;
  final String type;
  final int size;

  const Attachment({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        name: j['name']?.toString() ?? '',
        path: j['path']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
      );
}

// ══════════════════════════════════════════════════════════════
// DEAL MODEL
// ══════════════════════════════════════════════════════════════
class Deal {
  final String id;
  final String name;
  final String companyName;
  final String phone;
  final String email;
  final String stage;
  final String industry;
  final String source;
  final String clientType;
  final String country;
  final String address;
  final String assignTo;
  final String notes;
  final String currency;
  final String countryCode;
  final double value;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastReminderAt;
  final String? followUpDate;
  final String? followUpComment;
  final List<FollowUpHistoryItem> followUpHistory;
  final List<Attachment> attachments;

  const Deal({
    required this.id,
    required this.name,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.stage,
    required this.industry,
    required this.source,
    required this.clientType,
    required this.country,
    required this.address,
    required this.assignTo,
    required this.notes,
    required this.currency,
    required this.countryCode,
    required this.value,
    required this.createdAt,
    this.updatedAt,
    this.lastReminderAt,
    this.followUpDate,
    this.followUpComment,
    this.followUpHistory = const [],
    this.attachments = const [],
  });

  static String _s(dynamic v, [String fb = '']) =>
      v == null ? fb : v.toString();

  static String _normalizeClientType(dynamic v) {
    final raw = _s(v).trim().toUpperCase();
    if (raw == 'B2B' || raw == 'B2C') return raw;
    return '';
  }

  factory Deal.fromJson(Map<String, dynamic> j) {
    // assignTo
    String assignTo = '';
    final raw = j['assignTo'] ?? j['assignedTo'];
    if (raw is Map) {
      assignTo = '${_s(raw['firstName'])} ${_s(raw['lastName'])}';
    } else if (raw != null) {
      assignTo = _s(raw);
    }
    assignTo = assignTo.trim();

    // value — strip non-numeric chars before parsing
    double val = 0;
    final rv = j['value'] ?? j['dealValue'] ?? j['amount'];
    if (rv != null) {
      val =
          double.tryParse(rv.toString().replaceAll(RegExp(r'[^\d.\-]'), '')) ??
              0;
    }

    // currency — API sends bare "INR"; map to display string "₹ INR"
    final rawCur = _s(j['currency'], 'INR')
        .replaceAll(RegExp(r'[₹$€£¥\s]'), '')
        .toUpperCase();
    final currency = DealConstants.currencies.firstWhere(
      (c) => c.toUpperCase().contains(rawCur),
      orElse: () => '₹ INR',
    );

    // attachments
    final List<Attachment> attachments = [];
    final rawAttach = j['attachments'];
    if (rawAttach is List) {
      for (final a in rawAttach) {
        if (a is Map) {
          try {
            attachments.add(Attachment.fromJson(Map<String, dynamic>.from(a)));
          } catch (_) {}
        }
      }
    }

    // followUpHistory — used by Deal details "Follow-up history" tab.
    final List<FollowUpHistoryItem> followUpHistory = [];
    final rawHistory =
        j['followUpHistory'] ?? j['follow_up_history'] ?? j['followupHistory'];
    if (rawHistory is List) {
      for (final h in rawHistory) {
        if (h is! Map) continue;
        final m = Map<String, dynamic>.from(h);
        followUpHistory.add(FollowUpHistoryItem(
          date: DateTime.tryParse(m['date']?.toString() ?? ''),
          followUpDate: DateTime.tryParse(m['followUpDate']?.toString() ?? ''),
          action: (m['action'] ?? m['status'] ?? '').toString(),
          comment: (m['followUpComment'] ?? m['comment'] ?? '').toString(),
        ));
      }
    }

    return Deal(
      id: _s(j['_id'] ?? j['id']),
      name: _s(j['dealName'] ?? j['name']),
      companyName: _s(j['companyName'] ?? j['company']),
      phone: _s(j['phone'] ?? j['phoneNumber']),
      email: _s(j['email']),
      stage: _s(j['stage'], 'Qualification'),
      industry: _s(j['industry']),
      source: _s(j['source']),
      clientType: _normalizeClientType(j['clientType']),
      country: _s(j['country']),
      address: _s(j['address']),
      assignTo: assignTo,
      notes: _s(j['notes']),
      currency: currency,
      countryCode: _s(j['countryCode'], '+91 IN'),
      value: val,
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'].toString())
          : null,
      lastReminderAt: j['lastReminderAt'] != null
          ? DateTime.tryParse(j['lastReminderAt'].toString())
          : null,
      followUpDate: j['followUpDate']?.toString(),
      followUpComment: j['followUpComment']?.toString(),
      followUpHistory: followUpHistory,
      attachments: attachments,
    );
  }

  Deal copyWith({
    String? stage,
    List<Attachment>? attachments,
    List<FollowUpHistoryItem>? followUpHistory,
  }) =>
      Deal(
        id: id,
        name: name,
        companyName: companyName,
        phone: phone,
        email: email,
        stage: stage ?? this.stage,
        industry: industry,
        source: source,
        clientType: clientType,
        country: country,
        address: address,
        assignTo: assignTo,
        notes: notes,
        currency: currency,
        countryCode: countryCode,
        value: value,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastReminderAt: lastReminderAt,
        followUpDate: followUpDate,
        followUpComment: followUpComment,
        followUpHistory: followUpHistory ?? this.followUpHistory,
        attachments: attachments ?? this.attachments,
      );

  Map<String, dynamic> toPayload() => {
        'dealName': name,
        'companyName': companyName,
        'phoneNumber': phone,
        'email': email,
        'stage': stage,
        'industry': industry,
        'source': source,
        'clientType': clientType,
        'country': country,
        'address': address,
        'notes': notes,
        'currency': currency,
        'countryCode': countryCode,
        'value': value,
      };
}

class FollowUpHistoryItem {
  final DateTime? date; // when the action happened
  final DateTime? followUpDate; // scheduled datetime
  final String action; // e.g. "Scheduled", "Completed"
  final String comment;

  const FollowUpHistoryItem({
    this.date,
    this.followUpDate,
    required this.action,
    required this.comment,
  });
}

// ══════════════════════════════════════════════════════════════
// CONSTANTS
// ══════════════════════════════════════════════════════════════
class DealConstants {
  static const stages = [
    'Qualification',
    'Proposal Sent-Negotiation',
    'Invoice Sent',
    'Closed Won',
    'Closed Lost',
  ];

  /// Maps legacy/API stages to a column in [stages].
  static String canonicalStage(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return stages.first;
    final k = t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

    // Keep real "Invoice Sent" stages separate.
    if (k.contains('invoice') && k.contains('sent')) {
      return 'Invoice Sent';
    }

    // Show any proposal/negotiation-related stage under one bucket.
    // This also fixes the "Invoice Sent shows extra data" issue.
    if (k.contains('proposal') || k.contains('negotiation')) {
      return 'Proposal Sent-Negotiation';
    }

    return t;
  }

  static const currencies = [
    '₹ INR',
    '\$ USD',
    '€ EUR',
    '£ GBP',
    '¥ JPY',
    '¥ CNY',
    'A\$ AUD',
    'C\$ CAD',
    'CHF CHF',
    'RM MYR',
    'د.إ AED',
    'S\$ SGD',
    'R ZAR',
    '﷼ SAR',
  ];
  static const countryCodes = [
    '+91 IN',
    '+1 US',
    '+44 UK',
    '+61 AU',
    '+971 UAE',
    '+65 SG',
    '+81 JP',
    '+86 CN',
    '+49 DE',
    '+33 FR',
  ];
  static const industries = [
    'IT',
    'Finance',
    'Healthcare',
    'Education',
    'Manufacturing',
    'Retail',
    'Others',
  ];

  static String currencySymbol(String s) => s.split(' ').first;
}
