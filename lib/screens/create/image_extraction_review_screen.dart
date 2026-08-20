import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/article_model.dart';
import '../../models/image_extraction_result.dart';
import '../../models/saved_word.dart';
import '../../services/media_library_service.dart';
import '../../services/vocabulary_service.dart';
import '../../theme/books_modernist_style.dart';
import '../../widgets/capped_width.dart';
import '../story_reader_screen.dart';
import 'extracted_exercise_practice_screen.dart';

class ImageExtractionReviewScreen extends StatefulWidget {
  final ImageExtractionResult result;

  const ImageExtractionReviewScreen({super.key, required this.result});

  @override
  State<ImageExtractionReviewScreen> createState() =>
      _ImageExtractionReviewScreenState();
}

class _ImageExtractionReviewScreenState
    extends State<ImageExtractionReviewScreen> {
  bool _isSaving = false;

  String _articleFor(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'm':
      case 'masculine':
        return 'der';
      case 'f':
      case 'feminine':
        return 'die';
      case 'n':
      case 'neuter':
        return 'das';
      default:
        return '';
    }
  }

  bool get _hasSelection =>
      widget.result.vocabulary.any((v) => v.selected) ||
      (widget.result.saveLessonText &&
          (widget.result.lessonText?.isNotEmpty ?? false));

  bool get _allVocabSelected =>
      widget.result.vocabulary.isNotEmpty &&
      widget.result.vocabulary.every((v) => v.selected);

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      for (final v in widget.result.vocabulary) {
        v.selected = selectAll;
      }
    });
  }

  void _openExercisePractice() {
    if (widget.result.exercise == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExtractedExercisePracticeScreen(
          exercise: widget.result.exercise!,
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final vocabService = VocabularyService();
    final selectedWords =
        widget.result.vocabulary.where((v) => v.selected).toList();
    for (final item in selectedWords) {
      final word = SavedWord(
        id: item.word.toLowerCase().trim(),
        word: item.word,
        gender: item.gender,
        pos: item.pos,
        primaryDefinition: item.translation,
        contextSentence: item.exampleSentence,
        sourceTitle: widget.result.title,
        source: 'image_extracted',
      );
      await vocabService.upsertWord(word);
    }

    Article? savedArticle;
    if (widget.result.saveLessonText &&
        (widget.result.lessonText?.isNotEmpty ?? false)) {
      final lessonText = widget.result.lessonText!;
      savedArticle = Article(
        id: 'image_${DateTime.now().millisecondsSinceEpoch}',
        title: widget.result.title,
        description:
            '${lessonText.substring(0, lessonText.length > 50 ? 50 : lessonText.length)}...',
        level: 'Custom',
        date: DateTime.now(),
        imageUrl: 'assets/images/story_desert.png',
      );
      if (!mounted) return;
      await Provider.of<MediaLibraryService>(context, listen: false)
          .addImportedArticle(savedArticle, lessonText);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (savedArticle != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => StoryReaderScreen(article: savedArticle!)),
      );
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${selectedWords.length} word(s) saved to your deck.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final result = widget.result;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Review Extracted Content',
          style: TextStyle(
              color: colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: CappedWidth(
          maxWidth: 600,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Exercise Banner & Practice Action
                    if (result.hasExercise) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: BooksModernist.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: BooksModernist.accent.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: BooksModernist.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.quiz_rounded,
                                    size: 20,
                                    color: BooksModernist.accentDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        result.exercise!.title,
                                        style: BooksModernist.heading(
                                          size: 15,
                                          color: BooksModernist.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${result.exercise!.statements.length} Übungsfragen erkannt',
                                        style: BooksModernist.body(
                                          size: 12,
                                          color: BooksModernist.text.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (result.exercise!.instruction.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                result.exercise!.instruction,
                                style: BooksModernist.body(
                                  size: 12.5,
                                  weight: FontWeight.w600,
                                  color: BooksModernist.accentDark,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: _openExercisePractice,
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: const Text('Übung jetzt starten'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BooksModernist.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (result.notes != null && result.notes!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 18, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(result.notes!,
                                  style: const TextStyle(fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (result.vocabulary.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Vocabulary (${result.vocabulary.length} found)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _toggleSelectAll(!_allVocabSelected),
                            icon: Icon(
                              _allVocabSelected
                                  ? Icons.deselect_rounded
                                  : Icons.select_all_rounded,
                              size: 18,
                            ),
                            label: Text(_allVocabSelected
                                ? 'Deselect all'
                                : 'Select all'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...result.vocabulary.map((item) {
                        final article = _articleFor(item.gender);
                        final display =
                            article.isNotEmpty ? '$article ${item.word}' : item.word;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: CheckboxListTile(
                            value: item.selected,
                            onChanged: (v) =>
                                setState(() => item.selected = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(display,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.translation),
                                if (item.exampleSentence != null &&
                                    item.exampleSentence!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      item.exampleSentence!,
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    if (result.lessonText != null &&
                        result.lessonText!.isNotEmpty) ...[
                      SwitchListTile(
                        value: result.saveLessonText,
                        onChanged: (v) =>
                            setState(() => result.saveLessonText = v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Save as a reading lesson',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                            child: Text(result.lessonText!)),
                      ),
                    ],

                    if (result.vocabulary.isEmpty &&
                        !result.hasExercise &&
                        (result.lessonText == null || result.lessonText!.isEmpty))
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                            child: Text('Nothing usable was found in this image.')),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_hasSelection && !_isSaving) ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Save to Study Deck',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
