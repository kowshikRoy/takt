import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book_guide.dart';
import '../../services/book_guide_service.dart';
import '../../theme/books_modernist_style.dart';
import '../../theme/app_theme.dart';
import 'textbook_unit_screen.dart';
import '../../widgets/capped_width.dart';

class BookDetailScreen extends StatefulWidget {
  final BookGuide book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final Map<int, (int done, int total)> _chapterProgress = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final service = Provider.of<BookGuideService>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final Map<int, (int done, int total)> progress = {};

    for (final chapter in widget.book.chapters) {
      final unit = await service.loadTextbookUnit(chapter.jsonAssetPath);
      if (unit == null) continue;
      final allIds = unit.pages
          .expand((p) => p.sections.map((s) => s.id))
          .toSet();
      final completed = (prefs.getStringList(
                'completed_sections_unit_${unit.unitNumber}',
              ) ??
              [])
          .where(allIds.contains)
          .length;
      progress[chapter.chapterNumber] = (completed, allIds.length);
    }

    if (mounted) {
      setState(() => _chapterProgress.addAll(progress));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDone = _chapterProgress.values.fold(0, (s, p) => s + p.$1);
    final totalSections = _chapterProgress.values.fold(0, (s, p) => s + p.$2);
    final bookProgress = totalSections > 0 ? totalDone / totalSections : 0.0;

    return Theme(
      data: BooksModernist.readingTheme(context),
      child: Scaffold(
      backgroundColor: BooksModernist.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                child: CappedWidth(
                  maxWidth: 800,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBookHeader(),
                    _buildProgressSection(totalDone, totalSections, bookProgress),
                    const ModernistDivider(margin: EdgeInsets.symmetric(horizontal: 20)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'Kapitel (${widget.book.chapters.length})',
                        style: BooksModernist.heading(size: 15),
                      ),
                    ),
                    ...widget.book.chapters.map(
                      (chapter) => _buildChapterRow(context, chapter),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: BooksModernist.divider, width: 2)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(Icons.chevron_left_rounded, color: BooksModernist.text, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.book.title,
              style: BooksModernist.heading(size: 17),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GrayscaleCover(
            assetPath: widget.book.coverImage,
            width: 84,
            height: 112,
            border: Border.all(color: BooksModernist.divider),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final cefrColors = AppTheme.getCefrColors(widget.book.cefrLevel, isDark: isDark);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cefrColors.background,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: cefrColors.border, width: 0.8),
                      ),
                      child: Text(
                        'CEFR ${widget.book.cefrLevel}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cefrColors.foreground,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  widget.book.title,
                  style: BooksModernist.heading(size: 21, height: 1.15),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.book.subtitle,
                  style: BooksModernist.body(
                    size: 12.5,
                    color: BooksModernist.text.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(int done, int total, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FORTSCHRITT',
                style: BooksModernist.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: BooksModernist.text.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '$done / $total Abschnitte',
                style: BooksModernist.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: BooksModernist.text.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ModernistProgressBar(progress: progress, height: 6),
        ],
      ),
    );
  }

  Widget _buildChapterRow(BuildContext context, ChapterSummary chapter) {
    final progress = _chapterProgress[chapter.chapterNumber];
    final done = progress?.$1 ?? 0;
    final total = progress?.$2 ?? 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TextbookUnitScreen(
              chapterSummary: chapter,
              bookTitle: widget.book.title,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: BooksModernist.dividerThin)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              color: BooksModernist.text,
              child: Text(
                '${chapter.chapterNumber}',
                style: BooksModernist.heading(size: 14, color: BooksModernist.bg),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kapitel ${chapter.chapterNumber}: ${chapter.title}',
                    style: BooksModernist.heading(size: 14.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chapter.topic,
                    style: BooksModernist.body(
                      size: 12,
                      color: BooksModernist.text.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${chapter.wordCount} Wörter',
                        style: BooksModernist.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: BooksModernist.accentDark,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${chapter.audioCount} Dialoge',
                        style: BooksModernist.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: BooksModernist.accentDark,
                        ),
                      ),
                    ],
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 8),
                    ModernistProgressBar(progress: done / total, height: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (total > 0)
              Text(
                '$done/$total',
                style: BooksModernist.body(
                  size: 10,
                  weight: FontWeight.w700,
                  color: BooksModernist.accentDark,
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: BooksModernist.text.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
