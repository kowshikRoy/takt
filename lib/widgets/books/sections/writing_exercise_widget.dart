import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/books_modernist_style.dart';

/// Widget for free-text writing exercises (e.g. 4d personal stories, stichpunkte notes).
class WritingExerciseWidget extends StatefulWidget {
  final String sectionId;
  final String placeholder;

  const WritingExerciseWidget({
    super.key,
    required this.sectionId,
    required this.placeholder,
  });

  @override
  State<WritingExerciseWidget> createState() => _WritingExerciseWidgetState();
}

class _WritingExerciseWidgetState extends State<WritingExerciseWidget> {
  late TextEditingController _controller;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadSavedText();
  }

  Future<void> _loadSavedText() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('writing_ans_${widget.sectionId}') ?? '';
      if (mounted && saved.isNotEmpty) {
        setState(() {
          _controller.text = saved;
          _updateWordCount(saved);
        });
      }
    } catch (_) {}
  }

  void _updateWordCount(String text) {
    _wordCount = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).length;
  }

  void _onChanged(String val) {
    _updateWordCount(val);
    setState(() {});
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('writing_ans_${widget.sectionId}', val);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: BooksModernist.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            maxLines: 5,
            controller: _controller,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: BooksModernist.body(
                size: 12.5,
                color: BooksModernist.text.withValues(alpha: 0.4),
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: BooksModernist.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: BooksModernist.accent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: BooksModernist.body(size: 13),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💾 Automatisch gespeichert',
                style: BooksModernist.body(
                  size: 10.5,
                  color: BooksModernist.text.withValues(alpha: 0.5),
                ),
              ),
              Text(
                '$_wordCount Wörter',
                style: BooksModernist.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: BooksModernist.accentDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
