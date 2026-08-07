import 'package:flutter/material.dart';
import 'package:takt/l10n/app_localizations.dart';
import '../../models/grammar_lesson.dart';
import '../../services/tts_service.dart';
import '../../theme/books_modernist_style.dart';
import '../glance_word_sheet.dart';

/// Card widget for example sentences with word highlighting, TTS audio, and dictionary glance lookup.
class ExampleSentencesCard extends StatelessWidget {
  final List<ExamplePayload> examples;
  final String? title;

  const ExampleSentencesCard({
    super.key,
    required this.examples,
    this.title,
  });

  Widget _buildInteractiveSentence(
    BuildContext context,
    String text,
    List<String>? highlights,
    Color inkColor,
    bool isDark,
  ) {
    if (highlights == null || highlights.isEmpty) {
      // Split into words so each can be tapped for glance sheet
      final words = text.split(' ');
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: words.map((w) {
          final clean = w.replaceAll(RegExp(r'[^\wÄÖÜäöüß-]'), '');
          return GestureDetector(
            onTap: () {
              if (clean.isNotEmpty) {
                GlanceWordSheet.show(
                  context,
                  word: clean,
                  contextSentence: text,
                );
              }
            },
            child: Text(
              w,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: inkColor,
                height: 1.4,
              ),
            ),
          );
        }).toList(),
      );
    }

    // Build highlighted tokens
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      highlights.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );

    int start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        final plainSegment = text.substring(start, match.start);
        spans.add(
          TextSpan(
            text: plainSegment,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: inkColor,
            ),
          ),
        );
      }

      final matchedText = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF422119)
                  : const Color(0xFFFDE8E4),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: const Color(0xFF8C2D19).withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
            child: Text(
              matchedText,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8C2D19),
              ),
            ),
          ),
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: inkColor,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(height: 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFFAF6F0);
    final borderColor = isDark ? const Color(0xFF3D3730) : const Color(0xFFE5DDD0);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    const rustAccent = Color(0xFF8C2D19);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title!.trim().isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rustAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Icon(
                    Icons.record_voice_over_outlined,
                    color: rustAccent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title!,
                    style: BooksModernist.heading(
                      size: 16,
                      color: inkColor,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          ...examples.asMap().entries.map((entry) {
            final idx = entry.key;
            final example = entry.value;

            return Container(
              margin: EdgeInsets.only(
                bottom: idx == examples.length - 1 ? 0 : 12,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B1815)
                    : const Color(0xFFF2ECE1).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInteractiveSentence(
                          context,
                          example.german,
                          example.highlightedWords,
                          inkColor,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // TTS Listen button
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.volume_up_rounded,
                          size: 20,
                          color: rustAccent,
                        ),
                        tooltip: AppLocalizations.of(context)?.tooltipListenPronunciation ?? 'Aussprache anhören',
                        onPressed: () {
                          TtsService().speak(example.german);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    example.english,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: inkColor.withValues(alpha: 0.75),
                      height: 1.35,
                    ),
                  ),
                  if (example.note != null && example.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: rustAccent.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '💡 ',
                            style: TextStyle(fontSize: 12),
                          ),
                          Expanded(
                            child: Text(
                              example.note!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFFFFB4A4)
                                    : const Color(0xFF8C2D19),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
