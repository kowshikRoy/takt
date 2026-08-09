class SubtitleCue {
  final double start;
  final double end;
  final String original;
  final String translated;

  SubtitleCue({
    required this.start,
    required this.end,
    required this.original,
    required this.translated,
  });

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'original': original,
    'translated': translated,
  };

  factory SubtitleCue.fromJson(Map<String, dynamic> json) => SubtitleCue(
    start: (json['start'] as num).toDouble(),
    end: (json['end'] as num).toDouble(),
    original: (json['original'] as String?) ?? '',
    translated: (json['translated'] as String?) ?? '',
  );

  static const Set<String> _abbreviations = {
    'z.b.', 'd.h.', 'u.a.', 'bzw.', 'ca.', 'usw.', 'dr.', 'prof.',
    'nr.', 'str.', 'jan.', 'feb.', 'mrz.', 'apr.', 'jun.', 'jul.',
    'aug.', 'sept.', 'okt.', 'nov.', 'dez.', 'mio.', 'mrd.', 'evtl.',
    'vgl.', 'inkl.', 'exkl.', 'min.', 'std.', 'usf.', 'abs.', 'art.',
    'st.', 'vs.', 'etc.', 'co.', 'inc.', 'ltd.', 'hr.', 'fr.',
  };

  static bool isSentenceTerminal(String text) {
    var clean = text.replaceAll(RegExp(r'["\x27»«”’\)]+$'), '').trim();
    if (clean.isEmpty) return false;

    if (clean.endsWith('.') || clean.endsWith('!') || clean.endsWith('?') || clean.endsWith('…') || clean.endsWith('?!') || clean.endsWith('!?')) {
      final words = clean.split(RegExp(r'\s+'));
      if (words.isEmpty) return false;
      final lastWord = words.last.toLowerCase();
      if (_abbreviations.contains(lastWord)) return false;
      if (RegExp(r'^\d+\.$').hasMatch(lastWord)) return false;
      return true;
    }
    return false;
  }

  /// Merges fragmented subtitle cues into complete, grammatically sound sentences.
  static List<SubtitleCue> mergeFragmentedCues(
    List<SubtitleCue> cues, {
    double maxDuration = 12.0,
    int maxChars = 180,
    double maxPauseGap = 1.8,
  }) {
    if (cues.isEmpty) return [];

    final List<SubtitleCue> merged = [];
    final List<SubtitleCue> currentGroup = [];

    void flushGroup() {
      if (currentGroup.isEmpty) return;

      final startTime = currentGroup.first.start;
      final endTime = currentGroup.last.end;

      var combinedOriginal = currentGroup
          .map((c) => c.original.trim())
          .where((t) => t.isNotEmpty)
          .join(' ');
      combinedOriginal = combinedOriginal.replaceAll(RegExp(r'\s+([,.:;!?])'), r'$1');
      combinedOriginal = combinedOriginal.replaceAll(RegExp(r'\s+'), ' ').trim();

      final translations = currentGroup
          .map((c) => c.translated.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      var combinedTranslated = translations.isNotEmpty ? translations.join(' ') : '';
      if (combinedTranslated.isNotEmpty) {
        combinedTranslated = combinedTranslated.replaceAll(RegExp(r'\s+([,.:;!?])'), r'$1');
        combinedTranslated = combinedTranslated.replaceAll(RegExp(r'\s+'), ' ').trim();
      }

      if (combinedOriginal.isNotEmpty) {
        final double safeEnd = (endTime <= startTime)
            ? double.parse((startTime + 0.5).toStringAsFixed(2))
            : double.parse(endTime.toStringAsFixed(2));
        merged.add(SubtitleCue(
          start: double.parse(startTime.toStringAsFixed(2)),
          end: safeEnd,
          original: combinedOriginal,
          translated: combinedTranslated,
        ));
      }
      currentGroup.clear();
    }

    for (final cue in cues) {
      final cueText = cue.original.trim();
      if (cueText.isEmpty) continue;

      if (currentGroup.isEmpty) {
        currentGroup.add(cue);
        continue;
      }

      final prevCue = currentGroup.last;
      final prevText = prevCue.original.trim();

      final groupDuration = cue.end - currentGroup.first.start;
      final groupCharCount = currentGroup.fold<int>(0, (sum, c) => sum + c.original.length) + cueText.length + 1;
      final pauseGap = cue.start - prevCue.end;

      final prevIsTerminal = isSentenceTerminal(prevText);
      final firstChar = cueText.isNotEmpty ? cueText[0] : '';
      final startsLowercase = firstChar.toLowerCase() == firstChar && firstChar.toUpperCase() != firstChar;

      bool shouldMerge = false;

      if (!prevIsTerminal) {
        if (groupDuration <= maxDuration && groupCharCount <= maxChars && pauseGap <= maxPauseGap) {
          shouldMerge = true;
        } else if (startsLowercase && groupDuration <= maxDuration * 1.3) {
          shouldMerge = true;
        }
      } else {
        if (startsLowercase && pauseGap <= 0.8 && groupDuration <= maxDuration) {
          shouldMerge = true;
        }
      }

      if (shouldMerge) {
        currentGroup.add(cue);
      } else {
        flushGroup();
        currentGroup.add(cue);
      }
    }

    flushGroup();
    return merged;
  }
}
