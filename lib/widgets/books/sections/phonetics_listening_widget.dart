import 'package:flutter/material.dart';
import '../../../theme/books_modernist_style.dart';

/// Widget for phonetics listening choice exercises (e.g. 5a wie ich vs wie acht).
class PhoneticsListeningWidget extends StatefulWidget {
  final String sectionId;
  final List<dynamic> wordsList;

  const PhoneticsListeningWidget({
    super.key,
    required this.sectionId,
    required this.wordsList,
  });

  @override
  State<PhoneticsListeningWidget> createState() => _PhoneticsListeningWidgetState();
}

class _PhoneticsListeningWidgetState extends State<PhoneticsListeningWidget> {
  final Map<String, String> _userChoices = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.wordsList.map((item) {
            final map = item is Map ? item : <String, dynamic>{};
            final id = map['id']?.toString() ?? (item is String ? item : '');
            final word = map['word']?.toString() ?? (item is String ? item : '');
            final correctAns = map['answer']?.toString() ??
                map['sound']?.toString() ??
                (RegExp(r'(ach|och|uch|auch)', caseSensitive: false).hasMatch(word) ? 'acht' : 'ich');
            final options = map['options'] is List
                ? (map['options'] as List).map((e) => e.toString()).toList()
                : ['ich', 'acht'];
            final selected = _userChoices[id];
            final isDone = selected != null;
            final isCorrect = selected == correctAns;

            return Container(
              width: (MediaQuery.of(context).size.width - 72) / 2,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BooksModernist.surface,
                border: Border.all(
                  color: isDone
                      ? (isCorrect ? BooksModernist.accent : BooksModernist.accent600)
                      : BooksModernist.divider,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word,
                    style: BooksModernist.heading(size: 13.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: options.map((opt) {
                      final displayLabel = opt.startsWith('wie ') ? opt : 'wie $opt';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: _choiceButton(
                            label: displayLabel,
                            active: selected == opt,
                            onTap: () => setState(() => _userChoices[id] = opt),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (isDone) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Richtig: wie $correctAns',
                      style: BooksModernist.body(
                        size: 10,
                        weight: FontWeight.w700,
                        color: BooksModernist.accentDark,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _choiceButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? BooksModernist.accent : BooksModernist.bg,
          border: Border.all(
            color: active ? BooksModernist.accent : BooksModernist.divider,
          ),
        ),
        child: Text(
          label,
          style: BooksModernist.body(
            size: 10.5,
            weight: FontWeight.w700,
            color: active ? BooksModernist.bg : BooksModernist.text,
          ),
        ),
      ),
    );
  }
}
