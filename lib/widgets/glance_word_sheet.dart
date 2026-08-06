import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/saved_word.dart';
import '../services/vocabulary_service.dart';
import '../services/dictionary_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../screens/word_detail_screen.dart';
import 'word_header_card.dart';
import 'package:flutter/services.dart';

class GlanceWordSheet extends StatefulWidget {
  final String word;
  final List<Map<String, dynamic>>? detailsList;
  final String? contextSentence;
  final String? sourceTitle;

  const GlanceWordSheet({
    super.key,
    required this.word,
    this.detailsList,
    this.contextSentence,
    this.sourceTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String word,
    List<Map<String, dynamic>>? detailsList,
    String? contextSentence,
    String? sourceTitle,
  }) {
    HapticFeedback.selectionClick();
    final bool isDesktop = MediaQuery.of(context).size.width > 700;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: GlanceWordSheet(
                word: word,
                detailsList: detailsList,
                contextSentence: contextSentence,
                sourceTitle: sourceTitle,
              ),
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        curve: Curves.easeOutCubic,
        duration: const Duration(milliseconds: 280),
        reverseDuration: const Duration(milliseconds: 220),
      ),
      builder: (_) => GlanceWordSheet(
        word: word,
        detailsList: detailsList,
        contextSentence: contextSentence,
        sourceTitle: sourceTitle,
      ),
    );
  }

  @override
  State<GlanceWordSheet> createState() => _GlanceWordSheetState();
}

class _GlanceWordSheetState extends State<GlanceWordSheet> {
  final VocabularyService _vocabService = VocabularyService();
  final TtsService _ttsService = TtsService();

  List<Map<String, dynamic>> _detailsList = [];
  SavedWord? _savedWord;
  final int _selectedSenseIndex = 0;
  String? _pluralForm;
  String _cefrBadge = 'B1';

  @override
  void initState() {
    super.initState();
    if (widget.detailsList != null && widget.detailsList!.isNotEmpty) {
      _detailsList = widget.detailsList!;
    }
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final word = widget.word.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').trim();
    final dictService = DictionaryService();
    final dbDetails = await dictService.lookupContextualWord(
      word,
      contextSentence: widget.contextSentence,
    );

    if (dbDetails.isNotEmpty) {
      if (_detailsList.isEmpty) {
        _detailsList = List.from(dbDetails);
      } else {
        List<Map<String, dynamic>> mergedList = [];
        for (var instant in _detailsList) {
          final Map<String, dynamic> merged = Map<String, dynamic>.from(instant);
          Map<String, dynamic>? match;
          for (var dbEntry in dbDetails) {
            if (dbEntry['word'].toString().toLowerCase() == word.toLowerCase() ||
                dbEntry['base_form']?.toString().toLowerCase() == word.toLowerCase()) {
              match = dbEntry;
              break;
            }
          }
          match ??= dbDetails.first;

          if ((merged['gender'] == null || merged['gender'].toString().isEmpty) && match['gender'] != null) {
            merged['gender'] = match['gender'];
          }
          if ((merged['pos'] == null || merged['pos'].toString().isEmpty) && match['pos'] != null) {
            merged['pos'] = match['pos'];
          }
          if ((merged['base_form'] == null || merged['base_form'].toString().isEmpty) && match['base_form'] != null) {
            merged['base_form'] = match['base_form'];
          }
          if (merged['ipa'] == null && match['ipa'] != null) {
            merged['ipa'] = match['ipa'];
          }
          if (match['definitions'] != null && (match['definitions'] as List).isNotEmpty) {
            final dbDefs = List<String>.from(match['definitions']);
            final existingDefs = List<String>.from(merged['definitions'] ?? []);
            final combined = <String>[...dbDefs];
            for (var d in existingDefs) {
              if (!combined.contains(d)) {
                combined.add(d);
              }
            }
            merged['definitions'] = combined;
          }
          mergedList.add(merged);
        }

        for (var dbEntry in dbDetails) {
          bool exists = mergedList.any((m) => m['pos'] == dbEntry['pos']);
          if (!exists) {
            mergedList.add(dbEntry);
          }
        }
        _detailsList = mergedList;
      }
    }

    final saved = await _vocabService.getSavedWordByWord(word);
    String? foundPlural;
    String cefr = 'B1';
    if (_detailsList.isNotEmpty) {
      final first = _detailsList.first;
      final freqRank = first['freq_rank'] != null ? int.tryParse(first['freq_rank'].toString()) : null;
      if (freqRank != null) {
        if (freqRank <= 500) cefr = 'A1';
        else if (freqRank <= 1500) cefr = 'A2';
        else if (freqRank <= 3500) cefr = 'B1';
        else if (freqRank <= 6000) cefr = 'B2';
        else cefr = 'C1';
      }
      final wId = int.tryParse(first['id']?.toString() ?? '0') ?? 0;
      final baseForm = first['base_form']?.toString();
      foundPlural = await dictService.getPluralForm(wId, word, baseForm: baseForm);
    }
    if (mounted) {
      setState(() {
        _savedWord = saved;
        _pluralForm = foundPlural;
        _cefrBadge = cefr;
      });
    }
  }

