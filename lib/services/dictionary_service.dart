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
    // Using v11 to force fresh copy on devices
    var path = join(await getDatabasesPath(), "german_dictionary_v16.db");
    
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
        ByteData data = await rootBundle.load(join("assets", "german_dictionary_v16.db"));
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
    // print("DEBUG: Fetched word data: $word");

    final List<Map<String, dynamic>> defRes = await db.query('definitions', where: 'word_id = ?', whereArgs: [wordId]);
    List<String> definitions = defRes.map((d) => d['definition'] as String).toList();
    
    // If no definitions found but we have a base_form, fetch definitions for the base form
    if (definitions.isEmpty && word['base_form'] != null) {
       String baseForm = word['base_form'];
       // print("DEBUG: No definitions for '${word['word']}', fetching base form '$baseForm'");
       
       // Allow fetching ONLY the base form row to get its ID
       final List<Map<String, dynamic>> baseRes = await db.query(
         'words', 
         where: 'word = ? COLLATE NOCASE', 
         whereArgs: [baseForm], 
         limit: 1
       );
       
       if (baseRes.isNotEmpty) {
          int baseId = baseRes.first['id'] as int;
          // Fetch definitions for the base word
          final List<Map<String, dynamic>> baseDefRes = await db.query('definitions', where: 'word_id = ?', whereArgs: [baseId]);
          definitions = baseDefRes.map((d) => d['definition'] as String).toList();
          
          // Optionally: Could also fetch other properties from base form if needed (IPA, gender)
          // But strict definition lookup is the main request.
       }
    }

    word['definitions'] = definitions;

    // v9: Join forms with tags table
    final List<Map<String, dynamic>> formsRes = await db.rawQuery('''
      SELECT f.form, t.tags 
      FROM forms f
      LEFT JOIN tags t ON f.tag_id = t.id
      WHERE f.word_id = ?
    ''', [wordId]);
    word['forms'] = formsRes;

    // v16: Fetch relations (synonyms, antonyms, related)
    final List<Map<String, dynamic>> relationsRes = await db.query(
      'relations',
      columns: ['relation_type', 'related_word'],
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    
    // Group relations by type
    List<String> synonyms = [];
    List<String> antonyms = [];
    List<String> related = [];
    
    for (var rel in relationsRes) {
      String type = rel['relation_type'] as String;
      String relWord = rel['related_word'] as String;
      
      if (type == 'synonym') {
        synonyms.add(relWord);
      } else if (type == 'antonym') {
        antonyms.add(relWord);
      } else if (type == 'related') {
        related.add(relWord);
      }
    }
    
    word['synonyms'] = synonyms;
    word['antonyms'] = antonyms;
    word['related'] = related;

    return word;
  }

  Future<Map<String, dynamic>?> lookupWord(String word) async {
    print("DEBUG: lookupWord called with: '$word'");
    final db = await database;
    try {
      // Try exact match first
      final List<Map<String, dynamic>> results = await db.query(
        'words',
        where: 'word = ? COLLATE NOCASE',
        whereArgs: [word.trim()],
        limit: 1,
      );

      print("DEBUG: lookupWord found ${results.length} results for '$word'");

      if (results.isNotEmpty) {
        return await getWordDetails(results.first['id'] as int);
      }
      return null;
    } catch (e) {
      print("Lookup error: $e");
      return null;
    }
  }

  Future<Map<String, String>> getGendersForWords(List<String> words) async {
      final db = await database;
      if (words.isEmpty) return {};

      try {
        // Create placeholders for the IN clause
        String placeholders = List.filled(words.length, '?').join(',');
        
        // Query for words that match and have a non-null gender
        // We look for nouns specifically? The prompt implies nouns based on gender. 
        // Usually only nouns have gender in German learning context (der/die/das).
        // Let's filter by type='noun' to be safe, or just take any word with a gender.
        final List<Map<String, dynamic>> results = await db.query(
          'words',
          columns: ['word', 'gender'],
          where: 'word COLLATE NOCASE IN ($placeholders) AND gender IS NOT NULL',
          whereArgs: words,
        );

        Map<String, String> genderMap = {};
        for (var row in results) {
            if (row['word'] != null && row['gender'] != null) {
                genderMap[row['word'].toString()] = row['gender'].toString();
            }
        }
        return genderMap;

      } catch (e) {
          print("Batch gender lookup error: $e");
          return {};
      }
  }
}
