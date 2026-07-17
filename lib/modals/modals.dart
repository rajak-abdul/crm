// ╔══════════════════════════════════════════════════════════════╗
// ║                   lib/models/modals.dart                     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:convert'; // ✅ FIX #1: was missing — needed for jsonDecode in Lead.fromMap


/// ══════════════════════════════════════════════════════════════
/// LEAD STATUS ENUM
/// ══════════════════════════════════════════════════════════════
/// Minimal user reference used by rejectedBy / convertedBy.
/// Note: these payloads may omit `email` (unlike assignTo), so keep it nullable.
class UserRef {
  final String id;
  final String firstName;
  final String lastName;
  final String? email;

  const UserRef({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.email,
  });

  String get fullName {
    final full = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    return full.isNotEmpty ? full : (email ?? id);
  }

  factory UserRef.fromJson(Map<String, dynamic> j) => UserRef(
        id: (j['_id'] ?? '').toString(),
        firstName: (j['firstName'] ?? '').toString(),
        lastName: (j['lastName'] ?? '').toString(),
        email: j['email']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'firstName': firstName,
        'lastName': lastName,
        if (email != null) 'email': email,
      };

  /// Handles the case where the field might arrive as just an ID string
  /// (e.g. from some legacy or partially-populated responses).
  static UserRef? tryParse(dynamic v) {
    if (v == null) return null;
    if (v is Map) return UserRef.fromJson(Map<String, dynamic>.from(v));
    if (v is String && v.isNotEmpty) return UserRef(id: v);
    return null;
  }
}

class StatusHistoryEntry {
  final String id;
  final String status;
  final DateTime? changedAt;

