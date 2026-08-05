import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/book_guide.dart';
import '../models/textbook_unit.dart';

class BookGuideService extends ChangeNotifier {
  List<BookGuide> _books = [];
  bool _isLoading = false;
  final Map<String, ChapterGuide> _chapterCache = {};
  final Map<String, TextbookUnit> _unitCache = {};

  List<BookGuide> get books => _books;
  bool get isLoading => _isLoading;

  BookGuideService() {
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final jsonString = await rootBundle.loadString('assets/books/books_catalog.json');
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      _books = jsonList.map((e) => BookGuide.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading books_catalog.json: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ChapterGuide?> loadChapter(String jsonAssetPath) async {
    if (_chapterCache.containsKey(jsonAssetPath)) {
      return _chapterCache[jsonAssetPath];
    }

    try {
      final jsonString = await rootBundle.loadString(jsonAssetPath);
      final Map<String, dynamic> jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final chapter = ChapterGuide.fromJson(jsonMap);
      _chapterCache[jsonAssetPath] = chapter;
      return chapter;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading chapter JSON ($jsonAssetPath): $e');
      }
      return null;
    }
  }

  BookGuide? getBookById(String id) {
    try {
      return _books.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<TextbookUnit?> loadTextbookUnit(String jsonAssetPath) async {
    if (_unitCache.containsKey(jsonAssetPath)) {
      return _unitCache[jsonAssetPath];
    }

    try {
      final jsonString = await rootBundle.loadString(jsonAssetPath);
      final Map<String, dynamic> jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final unit = TextbookUnit.fromJson(jsonMap);
      _unitCache[jsonAssetPath] = unit;
      return unit;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading textbook unit JSON ($jsonAssetPath): $e');
      }
      return null;
    }
  }
}
