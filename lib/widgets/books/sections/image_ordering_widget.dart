import 'package:flutter/material.dart';
import '../../../theme/books_modernist_style.dart';

/// Widget for listening & image ordering exercises (e.g. 4c).
class ImageOrderingWidget extends StatelessWidget {
  final String sectionId;
  final List<dynamic> imageItems;
  final String? speechBubble;

  const ImageOrderingWidget({
    super.key,
    required this.sectionId,
    required this.imageItems,
    this.speechBubble,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: imageItems.map((item) {
            final map = item as Map<String, dynamic>;
            final id = map['id']?.toString() ?? '';
            final label = map['label']?.toString() ?? '';
            final correct = map['correct_order'] as int? ?? 1;

            return Container(
              width: (MediaQuery.of(context).size.width - 72) / 2,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BooksModernist.surface,
                border: Border.all(color: BooksModernist.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 64,
                    color: BooksModernist.bg,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, size: 28, color: BooksModernist.accent),
                        const SizedBox(height: 2),
                        Text(
                          'Bild $id',
                          style: BooksModernist.heading(size: 11, color: BooksModernist.accentDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(label, style: BooksModernist.body(size: 11.5, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reihenfolge:', style: BooksModernist.body(size: 10.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: BooksModernist.accent100,
                          border: Border.all(color: BooksModernist.accent),
                        ),
                        child: Text(
                          '# $correct',
                          style: BooksModernist.body(
                            size: 11,
                            weight: FontWeight.w800,
                            color: BooksModernist.accentDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (speechBubble != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: BooksModernist.bg,
              border: Border(left: BorderSide(color: BooksModernist.accent, width: 2.5)),
            ),
            child: Text(
              '💬 „$speechBubble"',
              style: BooksModernist.body(size: 12.5, weight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}
