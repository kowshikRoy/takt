import 'package:flutter/material.dart';
import '../../../theme/books_modernist_style.dart';

/// Clean, robust interactive widget for fill-in-the-blank statements (e.g. 3c).
class FillInStatementsWidget extends StatefulWidget {
  final String sectionId;
  final List<dynamic> statements;
  final List<dynamic>? optionsList;
  final String? unitTitle;

  const FillInStatementsWidget({
    super.key,
    required this.sectionId,
    required this.statements,
    this.optionsList,
    this.unitTitle,
  });

  @override
  State<FillInStatementsWidget> createState() => _FillInStatementsWidgetState();
}

class _FillInStatementsWidgetState extends State<FillInStatementsWidget> {
  final Map<String, String> _userChoices = {};
  bool _showSolution = false;

  @override
  Widget build(BuildContext context) {
    final options = widget.optionsList != null
        ? widget.optionsList!.map((e) => e.toString()).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Option Pool Header
        if (options.isNotEmpty) ...[
          Container(
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
                    Icon(Icons.style_outlined, size: 16, color: BooksModernist.accentDark),
                    const SizedBox(width: 6),
                    Text(
                      'Auswahl-Pool:',
                      style: BooksModernist.heading(size: 12.5, color: BooksModernist.accentDark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: options.map((opt) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: BooksModernist.bg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: BooksModernist.divider),
                      ),
                      child: Text(
                        opt,
                        style: BooksModernist.body(size: 11.5, weight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 2. Statements List
        ...widget.statements.map((st) {
          final map = st as Map<String, dynamic>;
          final id = map['id']?.toString() ?? '';
          final text = map['text']?.toString() ?? '';
          final correctAns = map['answer']?.toString() ?? '';
          final selected = _userChoices[id];
          final hasSelection = selected != null && selected.isNotEmpty;
          final isCorrect = hasSelection && selected == correctAns;

          // Format sentence with selected word or blank placeholder
          final formattedSentence = text.contains('...')
              ? text.replaceFirst('...', hasSelection ? selected : '________')
              : (text.contains('___')
                  ? text.replaceFirst('___', hasSelection ? selected : '________')
                  : (hasSelection ? '$selected $text' : '________ $text'));

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BooksModernist.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _showSolution
                    ? BooksModernist.accent
                    : (hasSelection
                        ? (isCorrect ? BooksModernist.accent : BooksModernist.accent600)
                        : BooksModernist.divider),
                width: (hasSelection || _showSolution) ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sentence Text Display
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$id. ',
                      style: BooksModernist.heading(
                        size: 13.5,
                        color: BooksModernist.text.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: formattedSentence,
                              style: BooksModernist.body(
                                size: 13.5,
                                weight: hasSelection ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasSelection) ...[
                      const SizedBox(width: 6),
                      Icon(
                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        size: 18,
                        color: isCorrect ? BooksModernist.accent : BooksModernist.accent600,
                      ),
                    ],
                  ],
                ),

                // Option Choice Buttons
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: options.map((opt) {
                      final isChosen = selected == opt;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isChosen) {
                              _userChoices.remove(id);
                            } else {
                              _userChoices[id] = opt;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isChosen ? BooksModernist.accent : BooksModernist.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isChosen ? BooksModernist.accent : BooksModernist.divider,
                              width: isChosen ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                opt,
                                style: BooksModernist.body(
                                  size: 11.5,
                                  weight: FontWeight.w700,
                                  color: isChosen ? BooksModernist.bg : BooksModernist.text,
                                ),
                              ),
                              if (isChosen) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.check_rounded,
                                  size: 13,
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

                // Solution Display (when solution toggle is active)
                if (_showSolution && correctAns.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '✓ Richtige Antwort: $correctAns',
                    style: BooksModernist.body(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        // Action Buttons: Reset & Solution Toggle
        const SizedBox(height: 6),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showSolution = !_showSolution;
                });
              },
              icon: Icon(
                _showSolution ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 16,
              ),
              label: Text(
                _showSolution ? 'Lösung ausblenden' : 'Lösung anzeigen',
                style: BooksModernist.body(size: 11.5, weight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: BooksModernist.accentDark,
                side: BorderSide(color: BooksModernist.accent),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _userChoices.clear();
                  _showSolution = false;
                });
              },
              child: Text(
                'Zurücksetzen',
                style: BooksModernist.body(
                  size: 11.5,
                  color: BooksModernist.text.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
