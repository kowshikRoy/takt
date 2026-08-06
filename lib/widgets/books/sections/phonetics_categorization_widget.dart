import 'package:flutter/material.dart';
import '../../../theme/books_modernist_style.dart';

/// Widget for phonetics categorization exercises (e.g. 5b sorting words into wie ich / wie acht columns).
class PhoneticsCategorizationWidget extends StatelessWidget {
  final String sectionId;
  final List<dynamic> wordsList;
  final Map<String, dynamic>? ruleCallout;

  const PhoneticsCategorizationWidget({
    super.key,
    required this.sectionId,
    required this.wordsList,
    this.ruleCallout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ruleCallout != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BooksModernist.accent100,
              border: Border(left: BorderSide(color: BooksModernist.accent, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: BooksModernist.accentDark),
                    const SizedBox(width: 6),
                    Text(
                      ruleCallout!['title']?.toString() ?? 'Ausspracheregel: ch',
                      style: BooksModernist.heading(size: 13, color: BooksModernist.accentDark),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (ruleCallout!['wie_acht'] != null)
                  Text(ruleCallout!['wie_acht'].toString(),
                      style: BooksModernist.body(size: 11.5)),
                if (ruleCallout!['wie_ich'] != null)
                  Text(ruleCallout!['wie_ich'].toString(),
                      style: BooksModernist.body(size: 11.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCategorizationColumn(
                title: 'wie ich',
                category: 'ich',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCategorizationColumn(
                title: 'wie acht',
                category: 'acht',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorizationColumn({
    required String title,
    required String category,
  }) {
    final catWords = wordsList.where((item) {
      String targetCat = '';
      if (item is Map) {
        targetCat = item['category']?.toString() ??
            item['sound']?.toString() ??
            item['answer']?.toString() ??
            '';
      } else if (item is String) {
        final lower = item.toLowerCase();
        if (RegExp(r'(ach|och|uch|auch)').hasMatch(lower)) {
          targetCat = 'acht';
        } else {
          targetCat = 'ich';
        }
      }
      return targetCat == category;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BooksModernist.surface,
        border: Border.all(color: BooksModernist.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: BooksModernist.accent,
            child: Text(
              title,
              style: BooksModernist.body(
                size: 11.5,
                weight: FontWeight.w800,
                color: BooksModernist.bg,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...catWords.map((item) {
            final word = item is Map
                ? (item['word']?.toString() ?? '')
                : item.toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: BooksModernist.bg,
              child: Text(
                word,
                style: BooksModernist.body(size: 12, weight: FontWeight.w600),
              ),
            );
          }),
        ],
      ),
    );
  }
}
