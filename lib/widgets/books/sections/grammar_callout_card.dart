import 'package:flutter/material.dart';
import '../../../theme/books_modernist_style.dart';
import '../../interactive_german_text.dart';

/// Card widget for textbook grammar callouts (e.g. G Genitiv, G Perfekt).
class GrammarCalloutCard extends StatelessWidget {
  final Map<String, dynamic> callout;
  final String? unitTitle;

  const GrammarCalloutCard({
    super.key,
    required this.callout,
    this.unitTitle,
  });

  @override
  Widget build(BuildContext context) {
    final title = callout['title']?.toString() ?? 'G Grammatik';
    final formula = callout['formula']?.toString();
    final examples = callout['examples'] is List ? (callout['examples'] as List) : [];
    final rules = callout['rules'] is List ? (callout['rules'] as List) : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BooksModernist.accent100.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BooksModernist.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BooksModernist.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'G',
                  style: BooksModernist.heading(size: 15, color: BooksModernist.bg),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: BooksModernist.heading(size: 14, color: BooksModernist.accentDark),
                    ),
                    if (formula != null)
                      Text(
                        formula,
                        style: BooksModernist.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: BooksModernist.accentDark,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (examples.isNotEmpty || rules.isNotEmpty) const SizedBox(height: 10),
          ...examples.map((ex) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InteractiveGermanText(
                  ex.toString(),
                  sourceTitle: unitTitle,
                  style: BooksModernist.body(size: 12.5, weight: FontWeight.w600),
                ),
              )),
          ...rules.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ${r.toString()}',
                  style: BooksModernist.body(size: 11.5),
                ),
              )),
        ],
      ),
    );
  }
}
