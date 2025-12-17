import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  static Database? _database;
  static Completer<Database>? _dbCompleter;

  factory DictionaryService() => _instance;

  DictionaryService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    if (_dbCompleter == null || _dbCompleter!.isCompleted) {
      _dbCompleter = Completer<Database>();
      _initDatabase().then((db) {
        _database = db;
        _dbCompleter!.complete(db);
      }).catchError((e) {
        _dbCompleter!.completeError(e);
      });
    }
    
    return _dbCompleter!.future;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    // Using v3 to force fresh copy on devices that have v1/v2
    String path = join(documentsDirectory.path, "german_dictionary_v3.db");
    
    // Explicitly define anticipated tables to verify
    bool isValid = false;
    
    if (await File(path).exists()) {
      try {
        print("Verifying existing database...");
        var db = await openDatabase(path, readOnly: true);
        // Robust check: Actually try to query the words table
        await db.rawQuery("SELECT count(*) FROM words LIMIT 1");
        await db.close();
        isValid = true;
        print("Database verification successful.");
      } catch (e) {
        print("Database verification failed: $e. Will re-copy.");
        isValid = false;
      }
    }

    if (!isValid) {
      if (await File(path).exists()) {
        try { await File(path).delete(); } catch (_) {}
      }
      await _copyFromAsset(path);
    }

    return await openDatabase(path, version: 1);
  }

  Future<void> _copyFromAsset(String path) async {
    print("Copying dictionary database from assets...");
    try {
        ByteData data = await rootBundle.load(join("assets", "german_dictionary_v3.db"));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        print("Database copied successfully.");
    } catch (e) {
        print("Error copying database: $e");
        throw Exception("Failed to copy dictionary database");
    }
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final db = await database;
    if (query.isEmpty) return [];
    
    // Standard SQL wildcard search: "query%" matches prefixes
    String sqlLike = '$query%'; 
    
    try {
      final results = await db.rawQuery('''
        SELECT * 
        FROM words 
        WHERE word LIKE ?
        ORDER BY LENGTH(word) ASC, word ASC
        LIMIT 20
      ''', [sqlLike]);
      return results;
    } catch (e) {
      print("Search error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getWordDetails(int wordId) async {
    final db = await database;
    
    final List<Map<String, dynamic>> wordRes = await db.query('words', where: 'id = ?', whereArgs: [wordId]);
    if (wordRes.isEmpty) return null;
    final word = Map<String, dynamic>.from(wordRes.first);

    final List<Map<String, dynamic>> defRes = await db.query('definitions', where: 'word_id = ?', whereArgs: [wordId]);
    word['definitions'] = defRes.map((d) => d['definition']).toList();

    final List<Map<String, dynamic>> formsRes = await db.query('forms', where: 'word_id = ?', whereArgs: [wordId]);
    word['forms'] = formsRes;

    return word;
  }
}
