import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/german_phrase.dart';
import '../services/phrase_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

class PhraseDetailSheet extends StatelessWidget {
  final GermanPhrase phrase;

  const PhraseDetailSheet({super.key, required this.phrase});

  static Future<void> show(BuildContext context, GermanPhrase phrase) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhraseDetailSheet(phrase: phrase),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final bg = isDark ? const Color(0xFF201C18) : const Color(0xFFFAF6F0);
    final rustAccent = const Color(0xFF8C2D19);
    final cefrColors = AppTheme.getCefrColors(phrase.level, isDark: isDark);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: inkColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row
                  Row(
                    children: [
                      // Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cefrColors.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: cefrColors.border, width: 1),
                        ),
                        child: Text(
                          phrase.level.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: cefrColors.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Formality Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: inkColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: inkColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          phrase.formality == 'formal'
                              ? 'Formal (Sie)'
                              : phrase.formality == 'informal'
                                  ? 'Informal (Du)'
                                  : 'Neutral',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: inkColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Category Tag
                      Expanded(
                        child: Text(
                          phrase.category,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: rustAccent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // German Phrase + Audio
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          phrase.german,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'serif',
                            height: 1.25,
                            color: inkColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.volume_up_rounded),
                        onPressed: () {
                          TtsService().speak(phrase.german);
                        },
                        tooltip: 'Listen to pronunciation',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // English Meaning Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF28231E)
                          : const Color(0xFFF2ECE1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: inkColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.translate_rounded,
                                size: 16, color: rustAccent),
                            const SizedBox(width: 6),
                            Text(
                              'ENGLISH MEANING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: rustAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          phrase.english,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: inkColor,
                          ),
                        ),
                        if (phrase.literalTranslation.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Divider(
                            color: inkColor.withValues(alpha: 0.1),
                            height: 1,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Literal: ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                  color: inkColor.withValues(alpha: 0.6),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  phrase.literalTranslation,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: inkColor.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Situation Context
                  if (phrase.situation.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 16, color: inkColor),
                        const SizedBox(width: 6),
                        Text(
                          'WHEN TO USE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: inkColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phrase.situation,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: inkColor.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Mini Dialogue
                  if (phrase.dialogue != null) ...[
                    Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 16, color: rustAccent),
                        const SizedBox(width: 6),
                        Text(
                          'CONVERSATION EXAMPLE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: rustAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDialogueCard(context, phrase.dialogue!, isDark, inkColor),
                    const SizedBox(height: 16),
                  ],

                  // Cultural Etiquette Tip
                  if (phrase.culturalNote.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEE9B00).withValues(alpha: isDark ? 0.15 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFEE9B00).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: Color(0xFFBB3E03),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CULTURAL INSIGHT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFFFFB74D)
                                        : const Color(0xFFBB3E03),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  phrase.culturalNote,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: inkColor.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Actions Row
                  Consumer<PhraseService>(
                    builder: (context, phraseService, _) {
                      final isBookmarked = phraseService.isBookmarked(phrase.id);

                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: inkColor,
                                side: BorderSide(
                                  color: inkColor.withValues(alpha: 0.3),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: Icon(
                                isBookmarked
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: isBookmarked ? Colors.amber[700] : null,
                              ),
                              label: Text(
                                isBookmarked ? 'Bookmarked' : 'Bookmark',
                              ),
                              onPressed: () {
                                phraseService.toggleBookmark(phrase.id);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: rustAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text('Save to Deck'),
                              onPressed: () async {
                                final success = await phraseService
                                    .savePhraseToVocabulary(phrase, context);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Saved phrase to your SRS review deck!'
                                            : 'Could not save phrase.',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogueCard(
    BuildContext context,
    PhraseDialogue dialogue,
    bool isDark,
    Color inkColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191613) : const Color(0xFFF7F3EB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: inkColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // Speaker A line
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: inkColor.withValues(alpha: 0.1),
                child: Text(
                  'A',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: inkColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogue.speakerA,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: inkColor,
                      ),
                    ),
                    Text(
                      dialogue.englishA,
                      style: TextStyle(
                        fontSize: 12,
                        color: inkColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => TtsService().speak(dialogue.speakerA),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: inkColor.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 10),
          // Speaker B line
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFF8C2D19).withValues(alpha: 0.15),
                child: const Text(
                  'B',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8C2D19),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogue.speakerB,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: inkColor,
                      ),
                    ),
                    Text(
                      dialogue.englishB,
                      style: TextStyle(
                        fontSize: 12,
                        color: inkColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => TtsService().speak(dialogue.speakerB),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
