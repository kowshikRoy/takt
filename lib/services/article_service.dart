import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/article_model.dart'; // We should probably update Article model or create a new one

class ArticleService {
  static final ArticleService _instance = ArticleService._internal();
  static Database? _database;

  factory ArticleService() => _instance;

  ArticleService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'user_data.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE articles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            original_content TEXT,
            processed_content_json TEXT,
            is_processed INTEGER DEFAULT 0,
            created_at INTEGER
          )
        ''');
      },
    );
  }

  Future<int> saveArticle(String title, String content, {Map<String, dynamic>? processedData}) async {
    final db = await database;
    return await db.insert('articles', {
      'title': title,
      'original_content': content,
      'processed_content_json': processedData != null ? jsonEncode(processedData) : null,
      'is_processed': processedData != null ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  Future<void> updateProcessedContent(int id, Map<String, dynamic> processedData) async {
      final db = await database;
      await db.update(
          'articles',
          {
              'processed_content_json': jsonEncode(processedData),
              'is_processed': 1
          },
          where: 'id = ?',
          whereArgs: [id]
      );
  }

  Future<List<Map<String, dynamic>>> getAllArticles() async {
    final db = await database;
    return await db.query('articles', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getArticle(int id) async {
    final db = await database;
    final res = await db.query('articles', where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isNotEmpty) {
        return res.first;
    }
    return null;
  }
}
