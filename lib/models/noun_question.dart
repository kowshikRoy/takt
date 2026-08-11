class NounQuestion {
  final String word;
  final String genderCode; // 'm', 'f', 'n'
  final String? ipa;
  final String translation;
  final String? plural;
  final int? freqRank;
  final bool isDueForSrs;
  final int srsInterval;

  NounQuestion({
    required this.word,
    required this.genderCode,
    this.ipa,
    required this.translation,
    this.plural,
    this.freqRank,
    this.isDueForSrs = false,
    this.srsInterval = 0,
  });

  String get article {
    switch (genderCode) {
      case 'm':
        return 'der';
      case 'f':
        return 'die';
      case 'n':
        return 'das';
      default:
        return 'der';
    }
  }

  static String? normalizeGender(String? raw) {
    if (raw == null) return null;
    final g = raw.trim().toLowerCase();
    if (g == 'm' ||
        g == 'der' ||
        g.startsWith('masc') ||
        g.startsWith('mask') ||
        g == 'm.' ||
        g == 'r') {
      return 'm';
    }
    if (g == 'f' ||
        g == 'die' ||
        g.startsWith('fem') ||
        g == 'f.' ||
        g == 'e') {
      return 'f';
    }
    if (g == 'n' ||
        g == 'das' ||
        g.startsWith('neu') ||
        g == 'n.' ||
        g == 's') {
      return 'n';
    }
    return null;
  }
}
