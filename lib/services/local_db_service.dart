import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._init();
  static Database? _database;

  LocalDatabaseService._init();

  Future<Database> get database async {                                                  
    if (_database != null) return _database!;
    _database = await _initDB('offline_kaascan_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event TEXT,
          details TEXT,
          timestamp TEXT
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    // School configuration
    await db.execute('''
      CREATE TABLE IF NOT EXISTS config (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Sync activity logs for debugging
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event TEXT,
        details TEXT,
        timestamp TEXT
      )
    ''');

    // Students registry for offline lookup
    await db.execute('''
      CREATE TABLE IF NOT EXISTS students (
        student_id TEXT PRIMARY KEY,
        name TEXT,
        card_id TEXT,
        balance REAL,
        photo_url TEXT,
        pin_hash TEXT,
        daily_limit REAL,
        updated_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_student_card ON students (card_id)');
    
    // Offline transactions queue
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        amount REAL,
        timestamp TEXT,
        nonce TEXT,
        signature TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_synced ON offline_transactions (synced, student_id)');
  }

  // --- CONFIG ---
  Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.insert('config', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getConfig(String key) async {
    final db = await database;
    final res = await db.query('config', where: 'key = ?', whereArgs: [key]);
    return res.isNotEmpty ? res.first['value'] as String : null;
  }

  // --- STUDENTS ---
  Future<void> upsertStudents(List<Map<String, dynamic>> students) async {
    final db = await database;
    final batch = db.batch();
    for (var s in students) {
      String? rawCardId = s['card_id']?.toString();
      // Normalize card_id: Uppercase + Strip Colons (common in different NFC readers)
      String? normalizedCardId = rawCardId?.toUpperCase();

      batch.insert('students', {
        'student_id': (s['student_id'] ?? s['id'])?.toString(),
        'name': s['student_name'] ?? s['name'],
        'card_id': normalizedCardId,
        'balance': (s['balance'] ?? s['account_balance'] ?? 0.0) is int 
            ? (s['balance'] ?? s['account_balance'] as int).toDouble() 
            : (s['balance'] ?? s['account_balance'] ?? 0.0),
        'photo_url': s['student_photo_url'] ?? s['photo_url'],
        'pin_hash': s['student_pin_hash'] ?? s['pin_hash'],
        'daily_limit': (s['daily_limit'] ?? 0.0) is int 
            ? (s['daily_limit'] as int).toDouble() 
            : (s['daily_limit'] ?? 0.0),
        'updated_at': s['updated_at']?.toString()
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearStudents() async {
    final db = await database;
    await db.delete('students');
  }

  Future<Map<String, dynamic>?> getStudentByCard(String cardId) async {
    final db = await database;
    // Normalize input similarly: Strip colons and force uppercase
    final normalizedId = cardId.toUpperCase();
    debugPrint('🔎 DB getStudentByCard: searching for "$normalizedId" (raw="$cardId")');
    
    final results = await db.rawQuery(
      'SELECT * FROM students WHERE UPPER(card_id) = ?',
      [normalizedId],
    );
    
    if (results.isEmpty) {
      debugPrint('❌ DB getStudentByCard: No student found for "$normalizedId"');
      return null;
    }
    
    debugPrint('✅ DB getStudentByCard: Found student "${results.first['name']}"');
    final student = Map<String, dynamic>.from(results.first);
    return await applyPendingTransactions(student);
  }

  Future<Map<String, dynamic>?> getStudentById(String studentId) async {
    final db = await database;
    final results = await db.query('students', where: 'student_id = ?', whereArgs: [studentId]);
    if (results.isEmpty) return null;

    final student = Map<String, dynamic>.from(results.first);
    return await applyPendingTransactions(student);
  }

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    final db = await database;
    return await db.query('students', orderBy: 'name ASC');
  }

  /// Adjusts the synced balance by subtracting pending offline purchases
  Future<Map<String, dynamic>> applyPendingTransactions(Map<String, dynamic> student) async {
    final db = await database;
    
    // Support both online ('id') and local ('student_id') keys
    final studentId = (student['student_id'] ?? student['id'])?.toString();
    if (studentId == null) return student;
    
    final pending = await db.query(
      'offline_transactions', 
      columns: ['SUM(amount) as total_pending'],
      where: 'student_id = ? AND synced = 0',
      whereArgs: [studentId]
    );

    double pendingAmount = 0.0;
    if (pending.isNotEmpty && pending.first['total_pending'] != null) {
      pendingAmount = (pending.first['total_pending'] as num).toDouble();
    }

    if (pendingAmount > 0) {
      // Support both local ('balance') and some online variants ('account_balance')
      double currentBalance = (student['balance'] ?? student['account_balance'] ?? 0.0) is int 
          ? (student['balance'] ?? student['account_balance'] as int).toDouble() 
          : (student['balance'] ?? student['account_balance'] ?? 0.0);
      
      student['balance'] = currentBalance - pendingAmount;
    }
    
    return student;
  }

  // --- TRANSACTIONS ---
  Future<int> queueTransaction(Map<String, dynamic> tx) async {
    final db = await database;
    return await db.insert('offline_transactions', {
      'student_id': tx['student_id'],
      'amount': tx['amount'],
      'timestamp': tx['timestamp'] ?? DateTime.now().toIso8601String(),
      'nonce': tx['nonce'],
      'signature': tx['signature'],
      'synced': 0
    });
  }

  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    final db = await database;
    return await db.query('offline_transactions', where: 'synced = 0');
  }

  Future<bool> hasPendingTransaction(String studentId) async {
    final db = await database;
    final results = await db.query(
      'offline_transactions',
      where: 'student_id = ? AND synced = 0',
      whereArgs: [studentId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update('offline_transactions', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database; 
    return await db.query('offline_transactions', orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getEnrichedTransactions() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        t.*, 
        s.name as student_name, 
        s.photo_url as student_photo,
        s.student_id as student_id_db
      FROM offline_transactions t
      LEFT JOIN students s ON t.student_id = s.student_id
      ORDER BY t.timestamp DESC
    ''');
  }

  Future<void> clearTransactions() async {
    final db = await database;
    await db.delete('offline_transactions');
  }

  // --- LOGGING ---
  Future<void> logSync(String event, dynamic details) async {
    try {
      final db = await database;
      await db.insert('sync_logs', {
        'event': event,
        'details': details.toString(),
        'timestamp': DateTime.now().toIso8601String()
      });
      debugPrint('📊 [DB LOG]: $event - $details');
    } catch (e) {
      debugPrint('❌ LogSync Failed (Continuing...): $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSyncLogs() async {
    try {
      final db = await database;
      return await db.query('sync_logs', orderBy: 'timestamp DESC', limit: 100);
    } catch (e) {
      debugPrint('❌ getSyncLogs Failed: $e');
      return [];
    }
  }
}
