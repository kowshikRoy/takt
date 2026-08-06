import 'package:flutter/material.dart';

class NounHeadwordTitle extends StatelessWidget {
  final String word;
  final String article; // "Der", "Die", "Das" or ""
  final String? pluralForm; // e.g. "die Gesellschaften" or "Gesellschaften"
  final Color genderColor;
  final double fontSize;

  const NounHeadwordTitle({
    super.key,
    required this.word,
    required this.article,
    this.pluralForm,
    required this.genderColor,
    this.fontSize = 26.0,
  });

  static String? extractPluralForm(Map<String, dynamic> wordData) {
    if (wordData['plural'] != null &&
        wordData['plural'].toString().isNotEmpty) {
      return wordData['plural'].toString();
    }
    final forms = (wordData['forms'] as List?) ?? [];
    final wordStr = wordData['word']?.toString() ?? '';
    final baseForm = wordData['base_form']?.toString();
    final targetWord = (baseForm != null && baseForm.isNotEmpty) ? baseForm : wordStr;

    // Priority 1: Nominative plural tag
    for (final f in forms) {
      if (f is! Map) continue;
      final form = (f['form'] ?? '').toString().trim();
      final tags = (f['tags'] ?? '').toString().toLowerCase();
      if (tags.contains('plural') &&
          (tags.contains('nominative') || (!tags.contains('genitive') && !tags.contains('dative'))) &&
          form.isNotEmpty &&
          form.toLowerCase() != targetWord.toLowerCase()) {
        return form.toLowerCase().startsWith('die ') ? form : 'die $form';
      }
    }

    // Priority 2: Any plural tag
    for (final f in forms) {
      if (f is! Map) continue;
      final form = (f['form'] ?? '').toString().trim();
      final tags = (f['tags'] ?? '').toString().toLowerCase();
      if (tags.contains('plural') &&
          form.isNotEmpty &&
          form.toLowerCase() != targetWord.toLowerCase()) {
        return form.toLowerCase().startsWith('die ') ? form : 'die $form';
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String cleanPluralNoun = (pluralForm != null && pluralForm!.isNotEmpty)
        ? (pluralForm!.toLowerCase().startsWith('die ')
            ? pluralForm!.substring(4).trim()
            : pluralForm!.trim())
        : '';

    final bool hasArticle = article.isNotEmpty;
    final Color mainColor =
        hasArticle ? genderColor : colorScheme.onSurface;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: word,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: mainColor,
              ),
            ),
            if (hasArticle && cleanPluralNoun.isNotEmpty) ...[
              TextSpan(
                text: ', die $cleanPluralNoun',
                style: TextStyle(
                  fontSize: fontSize * 0.88,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        maxLines: 1,
      ),
    );
  }
}
