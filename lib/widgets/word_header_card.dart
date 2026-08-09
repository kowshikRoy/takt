import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../theme/books_modernist_style.dart';
import '../models/saved_word.dart';
import '../services/tts_service.dart';
import '../services/dictionary_service.dart';
import 'vocab_status_pills.dart';
import 'noun_headword_title.dart';
import 'edit_word_dialog.dart';

class WordHeaderCard extends StatelessWidget {
  final Map<String, dynamic> wordData;
  final String? pluralForm;
  final Set<String> savedWordIds;
  final Map<String, VocabCategory> savedWordCategories;
  final ValueChanged<VocabCategory> onCategorySelected;
  final Future<String?>? wordImageFuture;
  final String? contextSentence;
  final String? ipa;
  final bool showStatusPills;
  final VoidCallback? onWordEdited;

  WordHeaderCard({
    super.key,
    required this.wordData,
    this.pluralForm,
    required this.savedWordIds,
    required this.savedWordCategories,
    required this.onCategorySelected,
    this.wordImageFuture,
    this.contextSentence,
    this.ipa,
    this.showStatusPills = true,
    this.onWordEdited,
  });

  final TtsService _ttsService = TtsService();

  String _inferGenderIfNull(String wordStr, String? rawGender, String? pos) {
    if (rawGender != null && rawGender.trim().isNotEmpty) {
      final g = rawGender.trim().toLowerCase();
      if (g == 'masculine' || g == 'm') return 'm';
      if (g == 'feminine' || g == 'f') return 'f';
      if (g == 'neuter' || g == 'n') return 'n';
    }
    final isNoun =
        pos == null ||
        pos.isEmpty ||
        pos.toLowerCase().contains('noun') ||
        (wordStr.isNotEmpty && wordStr[0] == wordStr[0].toUpperCase());

    if (!isNoun) return '';

    final lower = wordStr.toLowerCase();

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

    if (lower.endsWith('ismus') ||
        lower.endsWith('ling') ||
        lower.endsWith('or')) {
      return 'm';
    }

    return '';
  }

  Color _getGenderColor(String gender) {
    if (gender == 'm') return AppTheme.genderMasc;
    if (gender == 'f') return AppTheme.genderFem;
    if (gender == 'n') return AppTheme.genderNeu;
    return Colors.teal;
  }

  String _getArticle(String gender) {
    if (gender == 'm') return 'Der';
    if (gender == 'f') return 'Die';
    if (gender == 'n') return 'Das';
    return '';
  }

  String _getCefrLevel(dynamic freqRaw) => DictionaryService.getCefrLevel(freqRaw);

