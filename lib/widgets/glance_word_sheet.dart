import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/saved_word.dart';
import '../services/vocabulary_service.dart';
import '../services/dictionary_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../screens/dictionary_screen.dart';
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
      foundPlural = await dictService.getPluralForm(wId, word);
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

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required VocabCategory category,
  }) {
    final bool isActive = _savedWord != null && _savedWord!.category == category;
    final colorScheme = Theme.of(context).colorScheme;

    final Color activeBg = category == VocabCategory.mastered
        ? Colors.green.shade700
        : (category == VocabCategory.learning
            ? colorScheme.primary
            : Colors.amber.shade800);

    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleCategory(category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeBg : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? activeBg : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 15,
                color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildContextSentence(BuildContext context, String sentence, String targetWord) {
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
    final gender = activeDetails['gender']?.toString();
    final ipa = activeDetails['ipa']?.toString();
    final contextNote = activeDetails['contextNote']?.toString();

    List<String> defs = [];
    if (activeDetails['definitions'] != null) {
      defs = List<String>.from(activeDetails['definitions']);
    } else if (activeDetails['definition'] != null) {
      defs = [activeDetails['definition'].toString()];
    }

    final genderColor = _getGenderColor(gender);
    final article = _getArticle(gender);
    final String pluralNounOnly = (_pluralForm != null && _pluralForm!.isNotEmpty)
        ? (_pluralForm!.toLowerCase().startsWith('die ')
            ? _pluralForm!.substring(4).trim()
            : _pluralForm!.trim())
        : '';

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

          // Header: Article + Headword + Audio Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (contextNote != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "⚡ $contextNote",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$_cefrBadge • CEFR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (article.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: genderColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: genderColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              article.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: genderColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: word,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: article.isNotEmpty ? genderColor : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                if (article.isNotEmpty && pluralNounOnly.isNotEmpty) ...[
                                  TextSpan(
                                    text: ', die $pluralNounOnly',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ipa != null && ipa.isNotEmpty)
                      Text(
                        ipa,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  String textToSpeak = word;
                  if (article.isNotEmpty) {
                    if (_pluralForm != null && _pluralForm!.isNotEmpty) {
                      final pluralStr = _pluralForm!.toLowerCase().startsWith('die ')
                          ? _pluralForm!
                          : 'die $_pluralForm';
                      textToSpeak = '$article $word, $pluralStr';
                    } else {
                      textToSpeak = '$article $word';
                    }
                  }
                  _ttsService.speak(textToSpeak, lang: 'de-DE');
                },
                icon: const Icon(Icons.volume_up_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: genderColor.withValues(alpha: 0.15),
                  foregroundColor: genderColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Meanings list
          if (defs.isNotEmpty) ...[
            Text(
              "DEFINITION",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            ...defs.take(3).map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("• ", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Expanded(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ] else ...[
            Text(
              "No dictionary definition found.",
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],

          // Context Sentence snippet
          if (widget.contextSentence != null && widget.contextSentence!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_quote_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        "Context",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildContextSentence(context, widget.contextSentence!, word),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Vocabulary Status Header & Toggle Chips
          Text(
            "VOCABULARY STATUS",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCategoryChip(
                label: 'Save',
                icon: Icons.bookmark_border_rounded,
                activeIcon: Icons.bookmark_rounded,
                category: VocabCategory.reviewLater,
              ),
              const SizedBox(width: 8),
              _buildCategoryChip(
                label: 'Learning',
                icon: Icons.psychology_outlined,
                activeIcon: Icons.psychology_rounded,
                category: VocabCategory.learning,
              ),
              const SizedBox(width: 8),
              _buildCategoryChip(
                label: 'Known',
                icon: Icons.check_circle_outline_rounded,
                activeIcon: Icons.check_circle_rounded,
                category: VocabCategory.mastered,
              ),
            ],
          ),
          if (_savedWord != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(4, (index) {
                  final isEarned = index < _savedWord!.masteryLevel;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      isEarned ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 15,
                      color: isEarned
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  );
                }),
                const SizedBox(width: 6),
                Text(
                  'Mastery Level ${_savedWord!.masteryLevel} / 4',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DictionaryScreen(initialSearchQuery: widget.word),
                  ),
                );
              },
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('View Forms & Declensions →'),
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
