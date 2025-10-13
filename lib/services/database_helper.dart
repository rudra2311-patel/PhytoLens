import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// A data class to hold the information about a disease.
class Disease {
  final int id;
  final String name;
  final String? symptoms; // ✅ Made nullable
  final String? treatment; // ✅ Made nullable
  final String? prevention; // ✅ Made nullable

  Disease({
    required this.id,
    required this.name,
    this.symptoms, // ✅ Optional
    this.treatment, // ✅ Optional
    this.prevention, // ✅ Optional
  });

  // A helper factory method to create a Disease object from a map.
  factory Disease.fromMap(Map<String, dynamic> map) {
    return Disease(
      id: map['id'] as int? ?? 0, // ✅ Provide default if null
      name: map['name'] as String? ?? 'Unknown', // ✅ Provide default if null
      symptoms: map['symptoms'] as String?, // ✅ Can be null
      treatment: map['treatment'] as String?, // ✅ Can be null
      prevention: map['prevention'] as String?, // ✅ Can be null
    );
  }

  @override
  String toString() {
    return 'Disease(id: $id, name: $name, symptoms: $symptoms, treatment: $treatment, prevention: $prevention)';
  }
}

// A singleton class to manage your database.
class DatabaseHelper {
  // This ensures that you have only one instance of the database helper.
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  /// Gets the database instance.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database by copying it from assets if it doesn't exist.
  Future<Database> _initDatabase() async {
    // Get the default databases location.
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'agriscan.db');
    print("DATABASE IS LOCATED AT: $path");

    // Check if the database already exists in the documents directory.
    var exists = await databaseExists(path);

    if (!exists) {
      // If it doesn't exist, copy it from the assets folder.
      print("Creating new copy of database from assets...");
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset.
      ByteData data = await rootBundle.load(join("assets/db", "agriscan.db"));
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      // Write the file to the documents directory.
      await File(path).writeAsBytes(bytes, flush: true);
    } else {
      print("Opening existing database...");
    }

    // Open the database.
    return await openDatabase(path, readOnly: true);
  }

  /// Retrieves disease information by its name.
  /// Handles case-insensitive search and various name formats.
  Future<Disease?> getDisease(String name) async {
    try {
      final db = await database;

      // Clean the input name
      String cleanName = name.trim();

      print('🔍 Searching for disease: "$cleanName"');

      // Try exact match first (case-insensitive)
      List<Map<String, dynamic>> maps = await db.query(
        'diseases',
        where: 'LOWER(name) = LOWER(?)',
        whereArgs: [cleanName],
      );

      // If no exact match, try with underscores replaced
      if (maps.isEmpty) {
        String nameWithSpaces = cleanName.replaceAll('_', ' ');
        print('🔍 Trying with spaces: "$nameWithSpaces"');

        maps = await db.query(
          'diseases',
          where: 'LOWER(name) = LOWER(?)',
          whereArgs: [nameWithSpaces],
        );
      }

      // If still no match, try partial match
      if (maps.isEmpty) {
        print('🔍 Trying partial match...');

        maps = await db.query(
          'diseases',
          where: 'LOWER(name) LIKE LOWER(?)',
          whereArgs: ['%$cleanName%'],
          limit: 1,
        );
      }

      // If a result is found, convert it to a Disease object.
      if (maps.isNotEmpty) {
        Disease disease = Disease.fromMap(maps.first);
        print('✅ Found disease: ${disease.name}');
        return disease;
      }

      // If no result is found, return null.
      print('❌ No disease found for: "$cleanName"');
      return null;
    } catch (e) {
      print('❌ Database error in getDisease: $e');
      return null;
    }
  }

  /// Get all diseases (for debugging purposes)
  Future<List<Disease>> getAllDiseases() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('diseases');

      return List.generate(maps.length, (i) {
        return Disease.fromMap(maps[i]);
      });
    } catch (e) {
      print('❌ Error getting all diseases: $e');
      return [];
    }
  }

  /// Print all disease names (for debugging)
  Future<void> printAllDiseaseNames() async {
    try {
      final diseases = await getAllDiseases();
      print('📋 Database contains ${diseases.length} diseases:');
      for (var disease in diseases) {
        print('  - ${disease.name}');
      }
    } catch (e) {
      print('❌ Error printing disease names: $e');
    }
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
