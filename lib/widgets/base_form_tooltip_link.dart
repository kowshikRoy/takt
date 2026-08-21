import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/dictionary_service.dart';
import '../services/haptic_service.dart';
import '../screens/word_detail_screen.dart';

/// Renders an interactive inflected-form definition line:
/// e.g. "plural of " + highlighted [baseWord] + " (meaning)" + optional [suffix].
/// Tapping the base word triggers haptic feedback and opens its full dictionary entry.
class BaseFormTooltipLink extends StatefulWidget {
  final String baseWord;
  final String prefix;
  final String? suffix;
  final TextStyle style;

  const BaseFormTooltipLink({
    super.key,
    required this.baseWord,
    this.prefix = '',
    this.suffix,
    required this.style,
  });

  @override
  State<BaseFormTooltipLink> createState() => _BaseFormTooltipLinkState();
}

class _BaseFormTooltipLinkState extends State<BaseFormTooltipLink> {
  static final Map<String, String> _meaningCache = {};

  String? _meaning;
  late final TapGestureRecognizer _tapRecognizer;

  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer()..onTap = _handleTap;
    final key = widget.baseWord.toLowerCase().trim();
    if (_meaningCache.containsKey(key)) {
      _meaning = _meaningCache[key];
    } else {
      _fetchMeaning();
    }
  }

  @override
  void dispose() {
    _tapRecognizer.dispose();
    super.dispose();
  }

  void _handleTap() {
    AppHaptics.selection();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WordDetailScreen(word: widget.baseWord),
      ),
    );
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
        for (final r in results) {
          final defs = r['definitions'];
          if (defs is List) {
            for (final d in defs) {
              final dStr = d.toString().trim();
              final lower = dStr.toLowerCase();
              if (dStr.isNotEmpty &&
                  !lower.startsWith('plural of') &&
                  !lower.startsWith('inflection of') &&
                  !lower.startsWith('nominative') &&
                  !lower.startsWith('genitive') &&
                  !lower.startsWith('dative') &&
                  !lower.startsWith('accusative') &&
                  !lower.startsWith('participle of') &&
                  !lower.startsWith('comparative of') &&
                  !lower.startsWith('superlative of') &&
                  !lower.startsWith('first-person') &&
                  !lower.startsWith('second-person') &&
                  !lower.startsWith('third-person') &&
                  !lower.startsWith('past participle')) {
                found = dStr;
                break;
              }
            }
          }
          if (found != null) break;
          if (r['definition'] != null) {
            final dStr = r['definition'].toString().trim();
            final lower = dStr.toLowerCase();
            if (dStr.isNotEmpty &&
                !lower.startsWith('plural of') &&
                !lower.startsWith('inflection of') &&
                !lower.startsWith('nominative') &&
                !lower.startsWith('genitive') &&
                !lower.startsWith('dative') &&
                !lower.startsWith('accusative') &&
                !lower.startsWith('participle of')) {
              found = dStr;
              break;
            }
          }
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

  bool _isValidMeaning(String? m) {
    if (m == null || m.isEmpty || m == 'No definition found.') return false;
    final lower = m.toLowerCase().trim();
    if (lower.startsWith('plural of') ||
        lower.startsWith('inflection of') ||
        lower.startsWith('nominative') ||
        lower.startsWith('genitive') ||
        lower.startsWith('dative') ||
        lower.startsWith('accusative') ||
        lower.startsWith('participle of') ||
        lower.contains('of ${widget.baseWord.toLowerCase()}')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highlightColor = colorScheme.primary;

    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          if (widget.prefix.isNotEmpty)
            TextSpan(text: widget.prefix),
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
            recognizer: _tapRecognizer,
          ),
          if (_isValidMeaning(_meaning)) ...[
            TextSpan(
              text: ' (${_cleanShortMeaning(_meaning!)})',
              style: widget.style.copyWith(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
          if (widget.suffix != null && widget.suffix!.isNotEmpty) ...[
            TextSpan(
              text: ' ${widget.suffix}',
              style: widget.style.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: (widget.style.fontSize ?? 14.5) * 0.92,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

