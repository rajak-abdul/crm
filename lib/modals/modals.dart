// ╔══════════════════════════════════════════════════════════════╗
// ║                   lib/models/modals.dart                     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:convert'; // ✅ FIX #1: was missing — needed for jsonDecode in Lead.fromMap

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

const kBaseUrl = 'https://sales.stagingzar.com/api';

// ══════════════════════════════════════════════════════════════
// LEAD
// ══════════════════════════════════════════════════════════════
class Lead {
  final String id;
  final String name;
  final String companyName;
  final String phone;
  final String email;
  final String address;
  final String country;
  final String industry;
  final String source;

  /// `B2B` | `B2C` | '' when unset (legacy leads).
  final String clientType;
  final String requirement;
  final String status;
  final String assignTo;
  final DateTime? followUpDate;
  final String notes;
  final bool isLocal;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastReminderAt;
  final List<Attachment> attachments;
  final String? assignedToId;

  const Lead({
    this.assignedToId,
    this.attachments = const [],
    required this.id,
    required this.name,
    this.companyName = '',
    required this.phone,
    required this.email,
    this.address = '',
    this.country = '',
    this.industry = '',
    this.source = '',
    this.clientType = '',
    this.requirement = '',
    this.status = 'Hot',
    this.assignTo = '',
    this.followUpDate,
    this.notes = '',
    this.isLocal = false,
    this.createdAt,
    this.updatedAt,
    this.lastReminderAt,
  });

  static String _s(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  static String _normalizeClientType(dynamic v) {
    final raw = _s(v).trim();
    if (raw.isEmpty) return '';
    final u = raw.toUpperCase();
    if (u == 'B2B' || u == 'B2C') return u;
    return '';
  }

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
        id: _s(j['_id'] ?? j['id']),
        name: _s(j['name'] ?? j['leadName']),
        companyName: _s(j['companyName'] ?? j['company']),
        phone: _s(j['phone'] ?? j['phoneNumber']),
        email: _s(j['email']),
        address: _s(j['address']),
        country: _s(j['country']),
        industry: _s(j['industry']),
        source: _s(j['source']),
        clientType: _normalizeClientType(j['clientType']),
        requirement: _s(j['requirement']),
        status: _s(j['status'], 'Hot'),
        assignTo: _s(j['assignTo'] ?? j['assignedTo']),
        notes: _s(j['notes']),
        attachments: (j['attachments'] as List?)
                ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        isLocal: false,
        followUpDate: j['followUpDate'] != null
            ? DateTime.tryParse(j['followUpDate'].toString())
            : null,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'].toString())
            : null,
        updatedAt: j['updatedAt'] != null
            ? DateTime.tryParse(j['updatedAt'].toString())
            : null,
        lastReminderAt: j['lastReminderAt'] != null
            ? DateTime.tryParse(j['lastReminderAt'].toString())
            : null,
        assignedToId: j['assignedToId'] ??
            (j['assignTo'] is Map ? _s((j['assignTo'] as Map)['_id']) : null),
      );

