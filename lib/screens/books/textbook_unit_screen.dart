import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book_guide.dart';
import '../../models/textbook_unit.dart';
import '../../services/book_guide_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import '../../widgets/glance_word_sheet.dart';

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
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _unit != null
              ? 'Kapitel ${_unit!.unitNumber}: ${_unit!.title}'
              : 'Kapitel ${widget.chapterSummary.chapterNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  _isPracticeMode = !_isPracticeMode;
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isPracticeMode
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isPracticeMode
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPracticeMode
                          ? Icons.quiz_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                      color: _isPracticeMode
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isPracticeMode ? 'Üben' : 'Lösungen',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isPracticeMode
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'Kursbuch (Pages)'),
            Tab(text: 'Grammatik'),
            Tab(text: 'Redemittel'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unit == null
              ? const Center(child: Text('Could not load unit data.'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPagesTab(context),
                    _buildGrammarTab(context),
                    _buildRedemittelTab(context),
                  ],
                ),
    );
  }

  Widget _buildPagesTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pages = _unit!.pages;

    return Column(
      children: [
        // Objectives banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: colorScheme.primary.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lernziele (CEFR Objectives):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _unit!.objectives.map((obj) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        obj,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Page selector pill bar
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
              final isAllDone = totalOnPage > 0 && doneOnPage == totalOnPage;

              return GestureDetector(
                onTap: () => setState(() => _selectedPageIndex = index),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? colorScheme.primary : colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Seite ${page.pageNumber}${totalOnPage > 0 ? " ($doneOnPage/$totalOnPage${isAllDone ? ' ✓' : ''})" : ""}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Selected Page Sections
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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
    final colorScheme = Theme.of(context).colorScheme;
    final json = section.rawJson;
    final isDone = _completedSectionIds.contains(section.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
          right: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
          left: BorderSide(
            color: isDone ? Colors.green : colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: isDone ? 4 : 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with section ID and title/type
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  section.id.toUpperCase(),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (section.title != null)
                Expanded(
                  child: Text(
                    section.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: colorScheme.onSurface,
                    ),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    section.type.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.secondary,
                    ),
                  ),
                ),
              if (section.audioId != null || json['audio_id'] != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.volume_up_rounded,
                          size: 14, color: colorScheme.onSecondaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        'Track ${section.audioId ?? json['audio_id']}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _toggleSectionDone(section.id),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDone
                          ? Colors.green
                          : colorScheme.outlineVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 14,
                        color: isDone
                            ? Colors.green
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDone ? 'Erledigt' : 'Erledigen',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDone
                              ? Colors.green
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Instruction
          if (section.instruction != null) ...[
            Text(
              section.instruction!,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
          ],

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

          // Headings and Texts (e.g. Das letzte Jahr)
          if (json['headings'] is List)
            _buildHeadingsList(context, json['headings'] as List),
          if (json['texts'] is List)
            _buildPersonTexts(context, json['texts'] as List),

          // Statements (fill in the blank / comprehension)
          if (json['statements'] is List)
            _buildStatementsList(context, json['statements'] as List),

          // Left/Right clauses (matching_causal)
          if (json['left_clauses'] is List && json['right_clauses'] is List)
            _buildCausalMatching(
                context, json['left_clauses'] as List, json['right_clauses'] as List),

          // Questions and answers (e.g. FAQ matching)
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
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: InteractiveGermanText(
                json['text'].toString(),
                sourceTitle: _unit?.title,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),

          // Example Speech
          if (json['example_speech'] != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Beispiel: "${json['example_speech']}"',
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: colorScheme.onSurface),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfilesList(BuildContext context, List<ProfileModel> profiles) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: profiles.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                child: Text(
                  p.name.isNotEmpty ? p.name[0] : '?',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InteractiveGermanText(
                      p.text,
                      sourceTitle: _unit?.title,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: colorScheme.onSurfaceVariant,
                      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages.map((m) {
          final isMe = m.sender == 'Ben';
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(4),
                  topRight: const Radius.circular(4),
                  bottomLeft: Radius.circular(isMe ? 4 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.sender,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isMe
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.primary,
                        ),
                      ),
                      if (m.time != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          m.time!,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  InteractiveGermanText(
                    m.text,
                    sourceTitle: _unit?.title,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
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
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
            border: selectedAns != null
                ? Border.all(
                    color: isCorrect ? Colors.green : Colors.red,
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selectedAns != null
                      ? (isCorrect
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2))
                      : colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    item.id,
                    style: TextStyle(
                      color: selectedAns != null
                          ? (isCorrect ? Colors.green : Colors.red)
                          : colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 1. PRACTICE MODE WITH MULTIPLE CHOICE OPTIONS
                    if (_isPracticeMode &&
                        item.options != null &&
                        item.options!.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: item.options!.map((opt) {
                          final isThisSelected = selectedAns == opt;
                          Color chipBg = colorScheme.surface;
                          Color chipFg = colorScheme.onSurface;
                          Color borderCol = colorScheme.outlineVariant;
                          if (isThisSelected) {
                            if (isCorrect) {
                              chipBg = Colors.green;
                              chipFg = Colors.white;
                              borderCol = Colors.green;
                            } else {
                              chipBg = Colors.red;
                              chipFg = Colors.white;
                              borderCol = Colors.red;
                            }
                          }
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _userAnswers[key] = opt;
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: borderCol),
                              ),
                              child: Text(
                                opt,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: chipFg,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (isWrong)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Richtig ist: ${item.answer}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ]
                    // 2. PRACTICE MODE WITHOUT OPTIONS (FREE TEXT / MATCHING)
                    else if (_isPracticeMode) ...[
                      if (!isRevealed)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _revealedAnswers[key] = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility,
                                    size: 14, color: colorScheme.secondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Lösung anzeigen',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        if (item.answer != null)
                          Text(
                            '→ ${item.answer}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        if (item.matchTarget != null)
                          Text(
                            item.matchTarget!,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ]
                    // 3. SOLUTIONS MODE (REVIEW)
                    else ...[
                      if (item.answer != null)
                        Text(
                          '→ ${item.answer}',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      if (item.matchTarget != null)
                        Text(
                          item.matchTarget!,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: topics.map((t) {
        final map = t as Map<String, dynamic>;
        return Chip(
          label: Text('${map['id']}. ${map['label']}'),
          backgroundColor: colorScheme.secondaryContainer,
          labelStyle: TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold),
        );
      }).toList(),
    );
  }

  Widget _buildHeadingsList(BuildContext context, List<dynamic> headings) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: headings.map((h) {
        final map = h as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Überschrift ${map['id']}: "${map['title']}"',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPersonTexts(BuildContext context, List<dynamic> texts) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: texts.map((item) {
        final map = item as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                map['person']?.toString() ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              InteractiveGermanText(
                map['text']?.toString() ?? '',
                sourceTitle: _unit?.title,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatementsList(BuildContext context, List<dynamic> statements) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: statements.map((st) {
        final map = st as Map<String, dynamic>;
        final isCorrect = map['correct'] as bool?;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(
                '${map['id']}.',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  map['text']?.toString() ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (map['answer'] != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    map['answer'].toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              if (isCorrect != null)
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 20,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCausalMatching(
      BuildContext context, List<dynamic> lefts, List<dynamic> rights) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Satzanfang (Left Clauses):',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...lefts.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  '${(l as Map)['id']}. ${(l as Map)['text']}'),
            )),
        const SizedBox(height: 12),
        const Text('Nebensatz mit weil (Right Clauses):',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...rights.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  '${(r as Map)['id']}. ${(r as Map)['text']}'),
            )),
      ],
    );
  }

  Widget _buildQAMatching(
      BuildContext context, List<dynamic> questions, List<dynamic> answers) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fragen (Questions):',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...questions.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${(q as Map)['id']}. ${(q as Map)['question']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )),
        const SizedBox(height: 12),
        const Text('Antworten (Answers):',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...answers.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(a as Map)['id']}: ${(a as Map)['text']}',
                style: const TextStyle(fontSize: 13),
              ),
            )),
      ],
    );
  }

  Widget _buildStationsList(BuildContext context, List<dynamic> stations) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: stations.map((st) {
        final map = st as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.secondary,
                child: Text(
                  map['station']?.toString() ?? '',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      map['sense']?.toString() ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary),
                    ),
                    Text(map['description']?.toString() ?? ''),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: characters.map((c) {
        final map = c as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                map['name']?.toString() ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text('Beruf: ${map['job'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Typisch: ${map['typical'] ?? ''}'),
              Text('Hobby: ${map['hobby'] ?? ''}'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrammarTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grammarList = _unit!.grammar;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: grammarList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final g = grammarList[index];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rule_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InteractiveGermanText(
                g.rule,
                sourceTitle: _unit?.title,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Beispiele / Regeln:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              ...g.examples.map((ex) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: InteractiveGermanText(
                      ex,
                      sourceTitle: _unit?.title,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  )),
              if (g.tableData != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Tabelle:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Table(
                  border: TableBorder.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: 1,
                  ),
                  children: g.tableData!.entries.map((entry) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            entry.value.join(', '),
                            style: const TextStyle(fontSize: 13),
                          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final redemittelList = _unit!.redemittel;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: redemittelList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final cat = redemittelList[index];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cat.category,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              ...cat.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...item.phrases.map((phrase) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary)),
                                  Expanded(
                                    child: InteractiveGermanText(
                                      phrase,
                                      sourceTitle: _unit?.title,
                                      style: const TextStyle(
                                          fontSize: 14, height: 1.3),
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

