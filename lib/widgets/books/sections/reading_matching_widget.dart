import 'package:flutter/material.dart';
import '../../../theme/books_modernist_style.dart';
import '../../interactive_german_text.dart';

/// Generic, data-driven section widget for headline-to-text matching (e.g. 3a).
class ReadingMatchingWidget extends StatefulWidget {
  final String sectionId;
  final List<dynamic> headings;
  final List<dynamic> texts;
  final String? unitTitle;

  const ReadingMatchingWidget({
    super.key,
    required this.sectionId,
    required this.headings,
    required this.texts,
    this.unitTitle,
  });

  @override
  State<ReadingMatchingWidget> createState() => _ReadingMatchingWidgetState();
}

class _ReadingMatchingWidgetState extends State<ReadingMatchingWidget> {
  final Map<String, String> _userChoices = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Headline Options Pool
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BooksModernist.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BooksModernist.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.format_quote_rounded, size: 16, color: BooksModernist.accentDark),
                  const SizedBox(width: 6),
                  Text(
                    'Überschriften:',
                    style: BooksModernist.heading(size: 12.5, color: BooksModernist.accentDark),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...widget.headings.map((h) {
                final map = h as Map<String, dynamic>;
                final id = map['id']?.toString() ?? '';
                final title = map['title']?.toString() ?? '';

                // Check if this heading is assigned to any text
                final usedBy = _userChoices.entries
                    .where((e) => e.value == id)
                    .map((e) => e.key)
                    .toList();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: usedBy.isNotEmpty
                              ? BooksModernist.accent
                              : BooksModernist.accent100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: BooksModernist.accent),
                        ),
                        child: Text(
                          id,
                          style: BooksModernist.heading(
                            size: 12,
                            color: usedBy.isNotEmpty
                                ? BooksModernist.bg
                                : BooksModernist.accentDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InteractiveGermanText(
                          title,
                          sourceTitle: widget.unitTitle,
                          style: BooksModernist.body(
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (usedBy.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: BooksModernist.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Zuordnung: ${usedBy.join(", ")}',
                            style: BooksModernist.body(
                              size: 10,
                              weight: FontWeight.bold,
                              color: BooksModernist.bg,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        // 2. Data-driven Text Matching Cards
        ...widget.texts.map((t) {
          final map = t as Map<String, dynamic>;
          final person = map['person']?.toString() ?? map['id']?.toString() ?? map['label']?.toString() ?? '';
          final selectedHeading = _userChoices[person];
          final correctHeading = map['answer']?.toString() ?? map['correct_heading']?.toString() ?? map['correct']?.toString() ?? '';
          final hasSelection = selectedHeading != null && selectedHeading.isNotEmpty;
          final isCorrect = correctHeading.isEmpty || (hasSelection && selectedHeading == correctHeading);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BooksModernist.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasSelection
                    ? (isCorrect ? BooksModernist.accent : BooksModernist.accent600)
                    : BooksModernist.divider,
                width: hasSelection ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: BooksModernist.accent,
                      child: Text(
                        person.isNotEmpty ? person[0] : '?',
                        style: BooksModernist.heading(size: 12, color: BooksModernist.bg),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Welche Überschrift passt zu $person?',
                      style: BooksModernist.heading(size: 13.5, color: BooksModernist.accentDark),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Dynamic 1-Tap Headline Choice Chips (A, B, C, D...)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: widget.headings.map((h) {
                    final hid = (h as Map)['id']?.toString() ?? '';
                    final isChosen = selectedHeading == hid;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          if (isChosen) {
                            _userChoices.remove(person);
                          } else {
                            _userChoices[person] = hid;
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isChosen ? BooksModernist.accent : BooksModernist.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isChosen ? BooksModernist.accent : BooksModernist.divider,
                            width: isChosen ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Überschrift $hid',
                              style: BooksModernist.body(
                                size: 12,
                                weight: FontWeight.bold,
                                color: isChosen ? BooksModernist.bg : BooksModernist.text,
                              ),
                            ),
                            if (isChosen) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                size: 14,
                                color: BooksModernist.bg,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
