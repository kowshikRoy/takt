import 'package:flutter/material.dart';
import '../services/vocabulary_service.dart';
import 'dictionary_screen.dart';

class VocabularyListScreen extends StatefulWidget {
  const VocabularyListScreen({super.key});

  @override
  State<VocabularyListScreen> createState() => _VocabularyListScreenState();
}

class _VocabularyListScreenState extends State<VocabularyListScreen> {
  final VocabularyService _vocabularyService = VocabularyService();
  List<String> _savedWords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() => _isLoading = true);
    final words = await _vocabularyService.getSavedWords();
    if (mounted) {
      setState(() {
        _savedWords = words;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeWord(String word) async {
    await _vocabularyService.removeWord(word);
    await _loadWords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My Vocabulary',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No words saved yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedWords.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final word = _savedWords[index];
                    return Dismissible(
                      key: Key(word),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                      ),
                      onDismissed: (direction) {
                        _removeWord(word);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          title: Text(
                            word,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            // Navigate to DictionaryScreen with this word
                            // We replace the current route if we want a separate stack or push?
                            // Pushing is better so back button works.
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DictionaryScreen(initialWord: word),
                              ),
                            ).then((_) {
                              // Reload list when returning, in case user removed it in DictionaryScreen
                              _loadWords();
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
