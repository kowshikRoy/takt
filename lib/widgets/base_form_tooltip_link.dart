import 'package:flutter/material.dart';
import '../services/dictionary_service.dart';

/// Renders [baseWord] with a dotted underline; tapping it fetches the
/// word's meaning and shows it in a small popup anchored above the text.
/// Used for inflected-form glosses like "plural of Temperatur" so the base
/// word ("Temperatur") is a quick lookup instead of dead text.
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
  OverlayEntry? _overlayEntry;
  String? _meaning;
  bool _loading = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _toggleOverlay() async {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    _loading = true;
    _meaning = null;
    _showOverlay();

    String? meaning;
    try {
      // lookupWordFast is a single, unenriched SQL query — plenty for a quick
      // preview and much faster than the full multi-source consolidated lookup.
      var results = await DictionaryService().lookupWordFast(widget.baseWord);
      if (results.isEmpty) {
        // Local miss (or web, where there's no local sqflite DB at all) — fall
        // back to the slower but more complete lookup (Wiktionary, etc.).
        results = await DictionaryService().lookupConsolidatedWord(widget.baseWord);
      }
      if (results.isNotEmpty) {
        final defs = results.first['definitions'];
        if (defs is List && defs.isNotEmpty) {
          meaning = defs.first.toString();
        } else if (results.first['definition'] != null) {
          meaning = results.first['definition'].toString();
        }
      }
    } catch (_) {
      // fall through to "No definition found."
    }

    if (!mounted) return;
    _loading = false;
    _meaning = meaning ?? 'No definition found.';
    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    final colorScheme = Theme.of(context).colorScheme;

    const double tooltipMaxWidth = 240;
    const double horizontalPadding = 12;
    const double gap = 8;
    const double estimatedTooltipHeight = 74;
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final double topSafeArea = mediaQuery.padding.top;

    // Default to just off-screen-left; overwritten below once we can measure
    // the target word's actual position.
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
        // Preferred: anchor the tooltip's bottom edge just above the word,
        // letting it grow upward — no need to know its exact height up front.
        bottom = screenSize.height - target.dy + gap;
      } else {
        // Not enough room above (word near the top of the screen) — fall
        // back below the word instead of clipping off the top.
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
                      const BoxConstraints(maxWidth: tooltipMaxWidth, minWidth: 120),
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
                            fontSize: 12.5,
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
                            _meaning ?? '',
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
    final underlineColor = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: _toggleOverlay,
      child: Text(
        widget.baseWord,
        style: widget.style.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: underlineColor,
          decorationThickness: 2.2,
        ),
      ),
    );
  }
}
