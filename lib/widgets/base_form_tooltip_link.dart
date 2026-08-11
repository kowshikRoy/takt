import 'package:flutter/material.dart';
import '../services/dictionary_service.dart';
import '../services/haptic_service.dart';
import '../screens/word_detail_screen.dart';

/// Renders [baseWord] highlighted (bold + primary color + dotted underline)
/// alongside its bracketed meaning inline (e.g. "Haus (house, building)").
/// Tapping it triggers haptic feedback and opens the word's full dictionary entry.
class BaseFormTooltipLink extends StatefulWidget {
  final String baseWord;
  final TextStyle style;

  const BaseFormTooltipLink({
    super.key,
    required this.baseWord,
    required this.style,
  });

  @override
  State<BaseFormTooltipLink> createState() => _BaseFormTooltipLinkState();
}

class _BaseFormTooltipLinkState extends State<BaseFormTooltipLink> {
  static final Map<String, String> _meaningCache = {};

  String? _meaning;

  @override
  void initState() {
    super.initState();
    final key = widget.baseWord.toLowerCase().trim();
    if (_meaningCache.containsKey(key)) {
      _meaning = _meaningCache[key];
    } else {
      _fetchMeaning();
    }
  }

  @override
  void didUpdateWidget(covariant BaseFormTooltipLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseWord.toLowerCase().trim() !=
        widget.baseWord.toLowerCase().trim()) {
      final key = widget.baseWord.toLowerCase().trim();
      if (_meaningCache.containsKey(key)) {
        _meaning = _meaningCache[key];
      } else {
        _meaning = null;
        _fetchMeaning();
      }
    }
  }

  static String _cleanShortMeaning(String raw) {
    var clean = raw.trim();
    // Remove bracketed grammar or lengthy parentheticals e.g. "(male or unspecified gender)"
    clean = clean.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ').trim();
    // Take the first 1-2 comma/semicolon items
    final parts = clean.split(RegExp(r'[,;]\s*')).where((s) => s.trim().isNotEmpty).toList();
    if (parts.length > 2) {
      clean = '${parts[0]}, ${parts[1]}';
    }
    if (clean.length > 36) {
      clean = '${clean.substring(0, 33)}...';
    }
    return clean;
  }

  Future<void> _fetchMeaning() async {
    final key = widget.baseWord.toLowerCase().trim();
    if (key.isEmpty) return;

    try {
      var results = await DictionaryService().lookupWordFast(widget.baseWord);
      if (results.isEmpty) {
        results = await DictionaryService().lookupConsolidatedWord(widget.baseWord);
      }
      String? found;
      if (results.isNotEmpty) {
        final defs = results.first['definitions'];
        if (defs is List && defs.isNotEmpty) {
          found = defs.first.toString();
        } else if (results.first['definition'] != null) {
          found = results.first['definition'].toString();
        }
      }
      if (found != null && found.isNotEmpty) {
        _meaningCache[key] = found;
        if (mounted) {
          setState(() {
            _meaning = found;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highlightColor = colorScheme.primary;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WordDetailScreen(word: widget.baseWord),
          ),
        );
      },
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: widget.baseWord,
              style: widget.style.copyWith(
                fontWeight: FontWeight.bold,
                color: highlightColor,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: highlightColor.withValues(alpha: 0.6),
                decorationThickness: 1.8,
              ),
            ),
            if (_meaning != null &&
                _meaning!.isNotEmpty &&
                _meaning != 'No definition found.') ...[
              TextSpan(
                text: ' (${_cleanShortMeaning(_meaning!)})',
                style: widget.style.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

