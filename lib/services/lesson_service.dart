import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/article_model.dart';

class LessonService extends ChangeNotifier {
  static const String _importedArticlesKey = 'imported_articles';
  static const String _customContentKeyPrefix = 'custom_content_';

  List<Article> _importedArticles = [];

  List<Article> get importedArticles => _importedArticles;

  LessonService() {
    _loadImportedArticles();
  }

  Future<void> _loadImportedArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? articlesJson = prefs.getString(_importedArticlesKey);

    if (articlesJson != null) {
      final List<dynamic> decodedList = jsonDecode(articlesJson);
      _importedArticles = decodedList.map((item) {
        return Article(
          id: item['id'],
          title: item['title'],
          description: item['description'],
          level: item['level'],
          date: DateTime.parse(item['date']),
          imageUrl: item['imageUrl'],
        );
      }).toList();
    } else {
        // Mock data if empty
         _importedArticles = [
            Article(
                id: 'imp1',
                title: 'My Favorite Recipe',
                description: '',
                level: 'Custom',
                date: DateTime.now(),
                imageUrl: 'assets/images/story_hair.png',
            ),
         ];
    }
    notifyListeners();
  }

  Future<void> addImportedArticle(Article article, String content) async {
    _importedArticles.insert(0, article);
    notifyListeners();
    await _saveImportedArticles();
    await _saveCustomContent(article.id, content);
  }

  Future<void> deleteArticle(String id) async {
      _importedArticles.removeWhere((a) => a.id == id);
      notifyListeners();
      await _saveImportedArticles();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_customContentKeyPrefix$id');
  }

  Future<void> _saveImportedArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(_importedArticles.map((article) {
      return {
        'id': article.id,
        'title': article.title,
        'description': article.description,
        'level': article.level,
        'date': article.date.toIso8601String(),
        'imageUrl': article.imageUrl,
      };
    }).toList());

    await prefs.setString(_importedArticlesKey, encodedList);
  }

  Future<void> _saveCustomContent(String articleId, String content) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_customContentKeyPrefix$articleId', content);
  }

  Future<String?> getCustomContent(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_customContentKeyPrefix$articleId');
  }
}
