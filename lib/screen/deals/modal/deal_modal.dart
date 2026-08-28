import 'package:flutter/material.dart';

// ===============================
// Invoice Tab
// ===============================
class DealInvoice {
  final String id;
  final String invoiceNumber;
  final String status;
  final String total;
  final String currency;
  final DateTime issueDate;
  final DateTime dueDate;

  DealInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.total,
    required this.currency,
    required this.issueDate,
    required this.dueDate,
  });

  factory DealInvoice.fromJson(Map<String, dynamic> json) {
    return DealInvoice(
      id: json['_id'],
      invoiceNumber: json['invoicenumber'] ?? '',
      status: json['status'] ?? '',
      total: json['total'].toString(),
      currency: json['currency'] ?? '',
      issueDate: DateTime.parse(json['issueDate']),
      dueDate: DateTime.parse(json['dueDate']),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ATTACHMENT MODEL
// ══════════════════════════════════════════════════════════════
class Attachment {
  final String name;
  final String path;
  final String type;
  final int size;
  final DateTime? uploadedAt;

  const Attachment({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    this.uploadedAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        name: j['name']?.toString() ?? '',
        path: j['path']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
        uploadedAt: j['uploadedAt'] != null
            ? DateTime.tryParse(j['uploadedAt'].toString())
            : null,
      );
}

// Deal Activity Item
class DealActivityItem {
  final String type; // "followup" | "stage_change" | etc.
  final String description;
  final String performedByName;
  final DateTime timestamp;

  const DealActivityItem({
    required this.type,
    required this.description,
    required this.performedByName,
    required this.timestamp,
  });

  factory DealActivityItem.fromJson(Map<String, dynamic> j) {
    final performedBy = j['performedBy'];
    return DealActivityItem(
      type: (j['type'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      performedByName: performedBy is Map
          ? (performedBy['name'] ?? '').toString()
          : '',
      timestamp: DateTime.tryParse(j['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FOLLOW-UP HISTORY MODEL
// ══════════════════════════════════════════════════════════════
class FollowUpHistoryItem {
  final String id;
  final DateTime? date; // when the action happened
  final DateTime? followUpDate; // scheduled datetime
  final String action; // e.g. "Created", "Completed"
  final String comment;
  final String changedByName; // who logged this follow-up
  final String? outcome;
  final String? notes;

  const FollowUpHistoryItem({
    this.id = '',
    this.date,
    this.followUpDate,
    required this.action,
    required this.comment,
    this.changedByName = '',
    this.outcome,
    this.notes,
  });
}

// ══════════════════════════════════════════════════════════════
// STAGE HISTORY MODEL
// ══════════════════════════════════════════════════════════════
class StageHistoryItem {
  final String id;
  final String stage;
  final DateTime? movedAt;
  // API sends movedBy as a bare user-id string here, not an expanded
  // object like followUpHistory's changedBy — so we only have the id
  // to work with, not a name, unless the backend later expands it.
  final String movedById;

  const StageHistoryItem({
    this.id = '',
    required this.stage,
    this.movedAt,
    this.movedById = '',
  });
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
  final List<Attachment> images;

  // ── new fields ──────────────────────────────────────────────
  final String alternativeNumber;
  final String alternativeEmail;
  final String companySize;
  final String requirement;
  final String lossReason;
  final String lossNotes;
  final DateTime? stageLostAt;
  final List<StageHistoryItem> stageHistory;
  final DateTime? lostDate;

  // Location
final String city;
final String state;
final String pincode;
final double? latitude;
final double? longitude;

// Currency conversion
final String preferredCurrency;
final double preferredCurrencyValue;

// Company
final String? companyId;

// Status / trash
final bool isActive;
final bool trash;
final DateTime? trashedAt;

// Notes tracking
final String? notesUpdatedBy;
final DateTime? notesUpdatedAt;

// Admin activity
final bool taskAdminActivityDismissed;
final bool targetAdminActivityDismissed;

// Other API data
final List<dynamic> assignmentHistory;
final List<dynamic> leadStatusHistory;
final List<dynamic> customFields;

  // ── rejection fields ────────────────────────────────────────
  final String rejectionReason;
  final String rejectedByName;
  final DateTime? rejectedAt;

  // ── conversion / won fields ─────────────────────────────────
  final String leadId;
  final DateTime? convertedAt;
  final String convertedByName;
  final DateTime? wonAt;
  final String wonByName;
  final DateTime? leadCreatedAt;
  final double discountGiven;

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
    this.images = const [],
    this.alternativeNumber = '',
    this.alternativeEmail = '',
    this.companySize = '',
    this.requirement = '',
    this.lossReason = '',
    this.lossNotes = '',
    this.stageLostAt,
    this.stageHistory = const [],
    this.rejectionReason = '',
    this.rejectedByName = '',
    this.rejectedAt,
    this.leadId = '',
    this.convertedAt,
    this.convertedByName = '',
    this.wonAt,
    this.wonByName = '',
    this.leadCreatedAt,
    this.discountGiven = 0,
    this.city = '',
this.state = '',
this.pincode = '',
this.latitude,
this.longitude,
this.preferredCurrency = '',
this.preferredCurrencyValue = 0,
this.companyId,
this.isActive = true,
this.trash = false,
this.trashedAt,
this.notesUpdatedBy,
this.notesUpdatedAt,
this.taskAdminActivityDismissed = false,
this.targetAdminActivityDismissed = false,
this.assignmentHistory = const [],
this.leadStatusHistory = const [],
this.customFields = const [],
this.lostDate,

  });

  /// True when this deal was rejected — [Deal.stage] will be the raw
  /// API "Rejected" value, which is intentionally NOT one of
  /// [DealConstants.stages] (see [DealConstants.canonicalStage]).
  bool get isRejected => stage.trim().toLowerCase() == 'rejected';

  /// True when the deal has actually been marked won (server sent
  /// wonAt), as distinct from merely sitting in the "Closed Won"
  /// stage bucket — use this when precision on the won timestamp
  /// matters (e.g. period-filtered "Deals Won" reporting).
  bool get isWon => wonAt != null;

  static String _s(dynamic v, [String fb = '']) =>
      v == null ? fb : v.toString();

  static String _normalizeClientType(dynamic v) {
    final raw = _s(v).trim().toUpperCase();
    if (raw == 'B2B' || raw == 'B2C') return raw;
    return '';
  }

  static String _fullName(dynamic raw) {
    if (raw is Map) {
      return '${_s(raw['firstName'])} ${_s(raw['lastName'])}'.trim();
    }
    return raw != null ? _s(raw).trim() : '';
  }

  factory Deal.fromJson(Map<String, dynamic> j) {
    // assignTo — API uses "assignedTo" on some payloads (e.g. the
    // deals list) and "assignTo" on others; check both.
    final assignTo = _fullName(j['assignTo'] ?? j['assignedTo']);

    // value — prefer the numeric preferredCurrencyValue when present,
    // since `value` on the API can be a formatted string like
    // "10,000 INR"; fall back to stripping non-numeric chars from
    // whichever value/dealValue/amount field is available.
// Deal value — API returns value like "2,000 INR".
// Keep the original deal value separate from the
// converted preferred-currency value.
double val = 0;

final rawValue = j['value'] ?? j['dealValue'] ?? j['amount'];

if (rawValue != null) {
  if (rawValue is num) {
    val = rawValue.toDouble();
  } else {
    val = double.tryParse(
          rawValue
              .toString()
              .replaceAll(',', '')
              .replaceAll(RegExp(r'[^\d.\-]'), ''),
        ) ??
        0;
  }
}

// Preferred currency conversion is stored separately.
final preferredValue = j['preferredCurrencyValue'] is num
    ? (j['preferredCurrencyValue'] as num).toDouble()
    : double.tryParse(
          j['preferredCurrencyValue']?.toString() ?? '',
        ) ??
        0;
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

    // images
    final List<Attachment> images = [];

final rawImages = j['images'];

if (rawImages is List) {
  for (final image in rawImages) {
    if (image is Map) {
      try {
        images.add(
          Attachment.fromJson(
            Map<String, dynamic>.from(image),
          ),
        );
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
          id: _s(m['_id']),
          date: DateTime.tryParse(m['date']?.toString() ?? ''),
          followUpDate: DateTime.tryParse(m['followUpDate']?.toString() ?? ''),
          action: (m['action'] ?? m['status'] ?? '').toString(),
          comment: (m['followUpComment'] ?? m['comment'] ?? '').toString(),
          changedByName: (() {
            final cb = m['changedBy'];
            debugPrint('changedBy raw type=${cb.runtimeType} value=$cb');
            if (cb is Map) {
              final fn = (cb['firstName'] ?? '').toString().trim();
              final ln = (cb['lastName'] ?? '').toString().trim();
              final combined = [fn, ln].where((s) => s.isNotEmpty).join(' ');
              if (combined.isNotEmpty) return combined;
            }
            return '';
          })(),
          outcome: (m["outcome"] ?? '').toString(),
          notes: (m["notes"] ?? '').toString(),
        ));
      }
    }

    // stageHistory — timeline of stage moves.
    final List<StageHistoryItem> stageHistory = [];
    final rawStageHistory = j['stageHistory'];
    if (rawStageHistory is List) {
      for (final h in rawStageHistory) {
        if (h is! Map) continue;
        final m = Map<String, dynamic>.from(h);
        stageHistory.add(StageHistoryItem(
          id: _s(m['_id']),
          stage: _s(m['stage']),
          movedAt: DateTime.tryParse(m['movedAt']?.toString() ?? ''),
          // movedBy is a bare id string in this response, not an object
          movedById: m['movedBy'] is Map
              ? _s((m['movedBy'] as Map)['_id'])
              : _s(m['movedBy']),
        ));
      }
    }
    if (j['preferredCurrencyValue'] != null) {
  val = (j['preferredCurrencyValue'] as num?)?.toDouble() ??
      double.tryParse(j['preferredCurrencyValue'].toString()) ??
      0;
}

    // discountGiven — API sends a plain number.
    final discountGiven = (j['discountGiven'] is num)
        ? (j['discountGiven'] as num).toDouble()
        : double.tryParse(_s(j['discountGiven'], '0')) ?? 0;

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
      countryCode: _s(j['countryCode']),
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
      images: images,
      alternativeNumber: _s(j['alternativeNumber']),
      alternativeEmail: _s(j['alternativeEmail']),
      companySize: _s(j['companySize']),
      requirement: _s(j['requirement']),
      lossReason: _s(j['lossReason']),
      lossNotes: _s(j['lossNotes']),
      // API sends both stageLostAt and lostDate — prefer stageLostAt,
      // fall back to lostDate if only that one is populated.
      stageLostAt: j['stageLostAt'] != null
          ? DateTime.tryParse(j['stageLostAt'].toString())
          : (j['lostDate'] != null
              ? DateTime.tryParse(j['lostDate'].toString())
              : null),
      stageHistory: stageHistory,
      rejectionReason: _s(j['rejectionReason']),
      rejectedByName: _fullName(j['rejectedBy']),
      rejectedAt: j['rejectedAt'] != null
          ? DateTime.tryParse(j['rejectedAt'].toString())
          : null,
      leadId: _s(j['leadId']),
      convertedAt: j['convertedAt'] != null
          ? DateTime.tryParse(j['convertedAt'].toString())
          : null,
      convertedByName: _fullName(j['convertedBy']),
      wonAt: j['wonAt'] != null ? DateTime.tryParse(j['wonAt'].toString()) : null,
      wonByName: _fullName(j['wonBy']),
      leadCreatedAt: j['leadCreatedAt'] != null
          ? DateTime.tryParse(j['leadCreatedAt'].toString())
          : null,
      discountGiven: discountGiven,
      city: _s(j['city']),
state: _s(j['state']),
pincode: _s(j['pincode']),

latitude: (j['latitude'] as num?)?.toDouble(),
longitude: (j['longitude'] as num?)?.toDouble(),

preferredCurrency: _s(j['preferredCurrency']),
preferredCurrencyValue:
    (j['preferredCurrencyValue'] as num?)?.toDouble() ?? 0,

companyId: j['companyId']?.toString(),

isActive: j['isActive'] ?? true,
trash: j['trash'] ?? false,

trashedAt: j['trashedAt'] != null
    ? DateTime.tryParse(j['trashedAt'].toString())
    : null,

notesUpdatedBy: j['notesUpdatedBy']?.toString(),

notesUpdatedAt: j['notesUpdatedAt'] != null
    ? DateTime.tryParse(j['notesUpdatedAt'].toString())
    : null,

taskAdminActivityDismissed:
    j['taskAdminActivityDismissed'] ?? false,

targetAdminActivityDismissed:
    j['targetAdminActivityDismissed'] ?? false,

assignmentHistory:
    j['assignmentHistory'] is List
        ? List<dynamic>.from(j['assignmentHistory'])
        : const [],

leadStatusHistory:
    j['leadStatusHistory'] is List
        ? List<dynamic>.from(j['leadStatusHistory'])
        : const [],

customFields:
    j['customFields'] is List
        ? List<dynamic>.from(j['customFields'])
        : const [],

lostDate: j['lostDate'] != null
    ? DateTime.tryParse(j['lostDate'].toString())
    : null,
    );
  }

  Deal copyWith({
    String? stage,
    List<Attachment>? attachments,
    List<Attachment>? images,
    List<FollowUpHistoryItem>? followUpHistory,
    List<StageHistoryItem>? stageHistory,
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
        images: images ?? this.images,
        alternativeNumber: alternativeNumber,
        alternativeEmail: alternativeEmail,
        companySize: companySize,
        requirement: requirement,
        lossReason: lossReason,
        lossNotes: lossNotes,
        stageLostAt: stageLostAt,
        stageHistory: stageHistory ?? this.stageHistory,
        rejectionReason: rejectionReason,
        rejectedByName: rejectedByName,
        rejectedAt: rejectedAt,
        leadId: leadId,
        convertedAt: convertedAt,
        convertedByName: convertedByName,
        wonAt: wonAt,
        wonByName: wonByName,
        leadCreatedAt: leadCreatedAt,
        discountGiven: discountGiven,
        city: city,
state: state,
pincode: pincode,
latitude: latitude,
longitude: longitude,

preferredCurrency: preferredCurrency,
preferredCurrencyValue: preferredCurrencyValue,

companyId: companyId,

isActive: isActive,
trash: trash,
trashedAt: trashedAt,

notesUpdatedBy: notesUpdatedBy,
notesUpdatedAt: notesUpdatedAt,

taskAdminActivityDismissed:
    taskAdminActivityDismissed,

targetAdminActivityDismissed:
    targetAdminActivityDismissed,

assignmentHistory: assignmentHistory,
leadStatusHistory: leadStatusHistory,
customFields: customFields,

lostDate: lostDate,
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
        'alternativeNumber': alternativeNumber,
        'alternativeEmail': alternativeEmail,
        'companySize': companySize,
        'requirement': requirement,
        'city': city,
'state': state,
'pincode': pincode,
'latitude': latitude,
'longitude': longitude,
'preferredCurrency': preferredCurrency,
'preferredCurrencyValue': preferredCurrencyValue,
'companyId': companyId,
      };
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

  /// Stage used by rejected deals. Kept out of [stages] deliberately —
  /// rejected deals live in their own screen/tab (`/deals/rejected`),
  /// not as a Kanban column — but exposed here so callers can check
  /// against it explicitly instead of hardcoding the string.
  static const rejectedStage = 'Rejected';

  /// Maps legacy/API stages to a column in [stages].
  /// Returns [rejectedStage] as-is for rejected deals — callers that
  /// render the Kanban board should route those to the rejected-deals
  /// screen instead of trying to place them in a column.
  static String canonicalStage(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return stages.first;
    final k = t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

    if (k == 'rejected') return rejectedStage;

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
    'A\$ AUD',
    'C\$ CAD',
    'CHF CHF',
    'RM MYR',
    'د.إ AED',
    'S\$ SGD',
    'R ZAR',
    '﷼ SAR',
  ];

  /// Flag emoji per currency code, for the richer currency-picker rows.
  static const currencyFlags = {
    'INR': '🇮🇳',
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
    'JPY': '🇯🇵',
    'AUD': '🇦🇺',
    'CAD': '🇨🇦',
    'CHF': '🇨🇭',
    'MYR': '🇲🇾',
    'AED': '🇦🇪',
    'SGD': '🇸🇬',
    'ZAR': '🇿🇦',
    'SAR': '🇸🇦',
  };

  /// Full display name per currency code, for the richer currency-picker rows.
  static const currencyNames = {
    'INR': 'Indian Rupee',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'JPY': 'Japanese Yen',
    'AUD': 'Australian Dollar',
    'CAD': 'Canadian Dollar',
    'CHF': 'Swiss Franc',
    'MYR': 'Malaysian Ringgit',
    'AED': 'UAE Dirham',
    'SGD': 'Singapore Dollar',
    'ZAR': 'South African Rand',
    'SAR': 'Saudi Riyal',
  };
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
    'Energy & Utilities',
    'Construction',
    'Telecommunications',
    'Automotive',
    'Fashion & Apparel',
    'Food & Beverage',
    'Media  & Advertising',
    'Non-profit',
    'Other',
  ];


  static String currencySymbol(String s) => s.split(' ').first;
}