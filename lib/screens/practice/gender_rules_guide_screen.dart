import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/tts_service.dart';

class GenderSuffixRuleItem {
  final String suffix;
  final String genderCode; // 'm', 'f', 'n'
  final String certainty; // '100%', '~95%', '~90%', '~70%'
  final String title;
  final String description;
  final List<String> examples;
  final List<String> exceptions;
  final String? exceptionNote;

  GenderSuffixRuleItem({
    required this.suffix,
    required this.genderCode,
    required this.certainty,
    required this.title,
    required this.description,
    required this.examples,
    this.exceptions = const [],
    this.exceptionNote,
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
}

class GenderRulesGuideScreen extends StatefulWidget {
  final String? targetRuleTitle;
  final String? targetWord;

  const GenderRulesGuideScreen({
    super.key,
    this.targetRuleTitle,
    this.targetWord,
  });

  @override
  State<GenderRulesGuideScreen> createState() => _GenderRulesGuideScreenState();
}

class _GenderRulesGuideScreenState extends State<GenderRulesGuideScreen> {
  final TtsService _ttsService = TtsService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedGenderFilter = 'all'; // 'all', 'f', 'n', 'm', 'exceptions'
  String _searchQuery = '';

  final List<GenderSuffixRuleItem> _allRules = [
    // ==================== DIE (Feminine) ====================
    GenderSuffixRuleItem(
      suffix: '-ung',
      genderCode: 'f',
      certainty: '100%',
      title: 'Suffix -ung is 100% Feminine (Die)',
      description: 'Nouns formed from verbs ending in "-ung" are 100% feminine with zero exceptions in standard German.',
      examples: ['die Zeitung', 'die Wohnung', 'die Übung', 'die Meinung', 'die Hoffnung', 'die Bildung'],
    ),
    GenderSuffixRuleItem(
      suffix: '-heit',
      genderCode: 'f',
      certainty: '100%',
      title: 'Suffix -heit is 100% Feminine (Die)',
      description: 'Abstract nouns describing states or conditions ending in "-heit" are 100% feminine.',
      examples: ['die Freiheit', 'die Gesundheit', 'die Krankheit', 'die Wahrheit', 'die Schönheit'],
    ),
    GenderSuffixRuleItem(
      suffix: '-keit',
      genderCode: 'f',
      certainty: '100%',
      title: 'Suffix -keit is 100% Feminine (Die)',
      description: 'Abstract qualities ending in "-keit" derived from adjectives are 100% feminine.',
      examples: ['die Möglichkeit', 'die Eitelkeit', 'die Höflichkeit', 'die Kleinigkeit', 'die Feuchtigkeit'],
    ),
    GenderSuffixRuleItem(
      suffix: '-schaft',
      genderCode: 'f',
      certainty: '100%',
      title: 'Suffix -schaft is 100% Feminine (Die)',
      description: 'Nouns describing collective groups, states, or relationships ending in "-schaft" are 100% feminine.',
      examples: ['die Freundschaft', 'die Mannschaft', 'die Landschaft', 'die Wissenschaft', 'die Gesellschaft'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ei',
      genderCode: 'f',
      certainty: '100%',
      title: 'Suffix -ei is 100% Feminine (Die)',
      description: 'Nouns indicating places of business, trades, or repetitive activity ending in "-ei" are 100% feminine.',
      examples: ['die Bäckerei', 'die Bücherei', 'die Datei', 'die Malerei', 'die Polizerei'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ion',
      genderCode: 'f',
      certainty: '100%',
      title: 'Suffix -ion is 100% Feminine (Die)',
      description: 'Nouns of Latin origin ending in "-ion" describing processes or institutions are 100% feminine.',
      examples: ['die Station', 'die Region', 'die Situation', 'die Information', 'die Lektion', 'die Nation'],
    ),
    GenderSuffixRuleItem(
      suffix: '-tät',
      genderCode: 'f',
      certainty: '100%',
      title: 'Suffix -tät is 100% Feminine (Die)',
      description: 'Abstract concepts of Latin origin ending in "-tät" are 100% feminine.',
      examples: ['die Universität', 'die Qualität', 'die Realität', 'die Elektrizität', 'die Identität'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ik',
      genderCode: 'f',
      certainty: '~95%',
      title: 'Suffix -ik is Feminine (Die)',
      description: 'Academic fields, artistic, and technical subjects ending in "-ik" are feminine.',
      examples: ['die Musik', 'die Grammatik', 'die Politik', 'die Technik', 'die Physik', 'die Logik'],
      exceptions: ['das Atlantik', 'der Pazifik'],
      exceptionNote: 'Oceans and geographical proper names are masculine or neuter.',
    ),
    GenderSuffixRuleItem(
      suffix: '-in',
      genderCode: 'f',
      certainty: '100%',
      title: 'Female Role -in is 100% Feminine (Die)',
      description: 'Female professions, roles, and titles ending in "-in" are 100% feminine.',
      examples: ['die Lehrerin', 'die Studentin', 'die Ärztin', 'die Freundin', 'die Chefin', 'die Autorin'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ie',
      genderCode: 'f',
      certainty: '~90%',
      title: 'Suffix -ie is Feminine (Die)',
      description: 'Nouns of French/Greek origin ending in "-ie" are feminine.',
      examples: ['die Energie', 'die Biologie', 'die Serie', 'die Theorie', 'die Familie', 'die Industrie'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ur',
      genderCode: 'f',
      certainty: '~90%',
      title: 'Suffix -ur is Feminine (Die)',
      description: 'Nouns of Latin origin ending in "-ur" are feminine.',
      examples: ['die Natur', 'die Kultur', 'die Struktur', 'die Reparatur', 'die Frisur', 'die Agentur'],
    ),
    GenderSuffixRuleItem(
      suffix: '-e',
      genderCode: 'f',
      certainty: '~90%',
      title: 'Suffix -e is ~90% Feminine (Die)',
      description: 'Most two-syllable German nouns ending in "-e" are feminine.',
      examples: ['die Katze', 'die Blume', 'die Sonne', 'die Lampe', 'die Tasche', 'die Straße', 'die Kirche'],
      exceptions: ['der Käse', 'der Name', 'der Junge', 'der Gedanke', 'der Kunde', 'das Auge', 'das Ende', 'das Erbe'],
      exceptionNote: 'Masculine "-e" nouns are weak N-declension nouns (der Junge, der Name). Neuter exceptions are a few body parts and abstract nouns.',
    ),

    // ==================== DAS (Neuter) ====================
    GenderSuffixRuleItem(
      suffix: '-chen',
      genderCode: 'n',
      certainty: '100%',
      title: 'Diminutive -chen is 100% Neuter (Das)',
      description: 'Diminutive endings "-chen" (making things small or cute) are ALWAYS 100% neuter.',
      examples: ['das Mädchen', 'das Brötchen', 'das Hähnchen', 'das Häuschen', 'das Kätzchen'],
    ),
    GenderSuffixRuleItem(
      suffix: '-lein',
      genderCode: 'n',
      certainty: '100%',
      title: 'Diminutive -lein is 100% Neuter (Das)',
      description: 'Diminutive endings "-lein" are ALWAYS 100% neuter.',
      examples: ['das Fräulein', 'das Büchlein', 'das Tischlein', 'das Kindlein'],
    ),
    GenderSuffixRuleItem(
      suffix: '-um',
      genderCode: 'n',
      certainty: '100%',
      title: 'Suffix -um is 100% Neuter (Das)',
      description: 'Nouns of Latin origin ending in "-um" are 100% neuter.',
      examples: ['das Zentrum', 'das Museum', 'das Datum', 'das Studium', 'das Album', 'das Publikum'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ment',
      genderCode: 'n',
      certainty: '~95%',
      title: 'Suffix -ment is Neuter (Das)',
      description: 'Inanimate objects, tools, and abstract concepts ending in "-ment" are neuter.',
      examples: ['das Instrument', 'das Dokument', 'das Experiment', 'das Element', 'das Parlament', 'das Appartment'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ma',
      genderCode: 'n',
      certainty: '~90%',
      title: 'Suffix -ma is Neuter (Das)',
      description: 'Nouns of Greek origin ending in "-ma" are neuter.',
      examples: ['das Thema', 'das Drama', 'das Klima', 'das Schema', 'das Trauma', 'das System (from schema)'],
    ),
    GenderSuffixRuleItem(
      suffix: 'Ge-...-e',
      genderCode: 'n',
      certainty: '~90%',
      title: 'Prefix Ge-...-e is Neuter (Das)',
      description: 'Collective nouns starting with prefix "Ge-" and ending with "-e" or noun stems are neuter.',
      examples: ['das Gebäude', 'das Gemüse', 'das Gespräch', 'das Gebirge', 'das Geschenk', 'das Gepäck'],
      exceptions: ['die Geschichte', 'die Geduld', 'der Geruch'],
    ),
    GenderSuffixRuleItem(
      suffix: '-en',
      genderCode: 'n',
      certainty: '100%',
      title: 'Nominalized Verb (-en) is Neuter (Das)',
      description: 'Verbs converted directly into nouns (infinitive form) are ALWAYS 100% neuter.',
      examples: ['das Essen', 'das Lesen', 'das Schwimmen', 'das Laufen', 'das Leben', 'das Schreiben'],
    ),

    // ==================== DER (Masculine) ====================
    GenderSuffixRuleItem(
      suffix: '-ling',
      genderCode: 'm',
      certainty: '100%',
      title: 'Suffix -ling is 100% Masculine (Der)',
      description: 'Nouns describing people, animals, or young living things ending in "-ling" are 100% masculine.',
      examples: ['der Schmetterling', 'der Lehrling', 'der Neuling', 'der Schützling', 'der Säugling', 'der Frühling'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ismus',
      genderCode: 'm',
      certainty: '100%',
      title: 'Suffix -ismus is 100% Masculine (Der)',
      description: 'Nouns describing concepts, ideologies, or movements ending in "-ismus" are 100% masculine.',
      examples: ['der Optimismus', 'der Tourismus', 'der Egoismus', 'der Realismus', 'der Kapitalismus', 'der Journalismus'],
    ),
    GenderSuffixRuleItem(
      suffix: '-or',
      genderCode: 'm',
      certainty: '~90%',
      title: 'Suffix -or is Masculine (Der)',
      description: 'Nouns describing active agents, machines, or instruments ending in "-or" are masculine.',
      examples: ['der Motor', 'der Faktor', 'der Reaktor', 'der Sensor', 'der Organisator', 'der Doktor'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ist',
      genderCode: 'm',
      certainty: '~95%',
      title: 'Suffix -ist is Masculine (Der)',
      description: 'Nouns describing active people, professions, or practitioners ending in "-ist" are masculine.',
      examples: ['der Polizist', 'der Optimist', 'der Journalist', 'der Pianist', 'der Spezialist', 'der Tourist'],
    ),
    GenderSuffixRuleItem(
      suffix: '-ant / -ent',
      genderCode: 'm',
      certainty: '~90%',
      title: 'Suffix -ant / -ent is Masculine (Der)',
      description: 'Nouns describing people or active agents ending in "-ant" or "-ent" are masculine.',
      examples: ['der Elefant', 'der Student', 'der Lieferant', 'der Präsident', 'der Assistent', 'der Dozent'],
      exceptions: ['das Talent', 'das Patent', 'das Element'],
      exceptionNote: 'Inanimate technical concepts ending in "-ent" are neuter (das Talent, das Patent).',
    ),
    GenderSuffixRuleItem(
      suffix: '-er',
      genderCode: 'm',
      certainty: '~70%',
      title: 'Agent Suffix -er is ~70% Masculine (Der)',
      description: 'Nouns describing active human agents, occupations, or tools ending in "-er" are masculine.',
      examples: ['der Fahrer', 'der Computer', 'der Wecker', 'der Drucker', 'der Lehrer', 'der Schüler', 'der Kater'],
      exceptions: ['das Fenster', 'das Wasser', 'das Zimmer', 'das Messer', 'die Mutter', 'die Butter', 'die Tochter', 'die Schulter'],
      exceptionNote: 'Household objects (das Fenster, das Wasser) and female family relations (die Mutter, die Tochter) are neuter or feminine.',
    ),
  ];

  List<GenderSuffixRuleItem> get _filteredRules {
    return _allRules.where((rule) {
      // Gender filter
      if (_selectedGenderFilter == 'f' && rule.genderCode != 'f') return false;
      if (_selectedGenderFilter == 'n' && rule.genderCode != 'n') return false;
      if (_selectedGenderFilter == 'm' && rule.genderCode != 'm') return false;
      if (_selectedGenderFilter == 'exceptions' && rule.exceptions.isEmpty) return false;

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchSuffix = rule.suffix.toLowerCase().contains(q);
        final matchTitle = rule.title.toLowerCase().contains(q);
        final matchDesc = rule.description.toLowerCase().contains(q);
        final matchExamples = rule.examples.any((e) => e.toLowerCase().contains(q));
        final matchExceptions = rule.exceptions.any((e) => e.toLowerCase().contains(q));
        return matchSuffix || matchTitle || matchDesc || matchExamples || matchExceptions;
      }

      return true;
    }).toList();
  }

  Color _getGenderColor(String code) {
    switch (code) {
      case 'm':
        return AppTheme.genderMasc;
      case 'f':
        return AppTheme.genderFem;
      case 'n':
        return AppTheme.genderNeu;
      default:
        return AppTheme.genderMasc;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = _filteredRules;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gender Rules & Suffix Guide', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Banner & Search Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search suffix (-ung, -heit), word (Käse), or rule...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
          ),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Rules (${_allRules.length})', Icons.grid_view_rounded, Colors.grey),
                const SizedBox(width: 8),
                _buildFilterChip('f', 'Die / Feminine', Icons.female_rounded, AppTheme.genderFem),
                const SizedBox(width: 8),
                _buildFilterChip('n', 'Das / Neuter', Icons.trip_origin_rounded, AppTheme.genderNeu),
                const SizedBox(width: 8),
                _buildFilterChip('m', 'Der / Masculine', Icons.male_rounded, AppTheme.genderMasc),
                const SizedBox(width: 8),
                _buildFilterChip('exceptions', 'The Odd 10% Exceptions ⚠️', Icons.warning_amber_rounded, Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Target Word Highlight Banner (If opened from quiz)
          if (widget.targetWord != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Showing rule for target word: "${widget.targetWord}"',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Rule Cards List
          Expanded(
            child: rules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'No matching gender rules found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text('Try adjusting your search query or category filter.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rules.length,
                    itemBuilder: (ctx, idx) {
                      final rule = rules[idx];
                      final bool isTarget = widget.targetRuleTitle != null &&
                          rule.title.toLowerCase().contains(widget.targetRuleTitle!.toLowerCase());

                      return _buildRuleCard(ctx, rule, isTarget);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, IconData icon, Color color) {
    final bool isSelected = _selectedGenderFilter == filterKey;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedGenderFilter = filterKey;
          });
        }
      },
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      selectedColor: filterKey == 'all' ? Theme.of(context).colorScheme.primary : color,
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(
        color: isSelected
            ? (filterKey == 'all' ? Theme.of(context).colorScheme.primary : color)
            : Theme.of(context).dividerColor.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildRuleCard(BuildContext ctx, GenderSuffixRuleItem rule, bool isTarget) {
    final color = _getGenderColor(rule.genderCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(ctx).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isTarget ? color : color.withValues(alpha: 0.4),
          width: isTarget ? 3 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isTarget ? color.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
            blurRadius: isTarget ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                // Suffix Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rule.suffix,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${rule.article.toUpperCase()} (${rule.genderCode.toUpperCase()})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${rule.certainty} Certainty',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Rule Description
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              rule.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Interactive Example Nouns
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Example Nouns (Tap to hear speech 🔊):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: rule.examples.map((ex) {
                    final bool isWordTarget = widget.targetWord != null &&
                        ex.toLowerCase().contains(widget.targetWord!.toLowerCase());
                    return InkWell(
                      onTap: () => _ttsService.speak(ex, lang: 'de-DE'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWordTarget ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isWordTarget ? color : color.withValues(alpha: 0.3),
                            width: isWordTarget ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.volume_up_rounded, size: 14, color: color),
                            const SizedBox(width: 6),
                            Text(
                              ex,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(ctx).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Exception Box (The Odd 10%)
          if (rule.exceptions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                        SizedBox(width: 6),
                        Text(
                          'Watch Out For Exceptions:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rule.exceptions.join(', '),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    if (rule.exceptionNote != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        rule.exceptionNote!,
                        style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}
