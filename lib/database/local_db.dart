// ╔══════════════════════════════════════════════════════════════╗
// ║              lib/services/local_db.dart                      ║
// ║                                                              ║
// ║  SQLite — all WRITE operations (create / update / delete)    ║
// ║  READ from API only — this stores local-only records         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:convert';

import 'package:crm_app/modals/modals.dart' show AppRole, AppUser, Lead;
import 'package:crm_app/screen/dashboard/ui/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'crm_local.db');
    return openDatabase(
      path,
      // v1 → leads, users, roles
      // v2 → + invoices
      // v3 → + deals
      // v4 → + leads.assignedToId
      // v5 → + leads.clientType, leads.attachments
      // v6 → + invoices.inrAmount, invoices.exchangeRate, invoices.isLocal
      // v7 → + leaderboard_cache, leaderboard_stats
      // v8 → + dashboard_cache, dashboard_pipeline
      version: 12,
      onCreate: (db, _) async {
        await _createLeadsTable(db);
        await _createUsersTable(db);
        await _createRolesTable(db);
        await _createInvoicesTable(db);
        await _createDealsTable(db);
        await _createLeaderboardTables(db);
        await _createDashboardTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createInvoicesTable(db);
        if (oldVersion < 3) await _createDealsTable(db);
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE leads ADD COLUMN assignedToId TEXT');
          } catch (_) {}
        }
        if (oldVersion < 5) {
          try {
            await db.execute(
                'ALTER TABLE leads ADD COLUMN clientType TEXT DEFAULT ""');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE leads ADD COLUMN attachments TEXT DEFAULT "[]"');
          } catch (_) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE invoices ADD COLUMN inrAmount REAL');
          } catch (_) {}
          try {
            await db
                .execute('ALTER TABLE invoices ADD COLUMN exchangeRate REAL');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE invoices ADD COLUMN isLocal INTEGER DEFAULT 1');
          } catch (_) {}
        }
        if (oldVersion < 7) {
          await _createLeaderboardTables(db);
        }
        if (oldVersion < 8) {
          await _createDashboardTables(db);
        }
        // Add inside onUpgrade, after the existing `if (oldVersion < 8)` block:
        if (oldVersion < 9) {
          try {
            await db.execute(
              'ALTER TABLE dashboard_cache ADD COLUMN invoicesJson TEXT NOT NULL DEFAULT "[]"',
            );
          } catch (_) {}
        }
        if (oldVersion < 10) {
          try {
            await db.execute(
              'ALTER TABLE dashboard_cache ADD COLUMN dealRowsJson TEXT NOT NULL DEFAULT "[]"',
            );
          } catch (_) {}
        }
        if (oldVersion < 11) {
          try {
            await db
                .execute('ALTER TABLE users ADD COLUMN gender TEXT DEFAULT ""');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE users ADD COLUMN dob TEXT');
          } catch (_) {}
          try {
            await db
                .execute('ALTER TABLE users ADD COLUMN phone TEXT DEFAULT ""');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE users ADD COLUMN status TEXT DEFAULT "Active"');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE users ADD COLUMN address TEXT DEFAULT ""');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE users ADD COLUMN avatarUrl TEXT');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE users ADD COLUMN isLocal INTEGER DEFAULT 1');
          } catch (_) {}
        }
        if (oldVersion < 12) {
          try {
            await db.execute(
                'ALTER TABLE users ADD COLUMN createdAt TEXT DEFAULT ""');
          } catch (_) {}
        }
      },
    );
  }

  // ── Table creators ────────────────────────────────────────────
  static Future<void> _createLeadsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS leads (
      id             TEXT PRIMARY KEY,
      name           TEXT NOT NULL,
      companyName    TEXT,
      phone          TEXT,
      email          TEXT,
      address        TEXT,
      country        TEXT,
      industry       TEXT,
      source         TEXT,
      clientType     TEXT DEFAULT '',
      requirement    TEXT,
      status         TEXT DEFAULT 'Hot',
      assignTo       TEXT,
      assignedToId   TEXT,
      followUpDate   TEXT,
      notes          TEXT,
      attachments    TEXT DEFAULT '[]',
      createdAt      TEXT,
      updatedAt      TEXT,
      lastReminderAt TEXT,
      isLocal        INTEGER DEFAULT 1
    )
  ''');

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id         TEXT PRIMARY KEY,
      firstName  TEXT NOT NULL DEFAULT '',
      lastName   TEXT NOT NULL DEFAULT '',
      gender     TEXT NOT NULL DEFAULT '',
      dob        TEXT,
      phone      TEXT NOT NULL DEFAULT '',
      email      TEXT NOT NULL DEFAULT '',
      role       TEXT NOT NULL DEFAULT '',
      status     TEXT NOT NULL DEFAULT 'Active',
      address    TEXT NOT NULL DEFAULT '',
      avatarUrl  TEXT,
      isLocal    INTEGER NOT NULL DEFAULT 1,
      createdAt  TEXT NOT NULL DEFAULT ''
    )
  ''');
  }

  static Future<void> _createDealsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS deals (
      id                TEXT PRIMARY KEY,
      leadId            TEXT,
      dealName          TEXT NOT NULL,
      assignToId        TEXT,
      assignToFirstName TEXT,
      assignToLastName  TEXT,
      assignToEmail     TEXT,
      assignToRole      TEXT,
      value             TEXT,
      currency          TEXT,
      clientType        TEXT,
      discountGiven     REAL DEFAULT 0,
      stage             TEXT,
      convertedAt       TEXT,
      notes             TEXT,
      phoneNumber       TEXT,
      email             TEXT,
      source            TEXT,
      companyName       TEXT,
      companyId         TEXT,
      companySize       TEXT,
      industry          TEXT,
      requirement       TEXT,
      address           TEXT,
      country           TEXT,
      lossReason        TEXT,
      lossNotes         TEXT,
      stageLostAt       TEXT,
      lostDate          TEXT,
      followUpDate      TEXT,
      followUpComment   TEXT,
      lastReminderAt    TEXT,
      attachments       TEXT,
      createdAt         TEXT,
      updatedAt         TEXT,
      isLocal           INTEGER DEFAULT 1,
      isSynced          INTEGER DEFAULT 0,
      syncAction        TEXT DEFAULT 'create'
    )
  ''');

  Future<void> _createRolesTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS roles (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL DEFAULT '',
      permissions TEXT NOT NULL DEFAULT '[]',
      isLocal     INTEGER NOT NULL DEFAULT 1
    )
  ''');
  }

  static Future<void> _createInvoicesTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS invoices (
      id            TEXT PRIMARY KEY,
      invoiceNo     TEXT,
      assignTo      TEXT,
      issueDate     TEXT,
      dueDate       TEXT,
      status        TEXT,
      taxType       TEXT,
      taxValue      REAL,
      discountType  TEXT,
      discountValue REAL,
      dealId        TEXT,
      dealName      TEXT,
      notes         TEXT,
      currency      TEXT,
      price         REAL,
      inrAmount     REAL,
      exchangeRate  REAL,
      createdAt     TEXT,
      isLocal       INTEGER DEFAULT 1
    )
  ''');

  /// v7 — Leaderboard cache tables.
  ///
  /// [leaderboard_entries]  — one row per salesperson per cache key.
  /// [leaderboard_meta]     — one row per cache key storing stats +
  ///                          dateRange + userRole + cachedAt timestamp.
  ///
  /// Cache key = "<filterType>|<startDate>|<endDate>"
  /// e.g. "range|2024-01-01|2024-01-31"  or  "allTime||"
  static Future<void> _createLeaderboardTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS leaderboard_entries (
        cacheKey               TEXT NOT NULL,
        id                     TEXT NOT NULL,
        name                   TEXT,
        email                  TEXT,
        avatar                 TEXT,
        totalLeads             INTEGER DEFAULT 0,
        convertedLeads         INTEGER DEFAULT 0,
        conversionRate         REAL    DEFAULT 0,
        conversionDisplay      TEXT,
        cumulativeTotalLeads   INTEGER DEFAULT 0,
        cumulativeConvertedLeads INTEGER DEFAULT 0,
        cumulativeDisplay      TEXT,
        streak                 INTEGER DEFAULT 0,
        productiveDays         INTEGER DEFAULT 0,
        workHours              TEXT,
        status                 TEXT,
        statusIcon             TEXT,
        isCurrentUser          INTEGER DEFAULT 0,
        PRIMARY KEY (cacheKey, id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leaderboard_meta (
        cacheKey              TEXT PRIMARY KEY,
        totalSalespeople      INTEGER DEFAULT 0,
        activeSalespeople     INTEGER DEFAULT 0,
        avgConversionRate     REAL    DEFAULT 0,
        totalLeads            INTEGER DEFAULT 0,
        totalConvertedLeads   INTEGER DEFAULT 0,
        cumulativeTotalLeads  INTEGER DEFAULT 0,
        dateRangeFormatted    TEXT,
        userRole              TEXT,
        cachedAt              TEXT
      )
    ''');
  }

  // ── Safe row converter: sqflite returns Map<String,Object?> ──
  static Map<String, dynamic> _row(Map<String, Object?> r) =>
      Map<String, dynamic>.from(r);

  // ══════════════════════════════════════════════════════════
  // LEADS
  // ══════════════════════════════════════════════════════════

  Future<Lead> insertLead(Lead lead) async {
    final db = await database;
    final newId = 'local_lead_${DateTime.now().millisecondsSinceEpoch}';
    final row = <String, dynamic>{
      'id': newId,
      'name': lead.name,
      'companyName': lead.companyName,
      'phone': lead.phone,
      'email': lead.email,
      'address': lead.address,
      'country': lead.country,
      'industry': lead.industry,
      'source': lead.source,
      'requirement': lead.requirement,
      'status': lead.status,
      'assignTo': lead.assignTo,
      'assignedToId': lead.assignedToId ?? '',
      'followUpDate': lead.followUpDate?.toIso8601String(),
      'notes': lead.notes,
      'clientType': lead.clientType,
      'attachments':
          jsonEncode(lead.attachments.map((a) => a.toJson()).toList()),
      'createdAt': DateTime.now().toIso8601String(),
      'isLocal': 1,
    };
    await db.insert('leads', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return Lead.fromMap(row);
  }

  Future<Lead> updateLead(String id, Lead lead) async {
    final db = await database;
    final row = <String, dynamic>{
      'name': lead.name,
      'companyName': lead.companyName,
      'phone': lead.phone,
      'email': lead.email,
      'address': lead.address,
      'country': lead.country,
      'industry': lead.industry,
      'source': lead.source,
      'requirement': lead.requirement,
      'status': lead.status,
      'assignTo': lead.assignTo,
      'assignedToId': lead.assignedToId ?? '',
      'followUpDate': lead.followUpDate?.toIso8601String(),
      'notes': lead.notes,
      'clientType': lead.clientType,
      'attachments':
          jsonEncode(lead.attachments.map((a) => a.toJson()).toList()),
      'updatedAt': DateTime.now().toIso8601String(),
      'isLocal': 1,
    };
    await db.update('leads', row, where: 'id = ?', whereArgs: [id]);
    return Lead.fromMap({...row, 'id': id});
  }

  Future<void> deleteLead(String id) async {
    final db = await database;
    await db.delete('leads', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Lead>> getLocalLeads() async {
    final db = await database;
    final rows = await db.query('leads', orderBy: 'createdAt DESC');
    return rows.map((r) => Lead.fromMap(_row(r))).toList();
  }

  Future<void> upsertLeadFromApi(Lead lead) async {
    final db = await database;
    final row = <String, dynamic>{
      'id': lead.id,
      'name': lead.name,
      'companyName': lead.companyName,
      'phone': lead.phone,
      'email': lead.email,
      'address': lead.address,
      'country': lead.country,
      'industry': lead.industry,
      'source': lead.source,
      'clientType': lead.clientType,
      'requirement': lead.requirement,
      'status': lead.status,
      'assignTo': lead.assignTo,
      'assignedToId': lead.assignedToId ?? '',
      'followUpDate': lead.followUpDate?.toIso8601String(),
      'notes': lead.notes,
      'attachments':
          jsonEncode(lead.attachments.map((a) => a.toJson()).toList()),
      'createdAt':
          lead.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updatedAt': lead.updatedAt?.toIso8601String(),
      'lastReminderAt': lead.lastReminderAt?.toIso8601String(),
      'isLocal': 0,
    };
    if ((row['id'] as String).isEmpty) return;
    await db.insert('leads', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ══════════════════════════════════════════════════════════
  // USERS
  // ══════════════════════════════════════════════════════════

  Future<AppUser> insertUser(AppUser user) async {
    final db = await database;
    final newId = 'local_user_${DateTime.now().millisecondsSinceEpoch}';
    final row = <String, dynamic>{
      'id': newId,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'gender': user.gender,
      'dob': user.dob?.toIso8601String(),
      'phone': user.phone,
      'email': user.email,
      'role': user.role,
      'status': user.status,
      'address': user.address,
      'avatarUrl': user.avatarUrl,
      'isLocal': 1,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await db.insert('users', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return AppUser.fromMap(row);
  }

  Future<AppUser> updateUser(String id, AppUser user) async {
    final db = await database;
    final row = <String, dynamic>{
      'firstName': user.firstName,
      'lastName': user.lastName,
      'gender': user.gender,
      'dob': user.dob?.toIso8601String(),
      'phone': user.phone,
      'email': user.email,
      'role': user.role,
      'status': user.status,
      'address': user.address,
      'avatarUrl': user.avatarUrl,
    };
    await db.update('users', row, where: 'id = ?', whereArgs: [id]);
    final updated = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (updated.isNotEmpty) if (updated.isNotEmpty)
      return AppUser.fromMap(Map<String, dynamic>.from(updated.first));

    return AppUser.fromMap({...row, 'id': id, 'isLocal': user.isLocal ? 1 : 0});
  }

  Future<void> deleteUser(String id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AppUser>> getAllCachedUsers() async {
    final db = await database;
    final rows = await db.query('users');
    return rows
        .map((r) => AppUser.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> upsertUserFromApi(AppUser user) async {
    final db = await database;
    final row = <String, dynamic>{
      'id': user.id,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'gender': user.gender,
      'dob': user.dob?.toIso8601String(),
      'phone': user.phone,
      'email': user.email,
      'role': user.role,
      'status': user.status,
      'address': user.address,
      'avatarUrl': user.avatarUrl,
      'isLocal': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };
    if ((row['id'] as String).isEmpty) return;
    await db.insert('users', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ══════════════════════════════════════════════════════════
  // ROLES
  // ══════════════════════════════════════════════════════════

  Future<AppRole> insertRole(AppRole role) async {
    final db = await database;
    final newId = 'local_role_${DateTime.now().millisecondsSinceEpoch}';
    final row = <String, dynamic>{
      'id': newId,
      'name': role.name,
      'permissions': role.permissions.join(','),
      'isLocal': 1,
    };
    await db.insert('roles', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return AppRole.fromMap(row);
  }

  Future<void> upsertRoleFromApi(AppRole role) async {
    final db = await database;
    final row = <String, dynamic>{
      'id': role.id,
      'name': role.name,
      'permissions': role.permissions.join(','),
      'isLocal': 0,
    };
    if ((row['id'] as String).isEmpty) return;
    await db.insert('roles', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRole(String id) async {
    final db = await database;
    await db.delete('roles', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AppRole>> getLocalRoles() async {
    final db = await database;
    final rows = await db.query('roles', where: 'isLocal = ?', whereArgs: [1]);
    return rows
        .map((r) => AppRole.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  // ══════════════════════════════════════════════════════════
  // INVOICES
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> insertInvoice(Map<String, dynamic> data) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM invoices')) ??
        0;
    final invoiceNo = 'INV-${(count + 1).toString().padLeft(3, '0')}';
    final newId = 'local_invoice_${DateTime.now().millisecondsSinceEpoch}';

    final row = <String, dynamic>{
      'id': newId,
      'invoiceNo': invoiceNo,
      'assignTo': data['assignTo'] ?? '',
      'issueDate': data['issueDate'] ?? '',
      'dueDate': data['dueDate'] ?? '',
      'status': data['status'] ?? 'Unpaid',
      'taxType': data['taxType'] ?? 'Zero Tax',
      'taxValue': _toDouble(data['taxValue']),
      'discountType': data['discountType'] ?? 'No Discount',
      'discountValue': _toDouble(data['discountValue']),
      'dealId': data['dealId'] ?? '',
      'dealName': data['dealName'] ?? '',
      'notes': data['notes'] ?? '',
      'currency': data['currency'] ?? 'INR',
      'price': _toDouble(data['price']),
      'inrAmount': data['inrAmount'],
      'exchangeRate': data['exchangeRate'],
      'createdAt': DateTime.now().toIso8601String(),
      'isLocal': 1,
    };

    await db.insert('invoices', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return row;
  }

  Future<void> updateInvoice(String id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'invoices',
      {
        'assignTo': data['assignTo'] ?? '',
        'issueDate': data['issueDate'] ?? '',
        'dueDate': data['dueDate'] ?? '',
        'status': data['status'] ?? 'Unpaid',
        'taxType': data['taxType'] ?? 'Zero Tax',
        'taxValue': _toDouble(data['taxValue']),
        'discountType': data['discountType'] ?? 'No Discount',
        'discountValue': _toDouble(data['discountValue']),
        'dealId': data['dealId'] ?? '',
        'dealName': data['dealName'] ?? '',
        'notes': data['notes'] ?? '',
        'currency': data['currency'] ?? 'INR',
        'price': _toDouble(data['price']),
        'inrAmount': data['inrAmount'],
        'exchangeRate': data['exchangeRate'],
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteInvoice(String id) async {
    final db = await database;
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getInvoices() async {
    final db = await database;
    final rows = await db.query('invoices', orderBy: 'createdAt DESC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> upsertInvoiceFromApi(Map<String, dynamic> data) async {
    final db = await database;

    final id = (data['_id'] ?? data['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final invoiceNo = (data['invoiceNo'] ??
            data['invoicenumber'] ??
            data['invoiceNumber'] ??
            data['invoice_no'] ??
            '')
        .toString();

    final row = <String, dynamic>{
      'id': id,
      'invoiceNo': invoiceNo,
      'assignTo': (data['assignTo'] ?? '').toString(),
      'issueDate': (data['issueDate'] ?? '').toString(),
      'dueDate': (data['dueDate'] ?? '').toString(),
      'status': (data['status'] ?? 'Unpaid').toString(),
      'taxType': (data['taxType'] ?? 'Zero Tax').toString(),
      'taxValue': _toDouble(data['taxValue']),
      'discountType': (data['discountType'] ?? 'No Discount').toString(),
      'discountValue': _toDouble(data['discountValue']),
      'dealId': (data['dealId'] ?? data['deal_id'] ?? '').toString(),
      'dealName': (data['dealName'] ?? data['deal_name'] ?? '').toString(),
      'notes': (data['notes'] ?? data['note'] ?? data['description'] ?? '')
          .toString(),
      'currency': (data['currency'] ?? 'INR').toString(),
      'price': _toDouble(data['price'] ?? data['subtotal'] ?? data['amount']),
      'inrAmount':
          data['inrAmount'] != null ? _toDouble(data['inrAmount']) : null,
      'exchangeRate':
          data['exchangeRate'] != null ? _toDouble(data['exchangeRate']) : null,
      'createdAt':
          (data['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      'isLocal': (data['isLocal'] is int)
          ? data['isLocal'] as int
          : ((data['isLocal'] == true) ? 1 : 0),
    };

    await db.insert('invoices', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ══════════════════════════════════════════════════════════
  // DEALS
  // ══════════════════════════════════════════════════════════

  String _str(dynamic v, [String fb = '']) => v == null ? fb : v.toString();

  String _extractAssignedName(dynamic assignTo) {
    if (assignTo is Map) {
      final fn = _str(assignTo['firstName']).trim();
      final ln = _str(assignTo['lastName']).trim();
      return [fn, ln].where((e) => e.isNotEmpty).join(' ');
    }
    return _str(assignTo).trim();
  }

  Map<String, dynamic> _dealToRow(
    Map<String, dynamic> deal, {
    required bool isSynced,
    required String syncAction,
  }) {
    final now = DateTime.now().toIso8601String();
    final assign = deal['assignTo'] ?? deal['assignedTo'];
    final attachments = deal['attachments'];

    return <String, dynamic>{
      'id': _str(deal['_id'] ?? deal['id']),
      'leadId': _str(deal['leadId']),
      'dealName': _str(deal['dealName'] ?? deal['name']),
      'assignToId': _str(deal['assignToId'] ??
          deal['assignedToId'] ??
          (assign is Map ? assign['_id'] : null)),
      'assignToFirstName': assign is Map
          ? _str(assign['firstName'])
          : _extractAssignedName(assign),
      'assignToLastName': assign is Map ? _str(assign['lastName']) : '',
      'assignToEmail': assign is Map ? _str(assign['email']) : '',
      'assignToRole': assign is Map ? _str(assign['role']) : '',
      'value': _str(deal['value'] ?? deal['dealValue'] ?? deal['amount']),
      'currency': _str(deal['currency'], 'INR'),
      'clientType': _str(deal['clientType']),
      'discountGiven': (deal['discountGiven'] as num?)?.toDouble() ?? 0,
      'stage': _str(deal['stage'], 'Qualification'),
      'convertedAt': _str(deal['convertedAt']),
      'notes': _str(deal['notes']),
      'phoneNumber': _str(deal['phoneNumber'] ?? deal['phone']),
      'email': _str(deal['email']),
      'source': _str(deal['source']),
      'companyName': _str(deal['companyName'] ?? deal['company']),
      'companyId': _str(deal['companyId']),
      'companySize': _str(deal['companySize']),
      'industry': _str(deal['industry']),
      'requirement': _str(deal['requirement']),
      'address': _str(deal['address']),
      'country': _str(deal['country']),
      'lossReason': _str(deal['lossReason']),
      'lossNotes': _str(deal['lossNotes']),
      'stageLostAt': _str(deal['stageLostAt']),
      'lostDate': _str(deal['lostDate']),
      'followUpDate': _str(deal['followUpDate']),
      'followUpComment': _str(deal['followUpComment']),
      'lastReminderAt': _str(deal['lastReminderAt']),
      'attachments': attachments == null ? '[]' : jsonEncode(attachments),
      'createdAt': _str(deal['createdAt'], now),
      'updatedAt': _str(deal['updatedAt'], now),
      'isLocal': 1,
      'isSynced': isSynced ? 1 : 0,
      'syncAction': syncAction,
    };
  }

  Future<void> upsertDealFromApi(Map<String, dynamic> deal) async {
    final db = await database;
    final row = _dealToRow(deal, isSynced: true, syncAction: 'none');
    if (_str(row['id']).isEmpty) return;
    await db.insert('deals', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> replaceDealsFromApi(List<Map<String, dynamic>> deals) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('deals');
      for (final deal in deals) {
        final row = _dealToRow(deal, isSynced: true, syncAction: 'none');
        if (_str(row['id']).isEmpty) continue;
        await txn.insert('deals', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deleteDealHard(String id) async {
    final db = await database;
    await db.delete('deals', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getLocalDealMaps() async {
    final db = await database;
    final rows = await db.query('deals', orderBy: 'createdAt DESC');

    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      dynamic attachments = const <dynamic>[];
      final rawAttachments = m['attachments'];
      if (rawAttachments is String && rawAttachments.isNotEmpty) {
        try {
          attachments = jsonDecode(rawAttachments);
        } catch (_) {
          attachments = const <dynamic>[];
        }
      }

      return <String, dynamic>{
        '_id': _str(m['id']),
        'id': _str(m['id']),
        'dealName': _str(m['dealName']),
        'companyName': _str(m['companyName']),
        'phoneNumber': _str(m['phoneNumber']),
        'email': _str(m['email']),
        'stage': _str(m['stage']),
        'industry': _str(m['industry']),
        'source': _str(m['source']),
        'clientType': _str(m['clientType']),
        'country': _str(m['country']),
        'address': _str(m['address']),
        'assignTo': {
          '_id': _str(m['assignToId']),
          'firstName': _str(m['assignToFirstName']),
          'lastName': _str(m['assignToLastName']),
          'email': _str(m['assignToEmail']),
          'role': _str(m['assignToRole']),
        },
        'assignToName':
            '${_str(m['assignToFirstName'])} ${_str(m['assignToLastName'])}'
                .trim(),
        'notes': _str(m['notes']),
        'currency': _str(m['currency'], 'INR'),
        'value': _str(m['value']),
        'requirement': _str(m['requirement']),
        'companySize': _str(m['companySize']),
        'discountGiven': m['discountGiven'] ?? 0,
        'lossReason': _str(m['lossReason']),
        'lossNotes': _str(m['lossNotes']),
        'followUpDate': _str(m['followUpDate']),
        'followUpComment': _str(m['followUpComment']),
        'lastReminderAt': _str(m['lastReminderAt']),
        'createdAt': _str(m['createdAt']),
        'updatedAt': _str(m['updatedAt']),
        'attachments': attachments is List ? attachments : const <dynamic>[],
      };
    }).toList();
  }

  Future<void> insertDeal(Map<String, dynamic> data) async {
    final db = await database;
    if ((data['_id'] ?? data['id'] ?? '').toString().isEmpty) {
      data = {
        ...data,
        '_id': 'local_deal_${DateTime.now().millisecondsSinceEpoch}',
      };
    }
    final row = _dealToRow(data, isSynced: false, syncAction: 'create');
    await db.insert('deals', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateLocalDeal(String id, Map<String, dynamic> data) async {
    final db = await database;
    final assign = data['assignTo'] ?? data['assignedTo'];

    await db.update(
      'deals',
      {
        'dealName': _str(data['dealName'] ?? data['name']),
        'phoneNumber': _str(data['phoneNumber'] ?? data['phone']),
        'email': _str(data['email']),
        'companyName': _str(data['companyName'] ?? data['company']),
        'companySize': _str(data['companySize']),
        'value': _str(data['value'] ?? data['dealValue'] ?? data['amount']),
        'currency': _str(data['currency'], 'INR'),
        'clientType': _str(data['clientType']),
        'stage': _str(data['stage'], 'Qualification'),
        'notes': _str(data['notes']),
        'source': _str(data['source']),
        'industry': _str(data['industry']),
        'requirement': _str(data['requirement']),
        'address': _str(data['address']),
        'country': _str(data['country']),
        'assignToId': _str(assign is Map
            ? (assign['_id'] ?? assign['id'])
            : data['assignToId']),
        'assignToFirstName': assign is Map ? _str(assign['firstName']) : '',
        'assignToLastName': assign is Map ? _str(assign['lastName']) : '',
        'assignToEmail': assign is Map ? _str(assign['email']) : '',
        'assignToRole': assign is Map ? _str(assign['role']) : '',
        'followUpDate': _str(data['followUpDate']),
        'followUpComment': _str(data['followUpComment']),
        'discountGiven': (data['discountGiven'] as num?)?.toDouble() ?? 0,
        'lossReason': _str(data['lossReason']),
        'lossNotes': _str(data['lossNotes']),
        'attachments': data['attachments'] == null
            ? '[]'
            : jsonEncode(data['attachments']),
        'updatedAt': DateTime.now().toIso8601String(),
        'isSynced': 0,
        'syncAction': 'update',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteLocalDeal(String id) async {
    final db = await database;
    await db.delete('deals', where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════
  // LEADERBOARD CACHE
  // ══════════════════════════════════════════════════════════

  /// Builds a deterministic cache key from filter params.
  static String leaderboardCacheKey({
    String? filterType,
    String? startDate,
    String? endDate,
  }) =>
      '${filterType ?? "allTime"}|${startDate ?? ""}|${endDate ?? ""}';

  /// Persist a full [LeaderboardResponse] to SQLite.
  /// Replaces all previous entries for the same cache key atomically.
  Future<void> cacheLeaderboard({
    required String cacheKey,
    required Map<String, dynamic> responseJson,
  }) async {
    final db = await database;

    final stats = responseJson['stats'] as Map<String, dynamic>? ?? {};
    final dateRange = responseJson['dateRange'] as Map<String, dynamic>? ?? {};
    final entries = (responseJson['data'] as List<dynamic>? ?? []);

    await db.transaction((txn) async {
      // 1. Replace meta row
      await txn.insert(
        'leaderboard_meta',
        {
          'cacheKey': cacheKey,
          'totalSalespeople': stats['totalSalespeople'] ?? 0,
          'activeSalespeople': stats['activeSalespeople'] ?? 0,
          'avgConversionRate': (stats['avgConversionRate'] ?? 0).toDouble(),
          'totalLeads': stats['totalLeads'] ?? 0,
          'totalConvertedLeads': stats['totalConvertedLeads'] ?? 0,
          'cumulativeTotalLeads': stats['cumulativeTotalLeads'] ?? 0,
          'dateRangeFormatted': dateRange['formatted'] ?? '',
          'userRole': responseJson['userRole'] ?? '',
          'cachedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Drop stale entries for this key, then re-insert
      await txn.delete(
        'leaderboard_entries',
        where: 'cacheKey = ?',
        whereArgs: [cacheKey],
      );

      for (final e in entries) {
        final p = e as Map<String, dynamic>;
        await txn.insert(
          'leaderboard_entries',
          {
            'cacheKey': cacheKey,
            'id': p['id'] ?? '',
            'name': p['name'] ?? '',
            'email': p['email'] ?? '',
            'avatar': p['avatar'] ?? '',
            'totalLeads': p['totalLeads'] ?? 0,
            'convertedLeads': p['convertedLeads'] ?? 0,
            'conversionRate': (p['conversionRate'] ?? 0).toDouble(),
            'conversionDisplay': p['conversionDisplay'] ?? '0.0%',
            'cumulativeTotalLeads': p['cumulativeTotalLeads'] ?? 0,
            'cumulativeConvertedLeads': p['cumulativeConvertedLeads'] ?? 0,
            'cumulativeDisplay': p['cumulativeDisplay'] ?? '0.0%',
            'streak': p['streak'] ?? 0,
            'productiveDays': p['productiveDays'] ?? 0,
            'workHours': p['workHours'] ?? '—',
            'status': p['status'] ?? 'inactive',
            'statusIcon': p['statusIcon'] ?? '💤',
            'isCurrentUser': (p['isCurrentUser'] == true) ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Read cached leaderboard for a given cache key.
  /// Returns null if nothing is cached yet.
  Future<Map<String, dynamic>?> getCachedLeaderboard(String cacheKey) async {
    final db = await database;

    final metaRows = await db.query(
      'leaderboard_meta',
      where: 'cacheKey = ?',
      whereArgs: [cacheKey],
    );
    if (metaRows.isEmpty) return null;
    final meta = _row(metaRows.first);

    final entryRows = await db.query(
      'leaderboard_entries',
      where: 'cacheKey = ?',
      whereArgs: [cacheKey],
    );

    return {
      'success': true,
      'userRole': meta['userRole'] ?? '',
      'dateRange': {'formatted': meta['dateRangeFormatted'] ?? ''},
      'stats': {
        'totalSalespeople': meta['totalSalespeople'] ?? 0,
        'activeSalespeople': meta['activeSalespeople'] ?? 0,
        'avgConversionRate': meta['avgConversionRate'] ?? 0.0,
        'totalLeads': meta['totalLeads'] ?? 0,
        'totalConvertedLeads': meta['totalConvertedLeads'] ?? 0,
        'cumulativeTotalLeads': meta['cumulativeTotalLeads'] ?? 0,
      },
      'data': entryRows.map((r) {
        final m = _row(r);
        return {
          'id': m['id'],
          'name': m['name'],
          'email': m['email'],
          'avatar': m['avatar'],
          'totalLeads': m['totalLeads'],
          'convertedLeads': m['convertedLeads'],
          'conversionRate': m['conversionRate'],
          'conversionDisplay': m['conversionDisplay'],
          'cumulativeTotalLeads': m['cumulativeTotalLeads'],
          'cumulativeConvertedLeads': m['cumulativeConvertedLeads'],
          'cumulativeDisplay': m['cumulativeDisplay'],
          'streak': m['streak'],
          'productiveDays': m['productiveDays'],
          'workHours': m['workHours'],
          'status': m['status'],
          'statusIcon': m['statusIcon'],
          'isCurrentUser': m['isCurrentUser'] == 1,
        };
      }).toList(),
      '_cachedAt': meta['cachedAt'],
    };
  }

  /// Wipe all leaderboard cache (useful for forced refresh / logout).
  Future<void> clearLeaderboardCache() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('leaderboard_entries');
      await txn.delete('leaderboard_meta');
    });
  }

  // ══════════════════════════════════════════════════════════
  // UTILS
  // ══════════════════════════════════════════════════════════

  Future<void> close() async {
    final db = _db;
    if (db != null) await db.close();
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? 0;
  }

  // ════════════════════════════════════════════════════════════
  // DASHBOARD TABLES
  // ════════════════════════════════════════════════════════════

  Future<void> _createDashboardTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dashboard_cache (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        userId        TEXT    NOT NULL DEFAULT '',
        totalLeads    INTEGER NOT NULL DEFAULT 0,
        totalDeals    INTEGER NOT NULL DEFAULT 0,
        dealsWon      INTEGER NOT NULL DEFAULT 0,
        pendingLeads  INTEGER NOT NULL DEFAULT 0,
        leadsChange   REAL    NOT NULL DEFAULT 0,
        dealsChange   REAL    NOT NULL DEFAULT 0,
        paidRevenue   REAL    NOT NULL DEFAULT 0,
        unpaidRevenue REAL    NOT NULL DEFAULT 0,
        totalRevenue  REAL    NOT NULL DEFAULT 0,
        filterRange   TEXT    NOT NULL DEFAULT 'last7',
        filterMonth   INTEGER,
        filterYear    INTEGER,
        leadsJson     TEXT    NOT NULL DEFAULT '[]',
        invoicesJson  TEXT    NOT NULL DEFAULT '[]',
        dealRowsJson  TEXT    NOT NULL DEFAULT '[]',
        cachedAt      TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dashboard_pipeline (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        cacheId  INTEGER NOT NULL REFERENCES dashboard_cache(id) ON DELETE CASCADE,
        stage    TEXT    NOT NULL,
        count    INTEGER NOT NULL DEFAULT 0,
        value    REAL    NOT NULL DEFAULT 0,
        currency TEXT    NOT NULL DEFAULT 'INR'
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dashboard_cache_userId '
      'ON dashboard_cache(userId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dashboard_pipeline_cacheId '
      'ON dashboard_pipeline(cacheId)',
    );
  }

  // ════════════════════════════════════════════════════════════
  // DASHBOARD: PUBLIC API
  // ════════════════════════════════════════════════════════════

  /// Persist a loaded dashboard state so the next cold-start can
  /// render instantly while the network fetch runs in the background.
  /// Calling this replaces any previous snapshot for [userId].
  Future<void> saveDashboard({
    required String userId,
    required DashboardSummary summary,
    required List<PipelineStage> pipeline,
    required List<Lead> recentLeads,
    required List<InvoiceRecord> invoices,
    required List<Map<String, dynamic>> allDealRows, // ← ADD
    required String filterRange,
    int? filterMonth,
    int? filterYear,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Remove previous snapshot for this user
      final old = await txn.query(
        'dashboard_cache',
        columns: ['id'],
        where: 'userId = ?',
        whereArgs: [userId],
      );
      for (final row in old) {
        await txn.delete(
          'dashboard_pipeline',
          where: 'cacheId = ?',
          whereArgs: [row['id']],
        );
      }
      await txn.delete(
        'dashboard_cache',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      // Encode recent leads safely
      String leadsJson = '[]';
      try {
        leadsJson = jsonEncode(recentLeads.map((l) => l.toJson()).toList());
      } catch (_) {}

      // Encode invoices safely
      String invoicesJson = '[]';
      try {
        invoicesJson = jsonEncode(invoices.map((i) => i.toJson()).toList());
      } catch (_) {}

      // ← ADD THIS BLOCK RIGHT HERE
      String dealRowsJson = '[]';

      try {
        final safeRows = allDealRows.map((e) {
          return Map<String, dynamic>.from(e);
        }).toList();

        dealRowsJson = jsonEncode(safeRows);

        debugPrint("SAFE DEAL ROWS SAVED => $dealRowsJson");
      } catch (e) {
        debugPrint("Dashboard cache error => $e");
      }

      // Insert fresh snapshot
      final cacheId = await txn.insert('dashboard_cache', {
        'userId': userId,
        'totalLeads': summary.totalLeads,
        'totalDeals': summary.totalDeals,
        'dealsWon': summary.dealsWon,
        'pendingLeads': summary.pendingLeads,
        'leadsChange': summary.leadsChange,
        'dealsChange': summary.dealsChange,
        'paidRevenue': summary.paidRevenue,
        'unpaidRevenue': summary.unpaidRevenue,
        'totalRevenue': summary.totalRevenue,
        'filterRange': filterRange,
        'filterMonth': filterMonth,
        'filterYear': filterYear,
        'leadsJson': leadsJson,
        'invoicesJson': invoicesJson,
        'dealRowsJson': dealRowsJson,
        'cachedAt': DateTime.now().toIso8601String(),
      });

      // Insert pipeline rows
      for (final s in pipeline) {
        await txn.insert('dashboard_pipeline', {
          'cacheId': cacheId,
          'stage': s.stage,
          'count': s.count,
          'value': s.value,
          'currency': s.currency,
        });
      }
    });
  }

  /// Load the last-saved dashboard for [userId].
  /// Returns null only when no cache exists at all.
  /// No time expiry — always returns whatever was last saved online.
  Future<
      ({
        DashboardSummary summary,
        List<PipelineStage> pipeline,
        List<Lead> recentLeads,
        List<InvoiceRecord> invoices,
        List<Map<String, dynamic>> allDealRows, // ← ADD
        String filterRange,
        int? filterMonth,
        int? filterYear,
        DateTime cachedAt,
      })?> loadDashboard({required String userId}) async {
    final db = await database;

    final rows = await db.query(
      'dashboard_cache',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'cachedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final cachedAt = DateTime.tryParse(row['cachedAt'] as String? ?? '');
    if (cachedAt == null) return null;

    // No maxAge check — cache lives forever.
    // Offline always shows whatever was last visible online.

    final cacheId = row['id'] as int;
    final pipeRows = await db.query(
      'dashboard_pipeline',
      where: 'cacheId = ?',
      whereArgs: [cacheId],
      orderBy: 'id ASC',
    );

    final summary = DashboardSummary(
      totalLeads: (row['totalLeads'] as int?) ?? 0,
      totalDeals: (row['totalDeals'] as int?) ?? 0,
      dealsWon: (row['dealsWon'] as int?) ?? 0,
      pendingLeads: (row['pendingLeads'] as int?) ?? 0,
      leadsChange: (row['leadsChange'] as num?)?.toDouble() ?? 0,
      dealsChange: (row['dealsChange'] as num?)?.toDouble() ?? 0,
      paidRevenue: (row['paidRevenue'] as num?)?.toDouble() ?? 0,
      unpaidRevenue: (row['unpaidRevenue'] as num?)?.toDouble() ?? 0,
      totalRevenue: (row['totalRevenue'] as num?)?.toDouble() ?? 0,
    );

    final pipeline = pipeRows
        .map((r) => PipelineStage(
              stage: r['stage'] as String? ?? '',
              count: (r['count'] as int?) ?? 0,
              value: (r['value'] as num?)?.toDouble() ?? 0,
              currency: r['currency'] as String? ?? 'INR',
            ))
        .toList();

    List<Lead> recentLeads = [];
    try {
      final decoded = jsonDecode(row['leadsJson'] as String? ?? '[]') as List;
      recentLeads = decoded
          .whereType<Map>()
          .map((m) => Lead.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {}

    List<InvoiceRecord> invoices = [];
    try {
      final decoded =
          jsonDecode(row['invoicesJson'] as String? ?? '[]') as List;
      invoices = decoded
          .whereType<Map>()
          .map((m) => InvoiceRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {}

    List<Map<String, dynamic>> allDealRows = [];
    try {
      final decoded =
          jsonDecode(row['dealRowsJson'] as String? ?? '[]') as List;
      allDealRows = decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {}

    return (
      summary: summary,
      pipeline: pipeline,
      recentLeads: recentLeads,
      invoices: invoices,
      allDealRows: allDealRows, // ← added
      filterRange: row['filterRange'] as String? ?? 'last7',
      filterMonth: row['filterMonth'] as int?,
      filterYear: row['filterYear'] as int?,
      cachedAt: cachedAt,
    );
  }

  /// Hard-delete cached dashboard rows for [userId].
  /// Pipeline rows are removed automatically via ON DELETE CASCADE.
  Future<void> clearDashboardCache(String userId) async {
    final db = await database;
    await db.delete(
      'dashboard_cache',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }
}
