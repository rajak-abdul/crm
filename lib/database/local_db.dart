// ╔══════════════════════════════════════════════════════════════╗
// ║              lib/services/local_db.dart                      ║
// ║                                                              ║
// ║  SQLite — all WRITE operations (create / update / delete)    ║
// ║  READ from API only — this stores local-only records         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/modals/modals.dart' show AppRole, AppUser, Lead;
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
    final dir  = await getDatabasesPath();
    final path = join(dir, 'crm_local.db');
    return openDatabase(
      path,
      // ── Bump version when adding new tables ──────────────
      // v1 → leads, users, roles
      // v2 → + invoices
      version: 2,
      onCreate: (db, _) async {
        await _createLeadsTable(db);
        await _createUsersTable(db);
        await _createRolesTable(db);
        await _createInvoicesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Users upgrading from v1 → add invoices table only
        if (oldVersion < 2) await _createInvoicesTable(db);
      },
    );
  }

  // ── Table creators (called from onCreate + onUpgrade) ────
  static Future<void> _createLeadsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS leads (
      id           TEXT PRIMARY KEY,
      name         TEXT NOT NULL,
      companyName  TEXT,
      phone        TEXT,
      email        TEXT,
      address      TEXT,
      country      TEXT,
      industry     TEXT,
      source       TEXT,
      requirement  TEXT,
      status       TEXT DEFAULT 'Hot',
      assignTo     TEXT,
      followUpDate TEXT,
      notes        TEXT,
      createdAt    TEXT,
      isLocal      INTEGER DEFAULT 1
    )
  ''');

  static Future<void> _createUsersTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id          TEXT PRIMARY KEY,
      firstName   TEXT NOT NULL,
      lastName    TEXT NOT NULL,
      gender      TEXT,
      dob         TEXT,
      phone       TEXT,
      email       TEXT,
      role        TEXT,
      status      TEXT DEFAULT 'Active',
      address     TEXT,
      avatarUrl   TEXT,
      isLocal     INTEGER DEFAULT 1
    )
  ''');

  static Future<void> _createRolesTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS roles (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL,
      permissions TEXT,
      isLocal     INTEGER DEFAULT 1
    )
  ''');

  static Future<void> _createInvoicesTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS invoices (
      id            TEXT PRIMARY KEY,
      invoiceNo     TEXT NOT NULL,
      assignTo      TEXT,
      issueDate     TEXT,
      dueDate       TEXT,
      status        TEXT DEFAULT 'Unpaid',
      taxType       TEXT DEFAULT 'Zero Tax',
      taxValue      REAL DEFAULT 0,
      discountType  TEXT DEFAULT 'No Discount',
      discountValue REAL DEFAULT 0,
      dealId        TEXT,
      dealName      TEXT,
      price         REAL DEFAULT 0,
      notes         TEXT,
      currency      TEXT DEFAULT 'INR',
      createdAt     TEXT
    )
  ''');

  // ── Safe row converter: sqflite returns Map<String,Object?> ──
  // Must convert to Map<String,dynamic> before passing to fromMap
  static Map<String, dynamic> _row(Map<String, Object?> r) =>
      Map<String, dynamic>.from(r);

  // ══════════════════════════════════════════════════════════
  // LEADS
  // ══════════════════════════════════════════════════════════

  Future<Lead> insertLead(Lead lead) async {
    final db    = await database;
    final newId = 'local_lead_${DateTime.now().millisecondsSinceEpoch}';
    final row   = <String, dynamic>{
      'id':           newId,
      'name':         lead.name,
      'companyName':  lead.companyName,
      'phone':        lead.phone,
      'email':        lead.email,
      'address':      lead.address,
      'country':      lead.country,
      'industry':     lead.industry,
      'source':       lead.source,
      'requirement':  lead.requirement,
      'status':       lead.status,
      'assignTo':     lead.assignTo,
      'followUpDate': lead.followUpDate?.toIso8601String(),
      'notes':        lead.notes,
      'createdAt':    DateTime.now().toIso8601String(),
      'isLocal':      1,
    };
    await db.insert('leads', row, conflictAlgorithm: ConflictAlgorithm.replace);
    // Use fromMap (not fromJson) since this is DB-shaped data
    return Lead.fromMap(row);
  }

  Future<Lead> updateLead(String id, Lead lead) async {
    final db  = await database;
    final row = <String, dynamic>{
      'name':         lead.name,
      'companyName':  lead.companyName,
      'phone':        lead.phone,
      'email':        lead.email,
      'address':      lead.address,
      'country':      lead.country,
      'industry':     lead.industry,
      'source':       lead.source,
      'requirement':  lead.requirement,
      'status':       lead.status,
      'assignTo':     lead.assignTo,
      'followUpDate': lead.followUpDate?.toIso8601String(),
      'notes':        lead.notes,
      'isLocal':      1,
    };
    await db.update('leads', row, where: 'id = ?', whereArgs: [id]);
    return Lead.fromMap({...row, 'id': id});
  }

  Future<void> deleteLead(String id) async {
    final db = await database;
    await db.delete('leads', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Lead>> getLocalLeads() async {
    final db   = await database;
    final rows = await db.query('leads', orderBy: 'createdAt DESC');
    // ✅ Convert Map<String,Object?> → Map<String,dynamic> then use fromMap
    return rows.map((r) => Lead.fromMap(_row(r))).toList();
  }

  // ══════════════════════════════════════════════════════════
  // USERS
  // ══════════════════════════════════════════════════════════

  Future<AppUser> insertUser(AppUser user) async {
    final db    = await database;
    final newId = 'local_user_${DateTime.now().millisecondsSinceEpoch}';
    final row   = <String, dynamic>{
      'id':        newId,
      'firstName': user.firstName,
      'lastName':  user.lastName,
      'gender':    user.gender,
      'dob':       user.dob?.toIso8601String(),
      'phone':     user.phone,
      'email':     user.email,
      'role':      user.role,
      'status':    user.status,
      'address':   user.address,
      'avatarUrl': user.avatarUrl,
      'isLocal':   1,
    };
    await db.insert('users', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return AppUser.fromMap(row);
  }

  Future<AppUser> updateUser(String id, AppUser user) async {
    final db  = await database;
    final row = <String, dynamic>{
      'firstName': user.firstName,
      'lastName':  user.lastName,
      'gender':    user.gender,
      'dob':       user.dob?.toIso8601String(),
      'phone':     user.phone,
      'email':     user.email,
      'role':      user.role,
      'status':    user.status,
      'address':   user.address,
    };
    await db.update('users', row, where: 'id = ?', whereArgs: [id]);
    return AppUser.fromMap({...row, 'id': id});
  }

  Future<void> deleteUser(String id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AppUser>> getLocalUsers() async {
    final db   = await database;
    final rows = await db.query('users');
    // ✅ Convert Map<String,Object?> → Map<String,dynamic> then use fromMap
    return rows.map((r) => AppUser.fromMap(_row(r))).toList();
  }

  // ══════════════════════════════════════════════════════════
  // ROLES
  // ══════════════════════════════════════════════════════════

  Future<AppRole> insertRole(AppRole role) async {
    final db    = await database;
    final newId = 'local_role_${DateTime.now().millisecondsSinceEpoch}';
    final row   = <String, dynamic>{
      'id':          newId,
      'name':        role.name,
      'permissions': role.permissions.join(','),
      'isLocal':     1,
    };
    await db.insert('roles', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return AppRole(id: newId, name: role.name, permissions: role.permissions);
  }

  Future<void> deleteRole(String id) async {
    final db = await database;
    await db.delete('roles', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AppRole>> getLocalRoles() async {
    final db   = await database;
    final rows = await db.query('roles');
    // ✅ Safe: no 'as String' casts — use toString() + null-safe checks
    return rows.map((r) {
      final m     = _row(r);
      final perms = m['permissions'];
      return AppRole(
        id:          m['id']?.toString()   ?? '',
        name:        m['name']?.toString() ?? '',
        permissions: (perms is String && perms.isNotEmpty)
            ? perms.split(',').where((e) => e.isNotEmpty).toList()
            : [],
      );
    }).toList();
  }

  // ══════════════════════════════════════════════════════════
  // INVOICES  (all ops are local SQLite — no API writes)
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> insertInvoice(Map<String, dynamic> data) async {
    final db = await database;

    // Auto-generate sequential invoice number  INV-001, INV-002 …
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM invoices')) ?? 0;
    final invoiceNo = 'INV-${(count + 1).toString().padLeft(3, '0')}';

    final newId = 'inv_${DateTime.now().millisecondsSinceEpoch}';
    final row   = <String, dynamic>{
      'id':            newId,
      'invoiceNo':     invoiceNo,
      'assignTo':      data['assignTo']      ?? '',
      'issueDate':     data['issueDate']     ?? '',
      'dueDate':       data['dueDate']       ?? '',
      'status':        data['status']        ?? 'Unpaid',
      'taxType':       data['taxType']       ?? 'Zero Tax',
      'taxValue':      data['taxValue']      ?? 0.0,
      'discountType':  data['discountType']  ?? 'No Discount',
      'discountValue': data['discountValue'] ?? 0.0,
      'dealId':        data['dealId']        ?? '',
      'dealName':      data['dealName']      ?? '',
      'price':         data['price']         ?? 0.0,
      'notes':         data['notes']         ?? '',
      'currency':      data['currency']      ?? 'INR',
      'createdAt':     DateTime.now().toIso8601String(),
    };
    await db.insert('invoices', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return row;
  }

  Future<void> updateInvoice(String id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'invoices',
      {
        'assignTo':      data['assignTo']      ?? '',
        'issueDate':     data['issueDate']     ?? '',
        'dueDate':       data['dueDate']       ?? '',
        'status':        data['status']        ?? 'Unpaid',
        'taxType':       data['taxType']       ?? 'Zero Tax',
        'taxValue':      data['taxValue']      ?? 0.0,
        'discountType':  data['discountType']  ?? 'No Discount',
        'discountValue': data['discountValue'] ?? 0.0,
        'dealId':        data['dealId']        ?? '',
        'dealName':      data['dealName']      ?? '',
        'price':         data['price']         ?? 0.0,
        'notes':         data['notes']         ?? '',
        'currency':      data['currency']      ?? 'INR',
      },
      where:     'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteInvoice(String id) async {
    final db = await database;
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getInvoices() async {
    final db   = await database;
    final rows = await db.query('invoices', orderBy: 'createdAt DESC');
    // Convert Map<String,Object?> → Map<String,dynamic>
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ══════════════════════════════════════════════════════════
  // UTILS
  // ══════════════════════════════════════════════════════════

  Future<void> close() async {
    final db = _db;
    if (db != null) await db.close();
  }
}