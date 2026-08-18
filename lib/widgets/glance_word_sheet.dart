import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/saved_word.dart';
import '../services/vocabulary_service.dart';
import '../services/dictionary_service.dart';
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

  List<Map<String, dynamic>> _detailsList = [];
  SavedWord? _savedWord;
  final int _selectedSenseIndex = 0;
  String? _pluralForm;

  @override
  void initState() {
    super.initState();
    if (widget.detailsList != null && widget.detailsList!.isNotEmpty) {
      _detailsList = widget.detailsList!;
    }
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final word = widget.word.replaceAll(RegExp(r'\s+'), ' ').trim();
    final dictService = DictionaryService();
    final String? contextualPos = (widget.detailsList != null && widget.detailsList!.isNotEmpty)
        ? widget.detailsList!.first['pos']?.toString()
        : null;

    // Paint something immediately with the cheap SQLite-only lookup, then upgrade in the
    // background to the full context/pos-aware (WSD) result once it's ready — the sheet
    // shouldn't block opening on the slow Wiktionary/NMT/WSD pipeline every time a word is
    // tapped, but the final displayed sense should still reflect that context-aware lookup.
    if (_detailsList.isEmpty) {
      final fastDetails = await dictService.lookupWordFast(word);
      if (mounted && fastDetails.isNotEmpty && _detailsList.isEmpty) {
        setState(() {
          _detailsList = List.from(fastDetails);
        });
      }
    }

    final dbDetails = await dictService.lookupConsolidatedWord(
      word,
      pos: contextualPos,
      contextSentence: widget.contextSentence,
    );

    SavedWord? saved = await _vocabService.getSavedWordByWord(word) ??
        await _vocabService.getSavedWord(word.toLowerCase());

    if (saved == null && dbDetails.isNotEmpty) {
      final base = (dbDetails.first['base_form'] as String?)?.trim();
      if (base != null && base.isNotEmpty) {
        saved = await _vocabService.getSavedWordByWord(base) ??
            await _vocabService.getSavedWord(base.toLowerCase());
      }
    }

    if (mounted) {
      setState(() {
        if (dbDetails.isNotEmpty) {
          _detailsList = List.from(dbDetails);
        }
        _savedWord = saved;
      });
    }

    if (_detailsList.isNotEmpty) {
      final first = _detailsList.first;
      final wId = int.tryParse(first['id']?.toString() ?? '0') ?? 0;
      final baseForm = first['base_form']?.toString();
      final foundPlural = await dictService.getPluralForm(wId, word, baseForm: baseForm);
      if (mounted && foundPlural != null) {
        setState(() {
          _pluralForm = foundPlural;
        });
      }
    }
  }

  Future<void> _setCategory(VocabCategory category) async {
    final activeDetails = _detailsList.isNotEmpty ? _detailsList[_selectedSenseIndex] : <String, dynamic>{};
    final rawWord = activeDetails['word']?.toString() ?? widget.word;
    final baseForm = (activeDetails['base_form'] as String?)?.trim();
    // Resolve lemma: If base_form is available, use it as the main headword
    final wordStr = (baseForm != null && baseForm.isNotEmpty && baseForm.toLowerCase() != rawWord.toLowerCase())
        ? baseForm
        : rawWord;
    final gender = activeDetails['gender']?.toString();
    final pos = activeDetails['pos']?.toString();
    final ipa = activeDetails['ipa']?.toString();

    List<String> defs = [];
    if (activeDetails['definitions'] != null) {
      defs = List<String>.from(activeDetails['definitions']);
    }
    final primaryDef = defs.isNotEmpty ? defs.first : (activeDetails['definition']?.toString() ?? '');

    final String id = wordStr.toLowerCase().trim();

    final newSaved = SavedWord(
      id: id,
      word: wordStr,
      baseForm: baseForm ?? wordStr,
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
    final isMatching = _savedWord != null &&
        (_savedWord!.category == category ||
            (category == VocabCategory.reviewLater && _savedWord!.category == VocabCategory.learning));

    if (isMatching) {
      final cleanWord = widget.word.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').trim().toLowerCase();
      if (_savedWord != null) {
        await _vocabService.removeWord(_savedWord!.id);
        await _vocabService.removeWord(_savedWord!.word);
      }
      await _vocabService.removeWord(cleanWord);
      if (mounted) {
        setState(() {
          _savedWord = null;
        });
      }
    } else {
      await _setCategory(category);
    }
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
            onWordEdited: () => _loadSavedState(),
            onExplore: () {
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
          ),
        ],
      ).animate().fade(duration: 200.ms).slideY(begin: 0.1, end: 0),
    );
  }
}