  factory Lead.fromMap(Map<String, dynamic> map) {
    // parse attachments from JSON string stored in SQLite
    List<Attachment> attachments = [];
    final rawAttachments = map['attachments'];
    if (rawAttachments is String && rawAttachments.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAttachments);
        if (decoded is List) {
          attachments = decoded
              .whereType<Map>()
              .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (_) {}
    } else if (rawAttachments is List) {
      attachments = rawAttachments
          .whereType<Map>()
          .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return Lead(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      industry: map['industry']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      clientType: map['clientType']?.toString() ?? '',
      requirement: map['requirement']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Hot',
      assignTo: map['assignTo']?.toString() ?? '',
      assignedToId: map['assignedToId']?.toString(),
      followUpDate: map['followUpDate'] != null
          ? DateTime.tryParse(map['followUpDate'].toString())
          : null,
      notes: map['notes']?.toString() ?? '',
      attachments: attachments,
      isLocal: (map['isLocal'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
      lastReminderAt: map['lastReminderAt'] != null
          ? DateTime.tryParse(map['lastReminderAt'].toString())
          : null,
    );
  }

  // ✅ FIX #3: toMap() now includes clientType and attachments so they persist to SQLite
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'companyName': companyName,
        'phone': phone,
        'email': email,
        'address': address,
        'country': country,
        'industry': industry,
        'source': source,
        'clientType': clientType,
        'requirement': requirement,
        'status': status,
        'assignTo': assignTo,
        'assignedToId': assignedToId,
        'notes': notes,
        'isLocal': isLocal ? 1 : 0,
        'followUpDate': followUpDate?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'lastReminderAt': lastReminderAt?.toIso8601String(),
        // ✅ Serialize attachments to JSON string for SQLite storage
        'attachments': jsonEncode(attachments.map((a) => a.toJson()).toList()),
      };

  Map<String, dynamic> toJson() => {
        'name': name,
        'companyName': companyName,
        'phone': phone,
        'email': email,
        'address': address,
        'country': country,
        'industry': industry,
        'source': source,
        'clientType': clientType,
        'requirement': requirement,
        'status': status,
        'assignTo': assignTo,
        'notes': notes,
        if (followUpDate != null)
          'followUpDate': followUpDate!.toIso8601String(),
      };

  Lead copyWith({
    String? id,
    String? name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
    String? country,
    String? industry,
    String? source,
    String? clientType,
    String? requirement,
    String? status,
    String? assignTo,
    DateTime? followUpDate,
    String? notes,
    bool? isLocal,
    DateTime? updatedAt,
    DateTime? lastReminderAt,
    List<Attachment>? attachments,
    String? assignedToId,
  }) =>
      Lead(
        id: id ?? this.id,
        name: name ?? this.name,
        companyName: companyName ?? this.companyName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        country: country ?? this.country,
        industry: industry ?? this.industry,
        source: source ?? this.source,
        clientType: clientType ?? this.clientType,
        requirement: requirement ?? this.requirement,
        status: status ?? this.status,
        assignTo: assignTo ?? this.assignTo,
        followUpDate: followUpDate ?? this.followUpDate,
        notes: notes ?? this.notes,
        isLocal: isLocal ?? this.isLocal,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastReminderAt: lastReminderAt ?? this.lastReminderAt,
        attachments: attachments ?? this.attachments,
        assignedToId: assignedToId ?? this.assignedToId,
      );
}

// ══════════════════════════════════════════════════════════════
// ATTACHMENT
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

  // ✅ FIX #2: fromJson factory was completely missing — caused runtime crashes
  // wherever Attachment.fromJson() was called (Lead.fromJson, Lead.fromMap)
  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        name: j['name']?.toString() ?? '',
        path: j['path']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'type': type,
        'size': size,
      };
}

// ══════════════════════════════════════════════════════════════
// APP USER
// ══════════════════════════════════════════════════════════════
class AppUser {
  final String id,
      firstName,
      lastName,
      gender,
      phone,
      email,
      role,
      status,
      address;
  final DateTime? dob;
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool isLocal;
  final String? password;

  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.gender = '',
    this.dob,
    this.createdAt,
    required this.phone,
    required this.email,
    this.role = 'Sales Rep',
    this.status = 'Active',
    this.address = '',
    this.avatarUrl,
    this.isLocal = false,
    this.password,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}'
          '${lastName.isNotEmpty ? lastName[0] : ''}'
      .toUpperCase();

  static String _s(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _s(j['_id'] ?? j['id']),
        firstName: _s(j['firstName'] ?? j['first_name']),
        lastName: _s(j['lastName'] ?? j['last_name']),
        gender: _s(j['gender']),
        phone: _s(j['mobileNumber'] ?? j['phone'] ?? j['phoneNumber']),
        email: _s(j['email']),
        role: (j['role'] is Map)
            ? _s((j['role'] as Map)['_id'] ?? (j['role'] as Map)['id'], '')
            : _s(j['role'], ''),
        status: _s(j['status'], 'Active'),
        address: _s(j['address']),
        avatarUrl: j['profileImage'] is String
            ? j['profileImage'] as String
            : j['avatar'] is String
                ? j['avatar'] as String
                : j['avatarUrl'] is String
                    ? j['avatarUrl'] as String
                    : null,
        isLocal: false,
        dob: j['dateOfBirth'] != null
            ? DateTime.tryParse(j['dateOfBirth'].toString())
            : j['dob'] != null
                ? DateTime.tryParse(j['dob'].toString())
                : null,
        createdAt: j['createdAt'] != null // ← ADD THIS
            ? DateTime.tryParse(j['createdAt'].toString())
            : null,
      );

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: _s(m['id']),
        firstName: _s(m['firstName']),
        lastName: _s(m['lastName']),
        gender: _s(m['gender']),
        phone: _s(m['phone']),
        email: _s(m['email']),
        role: _s(m['role'], ''),
        status: _s(m['status'], 'Active'),
        address: _s(m['address']),
        avatarUrl: m['avatarUrl'] is String ? m['avatarUrl'] as String : null,
        isLocal: (m['isLocal'] as int? ?? 0) == 1,
        dob: m['dob'] != null ? DateTime.tryParse(m['dob'].toString()) : null,
        createdAt: m['createdAt'] != null // ← ADD THIS
            ? DateTime.tryParse(m['createdAt'].toString())
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'phone': phone,
        'email': email,
        'role': role,
        'status': status,
        'address': address,
        'avatarUrl': avatarUrl,
        'isLocal': isLocal ? 1 : 0,
        'dob': dob?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
      };

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'mobileNumber': phone,
        'email': email,
        'role': role,
        'status': status,
        'address': address,
        if (dob != null) 'dateOfBirth': dob!.toIso8601String(),
      };

  AppUser copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? gender,
    DateTime? dob,
    DateTime? createdAt,
    String? phone,
    String? email,
    String? role,
    String? status,
    String? address,
    String? avatarUrl,
    bool? isLocal,
    String? password,
  }) =>
      AppUser(
        id: id ?? this.id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        gender: gender ?? this.gender,
        dob: dob ?? this.dob,
        createdAt: createdAt ?? this.createdAt,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        role: role ?? this.role,
        status: status ?? this.status,
        address: address ?? this.address,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isLocal: isLocal ?? this.isLocal,
        password: password ?? this.password,
      );
}

