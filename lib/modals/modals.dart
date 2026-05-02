// ╔══════════════════════════════════════════════════════════════╗
// ║                   lib/models/modals.dart                     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

const kBaseUrl = 'https://sales.stagingzar.com/api';

// ══════════════════════════════════════════════════════════════
// LEAD
// ══════════════════════════════════════════════════════════════
class Lead {
  final String    id;
  final String    name;
  final String    companyName;
  final String    phone;
  final String    email;
  final String    address;
  final String    country;
  final String    industry;
  final String    source;
  /// `B2B` | `B2C` | '' when unset (legacy leads).
  final String    clientType;
  final String    requirement;
  final String    status;
  final String    assignTo;
  final DateTime? followUpDate;
  final String    notes;
  final bool      isLocal;
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
    this.companyName  = '',
    required this.phone,
    required this.email,
    this.address      = '',
    this.country      = '',
    this.industry     = '',
    this.source       = '',
    this.clientType   = '',
    this.requirement  = '',
    this.status       = 'Hot',
    this.assignTo     = '',
    this.followUpDate,
    this.notes        = '',
    this.isLocal      = false,
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
        id:           _s(j['_id']         ?? j['id']),
        name:         _s(j['name']        ?? j['leadName']),
        companyName:  _s(j['companyName'] ?? j['company']),
        phone:        _s(j['phone']       ?? j['phoneNumber']),
        email:        _s(j['email']),
        address:      _s(j['address']),
        country:      _s(j['country']),
        industry:     _s(j['industry']),
        source:       _s(j['source']),
        clientType:   _normalizeClientType(j['clientType']),
        requirement:  _s(j['requirement']),
        status:       _s(j['status'], 'Hot'),
        assignTo:     _s(j['assignTo']    ?? j['assignedTo']),
        notes:        _s(j['notes']),
        attachments: (j['attachments'] as List?)
        ?.map((e) => Attachment.fromJson(e))
        .toList() ??
    [],
        isLocal:      false,
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
            (j['assignTo'] is Map
                ? _s((j['assignTo'] as Map)['_id'])
                : null),
      );
      

  factory Lead.fromMap(Map<String, dynamic> m) => Lead(
        id:           _s(m['id']),
        name:         _s(m['name']),
        companyName:  _s(m['companyName']),
        phone:        _s(m['phone']),
        email:        _s(m['email']),
        address:      _s(m['address']),
        country:      _s(m['country']),
        industry:     _s(m['industry']),
        source:       _s(m['source']),
        clientType:   _normalizeClientType(m['clientType']),
        requirement:  _s(m['requirement']),
        status:       _s(m['status'], 'Hot'),
        assignTo:     _s(m['assignTo']),
        notes:        _s(m['notes']),
        isLocal:      (m['isLocal'] as int? ?? 0) == 1,
        followUpDate: m['followUpDate'] != null
            ? DateTime.tryParse(m['followUpDate'].toString())
            : null,
        createdAt: m['createdAt'] != null
            ? DateTime.tryParse(m['createdAt'].toString())
            : null,
        updatedAt: m['updatedAt'] != null
            ? DateTime.tryParse(m['updatedAt'].toString())
            : null,
        lastReminderAt: m['lastReminderAt'] != null
            ? DateTime.tryParse(m['lastReminderAt'].toString())
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id':           id,
        'name':         name,
        'companyName':  companyName,
        'phone':        phone,
        'email':        email,
        'address':      address,
        'country':      country,
        'industry':     industry,
        'source':       source,
        'clientType':   clientType,
        'requirement':  requirement,
        'status':       status,
        'assignTo':     assignTo,
        'notes':        notes,
        'isLocal':      isLocal ? 1 : 0,
        'followUpDate': followUpDate.toString(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'lastReminderAt': lastReminderAt?.toIso8601String(),
      };

  Map<String, dynamic> toJson() => {
        'name':        name,
        'companyName': companyName,
        'phone':       phone,
        'email':       email,
        'address':     address,
        'country':     country,
        'industry':    industry,
        'source':      source,
        'clientType':  clientType,
        'requirement': requirement,
        'status':      status,
        'assignTo':    assignTo,
        'notes':       notes,
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
  List<Attachment>? attachments, // ✅ ADD THIS
  String? assignedToId,
}) =>
    Lead(
      id:           id           ?? this.id,
      name:         name         ?? this.name,
      companyName:  companyName  ?? this.companyName,
      phone:        phone        ?? this.phone,
      email:        email        ?? this.email,
      address:      address      ?? this.address,
      country:      country      ?? this.country,
      industry:     industry     ?? this.industry,
      source:       source       ?? this.source,
      clientType:   clientType   ?? this.clientType,
      requirement:  requirement  ?? this.requirement,
      status:       status       ?? this.status,
      assignTo:     assignTo     ?? this.assignTo,
      followUpDate: followUpDate ?? this.followUpDate,
      notes:        notes        ?? this.notes,
      isLocal:      isLocal      ?? this.isLocal,
      createdAt:    createdAt,
      updatedAt:    updatedAt ?? this.updatedAt,
      lastReminderAt: lastReminderAt ?? this.lastReminderAt,
      attachments:  attachments ?? this.attachments,
      assignedToId: assignedToId ?? this.assignedToId,
    );
}

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

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: json['type'] ?? '',
      size: json['size'] ?? 0,
    );
  }
}
// ══════════════════════════════════════════════════════════════
// APP USER
// ══════════════════════════════════════════════════════════════
class AppUser {
  final String    id, firstName, lastName, gender,
                  phone, email, role, status, address;
  final DateTime? dob;
  final String?   avatarUrl;
  final bool      isLocal;
  final String?   password;

  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.gender    = '',
    this.dob,
    required this.phone,
    required this.email,
    this.role      = 'Sales Rep',
    this.status    = 'Active',
    this.address   = '',
    this.avatarUrl,
    this.isLocal   = false,
    this.password,
  });

  String get fullName  => '$firstName $lastName'.trim();
  String get initials  =>
      '${firstName.isNotEmpty ? firstName[0] : ''}'
      '${lastName.isNotEmpty  ? lastName[0]  : ''}'.toUpperCase();

  static String _s(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id:        _s(j['_id']       ?? j['id']),
        firstName: _s(j['firstName'] ?? j['first_name']),
        lastName:  _s(j['lastName']  ?? j['last_name']),
        gender:    _s(j['gender']),
        // ✅ FIX: API returns 'mobileNumber' — also fall back to phone/phoneNumber
        phone: _s(
          j['mobileNumber'] ?? j['phone'] ?? j['phoneNumber'],
        ),
        email:  _s(j['email']),
        // role can be a populated object {_id, name} or a raw id string
        role: (j['role'] is Map)
            ? _s((j['role'] as Map)['_id'] ?? (j['role'] as Map)['id'], '')
            : _s(j['role'], ''),
        status:    _s(j['status'], 'Active'),
        address:   _s(j['address']),
        // ✅ FIX: API uses 'profileImage' key
        avatarUrl: j['profileImage'] is String
            ? j['profileImage'] as String
            : j['avatar'] is String
                ? j['avatar'] as String
                : j['avatarUrl'] is String
                    ? j['avatarUrl'] as String
                    : null,
        isLocal: false,
        // ✅ FIX: API returns 'dateOfBirth', not 'dob'
        dob: j['dateOfBirth'] != null
            ? DateTime.tryParse(j['dateOfBirth'].toString())
            : j['dob'] != null
                ? DateTime.tryParse(j['dob'].toString())
                : null,
      );

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id:        _s(m['id']),
        firstName: _s(m['firstName']),
        lastName:  _s(m['lastName']),
        gender:    _s(m['gender']),
        phone:     _s(m['phone']),   // SQLite local column is 'phone'
        email:     _s(m['email']),
        role:      _s(m['role'], ''),
        status:    _s(m['status'], 'Active'),
        address:   _s(m['address']),
        avatarUrl: m['avatarUrl'] is String ? m['avatarUrl'] as String : null,
        isLocal:   (m['isLocal'] as int? ?? 0) == 1,
        dob: m['dob'] != null
            ? DateTime.tryParse(m['dob'].toString())
            : null,
      );

  /// SQLite row — password intentionally excluded
  Map<String, dynamic> toMap() => {
        'id':        id,
        'firstName': firstName,
        'lastName':  lastName,
        'gender':    gender,
        'phone':     phone,
        'email':     email,
        'role':      role,
        'status':    status,
        'address':   address,
        'avatarUrl': avatarUrl,
        'isLocal':   isLocal ? 1 : 0,
        'dob':       dob?.toIso8601String(),
      };

  /// API payload — uses correct server field names
  Map<String, dynamic> toJson() => {
        'firstName':    firstName,
        'lastName':     lastName,
        'gender':       gender,
        'mobileNumber': phone,
        'email':        email,
        'role':         role,
        'status':       status,
        'address':      address,
        if (dob != null) 'dateOfBirth': dob!.toIso8601String(),
      };

  AppUser copyWith({
    String?   id,
    String?   firstName,
    String?   lastName,
    String?   gender,
    DateTime? dob,
    String?   phone,
    String?   email,
    String?   role,
    String?   status,
    String?   address,
    String?   avatarUrl,
    bool?     isLocal,
    String?   password,
  }) =>
      AppUser(
        id:        id        ?? this.id,
        firstName: firstName ?? this.firstName,
        lastName:  lastName  ?? this.lastName,
        gender:    gender    ?? this.gender,
        dob:       dob       ?? this.dob,
        phone:     phone     ?? this.phone,
        email:     email     ?? this.email,
        role:      role      ?? this.role,
        status:    status    ?? this.status,
        address:   address   ?? this.address,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isLocal:   isLocal   ?? this.isLocal,
        password:  password  ?? this.password,
      );
}

