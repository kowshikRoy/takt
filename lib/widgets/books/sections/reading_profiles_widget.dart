import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/textbook_unit.dart';
import '../../../services/tts_service.dart';
import '../../../services/ondevice_ai_service.dart';
import '../../../theme/books_modernist_style.dart';
import '../../interactive_german_text.dart';

/// Widget for displaying reading profile cards (e.g. Julia & Jonas reading profiles).
class ReadingProfilesWidget extends StatelessWidget {
  final List<ProfileModel>? profiles;
  final List<dynamic>? rawProfiles;
  final String? unitTitle;

  const ReadingProfilesWidget({
    super.key,
    this.profiles,
    this.rawProfiles,
    this.unitTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (profiles != null && profiles!.isNotEmpty) {
      return Column(
        children: profiles!
            .map((p) => _ReadingProfileCard(
                  name: p.name,
                  text: p.text,
                  unitTitle: unitTitle,
                ))
            .toList(),
      );
    }
    if (rawProfiles != null && rawProfiles!.isNotEmpty) {
      return Column(
        children: rawProfiles!.map((p) {
          final map = p as Map<String, dynamic>;
          final name = map['name']?.toString() ?? map['id']?.toString() ?? '';
          final text = map['text']?.toString() ?? '';
          final translation = map['translation']?.toString() ?? map['translation_en']?.toString();
          return _ReadingProfileCard(
            name: name,
            text: text,
            translation: translation,
            unitTitle: unitTitle,
          );
        }).toList(),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ReadingProfileCard extends StatefulWidget {
  final String name;
  final String text;
  final String? translation;
  final String? unitTitle;

  const _ReadingProfileCard({
    required this.name,
    required this.text,
    this.translation,
    this.unitTitle,
  });

  @override
  State<_ReadingProfileCard> createState() => _ReadingProfileCardState();
}

class _ReadingProfileCardState extends State<_ReadingProfileCard> {
  final TtsService _ttsService = TtsService();
  StreamSubscription<TtsProgress?>? _ttsSubscription;
  Timer? _fallbackTimer;

  bool _isPlaying = false;
  int? _currentSpokenStart;
  int? _currentSpokenEnd;
  int? _currentWordIndex;

  bool _showTranslation = false;
  bool _isTranslating = false;
  String? _translatedText;

  @override
  void initState() {
    super.initState();
    _translatedText = widget.translation;
    _ttsSubscription = _ttsService.progressStream.listen((progress) {
      if (!mounted) return;
      if (progress != null && progress.word.isNotEmpty) {
        setState(() {
          _isPlaying = true;
          _currentSpokenStart = progress.start;
          _currentSpokenEnd = progress.end;
        });
      } else {
        _stopHighlighting();
      }
    });
  }

  @override
  void dispose() {
    _ttsSubscription?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _stopHighlighting() {
    _fallbackTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _currentSpokenStart = null;
        _currentSpokenEnd = null;
        _currentWordIndex = null;
      });
    }
  }

  Future<void> _toggleTranslation() async {
    if (_showTranslation) {
      setState(() => _showTranslation = false);
      return;
    }

    if (_translatedText != null && _translatedText!.isNotEmpty) {
      setState(() => _showTranslation = true);
      return;
    }

    setState(() {
      _isTranslating = true;
      _showTranslation = true;
    });

    try {
      final res = await OnDeviceAIService().translateText(widget.text);
      if (mounted) {
        setState(() {
          _translatedText = res;
          _isTranslating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  void _speak() {
    if (_isPlaying) {
      _ttsService.stop();
      _stopHighlighting();
    } else {
      setState(() {
        _isPlaying = true;
        _currentWordIndex = 0;
      });
      _ttsService.speak(widget.text, lang: 'de-DE');

      final words = widget.text.split(' ');
      const intervalMs = 380;
      _fallbackTimer?.cancel();
      _fallbackTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
        if (!mounted || !_isPlaying) {
          timer.cancel();
          return;
        }
        if (_currentSpokenStart == null) {
          setState(() {
            _currentWordIndex = (timer.tick).clamp(0, words.length - 1);
          });
          if (timer.tick >= words.length) {
            timer.cancel();
            _stopHighlighting();
          }
        }
      });
    }
  }

  Widget _buildHighlightedText(BuildContext context) {
    if (!_isPlaying || (_currentSpokenStart == null && _currentWordIndex == null)) {
      return InteractiveGermanText(
        widget.text,
        sourceTitle: widget.unitTitle,
        style: BooksModernist.body(size: 13.5).copyWith(height: 1.5),
      );
    }

    if (_currentSpokenStart != null && _currentSpokenEnd != null) {
      final start = _currentSpokenStart!.clamp(0, widget.text.length);
      final end = _currentSpokenEnd!.clamp(start, widget.text.length);

      final before = widget.text.substring(0, start);
      final word = widget.text.substring(start, end);
      final after = widget.text.substring(end);

      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: before,
              style: BooksModernist.body(size: 13.5).copyWith(height: 1.5),
            ),
            TextSpan(
              text: word,
              style: BooksModernist.body(
                size: 13.5,
                weight: FontWeight.w800,
                color: BooksModernist.accentDark,
              ).copyWith(
                height: 1.5,
                backgroundColor: BooksModernist.accent.withValues(alpha: 0.22),
              ),
            ),
            TextSpan(
              text: after,
              style: BooksModernist.body(size: 13.5).copyWith(height: 1.5),
            ),
          ],
        ),
      );
    }

    final words = widget.text.split(' ');
    return Text.rich(
      TextSpan(
        children: List.generate(words.length, (idx) {
          final isHighlighted = idx == _currentWordIndex;
          final word = words[idx];

          if (isHighlighted) {
            return TextSpan(
              text: '$word ',
              style: BooksModernist.body(
                size: 13.5,
                weight: FontWeight.w800,
                color: BooksModernist.accentDark,
              ).copyWith(
                height: 1.5,
                backgroundColor: BooksModernist.accent.withValues(alpha: 0.22),
              ),
            );
          }

          return TextSpan(
            text: '$word ',
            style: BooksModernist.body(size: 13.5).copyWith(height: 1.5),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BooksModernist.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BooksModernist.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.name.isNotEmpty) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: BooksModernist.accent,
                  child: Text(
                    widget.name[0],
                    style: BooksModernist.heading(size: 13, color: BooksModernist.bg),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.name,
                  style: BooksModernist.heading(size: 14, color: BooksModernist.accentDark),
                ),
              ],
              const Spacer(),
              IconButton(
                onPressed: _speak,
                tooltip: _isPlaying ? 'Stopp' : 'Vorlesen',
                icon: Icon(
                  _isPlaying ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                  size: 20,
                  color: _isPlaying ? BooksModernist.accent : BooksModernist.text.withValues(alpha: 0.65),
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _toggleTranslation,
                tooltip: _showTranslation ? 'Übersetzung ausblenden' : 'Übersetzung anzeigen',
                icon: Icon(
                  _showTranslation ? Icons.g_translate_rounded : Icons.translate_rounded,
                  size: 20,
                  color: _showTranslation ? BooksModernist.accentDark : BooksModernist.text.withValues(alpha: 0.65),
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 10),

          _buildHighlightedText(context),

          if (_showTranslation) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BooksModernist.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border(left: BorderSide(color: BooksModernist.accent, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate_rounded, size: 14, color: BooksModernist.accentDark),
                      const SizedBox(width: 5),
                      Text(
                        'English Translation',
                        style: BooksModernist.body(size: 11, weight: FontWeight.w800, color: BooksModernist.accentDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_isTranslating)
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Übersetzung wird geladen...',
                          style: BooksModernist.body(size: 12, weight: FontWeight.w600),
                        ),
                      ],
                    )
                  else
                    Text(
                      _translatedText ?? 'No translation available',
                      style: BooksModernist.body(size: 12.5, weight: FontWeight.w500),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