  List<String> _extractDefinitions(Map<String, dynamic> data) {
    if (data['definitions'] != null) {
      final list = List<String>.from(data['definitions'])
          .map((d) => d.toString().trim())
          .where((d) => d.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    }
    if (data['definition'] != null && data['definition'].toString().trim().isNotEmpty) {
      return [data['definition'].toString().trim()];
    }
    return [];
  }

  String _extractSingleSentence(String rawText, String targetWord) {
    if (!rawText.contains('.')) return rawText;
    final sentences = rawText.split(RegExp(r'(?<=[.!?])\s+'));
    final lowerWord = targetWord.toLowerCase();
    for (final s in sentences) {
      if (s.toLowerCase().contains(lowerWord)) {
        return s.trim();
      }
    }
    return sentences.first.trim();
  }

  Widget _buildMeaningSourceBadge(BuildContext context, Map<String, dynamic> data) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final source = data['source']?.toString().toLowerCase() ?? '';
    final isUserEdited = source == 'user_edited' || source == 'custom';
    final isWiki = data['isWiktionaryFallback'] == true || source == 'wiktionary' || source == 'wiktionary_fetched';
    final isNmt = data['isNmtTranslation'] == true || source == 'nmt_translation';

    IconData icon;
    String label;
    Color badgeColor;

    if (isUserEdited) {
      icon = Icons.edit_note_rounded;
      label = "Custom Note";
      badgeColor = Colors.purple.shade700;
    } else if (isWiki) {
      icon = Icons.public_rounded;
      label = "Wiktionary";
      badgeColor = Colors.blue.shade700;
    } else if (isNmt) {
      icon = Icons.g_translate_rounded;
      label = "Google Translate";
      badgeColor = Colors.deepPurple.shade400;
    } else {
      icon = Icons.menu_book_rounded;
      label = "Dictionary";
      badgeColor = colorScheme.primary;
    }

    return Tooltip(
      message: "Meaning source: $label",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: badgeColor.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 11.5,
              color: badgeColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: badgeColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextSentence(
    BuildContext context,
    String rawText,
    String targetWord,
  ) {
    final sentence = _extractSingleSentence(rawText, targetWord);
    final cleanWord = targetWord.replaceAll(RegExp(r'[^\wäöüÄÖÜß]'), '').trim();
    if (cleanWord.isEmpty ||
        !sentence.toLowerCase().contains(cleanWord.toLowerCase())) {
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
        spans.add(
          TextSpan(
            text: sentence.substring(lastEnd, match.start),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: sentence.substring(match.start, match.end),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < sentence.length) {
      spans.add(
        TextSpan(
          text: sentence.substring(lastEnd),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final word = wordData['word']?.toString() ?? '';
    final pos = wordData['pos']?.toString();
    final rawGender = wordData['gender']?.toString();
    final gender = _inferGenderIfNull(word, rawGender, pos);
    final freq = wordData['freq_rank'];
    final defs = _extractDefinitions(wordData);
    final wordId = word.toLowerCase().trim();

    final genderColor = _getGenderColor(gender);
    final article = _getArticle(gender);
    final resolvedPlural =
        pluralForm ?? NounHeadwordTitle.extractPluralForm(wordData);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Single Header Line: [Article] Noun, [die] Plural Form   [speaker] [Level]
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
              child: NounHeadwordTitle(
                word: word,
                article: article,
                pluralForm: resolvedPlural,
                genderColor: genderColor,
                fontSize: 22,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.volume_up_rounded, size: 20, color: genderColor),
              onPressed: () {
                String textToSpeak = word;
                if (article.isNotEmpty) {
                  if (resolvedPlural != null && resolvedPlural.isNotEmpty) {
                    final pluralStr =
                        resolvedPlural.toLowerCase().startsWith('die ')
                        ? resolvedPlural
                        : 'die $resolvedPlural';
                    textToSpeak = '$article $word, $pluralStr';
                  } else {
                    textToSpeak = '$article $word';
                  }
                }
                _ttsService.speak(textToSpeak, lang: 'de-DE');
              },
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final cefr = _getCefrLevel(freq);
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final cefrColors = AppTheme.getCefrColors(cefr, isDark: isDark);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cefrColors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: cefrColors.border, width: 0.8),
                  ),
                  child: Text(
                    cefr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cefrColors.foreground,
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        if (ipa != null && ipa!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            ipa!,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],

        const SizedBox(height: 16),

        // Optional Image
        if (wordImageFuture != null) _buildWordImage(context),

        // Definitions Header + List
        if (defs.isNotEmpty) ...[
          Row(
            children: [
              Text(
                "DEFINITION",
                style: BooksModernist.heading(
                  size: 11,
                  color: colorScheme.primary,
                  context: context,
                ),
              ),
              if ((pos ?? '').isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    pos!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              _buildMeaningSourceBadge(context, wordData),
              if (showStatusPills) ...[
                const SizedBox(width: 8),
                VocabStatusPills(
                  iconOnly: true,
                  currentCategory: savedWordCategories[wordId] ??
                      (savedWordIds.contains(wordId)
                          ? VocabCategory.reviewLater
                          : null),
                  onCategorySelected: onCategorySelected,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ...defs.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "→ ",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      d,
                      style: BooksModernist.body(
                        size: 14.5,
                        weight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        context: context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Text(
            "No dictionary definition found.",
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],

        // Context Sentence snippet
        if (contextSentence != null && contextSentence!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Context",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildContextSentence(context, contextSentence!, word),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWordImage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<String?>(
      future: wordImageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final imageUrl = snapshot.data;
        if (imageUrl == null || imageUrl.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: colorScheme.surfaceContainerHigh),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