// ══════════════════════════════════════════════════════════════
// APP ROLE
// ══════════════════════════════════════════════════════════════
class AppRole {
  final String id, name;
  final List<String> permissions;
  final bool isLocal;

  const AppRole({
    required this.id,
    required this.name,
    required this.permissions,
    this.isLocal = false,
  });

  static const _apiKeyToDisplay = <String, String>{
    'dashboard': 'Dashboard',
    'leads': 'Leads',
    'deals_all': 'Deals',
    'deals_pipeline': 'Deals',
    'invoices': 'Invoices',
    'proposal': 'Invoices',
    'activities': 'Deals',
    'activities_calendar': 'Deals',
    'activities_list': 'Deals',
    'users_roles': 'Users & Roles',
    'admin_access': 'Users & Roles',
    'email_chat': 'Leads',
    'whatsapp_chat': 'Leads',
    'reports': 'Dashboard',
  };

  factory AppRole.fromJson(Map<String, dynamic> json) {
    List<String> perms = [];
    final raw = json['permissions'];
    if (raw is Map) {
      final displayNames = <String>{};
      for (final entry in raw.entries) {
        if (entry.value == true) {
          final display = _apiKeyToDisplay[entry.key.toString()];
          if (display != null) displayNames.add(display);
        }
      }
      perms = displayNames.toList();
    } else if (raw is List) {
      perms = raw.map((e) => e.toString()).toList();
    }
    return AppRole(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      permissions: perms,
      isLocal: false,
    );
  }

