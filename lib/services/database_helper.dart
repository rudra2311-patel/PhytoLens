import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// A data class to hold the information about a disease.
class Disease {
  final int id;
  final String name;
  final String symptoms;
  final String treatment;
  final String prevention;

  Disease({
    required this.id,
    required this.name,
    required this.symptoms,
    required this.treatment,
    required this.prevention,
  });

  // A helper factory method to create a Disease object from a map.
  factory Disease.fromMap(Map<String, dynamic> map) {
    return Disease(
      id: map['id'],
      name: map['name'],
      symptoms: map['symptoms'],
      treatment: map['treatment'],
      prevention: map['prevention'],
    );
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
  Future<Disease?> getDisease(String name) async {
    final db = await database;
    // Query the 'diseases' table for a specific disease by name.
    final List<Map<String, dynamic>> maps = await db.query(
      'diseases',
      where: 'name = ?',
      whereArgs: [name],
    );

    // If a result is found, convert it to a Disease object.
    if (maps.isNotEmpty) {
      return Disease.fromMap(maps.first);
    }
    // If no result is found, return null.
    return null;
  }

  Future<Disease?> getDiseaseByName(String diseaseName) async {
    return null;
  }
}
