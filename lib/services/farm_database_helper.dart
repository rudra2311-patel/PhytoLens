import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/farm_model.dart';
import '../models/alert_model.dart';
import 'auth_services.dart';

class FarmDatabaseHelper {
  static final FarmDatabaseHelper instance = FarmDatabaseHelper._init();
  static Database? _database;

  FarmDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('agriscan_farms.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4, // SECURITY FIX: Added user_id column
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE farms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        backend_id TEXT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        location TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        crop_type TEXT NOT NULL,
        farm_size REAL,
        created_at TEXT NOT NULL,
        risk_level TEXT,
        image_url TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        farm_id INTEGER,
        farm_name TEXT,
        user_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        metadata TEXT,
        FOREIGN KEY (farm_id) REFERENCES farms (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add backend_id column for existing databases (without UNIQUE constraint on ALTER)
      // SQLite doesn't support adding UNIQUE constraint via ALTER TABLE
      // We'll add it without UNIQUE first, then handle duplicates in application logic
      try {
        await db.execute('ALTER TABLE farms ADD COLUMN backend_id TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        print('backend_id column might already exist: $e');
      }
    }

    if (oldVersion < 3) {
      // Fix: Drop and recreate tables to ensure clean schema
      print('🔄 Recreating database tables for version 3...');
      await db.execute('DROP TABLE IF EXISTS alerts');
      await db.execute('DROP TABLE IF EXISTS farms');
      await _createDB(db, newVersion);
    }

    if (oldVersion < 4) {
      // SECURITY FIX: Add user_id column to isolate user data
      print('🔒 SECURITY UPDATE: Adding user_id columns...');
      await db.execute('DROP TABLE IF EXISTS alerts');
      await db.execute('DROP TABLE IF EXISTS farms');
      await _createDB(db, newVersion);
      print('✅ Database upgraded with user isolation');
    }
  }

  // Farm operations
  Future<int> createFarm(Farm farm) async {
    final db = await database;
    return await db.insert('farms', farm.toMap());
  }

  Future<List<Farm>> getAllFarms() async {
    final db = await database;

    // SECURITY: Get current user_id to filter farms
    final currentUserId = await AuthService.getUserId();
    if (currentUserId == null) {
      debugPrint('⚠️ No user logged in, returning empty farms list');
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'farms',
      where: 'user_id = ?',
      whereArgs: [currentUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Farm.fromMap(map)).toList();
  }

  Future<Farm?> getFarmById(int id) async {
    final db = await database;
    final maps = await db.query('farms', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Farm.fromMap(maps.first);
  }

  Future<Farm?> getFarmByBackendId(String backendId) async {
    final db = await database;
    final maps = await db.query(
      'farms',
      where: 'backend_id = ?',
      whereArgs: [backendId],
    );
    if (maps.isEmpty) return null;
    return Farm.fromMap(maps.first);
  }

  Future<int> updateFarm(Farm farm) async {
    final db = await database;
    return await db.update(
      'farms',
      farm.toMap(),
      where: 'id = ?',
      whereArgs: [farm.id],
    );
  }

  Future<int> deleteFarm(int id) async {
    final db = await database;
    return await db.delete('farms', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getFarmsCount() async {
    final db = await database;

    // SECURITY: Get current user_id to filter farms
    final currentUserId = await AuthService.getUserId();
    if (currentUserId == null) {
      debugPrint('⚠️ No user logged in, returning 0 farms count');
      return 0;
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM farms WHERE user_id = ?',
      [currentUserId],
    );
    return result.first['count'] as int;
  }

  /// Remove duplicate farms based on backend_id or coordinates
  Future<int> removeDuplicateFarms() async {
    final db = await database;
    int deletedCount = 0;

    // Get all farms
    final farms = await getAllFarms();
    final Map<String, Farm> uniqueFarms = {};
    final List<int> idsToDelete = [];

    for (var farm in farms) {
      // Create unique key: prefer backend_id, fallback to coordinates
      final key = farm.backendId ?? '${farm.latitude}_${farm.longitude}';

      if (uniqueFarms.containsKey(key)) {
        // This is a duplicate, mark the one with lower id for deletion
        final existingFarm = uniqueFarms[key]!;
        if (farm.id! < existingFarm.id!) {
          // Keep the newer farm (higher id), delete this one
          idsToDelete.add(farm.id!);
        } else {
          // Keep this farm, delete the older one
          idsToDelete.add(existingFarm.id!);
          uniqueFarms[key] = farm;
        }
      } else {
        uniqueFarms[key] = farm;
      }
    }

    // Delete duplicates
    for (var id in idsToDelete) {
      await db.delete('farms', where: 'id = ?', whereArgs: [id]);
      deletedCount++;
    }

    print('🗑️ Removed $deletedCount duplicate farm(s) from database');
    return deletedCount;
  }

  // Alert operations
  Future<int> createAlert(Alert alert) async {
    final db = await database;
    return await db.insert('alerts', alert.toMap());
  }

  Future<List<Alert>> getAllAlerts() async {
    final db = await database;

    // SECURITY: Get current user_id to filter alerts
    final currentUserId = await AuthService.getUserId();
    if (currentUserId == null) {
      debugPrint('⚠️ No user logged in, returning empty alerts list');
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'alerts',
      where: 'user_id = ?',
      whereArgs: [currentUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Alert.fromMap(map)).toList();
  }

  Future<List<Alert>> getAlertsByType(String type) async {
    final db = await database;

    // SECURITY: Get current user_id to filter alerts
    final currentUserId = await AuthService.getUserId();
    if (currentUserId == null) {
      debugPrint('⚠️ No user logged in, returning empty alerts list');
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'alerts',
      where: 'type = ? AND user_id = ?',
      whereArgs: [type, currentUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Alert.fromMap(map)).toList();
  }

  Future<List<Alert>> getUnreadAlerts() async {
    final db = await database;

    // SECURITY: Get current user_id to filter alerts
    final currentUserId = await AuthService.getUserId();
    if (currentUserId == null) {
      debugPrint('⚠️ No user logged in, returning empty alerts list');
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'alerts',
      where: 'is_read = ? AND user_id = ?',
      whereArgs: [0, currentUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Alert.fromMap(map)).toList();
  }

  Future<int> getUnreadAlertsCount() async {
    final db = await database;

    // SECURITY: Get current user_id to filter alerts
    final currentUserId = await AuthService.getUserId();
    if (currentUserId == null) {
      debugPrint('⚠️ No user logged in, returning 0 unread alerts');
      return 0;
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM alerts WHERE is_read = 0 AND user_id = ?',
      [currentUserId],
    );
    return result.first['count'] as int;
  }

  Future<int> markAlertAsRead(int id) async {
    final db = await database;
    return await db.update(
      'alerts',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAllAlertsAsRead() async {
    final db = await database;
    return await db.update('alerts', {'is_read': 1});
  }

  Future<int> deleteAlert(int id) async {
    final db = await database;
    return await db.delete('alerts', where: 'id = ?', whereArgs: [id]);
  }

  // Delete all alerts for a specific farm
  Future<int> deleteAlertsByFarmId(int farmId) async {
    final db = await database;
    final deletedCount = await db.delete(
      'alerts',
      where: 'farm_id = ?',
      whereArgs: [farmId],
    );
    debugPrint('🗑️ Deleted $deletedCount alert(s) for farm ID: $farmId');
    return deletedCount;
  }

  /// SECURITY: Clear all data for current user on logout
  Future<void> clearAllUserData() async {
    final db = await database;
    await db.delete('alerts');
    await db.delete('farms');
    print('🗑️ Cleared all user data from local database');
  }

  /// SECURITY: Clear entire database (nuclear option)
  Future<void> clearDatabase() async {
    final db = await database;
    await db.execute('DELETE FROM alerts');
    await db.execute('DELETE FROM farms');
    print('🗑️ Database wiped clean');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