  factory AppRole.fromMap(Map<String, dynamic> m) => AppRole(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        permissions:
            ((m['permissions'] is String) ? (m['permissions'] as String) : '')
                .split(',')
                .where((e) => e.isNotEmpty)
                .toList(),
        isLocal: (m['isLocal'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'permissions': permissions.join(','),
        'isLocal': isLocal ? 1 : 0,
      };

  Map<String, dynamic> toJson() => {'name': name, 'permissions': permissions};

  AppRole copyWith({
    String? id,
    String? name,
    List<String>? permissions,
    bool? isLocal,
  }) =>
      AppRole(
        id: id ?? this.id,
        name: name ?? this.name,
        permissions: permissions ?? this.permissions,
        isLocal: isLocal ?? this.isLocal,
      );
}

// ══════════════════════════════════════════════════════════════
// APP CONSTANTS
// ══════════════════════════════════════════════════════════════
class AppConstants {
  static const leadStatuses = ['Hot', 'Cold', 'Warm', 'Junk', 'Converted'];
  static const leadSources = [
    'Website',
    'Referral',
    'Social Media',
    'Email',
    'Phone',
    'Other',
  ];
  static const industries = [
    'IT',
    'Finance',
    'Healthcare',
    'Education',
    'Manufacturing',
    'Retail',
    'Other',
  ];
  static const permissions = [
    'Dashboard',
    'Leads',
    'Deals',
    'Invoices',
    'Users & Roles',
  ];
  static const genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const userStatuses = ['Active', 'Inactive'];
  static const countries = [
    'Afghanistan',
    'Albania',
    'Algeria',
    'Andorra',
    'Angola',
    'Antigua and Barbuda',
    'Argentina',
    'Armenia',
    'Australia',
    'Austria',
    'Azerbaijan',
    'Bahamas',
    'Bahrain',
    'Bangladesh',
    'Barbados',
    'Belarus',
    'Belgium',
    'Belize',
    'Benin',
    'Bhutan',
    'Bolivia',
    'Bosnia and Herzegovina',
    'Botswana',
    'Brazil',
    'Brunei',
    'Bulgaria',
    'Burkina Faso',
    'Burundi',
    'Cambodia',
    'Cameroon',
    'Canada',
    'Cape Verde',
    'Central African Republic',
    'Chad',
    'Chile',
    'China',
    'Colombia',
    'Comoros',
    'Congo',
    'Costa Rica',
    'Croatia',
    'Cuba',
    'Cyprus',
    'Czech Republic',
    'Denmark',
    'Djibouti',
    'Dominica',
    'Dominican Republic',
    'Ecuador',
    'Egypt',
    'El Salvador',
    'Equatorial Guinea',
    'Eritrea',
    'Estonia',
    'Eswatini',
    'Ethiopia',
    'Fiji',
    'Finland',
    'France',
    'Gabon',
    'Gambia',
    'Georgia',
    'Germany',
    'Ghana',
    'Greece',
    'Grenada',
    'Guatemala',
    'Guinea',
    'Guinea-Bissau',
    'Guyana',
    'Haiti',
    'Honduras',
    'Hungary',
    'Iceland',
    'India',
    'Indonesia',
    'Iran',
    'Iraq',
    'Ireland',
    'Israel',
    'Italy',
    'Jamaica',
    'Japan',
    'Jordan',
    'Kazakhstan',
    'Kenya',
    'Kiribati',
    'Kuwait',
    'Kyrgyzstan',
    'Laos',
    'Latvia',
    'Lebanon',
    'Lesotho',
    'Liberia',
    'Libya',
    'Liechtenstein',
    'Lithuania',
    'Luxembourg',
    'Madagascar',
    'Malawi',
    'Malaysia',
    'Maldives',
    'Mali',
    'Malta',
    'Marshall Islands',
    'Mauritania',
    'Mauritius',
    'Mexico',
    'Micronesia',
    'Moldova',
    'Monaco',
    'Mongolia',
    'Montenegro',
    'Morocco',
    'Mozambique',
    'Myanmar',
    'Namibia',
    'Nauru',
    'Nepal',
    'Netherlands',
    'New Zealand',
    'Nicaragua',
    'Niger',
    'Nigeria',
    'North Korea',
    'North Macedonia',
    'Norway',
    'Oman',
    'Pakistan',
    'Palau',
    'Panama',
    'Papua New Guinea',
    'Paraguay',
    'Peru',
    'Philippines',
    'Poland',
    'Portugal',
    'Qatar',
    'Romania',
    'Russia',
    'Rwanda',
    'Saint Kitts and Nevis',
    'Saint Lucia',
    'Saint Vincent and the Grenadines',
    'Samoa',
    'San Marino',
    'Sao Tome and Principe',
    'Saudi Arabia',
    'Senegal',
    'Serbia',
    'Seychelles',
    'Sierra Leone',
    'Singapore',
    'Slovakia',
    'Slovenia',
    'Solomon Islands',
    'Somalia',
    'South Africa',
    'South Korea',
    'South Sudan',
    'Spain',
    'Sri Lanka',
    'Sudan',
    'Suriname',
    'Sweden',
    'Switzerland',
    'Syria',
    'Taiwan',
    'Tajikistan',
    'Tanzania',
    'Thailand',
    'Timor-Leste',
    'Togo',
    'Tonga',
    'Trinidad and Tobago',
    'Tunisia',
    'Turkey',
    'Turkmenistan',
    'Tuvalu',
    'Uganda',
    'Ukraine',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'Uruguay',
    'Uzbekistan',
    'Vanuatu',
    'Vatican City',
    'Venezuela',
    'Vietnam',
    'Yemen',
    'Zambia',
    'Zimbabwe',
  ];
}

// ══════════════════════════════════════════════════════════════
// LOCAL DATABASE  ──  SQLite
// ✅ FIX #4 & #5: Removed stale LocalDatabase class entirely.
// Use LocalDb from lib/services/local_db.dart — it is the correct,
// versioned, migration-aware database singleton. Having two Database
// singletons pointing to the same file caused race conditions and
// schema divergence. All callers should import LocalDb.instance.
// ══════════════════════════════════════════════════════════════
