import 'package:flutter/material.dart';
import '../services/dictionary_service.dart';
import '../services/haptic_service.dart';

/// Renders [baseWord] highlighted (bold + primary color + dotted underline)
/// alongside its bracketed meaning inline (e.g. "Haus (house, building)").
/// Tapping it triggers haptic feedback and displays an anchored popup tooltip.
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

  OverlayEntry? _overlayEntry;
  String? _meaning;
  bool _loading = false;

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

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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

  Future<void> _toggleOverlay() async {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    _loading = _meaning == null;
    _showOverlay();

    if (_meaning == null) {
      await _fetchMeaning();
      if (!mounted) return;
      _loading = false;
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _showOverlay() {
    final colorScheme = Theme.of(context).colorScheme;

    const double tooltipMaxWidth = 260;
    const double horizontalPadding = 12;
    const double gap = 8;
    const double estimatedTooltipHeight = 74;
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final double topSafeArea = mediaQuery.padding.top;

    double left = horizontalPadding;
    double? top;
    double? bottom;

    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final Offset target = renderObject.localToGlobal(Offset.zero);
      final Size targetSize = renderObject.size;

      final double desiredLeft =
          target.dx + targetSize.width / 2 - tooltipMaxWidth / 2;
      final double maxLeft = (screenSize.width - tooltipMaxWidth - horizontalPadding)
          .clamp(horizontalPadding, screenSize.width);
      left = desiredLeft.clamp(horizontalPadding, maxLeft);

      final bool roomAbove =
          target.dy - estimatedTooltipHeight - gap >= topSafeArea;
      if (roomAbove) {
        bottom = screenSize.height - target.dy + gap;
      } else {
        top = target.dy + targetSize.height + gap;
      }
    }

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              bottom: bottom,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: tooltipMaxWidth, minWidth: 140),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.baseWord,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onInverseSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (_loading)
                          SizedBox(
                            height: 12,
                            width: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: colorScheme.onInverseSurface,
                            ),
                          )
                        else
                          Text(
                            _meaning ?? 'No definition found.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onInverseSurface
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highlightColor = colorScheme.primary;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        _toggleOverlay();
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

