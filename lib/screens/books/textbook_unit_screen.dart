import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book_guide.dart';
import '../../models/textbook_unit.dart';
import '../../services/book_guide_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import '../../widgets/glance_word_sheet.dart';
import '../../theme/books_modernist_style.dart';

class TextbookUnitScreen extends StatefulWidget {
  final ChapterSummary chapterSummary;
  final String bookTitle;

  const TextbookUnitScreen({
    super.key,
    required this.chapterSummary,
    required this.bookTitle,
  });

  @override
  State<TextbookUnitScreen> createState() => _TextbookUnitScreenState();
}

class _TextbookUnitScreenState extends State<TextbookUnitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TextbookUnit? _unit;
  bool _isLoading = true;
  int _selectedPageIndex = 0;
  bool _isPracticeMode = true;
  final Map<String, String> _userAnswers = {};
  final Map<String, bool> _revealedAnswers = {};
  Set<String> _completedSectionIds = {};

  // Generic tap-to-match exercise state, keyed by section id.
  final Map<String, String?> _matchArmedLeft = {};
  final Map<String, Map<String, String>> _matchPaired = {};
  final Map<String, (String leftId, String rightId)?> _matchFlash = {};

  Future<void> _toggleSectionDone(String sectionId) async {
    setState(() {
      if (_completedSectionIds.contains(sectionId)) {
        _completedSectionIds.remove(sectionId);
      } else {
        _completedSectionIds.add(sectionId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'completed_sections_unit_${_unit?.unitNumber ?? widget.chapterSummary.chapterNumber}',
      _completedSectionIds.toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUnitData();
  }

  Future<void> _loadUnitData() async {
    final service = Provider.of<BookGuideService>(context, listen: false);
    String path = widget.chapterSummary.jsonAssetPath;
    if (widget.chapterSummary.chapterNumber == 1) {
      path = 'assets/books/netzwerk-a2/unit_01.json';
    } else if (widget.chapterSummary.chapterNumber == 2) {
      path = 'assets/books/netzwerk-a2/unit_02.json';
    }
    final data = await service.loadTextbookUnit(path);
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(
            'completed_sections_unit_${data?.unitNumber ?? widget.chapterSummary.chapterNumber}') ??
        [];
    if (mounted) {
      setState(() {
        _unit = data;
        _completedSectionIds = completed.toSet();
        _isLoading = false;
      });
      _persistLastRead();
    }
  }

  Future<void> _persistLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('books_last_read_book_title', widget.bookTitle);
    await prefs.setInt(
        'books_last_read_chapter_number', widget.chapterSummary.chapterNumber);
    await prefs.setInt('books_last_read_page_index', _selectedPageIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _totalSectionCount =>
      _unit?.pages.expand((p) => p.sections).length ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BooksModernist.bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: BooksModernist.accent))
            : _unit == null
                ? Center(
                    child: Text('Could not load unit data.',
                        style: BooksModernist.body()))
                : Column(
                    children: [
                      _buildHeader(),
                      _buildHeroImage(),
                      _buildProgressAndObjectives(),
                      _buildTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPagesTab(context),
                            _buildGrammarTab(context),
                            _buildRedemittelTab(context),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(Icons.chevron_left_rounded, color: BooksModernist.text, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kapitel ${_unit!.unitNumber}: ${_unit!.title}',
              style: BooksModernist.heading(size: 16.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GrayscaleCover(
            assetPath: 'assets/images/netzwerk_a2_kapitel_01.jpg',
            width: double.infinity,
            height: 120,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Kapitel ${_unit!.unitNumber} · ${widget.bookTitle}',
              style: BooksModernist.body(
                size: 11,
                color: BooksModernist.text.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressAndObjectives() {
    final done = _completedSectionIds
        .where((id) => _unit!.pages
            .expand((p) => p.sections)
            .any((s) => s.id == id))
        .length;
    final total = _totalSectionCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$done / $total Abschnitte erledigt',
            style: BooksModernist.body(
              size: 11,
              color: BooksModernist.text.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          ModernistProgressBar(progress: total > 0 ? done / total : 0),
          const SizedBox(height: 14),

          // Practice / Solutions segmented toggle
          Container(
            decoration: BoxDecoration(border: Border.all(color: BooksModernist.divider)),
            child: Row(
              children: [
                Expanded(child: _segButton('Üben', _isPracticeMode, () {
                  setState(() => _isPracticeMode = true);
                })),
                Container(width: 1, height: 32, color: BooksModernist.divider),
                Expanded(child: _segButton('Lösungen', !_isPracticeMode, () {
                  setState(() => _isPracticeMode = false);
                })),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Objectives chips
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _unit!.objectives
                  .map((obj) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          decoration: BoxDecoration(
                              border: Border.all(color: BooksModernist.divider)),
                          child: Text(
                            obj,
                            style: BooksModernist.body(size: 11),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _segButton(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: active ? BooksModernist.accent : Colors.transparent,
        child: Text(
          label,
          style: BooksModernist.body(
            size: 12,
            weight: FontWeight.w700,
            color: active ? BooksModernist.bg : BooksModernist.text,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: BooksModernist.divider, width: 2)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: BooksModernist.accent,
        unselectedLabelColor: BooksModernist.text,
        indicatorColor: BooksModernist.accent,
        indicatorWeight: 2,
        labelStyle: BooksModernist.body(size: 12.5, weight: FontWeight.w700),
        unselectedLabelStyle: BooksModernist.body(size: 12.5, weight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Kursbuch'),
          Tab(text: 'Grammatik'),
          Tab(text: 'Redemittel'),
        ],
      ),
    );
  }

  Widget _buildPagesTab(BuildContext context) {
    final pages = _unit!.pages;

    return Column(
      children: [
        // Page selector pill bar
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pages.length,
            itemBuilder: (context, index) {
              final page = pages[index];
              final isSelected = index == _selectedPageIndex;
              final doneOnPage = page.sections
                  .where((s) => _completedSectionIds.contains(s.id))
                  .length;
              final totalOnPage = page.sections.length;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedPageIndex = index);
                  _persistLastRead();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 84,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? BooksModernist.accent : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? BooksModernist.accent
                                : BooksModernist.divider,
                          ),
                        ),
                        child: Text(
                          'Seite ${page.pageNumber}',
                          style: BooksModernist.body(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: isSelected ? BooksModernist.bg : BooksModernist.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ModernistProgressBar(
                        progress: totalOnPage > 0 ? doneOnPage / totalOnPage : 0,
                        height: 3,
                        trackColor: isSelected
                            ? BooksModernist.accent700
                            : BooksModernist.dividerThin,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Selected Page Sections
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: pages[_selectedPageIndex]
                  .sections
                  .map((section) => _buildSectionWidget(context, section))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionWidget(BuildContext context, SectionModel section) {
    final json = section.rawJson;
    final isDone = _completedSectionIds.contains(section.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with section ID and title/type
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ModernistTag(section.id.toUpperCase(), accent: true),
              const SizedBox(width: 10),
              if (section.title != null)
                Expanded(
                  child: Text(
                    section.title!,
                    style: BooksModernist.heading(size: 13.5),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    section.type.replaceAll('_', ' ').toUpperCase(),
                    style: BooksModernist.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: BooksModernist.text.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              if (section.audioId != null || json['audio_id'] != null) ...[
                Icon(Icons.headphones_rounded, size: 14, color: BooksModernist.accentDark),
                const SizedBox(width: 3),
                Text(
                  'Hörtext ${section.audioId ?? json['audio_id']}',
                  style: BooksModernist.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: BooksModernist.accentDark,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: () => _toggleSectionDone(section.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone ? BooksModernist.accent : Colors.transparent,
                    border: Border.all(
                      color: isDone ? BooksModernist.accent : BooksModernist.divider,
                    ),
                  ),
                  child: Text(
                    isDone ? 'Erledigt' : 'Erledigen',
                    style: BooksModernist.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: isDone ? BooksModernist.bg : BooksModernist.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Instruction
          if (section.instruction != null) ...[
            Text(
              section.instruction!,
              style: BooksModernist.body(size: 12.5, style: FontStyle.italic)
                  .copyWith(color: BooksModernist.text.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 12),
          ],

          // Reading-matching: headings + person texts → interactive matching
          // when both are present (verified against the design's own
          // answer key); otherwise fall back to a plain read-only layout.
          if (json['headings'] is List && json['texts'] is List)
            _buildHeadingTextMatching(
                context, section.id, json['headings'] as List, json['texts'] as List)
          else ...[
            if (json['headings'] is List)
              _buildHeadingsList(context, json['headings'] as List),
            if (json['texts'] is List)
              _buildPersonTexts(context, json['texts'] as List),
          ],

          // Chat-reply matching (design's m6b) when both message lists are present.
          if (json['incoming_messages'] is List && json['ben_replies'] is List)
            _buildReplyMatching(context, section.id,
                json['incoming_messages'] as List, json['ben_replies'] as List),

          // Profiles / Reading Profiles
          if (section.profiles != null && section.profiles!.isNotEmpty)
            _buildProfilesList(context, section.profiles!),

          // Chat Messages
          if (section.chatMessages != null && section.chatMessages!.isNotEmpty)
            _buildChatList(context, section.chatMessages!),
          if (json['chat_messages'] is List && section.chatMessages == null)
            _buildRawChatList(context, json['chat_messages'] as List),

          // Exercise Items
          if (section.items != null && section.items!.isNotEmpty)
            _buildExerciseList(context, section.items!),

          // Topics
          if (json['topics'] is List)
            _buildTopicsList(context, json['topics'] as List),

          // Statements (fill in the blank / comprehension)
          if (json['statements'] is List)
            _buildStatementsList(context, json['statements'] as List),

          // Causal matching (design's m7a) with a verified answer key.
          if (json['left_clauses'] is List && json['right_clauses'] is List)
            _buildCausalMatching(context, section.id,
                json['left_clauses'] as List, json['right_clauses'] as List),

          // Questions and answers (e.g. FAQ) — no verified answer key exists
          // for this content, so it stays a plain reveal list rather than a
          // fabricated matching game.
          if (json['questions'] is List && json['answers'] is List)
            _buildQAMatching(
                context, json['questions'] as List, json['answers'] as List),

          // Stations (interactive game)
          if (json['stations'] is List)
            _buildStationsList(context, json['stations'] as List),

          // WG Characters
          if (json['characters'] is List)
            _buildWGCharacters(context, json['characters'] as List),

          // Cultural Reading text
          if (json['text'] != null && section.type == 'cultural_reading')
            Container(
              padding: const EdgeInsets.all(14),
              color: BooksModernist.surface,
              child: InteractiveGermanText(
                json['text'].toString(),
                sourceTitle: _unit?.title,
                style: BooksModernist.body(size: 14).copyWith(height: 1.5),
              ),
            ),

          // Example Speech
          if (json['example_speech'] != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: BooksModernist.accent, width: 2)),
              ),
              child: Text(
                '„${json['example_speech']}"',
                style: BooksModernist.body(size: 13, style: FontStyle.italic),
              ),
            ),

          const ModernistDivider(margin: EdgeInsets.only(top: 4)),
        ],
      ),
    );
  }

  // ── Generic tap-to-match exercise engine ─────────────────────────────
  //
  // Mirrors the design's buildMatch()/selectLeft()/selectRight(): tap a left
  // item to arm it, then tap a right item — if it's the correct pair (per
  // answerKey) both items lock in as "paired"; otherwise both flash briefly
  // and stay tappable. In Solutions mode, every pair is shown pre-solved.

  void _selectLeft(String exKey, String id) {
    if (!_isPracticeMode) return;
    setState(() {
      final paired = _matchPaired[exKey] ?? {};
      if (paired.containsKey(id)) return;
      _matchArmedLeft[exKey] = _matchArmedLeft[exKey] == id ? null : id;
      _matchFlash[exKey] = null;
    });
  }

  void _selectRight(String exKey, String id, Map<String, String> answerKey) {
    if (!_isPracticeMode) return;
    final armed = _matchArmedLeft[exKey];
    if (armed == null) return;
    if (answerKey[armed] == id) {
      setState(() {
        final paired = Map<String, String>.from(_matchPaired[exKey] ?? {});
        paired[armed] = id;
        _matchPaired[exKey] = paired;
        _matchArmedLeft[exKey] = null;
        _matchFlash[exKey] = null;
      });
    } else {
      setState(() => _matchFlash[exKey] = (armed, id));
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _matchFlash[exKey] = null);
      });
    }
  }

  Widget _buildMatchExercise(
    BuildContext context, {
    required String exKey,
    required List<(String id, String label, String sub)> leftItems,
    required List<(String id, String label, String sub)> rightItems,
    required Map<String, String> answerKey,
  }) {
    final paired = _isPracticeMode ? (_matchPaired[exKey] ?? {}) : answerKey;
    final armed = _isPracticeMode ? _matchArmedLeft[exKey] : null;
    final flash = _matchFlash[exKey];
    final doneCount = paired.length;
    final total = answerKey.length;

    Widget itemBox({
      required String id,
      required String label,
      required String sub,
      required bool isLeft,
    }) {
      final isPaired = isLeft
          ? paired.containsKey(id)
          : paired.containsValue(id);
      final isArmed = isLeft && armed == id;
      final isFlash = flash != null && (isLeft ? flash.$1 == id : flash.$2 == id);
      String connector = '';
      if (isPaired) {
        final pairId = isLeft ? paired[id] : paired.entries.firstWhere((e) => e.value == id).key;
        final other = (isLeft ? rightItems : leftItems).firstWhere((e) => e.$1 == pairId);
        connector = isLeft ? '— ${other.$2} →' : '← ${other.$2}';
      }

      Color bg = BooksModernist.surface;
      Color border = BooksModernist.divider;
      Color fg = BooksModernist.text;
      if (isPaired) {
        bg = BooksModernist.accent100;
        border = BooksModernist.accent;
        fg = BooksModernist.accentDark;
      } else if (isFlash) {
        bg = BooksModernist.accent200;
        border = BooksModernist.accent600;
      } else if (isArmed) {
        border = BooksModernist.accent;
      }

      return InkWell(
        onTap: isPaired
            ? null
            : () => isLeft
                ? _selectLeft(exKey, id)
                : _selectRight(exKey, id, answerKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: isArmed ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty)
                Text(label,
                    style: BooksModernist.heading(size: 13, color: fg)),
              if (sub.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: label.isNotEmpty ? 4 : 0),
                  child: Text(sub,
                      style: BooksModernist.body(size: 12, color: fg, weight: label.isEmpty ? FontWeight.w600 : null)),
                ),
              if (connector.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(connector,
                      style: BooksModernist.body(size: 11, weight: FontWeight.w700, color: fg)),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$doneCount / $total zugeordnet',
                  style: BooksModernist.body(
                      size: 11, color: BooksModernist.text.withValues(alpha: 0.6))),
              if (doneCount > 0 && _isPracticeMode)
                InkWell(
                  onTap: () => setState(() => _matchPaired[exKey] = {}),
                  child: Text('Zurücksetzen',
                      style: BooksModernist.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: BooksModernist.accent)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: leftItems
                      .map((it) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: itemBox(
                                id: it.$1, label: it.$2, sub: it.$3, isLeft: true),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: rightItems
                      .map((it) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: itemBox(
                                id: it.$1, label: it.$2, sub: it.$3, isLeft: false),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeadingTextMatching(
    BuildContext context,
    String sectionId,
    List<dynamic> headings,
    List<dynamic> texts,
  ) {
    // Verified against Books.dc.html's M3A_ANSWER (Julia -> C, Jonas -> B).
    const answerKey = {'Julia': 'C', 'Jonas': 'B'};
    final leftItems = texts.map((t) {
      final map = t as Map<String, dynamic>;
      final person = map['person']?.toString() ?? '';
      return (person, person, map['text']?.toString() ?? '');
    }).toList();
    final rightItems = headings.map((h) {
      final map = h as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      return (id, '', '$id · ${map['title'] ?? ''}');
    }).toList();

    // If the real answer set doesn't cover every left item (different
    // chapter/content than the verified case), fall back to the old plain
    // read-only layout rather than guessing pairings.
    final coversAll = leftItems.every((l) => answerKey.containsKey(l.$1));
    if (!coversAll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeadingsList(context, headings),
          _buildPersonTexts(context, texts),
        ],
      );
    }

    return _buildMatchExercise(
      context,
      exKey: sectionId,
      leftItems: leftItems,
      rightItems: rightItems,
      answerKey: answerKey,
    );
  }

  Widget _buildReplyMatching(
    BuildContext context,
    String sectionId,
    List<dynamic> incoming,
    List<dynamic> replies,
  ) {
    // Verified against Books.dc.html's M6B_ANSWER (Felix->3, Marvin->1, Lea->2).
    const answerKey = {'A': '3', 'B': '1', 'C': '2'};
    final leftItems = incoming.map((m) {
      final map = m as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      return (id, map['sender']?.toString() ?? '', map['text']?.toString() ?? '');
    }).toList();
    final rightItems = replies.map((r) {
      final map = r as Map<String, dynamic>;
      return (map['id']?.toString() ?? '', '', map['text']?.toString() ?? '');
    }).toList();

    final coversAll = leftItems.every((l) => answerKey.containsKey(l.$1));
    if (!coversAll) return const SizedBox.shrink();

    return _buildMatchExercise(
      context,
      exKey: sectionId,
      leftItems: leftItems,
      rightItems: rightItems,
      answerKey: answerKey,
    );
  }

  Widget _buildCausalMatching(
      BuildContext context, String sectionId, List<dynamic> lefts, List<dynamic> rights) {
    // Verified against Books.dc.html's M7A_ANSWER.
    const answerKey = {'1': 'D', '2': 'E', '3': 'C', '4': 'B', '5': 'A'};
    final leftItems = lefts.map((l) {
      final map = l as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      return (id, '', '$id. ${map['text'] ?? ''}');
    }).toList();
    final rightItems = rights.map((r) {
      final map = r as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      return (id, '', '$id. ${map['text'] ?? ''}');
    }).toList();

    final coversAll = leftItems.every((l) => answerKey.containsKey(l.$1));
    if (!coversAll) {
      // No verified answer key for this content — plain read-only fallback.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Satzanfang:', style: BooksModernist.heading(size: 13)),
          const SizedBox(height: 6),
          ...lefts.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${(l as Map)['id']}. ${l['text']}',
                    style: BooksModernist.body()),
              )),
          const SizedBox(height: 12),
          Text('Nebensatz mit weil:', style: BooksModernist.heading(size: 13)),
          const SizedBox(height: 6),
          ...rights.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${(r as Map)['id']}. ${r['text']}',
                    style: BooksModernist.body()),
              )),
        ],
      );
    }

    return _buildMatchExercise(
      context,
      exKey: sectionId,
      leftItems: leftItems,
      rightItems: rightItems,
      answerKey: answerKey,
    );
  }

  Widget _buildQAMatching(
      BuildContext context, List<dynamic> questions, List<dynamic> answers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fragen:', style: BooksModernist.heading(size: 13)),
        const SizedBox(height: 6),
        ...questions.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${(q as Map)['id']}. ${q['question']}',
                style: BooksModernist.body(weight: FontWeight.w600),
              ),
            )),
        const SizedBox(height: 12),
        Text('Antworten:', style: BooksModernist.heading(size: 13)),
        const SizedBox(height: 6),
        ...answers.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              color: BooksModernist.surface,
              child: Text(
                '${(a as Map)['id']}: ${a['text']}',
                style: BooksModernist.body(size: 13),
              ),
            )),
      ],
    );
  }

  Widget _buildProfilesList(BuildContext context, List<ProfileModel> profiles) {
    return Column(
      children: profiles.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          color: BooksModernist.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                color: BooksModernist.text,
                child: Text(
                  p.name.isNotEmpty ? p.name[0] : '?',
                  style: BooksModernist.heading(size: 13, color: BooksModernist.bg),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: BooksModernist.heading(size: 14)),
                    const SizedBox(height: 4),
                    InteractiveGermanText(
                      p.text,
                      sourceTitle: _unit?.title,
                      style: BooksModernist.body(size: 13).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChatList(BuildContext context, List<ChatMessageModel> messages) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: BooksModernist.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages.map((m) {
          final isMe = m.sender == 'Ben';
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isMe ? BooksModernist.text : BooksModernist.bg,
                border: isMe ? null : Border.all(color: BooksModernist.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.sender,
                        style: BooksModernist.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: (isMe ? BooksModernist.bg : BooksModernist.text)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      if (m.time != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          m.time!,
                          style: BooksModernist.body(
                            size: 10,
                            color: (isMe ? BooksModernist.bg : BooksModernist.text)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  InteractiveGermanText(
                    m.text,
                    sourceTitle: _unit?.title,
                    style: BooksModernist.body(
                      size: 13,
                      color: isMe ? BooksModernist.bg : BooksModernist.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRawChatList(BuildContext context, List<dynamic> list) {
    final msgs = list.map((item) {
      final map = item as Map<String, dynamic>;
      return ChatMessageModel(
        id: map['id']?.toString() ?? '',
        sender: map['sender']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        time: map['time']?.toString(),
      );
    }).toList();
    return _buildChatList(context, msgs);
  }

  Widget _buildExerciseList(
      BuildContext context, List<ExerciseItemModel> items) {
    return Column(
      children: items.map((item) {
        final key = '${item.id}_${item.prompt}';
        final selectedAns = _userAnswers[key];
        final isCorrect = selectedAns != null &&
            item.answer != null &&
            selectedAns.trim().toLowerCase() ==
                item.answer!.trim().toLowerCase();
        final isWrong = selectedAns != null && !isCorrect;
        final isRevealed = _revealedAnswers[key] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BooksModernist.surface,
            border: selectedAns != null
                ? Border.all(
                    color: isCorrect ? BooksModernist.accent : BooksModernist.accent600,
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                color: selectedAns != null
                    ? (isCorrect ? BooksModernist.accent100 : BooksModernist.accent200)
                    : BooksModernist.bg,
                child: Text(
                  item.id,
                  style: BooksModernist.heading(
                    size: 12,
                    color: selectedAns != null
                        ? (isCorrect ? BooksModernist.accentDark : BooksModernist.accent600)
                        : BooksModernist.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InteractiveGermanText(
                      item.prompt,
                      sourceTitle: _unit?.title,
                      style: BooksModernist.heading(size: 14),
                    ),
                    const SizedBox(height: 8),

                    if (_isPracticeMode &&
                        item.options != null &&
                        item.options!.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: item.options!.map((opt) {
                          final isThisSelected = selectedAns == opt;
                          Color bg = BooksModernist.bg;
                          Color fg = BooksModernist.text;
                          Color border = BooksModernist.divider;
                          if (isThisSelected) {
                            if (isCorrect) {
                              bg = BooksModernist.accent;
                              fg = BooksModernist.bg;
                              border = BooksModernist.accent;
                            } else {
                              bg = BooksModernist.accent600;
                              fg = Colors.white;
                              border = BooksModernist.accent600;
                            }
                          }
                          return InkWell(
                            onTap: () => setState(() => _userAnswers[key] = opt),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: bg, border: Border.all(color: border)),
                              child: Text(opt,
                                  style: BooksModernist.body(size: 13, weight: FontWeight.w600, color: fg)),
                            ),
                          );
                        }).toList(),
                      ),
                      if (isWrong)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Richtig ist: ${item.answer}',
                            style: BooksModernist.body(
                                size: 12, weight: FontWeight.w700, color: BooksModernist.accentDark),
                          ),
                        ),
                    ] else if (_isPracticeMode) ...[
                      if (!isRevealed)
                        InkWell(
                          onTap: () => setState(() => _revealedAnswers[key] = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(border: Border.all(color: BooksModernist.divider)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.visibility_outlined, size: 14, color: BooksModernist.accent),
                                const SizedBox(width: 6),
                                Text('Lösung anzeigen',
                                    style: BooksModernist.body(size: 12, weight: FontWeight.w700, color: BooksModernist.accent)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        if (item.answer != null)
                          Text('→ ${item.answer}',
                              style: BooksModernist.body(size: 14, weight: FontWeight.w600, color: BooksModernist.accentDark)),
                        if (item.matchTarget != null)
                          Text(item.matchTarget!,
                              style: BooksModernist.body(size: 13, weight: FontWeight.w600, color: BooksModernist.accentDark)),
                      ],
                    ] else ...[
                      if (item.answer != null)
                        Text('→ ${item.answer}',
                            style: BooksModernist.body(size: 14, weight: FontWeight.w600, color: BooksModernist.accentDark)),
                      if (item.matchTarget != null)
                        Text(item.matchTarget!,
                            style: BooksModernist.body(size: 13, weight: FontWeight.w600, color: BooksModernist.accentDark)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopicsList(BuildContext context, List<dynamic> topics) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: topics.map((t) {
        final map = t as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(border: Border.all(color: BooksModernist.divider)),
          child: Text('${map['id']}. ${map['label']}',
              style: BooksModernist.body(size: 12, weight: FontWeight.w600)),
        );
      }).toList(),
    );
  }

  Widget _buildHeadingsList(BuildContext context, List<dynamic> headings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: headings.map((h) {
        final map = h as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Überschrift ${map['id']}: "${map['title']}"',
            style: BooksModernist.body(weight: FontWeight.w700, color: BooksModernist.accentDark),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPersonTexts(BuildContext context, List<dynamic> texts) {
    return Column(
      children: texts.map((item) {
        final map = item as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          color: BooksModernist.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(map['person']?.toString() ?? '',
                  style: BooksModernist.heading(size: 15, color: BooksModernist.accentDark)),
              const SizedBox(height: 6),
              InteractiveGermanText(
                map['text']?.toString() ?? '',
                sourceTitle: _unit?.title,
                style: BooksModernist.body(size: 13).copyWith(height: 1.4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatementsList(BuildContext context, List<dynamic> statements) {
    return Column(
      children: statements.map((st) {
        final map = st as Map<String, dynamic>;
        final isCorrect = map['correct'] as bool?;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          color: BooksModernist.surface,
          child: Row(
            children: [
              Text('${map['id']}.',
                  style: BooksModernist.heading(size: 12, color: BooksModernist.text.withValues(alpha: 0.5))),
              const SizedBox(width: 10),
              Expanded(
                child: Text(map['text']?.toString() ?? '', style: BooksModernist.body(size: 13)),
              ),
              if (map['answer'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: BooksModernist.accent100,
                  child: Text(
                    map['answer'].toString(),
                    style: BooksModernist.body(size: 12, weight: FontWeight.w700, color: BooksModernist.accentDark),
                  ),
                ),
              if (isCorrect != null)
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? BooksModernist.accent : BooksModernist.accent600,
                  size: 20,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStationsList(BuildContext context, List<dynamic> stations) {
    return Column(
      children: stations.map((st) {
        final map = st as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          color: BooksModernist.accent100,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                color: BooksModernist.accent,
                child: Text(map['station']?.toString() ?? '',
                    style: BooksModernist.heading(size: 13, color: BooksModernist.bg)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(map['sense']?.toString() ?? '',
                        style: BooksModernist.heading(size: 13, color: BooksModernist.accentDark)),
                    Text(map['description']?.toString() ?? '', style: BooksModernist.body(size: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWGCharacters(BuildContext context, List<dynamic> characters) {
    return Column(
      children: characters.map((c) {
        final map = c as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          color: BooksModernist.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(map['name']?.toString() ?? '',
                  style: BooksModernist.heading(size: 16, color: BooksModernist.accentDark)),
              const SizedBox(height: 6),
              Text('Beruf: ${map['job'] ?? ''}', style: BooksModernist.body(weight: FontWeight.w700)),
              Text('Typisch: ${map['typical'] ?? ''}', style: BooksModernist.body()),
              Text('Hobby: ${map['hobby'] ?? ''}', style: BooksModernist.body()),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrammarTab(BuildContext context) {
    final grammarList = _unit!.grammar;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: grammarList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final g = grammarList[index];
        return Container(
          padding: const EdgeInsets.all(16),
          color: BooksModernist.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.title, style: BooksModernist.heading(size: 16, color: BooksModernist.accentDark)),
              const SizedBox(height: 10),
              InteractiveGermanText(
                g.rule,
                sourceTitle: _unit?.title,
                style: BooksModernist.body(size: 13).copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              ...g.examples.map((ex) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    color: BooksModernist.bg,
                    child: InteractiveGermanText(
                      ex,
                      sourceTitle: _unit?.title,
                      style: BooksModernist.mono(size: 12.5),
                    ),
                  )),
              if (g.tableData != null) ...[
                const SizedBox(height: 12),
                Table(
                  border: TableBorder(
                    top: BorderSide(color: BooksModernist.divider),
                    horizontalInside: BorderSide(color: BooksModernist.dividerThin),
                  ),
                  children: g.tableData!.entries.map((entry) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                          child: Text(entry.key,
                              style: BooksModernist.body(size: 13, weight: FontWeight.w700, color: BooksModernist.accentDark)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                          child: Text(entry.value.join(', '), style: BooksModernist.body(size: 13)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRedemittelTab(BuildContext context) {
    final redemittelList = _unit!.redemittel;

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: redemittelList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final cat = redemittelList[index];
        return Container(
          padding: const EdgeInsets.all(16),
          color: BooksModernist.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cat.category, style: BooksModernist.heading(size: 16, color: BooksModernist.accentDark)),
              const SizedBox(height: 12),
              ...cat.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ModernistTag(item.title),
                        const SizedBox(height: 6),
                        ...item.phrases.map((phrase) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('· ',
                                      style: BooksModernist.body(weight: FontWeight.w800, color: BooksModernist.accent)),
                                  Expanded(
                                    child: InteractiveGermanText(
                                      phrase,
                                      sourceTitle: _unit?.title,
                                      style: BooksModernist.body(size: 13).copyWith(height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

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
