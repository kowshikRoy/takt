import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../theme/books_modernist_style.dart';
import '../models/saved_word.dart';
import '../services/tts_service.dart';
import '../services/dictionary_service.dart';
import '../services/goethe_curriculum_service.dart';
import '../services/haptic_service.dart';
import 'vocab_status_pills.dart';
import 'noun_headword_title.dart';
import 'base_form_tooltip_link.dart';
import 'sense_badge_chip.dart';

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
  final VoidCallback? onExplore;
  final bool showSpeakerButton;

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
    this.onExplore,
    this.showSpeakerButton = true,
  });

  final TtsService _ttsService = TtsService();

  static String _inferGenderIfNull(String wordStr, String? rawGender, String? pos) {
    // A known non-noun POS (adj, verb, ...) must never show a gender/article
    // — German verbs/adjectives don't have grammatical gender, full stop.
    // This overrides even an explicit `rawGender` value: stale or mis-tagged
    // data (e.g. a saved word whose gender field predates a dictionary fix)
    // must not resurrect a bogus "Der/Die/Das" just because some gender
    // string happens to be present.
    final posLower = pos?.toLowerCase().trim() ?? '';
    final posKnownNonNoun = posLower.isNotEmpty && !posLower.contains('noun');
    if (posKnownNonNoun) return '';

    if (rawGender != null && rawGender.trim().isNotEmpty) {
      final g = rawGender.trim().toLowerCase();
      if (g == 'masculine' || g == 'm') return 'm';
      if (g == 'feminine' || g == 'f') return 'f';
      if (g == 'neuter' || g == 'n') return 'n';
    }
    // Capitalization is only a useful noun hint when the POS is genuinely
    // unknown (already excluded the known-non-noun case above).
    final isNoun = pos == null ||
        pos.isEmpty ||
        posLower.contains('noun') ||
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

  String _getArticle(String gender) => _getArticleStatic(gender);

  static String _getArticleStatic(String gender) {
    if (gender == 'm') return 'Der';
    if (gender == 'f') return 'Die';
    if (gender == 'n') return 'Das';
    return '';
  }

  /// Builds the text to speak for a word's header: "Der/Die/Das Word, die
  /// Plural" when it's a noun with a known gender and plural, or just the
  /// bare word otherwise. Shared by the header's own speaker button and by
  /// callers (e.g. the review/practice screen) that want to auto-play the
  /// same thing when a card flips to reveal its answer.
  static String buildSpeakText(Map<String, dynamic> wordData) {
    final word = wordData['word']?.toString() ?? '';
    final pos = wordData['pos']?.toString();
    final rawGender = wordData['gender']?.toString();
    final gender = _inferGenderIfNull(word, rawGender, pos);
    final article = _getArticleStatic(gender);
    if (article.isEmpty) return word;

    final resolvedPlural = NounHeadwordTitle.extractPluralForm(wordData);
    if (resolvedPlural != null && resolvedPlural.isNotEmpty) {
      final pluralStr = resolvedPlural.toLowerCase().startsWith('die ')
          ? resolvedPlural
          : 'die $resolvedPlural';
      return '$article $word, $pluralStr';
    }
    return '$article $word';
  }

  String _getCefrLevel(dynamic freqRaw, {String? word, String? baseForm}) =>
      DictionaryService.getCefrLevel(freqRaw, word: word, baseForm: baseForm);

  Widget _buildUnifiedLevelBadge(BuildContext context, dynamic freqRaw, {required String word, String? baseForm}) {
    final goethe = GoetheCurriculumService.getGoetheLevel(word, baseForm: baseForm);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (goethe != null) {
      return Tooltip(
        message: "Certified in official Goethe-Institut $goethe core curriculum",
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: isDark ? 0.20 : 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.green.withValues(alpha: isDark ? 0.40 : 0.30),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 12, color: Colors.green),
              const SizedBox(width: 3.5),
              Text(
                goethe,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Alternative: Statistical CEFR level based on frequency
    final cefr = _getCefrLevel(freqRaw, word: word, baseForm: baseForm);
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
  }

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

  /// Grammatical labels that mark a definition as an inflected-form gloss
  /// (noun cases/plural, verb person/tense/mood, adjective degrees, and derivations)
  /// rather than an ordinary dictionary sense.
  static const _grammaticalFormKeywords = [
    'strong', 'weak', 'mixed', 'inflection', 'participle', 'plural',
    'genitive', 'dative', 'accusative', 'nominative', 'singular',
    'degree', 'comparative', 'superlative',
    'person', 'present', 'past', 'imperative', 'subjunctive',
    'indicative', 'preterite', 'perfect', 'tense',
    'equivalent', 'diminutive', 'spelling', 'form', 'agent',
    'gerund', 'nominalization', 'verbal', 'synonym', 'abbreviation',
  ];

  /// If [d] is an inflected-form gloss (e.g. "plural of Temperatur",
  /// "genitive singular of Haus", "third-person singular present of
  /// gehen", "inflection of schön:"), splits it into the leading grammatical label,
  /// the base word it points to, and any optional trailing qualifier.
  ({String prefix, String baseWord, String? suffix})? _parseFormOfDefinition(String d) {
    final trimmed = d.trim();
    if (trimmed.isEmpty) return null;

    final headword = (wordData['word']?.toString() ?? '').trim();

    // Pattern 1: "inflection of <base>[: ...]"
    final matchInflection = RegExp(
      r'^(inflection\s+of\s+)([A-ZÄÖÜa-zäöüß][\wäöüÄÖÜß-]*)(?:[:\s\n]([\s\S]*))?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (matchInflection != null) {
      final baseWord = matchInflection.group(2)!.trim();
      if (baseWord.isNotEmpty && baseWord.toLowerCase() != headword.toLowerCase()) {
        final suffix = matchInflection.group(3)?.trim();
        return (
          prefix: matchInflection.group(1)!,
          baseWord: baseWord,
          suffix: (suffix != null && suffix.isNotEmpty) ? ': $suffix' : null,
        );
      }
    }

    // Pattern 2: "<prefix...> of <base>[: ...]"
    final match = RegExp(
      r'^(.*\bof\s+)([A-ZÄÖÜa-zäöüß][\wäöüÄÖÜß-]*)(?:[:\s]([\s\S]*))?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match == null) return null;

    final prefix = match.group(1)!;
    final lowerPrefix = prefix.toLowerCase();
    final looksLikeFormOf =
        _grammaticalFormKeywords.any((k) => lowerPrefix.contains(k));
    if (!looksLikeFormOf) return null;

    final baseWord = match.group(2)!.trim();
    if (baseWord.isEmpty || baseWord.toLowerCase() == headword.toLowerCase()) {
      return null;
    }
    final suffix = match.group(3)?.trim();
    return (
      prefix: prefix,
      baseWord: baseWord,
      suffix: (suffix != null && suffix.isNotEmpty) ? ': $suffix' : null,
    );
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

    final baseForm = (wordData['base_form'] as String?)?.trim();
    final baseWordId = (baseForm != null && baseForm.isNotEmpty)
        ? baseForm.toLowerCase().trim()
        : wordId;

    final genderColor = _getGenderColor(gender);
    final article = _getArticle(gender);
    // A known non-noun POS (adj, verb, ...) must never show a "die ..." plural
    // header — adjectives/verbs have their own "plural"-tagged inflection
    // forms (e.g. "weiße" for the adjective "weiß") that aren't noun plurals.
    final posLowerForPlural = pos?.toLowerCase().trim() ?? '';
    final isKnownNonNoun =
        posLowerForPlural.isNotEmpty && !posLowerForPlural.contains('noun');
    final resolvedPlural = isKnownNonNoun
        ? null
        : (pluralForm ?? NounHeadwordTitle.extractPluralForm(wordData));

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
            if (showSpeakerButton) ...[
              const SizedBox(width: 6),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.volume_up_rounded, size: 20, color: genderColor),
                onPressed: () {
                  AppHaptics.light();
                  _ttsService.speak(buildSpeakText(wordData), lang: 'de-DE');
                },
              ),
            ],
            const SizedBox(width: 8),
            _buildUnifiedLevelBadge(
              context,
              freq,
              word: word,
              baseForm: (wordData['base_form'] as String?)?.trim(),
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
            ],
          ),
          const SizedBox(height: 8),
          ...defs.asMap().entries.map((entry) {
            final idx = entry.key;
            final d = entry.value;
            final contextMatchedIdx = wordData['context_matched_sense_index'] as int?;
            final badges = DictionaryService.parseSenseBadges(
              d,
              idx,
              contextMatchedIndex: contextMatchedIdx,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${idx + 1}. ",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Builder(builder: (context) {
                            final defStyle = BooksModernist.body(
                              size: 14.5,
                              weight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              context: context,
                            );
                            final formOf = _parseFormOfDefinition(d);
                            if (formOf == null) {
                              return Text(d, style: defStyle);
                            }
                            return BaseFormTooltipLink(
                              prefix: formOf.prefix,
                              baseWord: formOf.baseWord,
                              suffix: formOf.suffix,
                              style: defStyle,
                            );
                          }),
                        ),
                        if (badges.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          SenseBadgeWrap(badges: badges),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
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

        // Vocabulary Status Bar (In Deck, Known, Explore)
        if (showStatusPills) ...[
          const SizedBox(height: 16),
          VocabStatusPills(
            iconOnly: false,
            currentCategory: savedWordCategories[wordId] ??
                savedWordCategories[baseWordId] ??
                (savedWordIds.contains(wordId) || savedWordIds.contains(baseWordId)
                    ? VocabCategory.reviewLater
                    : null),
            onCategorySelected: onCategorySelected,
            onExplore: onExplore,
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
