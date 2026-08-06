import 'package:flutter/material.dart';
import '../../../theme/books_modernist_style.dart';
import 'grammar_callout_card.dart';

/// Widget for grammar table classification exercises (e.g. 4a Perfekt tables).
class GrammarClassificationWidget extends StatelessWidget {
  final List<dynamic> tablesList;
  final Map<String, dynamic>? callout;
  final String? unitTitle;

  const GrammarClassificationWidget({
    super.key,
    required this.tablesList,
    this.callout,
    this.unitTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (callout != null) GrammarCalloutCard(callout: callout!, unitTitle: unitTitle),

        ...tablesList.map((t) {
          final tableMap = t as Map<String, dynamic>;
          final categoryTitle = tableMap['category']?.toString() ?? '';
          final columns = (tableMap['columns'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
          final rows = (tableMap['rows'] as List<dynamic>? ?? []);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            color: BooksModernist.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryTitle,
                    style: BooksModernist.heading(size: 14, color: BooksModernist.accentDark)),
                const SizedBox(height: 8),
                Table(
                  border: TableBorder.all(color: BooksModernist.divider, width: 1),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: BooksModernist.bg),
                      children: columns
                          .map((col) => Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(col,
                                    style: BooksModernist.body(
                                        size: 11, weight: FontWeight.w700)),
                              ))
                          .toList(),
                    ),
                    ...rows.map((r) {
                      final rowMap = r as Map<String, dynamic>;
                      final cellValues = rowMap.values.map((v) => v?.toString() ?? '—').toList();
                      return TableRow(
                        children: cellValues
                            .map((val) => Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(val, style: BooksModernist.body(size: 11)),
                                ))
                            .toList(),
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