  Future<void> _setCategory(VocabCategory category) async {
    final activeDetails = _detailsList.isNotEmpty ? _detailsList[_selectedSenseIndex] : <String, dynamic>{};
    final wordStr = activeDetails['word']?.toString() ?? widget.word;
    final gender = activeDetails['gender']?.toString();
    final pos = activeDetails['pos']?.toString();
    final ipa = activeDetails['ipa']?.toString();
    final baseForm = activeDetails['base_form']?.toString();

    List<String> defs = [];
    if (activeDetails['definitions'] != null) {
      defs = List<String>.from(activeDetails['definitions']);
    }
    final primaryDef = defs.isNotEmpty ? defs.first : (activeDetails['definition']?.toString() ?? '');

    final String id = wordStr.toLowerCase().trim();

    final newSaved = SavedWord(
      id: id,
      word: wordStr,
      baseForm: baseForm,
      pos: pos,
      gender: gender,
      primaryDefinition: primaryDef,
      definitions: defs,
      ipa: ipa,
      contextSentence: widget.contextSentence,
      sourceTitle: widget.sourceTitle,
      category: category,
      interval: _savedWord?.interval ?? 0,
      easeFactor: _savedWord?.easeFactor ?? 2.5,
      repetitions: _savedWord?.repetitions ?? 0,
      dueDate: _savedWord?.dueDate ?? DateTime.now(),
      createdAt: _savedWord?.createdAt ?? DateTime.now(),
    );

    await _vocabService.upsertWord(newSaved);
    if (mounted) {
      setState(() {
        _savedWord = newSaved;
      });
    }
  }

  Future<void> _toggleCategory(VocabCategory category) async {
    HapticFeedback.selectionClick();
    if (_savedWord != null && _savedWord!.category == category) {
      final wordStr = widget.word.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').trim().toLowerCase();
      await _vocabService.removeWord(wordStr);
      if (mounted) {
        setState(() {
          _savedWord = null;
        });
      }
    } else {
      await _setCategory(category);
    }
  }

  String _inferGenderIfNull(String wordStr, String? rawGender, String? pos) {
    if (rawGender != null && rawGender.trim().isNotEmpty) {
      final g = rawGender.trim().toLowerCase();
      if (g == 'masculine' || g == 'm') return 'm';
      if (g == 'feminine' || g == 'f') return 'f';
      if (g == 'neuter' || g == 'n') return 'n';
    }

    final lower = wordStr.trim().toLowerCase();
    
    if (lower.endsWith('schaft') ||
        lower.endsWith('ung') ||
        lower.endsWith('heit') ||
        lower.endsWith('keit') ||
        lower.endsWith('tät') ||
        lower.endsWith('tion') ||
        lower.endsWith('ei') ||
        lower.endsWith('in')) {
      return 'f';
    }
    if (lower.endsWith('chen') ||
        lower.endsWith('lein') ||
        lower.endsWith('tum') ||
        lower.endsWith('ment')) {
      return 'n';
    }
    if (lower.endsWith('ismus') || lower.endsWith('ling') || lower.endsWith('or')) {
      return 'm';
    }

    return '';
  }

  Color _getGenderColor(String? gender) {
    if (gender == 'masculine' || gender == 'm') return AppTheme.genderMasc;
    if (gender == 'feminine' || gender == 'f') return AppTheme.genderFem;
    if (gender == 'neuter' || gender == 'n') return AppTheme.genderNeu;
    return Theme.of(context).colorScheme.primary;
  }

  String _getArticle(String? gender) {
    if (gender == 'masculine' || gender == 'm') return 'Der';
    if (gender == 'feminine' || gender == 'f') return 'Die';
    if (gender == 'neuter' || gender == 'n') return 'Das';
    return '';
  }

  String _extractSingleSentence(String text, String targetWord) {
    final cleanWord = targetWord.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').trim();
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+|\n+'));
    if (cleanWord.isNotEmpty) {
      for (final s in sentences) {
        if (s.toLowerCase().contains(cleanWord.toLowerCase())) {
          return s.trim();
        }
      }
    }
    return sentences.first.trim();
  }

  Widget _buildContextSentence(BuildContext context, String rawText, String targetWord) {
    final sentence = _extractSingleSentence(rawText, targetWord);
    final cleanWord = targetWord.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').trim();
    if (cleanWord.isEmpty || !sentence.toLowerCase().contains(cleanWord.toLowerCase())) {
      return Text(
        sentence,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    final regExp = RegExp(RegExp.escape(cleanWord), caseSensitive: false);
    final matches = regExp.allMatches(sentence);
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: sentence.substring(lastEnd, match.start),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ));
      }
      spans.add(TextSpan(
        text: sentence.substring(match.start, match.end),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < sentence.length) {
      spans.add(TextSpan(
        text: sentence.substring(lastEnd),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final activeDetails = _detailsList.isNotEmpty ? _detailsList[_selectedSenseIndex] : <String, dynamic>{};
    final word = activeDetails['word']?.toString() ?? widget.word;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          WordHeaderCard(
            wordData: activeDetails.isNotEmpty
                ? activeDetails
                : {'word': widget.word},
            pluralForm: _pluralForm,
            savedWordIds:
                _savedWord != null ? {_savedWord!.id.toLowerCase().trim()} : {},
            savedWordCategories: _savedWord != null
                ? {_savedWord!.id.toLowerCase().trim(): _savedWord!.category}
                : {},
            onCategorySelected: _toggleCategory,
            contextSentence: widget.contextSentence,
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final wordToExplore = word;
                final wordDataToPass = Map<String, dynamic>.from(activeDetails);
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        WordDetailScreen(
                      word: wordToExplore,
                      wordData: wordDataToPass,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 200),
                  ),
                );
              },
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('Explore in Dictionary →'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ],
      ).animate().fade(duration: 200.ms).slideY(begin: 0.1, end: 0),
    );
  }
}
