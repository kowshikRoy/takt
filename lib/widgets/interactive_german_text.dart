import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'glance_word_sheet.dart';

class InteractiveGermanText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final String? sourceTitle;

  const InteractiveGermanText(
    this.text, {
    super.key,
    this.style,
    this.sourceTitle,
  });

  @override
  State<InteractiveGermanText> createState() => _InteractiveGermanTextState();
}

class _InteractiveGermanTextState extends State<InteractiveGermanText> {
  late List<InlineSpan> _spans;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _buildSpans();
  }

  @override
  void didUpdateWidget(covariant InteractiveGermanText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
      _buildSpans();
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _buildSpans() {
    _spans = [];
    final regex = RegExp(r'([a-zA-ZäöüÄÖÜß]+)|([^a-zA-ZäöüÄÖÜß]+)');
    final matches = regex.allMatches(widget.text);

    for (final match in matches) {
      final word = match.group(1);
      final nonWord = match.group(2);

      if (word != null && word.length >= 2) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            GlanceWordSheet.show(
              context,
              word: word,
              contextSentence: widget.text,
              sourceTitle: widget.sourceTitle,
            );
          };
        _recognizers.add(recognizer);

        _spans.add(
          TextSpan(
            text: word,
            recognizer: recognizer,
            style: widget.style,
          ),
        );
      } else {
        _spans.add(TextSpan(text: word ?? nonWord, style: widget.style));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _spans),
      style: widget.style,
    );
  }
}
