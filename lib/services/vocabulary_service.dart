import 'package:shared_preferences/shared_preferences.dart';

class VocabularyService {
  static final VocabularyService _instance = VocabularyService._internal();
  static const String _storageKey = 'user_vocabulary_list';
  SharedPreferences? _prefs;

  factory VocabularyService() => _instance;

  VocabularyService._internal();

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveWord(String word) async {
    await _init();
    final List<String> currentList = await getSavedWords();
    if (!currentList.contains(word)) {
      currentList.add(word);
      await _prefs!.setStringList(_storageKey, currentList);
    }
  }

  Future<void> removeWord(String word) async {
    await _init();
    final List<String> currentList = await getSavedWords();
    if (currentList.contains(word)) {
      currentList.remove(word);
      await _prefs!.setStringList(_storageKey, currentList);
    }
  }

  Future<bool> isWordSaved(String word) async {
    await _init();
    final List<String> currentList = await getSavedWords();
    return currentList.contains(word);
  }

  Future<List<String>> getSavedWords() async {
    await _init();
    return _prefs!.getStringList(_storageKey) ?? [];
  }
}