// ══════════════════════════════════════════════════════════════
// APP ROLE
// ══════════════════════════════════════════════════════════════
class AppRole {
  final String       id, name;
  final List<String> permissions;
  final bool         isLocal;

  const AppRole({
    required this.id,
    required this.name,
    required this.permissions,
    this.isLocal = false,
  });

  static const _apiKeyToDisplay = <String, String>{
    'dashboard':           'Dashboard',
    'leads':               'Leads',
    'deals_all':           'Deals',
    'deals_pipeline':      'Deals',
    'invoices':            'Invoices',
    'proposal':            'Invoices',
    'activities':          'Deals',
    'activities_calendar': 'Deals',
    'activities_list':     'Deals',
    'users_roles':         'Users & Roles',
    'admin_access':        'Users & Roles',
    'email_chat':          'Leads',
    'whatsapp_chat':       'Leads',
    'reports':             'Dashboard',
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
      id:          json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name:        json['name']?.toString() ?? '',
      permissions: perms,
      isLocal:     false,
    );
  }

  factory AppRole.fromMap(Map<String, dynamic> m) => AppRole(
        id:   m['id']   ?? '',
        name: m['name'] ?? '',
        permissions: ((m['permissions'] is String)
                ? (m['permissions'] as String)
                : '')
            .split(',')
            .where((e) => e.isNotEmpty)
            .toList(),
        isLocal: (m['isLocal'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id':          id,
        'name':        name,
        'permissions': permissions.join(','),
        'isLocal':     isLocal ? 1 : 0,
      };

  Map<String, dynamic> toJson() =>
      {'name': name, 'permissions': permissions};

  AppRole copyWith({
    String?       id,
    String?       name,
    List<String>? permissions,
    bool?         isLocal,
  }) =>
      AppRole(
        id:          id          ?? this.id,
        name:        name        ?? this.name,
        permissions: permissions ?? this.permissions,
        isLocal:     isLocal     ?? this.isLocal,
      );
}

// ══════════════════════════════════════════════════════════════
// APP CONSTANTS
// ══════════════════════════════════════════════════════════════
class AppConstants {
  static const leadStatuses = ['Hot', 'Cold', 'Warm', 'Junk', 'Converted'];
  static const leadSources  = [
    'Website', 'Referral', 'Social Media', 'Email', 'Cold Call', 'Others',
  ];
  static const industries = [
    'Technology', 'Finance & Banking', 'Healthcare', 'Retail & E-commerce',
    'Manufacturing', 'Real Estate', 'Education', 'Media & Entertainment',
    'Hospitality & Tourism', 'Logistics & Supply Chain', 'Energy & Utilities',
    'Agriculture', 'Construction', 'Automotive', 'Pharmaceuticals',
    'Telecommunications', 'Legal Services', 'Marketing & Advertising',
    'Non-Profit', 'Government', 'Other',
  ];
  static const permissions = [
    'Dashboard', 'Leads', 'Deals', 'Invoices', 'Users & Roles',
  ];
  static const genders      = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const userStatuses = ['Active', 'Inactive'];
  static const countries    = [
    'Afghanistan', 'Albania', 'Algeria', 'Argentina', 'Australia', 'Austria',
    'Bangladesh', 'Belgium', 'Brazil', 'Canada', 'Chile', 'China', 'Colombia',
    'Czech Republic', 'Denmark', 'Egypt', 'Finland', 'France', 'Germany',
    'Ghana', 'Greece', 'Hungary', 'India', 'Indonesia', 'Iran', 'Iraq',
    'Ireland', 'Israel', 'Italy', 'Japan', 'Jordan', 'Kenya', 'Malaysia',
    'Mexico', 'Morocco', 'Netherlands', 'New Zealand', 'Nigeria', 'Norway',
    'Pakistan', 'Philippines', 'Poland', 'Portugal', 'Romania', 'Russia',
    'Saudi Arabia', 'Singapore', 'South Africa', 'South Korea', 'Spain',
    'Sri Lanka', 'Sweden', 'Switzerland', 'Thailand', 'Turkey', 'UAE',
    'Ukraine', 'United Kingdom', 'United States', 'Vietnam', 'Other',
  ];
}

// ══════════════════════════════════════════════════════════════
// LOCAL DATABASE  ──  SQLite
// ══════════════════════════════════════════════════════════════
class LocalDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'crm_local.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE leads (
            id           TEXT PRIMARY KEY,
            name         TEXT NOT NULL,
            companyName  TEXT,
            phone        TEXT NOT NULL,
            email        TEXT NOT NULL,
            address      TEXT,
            country      TEXT,
            industry     TEXT,
            source       TEXT,
            requirement  TEXT,
            status       TEXT DEFAULT "Hot",
            assignTo     TEXT,
            notes        TEXT,
            followUpDate TEXT,
            createdAt    TEXT,
            isLocal      INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE users (
            id         TEXT PRIMARY KEY,
            firstName  TEXT NOT NULL,
            lastName   TEXT NOT NULL,
            gender     TEXT,
            dob        TEXT,
            phone      TEXT NOT NULL,
            email      TEXT NOT NULL,
            role       TEXT,
            status     TEXT DEFAULT "Active",
            address    TEXT,
            avatarUrl  TEXT,
            isLocal    INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE roles (
            id          TEXT PRIMARY KEY,
            name        TEXT NOT NULL,
            permissions TEXT,
            isLocal     INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }
}