  const StatusHistoryEntry({
    required this.id,
    required this.status,
    this.changedAt,
  });

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> j) =>
      StatusHistoryEntry(
        id: (j['_id'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        changedAt: j['changedAt'] != null
            ? DateTime.tryParse(j['changedAt'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'status': status,
        if (changedAt != null) 'changedAt': changedAt!.toIso8601String(),
      };
}

// ══════════════════════════════════════════════════════════════
// LEAD
// ══════════════════════════════════════════════════════════════
class FollowUpNote {
  final String id;
  final String note;
  final DateTime? createdAt;

  const FollowUpNote({
    required this.id,
    required this.note,
    this.createdAt,
  });

  factory FollowUpNote.fromJson(Map<String, dynamic> j) => FollowUpNote(
        id: (j['_id'] ?? '').toString(),
        note: (j['note'] ?? '').toString(),
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'note': note,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}

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

  /// Display name of assigned salesman, e.g. "Kishore S".
  final String assignTo;
  final DateTime? followUpDate;
  final String notes;
  final bool isLocal;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastReminderAt;
  final List<Attachment> attachments;
  final String? assignedToId;
  final String? assignedToEmail;

  final List<FollowUpNote> followUpNotes;
  final bool isActive;
  final String rejectionReason;
  final List<StatusHistoryEntry> statusHistory;
  final UserRef? rejectedBy;
  final DateTime? rejectedAt;
  final UserRef? convertedBy;

  const Lead({
    this.assignedToId,
    this.assignedToEmail,
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
    this.followUpNotes = const [],
    this.isActive = true,
    this.rejectionReason = '',
    this.statusHistory = const [],
    this.rejectedBy,
    this.rejectedAt,
    this.convertedBy,
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

  /// `assignTo` can arrive as:
  /// - a Map (new backend): { _id, firstName, lastName, email, role }
  /// - a plain string (legacy/local cache)
  /// - null
  static String _assignToName(dynamic v) {
    if (v == null) return '';
    if (v is Map) {
      final first = _s(v['firstName']).trim();
      final last = _s(v['lastName']).trim();
      final full = [first, last].where((s) => s.isNotEmpty).join(' ');
      if (full.isNotEmpty) return full;
      return _s(v['email'] ?? v['_id']);
    }
    return v.toString();
  }

  static String _assignToId(dynamic v) {
  if (v is Map<String, dynamic>) {
    return _s(v['_id']);
  }
  return '';
}

  static String? _assignToEmail(dynamic v) {
    if (v is Map) return _s(v['email']);
    return null;
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
        assignTo: _assignToName(j['assignTo']),
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
        assignedToId: _s(j['assignedToId'], '').isNotEmpty
            ? _s(j['assignedToId'])
            : _assignToId(j['assignTo']),
        assignedToEmail: _assignToEmail(j['assignTo']),
        followUpNotes: (j['followUpNotes'] as List?)
                ?.whereType<Map>()
                .map((e) => FollowUpNote.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        isActive: j['isActive'] is bool ? j['isActive'] as bool : true,
        rejectionReason: _s(j['rejectionReason']),
        statusHistory: (j['statusHistory'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    StatusHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        rejectedBy: UserRef.tryParse(j['rejectedBy']),
        rejectedAt: j['rejectedAt'] != null
            ? DateTime.tryParse(j['rejectedAt'].toString())
            : null,
        convertedBy: UserRef.tryParse(j['convertedBy']),
      
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

    // parse followUpNotes from JSON string stored in SQLite
    List<FollowUpNote> followUpNotes = [];
    final rawNotes = map['followUpNotes'];
    if (rawNotes is String && rawNotes.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNotes);
        if (decoded is List) {
          followUpNotes = decoded
              .whereType<Map>()
              .map((e) => FollowUpNote.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (_) {}
    }

    List<StatusHistoryEntry> statusHistory = [];
    final rawHistory = map['statusHistory'];
    if (rawHistory is String && rawHistory.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawHistory);
        if (decoded is List) {
          statusHistory = decoded
              .whereType<Map>()
              .map((e) =>
                  StatusHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (_) {}
    }

    UserRef? decodeUserRef(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return UserRef.fromJson(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
      return null;
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
      assignedToEmail: map['assignedToEmail']?.toString(),
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
      followUpNotes: followUpNotes,
      isActive: (map['isActive'] as int? ?? 1) == 1,
      rejectionReason: map['rejectionReason']?.toString() ?? '',
      statusHistory: statusHistory,
      rejectedBy: decodeUserRef(map['rejectedBy']),
      rejectedAt: map['rejectedAt'] != null
          ? DateTime.tryParse(map['rejectedAt'].toString())
          : null,
      convertedBy: decodeUserRef(map['convertedBy']),
    );
  }

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
        'assignedToEmail': assignedToEmail,
        'notes': notes,
        'isLocal': isLocal ? 1 : 0,
        'followUpDate': followUpDate?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'lastReminderAt': lastReminderAt?.toIso8601String(),
        'attachments': jsonEncode(attachments.map((a) => a.toJson()).toList()),
        'followUpNotes':
            jsonEncode(followUpNotes.map((n) => n.toJson()).toList()),
        'isActive': isActive ? 1 : 0,
        'rejectionReason': rejectionReason,
        'statusHistory':
            jsonEncode(statusHistory.map((s) => s.toJson()).toList()),
        'rejectedBy': rejectedBy != null ? jsonEncode(rejectedBy!.toJson()) : null,
        'rejectedAt': rejectedAt?.toIso8601String(),
        'convertedBy':
            convertedBy != null ? jsonEncode(convertedBy!.toJson()) : null,

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
    String? assignedToEmail,
    List<FollowUpNote>? followUpNotes,
    bool? isActive,
    String? rejectionReason,
    List<StatusHistoryEntry>? statusHistory,
    UserRef? rejectedBy,
    DateTime? rejectedAt,
    UserRef? convertedBy,
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
        assignedToEmail: assignedToEmail ?? this.assignedToEmail,
        followUpNotes: followUpNotes ?? this.followUpNotes,
        isActive: isActive ?? this.isActive,
        rejectionReason: rejectionReason ?? this.rejectionReason,
         statusHistory: statusHistory ?? this.statusHistory,
        rejectedBy: rejectedBy ?? this.rejectedBy,
        rejectedAt: rejectedAt ?? this.rejectedAt,
        convertedBy: convertedBy ?? this.convertedBy,
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
  'deals_pipeline': 'Deals Pipeline',
  'invoices': 'Invoices',
  'users_roles': 'Users & Roles',
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

  Map<String, dynamic> toJson() {
  final permissionMap = <String, bool>{
    'dashboard': permissions.contains('Dashboard'),
    'leads': permissions.contains('Leads'),

    'deals_all': permissions.contains('Deals'),
    'deals_pipeline': permissions.contains('Deals Pipeline'),

    'invoices': permissions.contains('Invoices'),

    'users_roles':
        permissions.contains('Users & Roles'),

    
  };

  return {
    'name': name,
    'permissions': permissionMap,
  };
}

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
  'Deals Pipeline',
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
