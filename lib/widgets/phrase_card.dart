import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/german_phrase.dart';
import '../services/phrase_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import 'phrase_detail_sheet.dart';

class PhraseCard extends StatelessWidget {
  final GermanPhrase phrase;

  const PhraseCard({super.key, required this.phrase});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFFBF8F2);
    final rustAccent = const Color(0xFF8C2D19);
    final cefrColors = AppTheme.getCefrColors(phrase.level, isDark: isDark);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => PhraseDetailSheet.show(context, phrase),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Meta Row
              Row(
                children: [
                  // Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cefrColors.background,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: cefrColors.border, width: 0.8),
                    ),
                    child: Text(
                      phrase.level.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: cefrColors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Formality Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: inkColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      phrase.formality == 'formal'
                          ? 'Sie'
                          : phrase.formality == 'informal'
                              ? 'Du'
                              : 'Neutral',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: inkColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Category Label
                  Expanded(
                    child: Text(
                      phrase.category,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: rustAccent,
                      ),
                    ),
                  ),

                  // Bookmark Button
                  Consumer<PhraseService>(
                    builder: (context, phraseService, _) {
                      final isBookmarked =
                          phraseService.isBookmarked(phrase.id);
                      return IconButton(
                        icon: Icon(
                          isBookmarked
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 20,
                          color: isBookmarked
                              ? Colors.amber[700]
                              : inkColor.withValues(alpha: 0.4),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: isBookmarked ? 'Bookmarked' : 'Bookmark',
                        onPressed: () {
                          phraseService.toggleBookmark(phrase.id);
                        },
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Main German Phrase
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      phrase.german,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'serif',
                        color: inkColor,
                        height: 1.25,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.volume_up_rounded,
                      size: 20,
                      color: rustAccent,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Listen',
                    onPressed: () => TtsService().speak(phrase.german),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // English Translation
              Text(
                phrase.english,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: inkColor.withValues(alpha: 0.85),
                ),
              ),

              if (phrase.situation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  phrase.situation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: inkColor.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
