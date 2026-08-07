import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book_guide.dart';
import '../../services/book_guide_service.dart';
import '../../services/vocabulary_service.dart';

class ChapterStudyScreen extends StatefulWidget {
  final ChapterSummary chapterSummary;
  final String bookTitle;

  const ChapterStudyScreen({
    super.key,
    required this.chapterSummary,
    required this.bookTitle,
  });

  @override
  State<ChapterStudyScreen> createState() => _ChapterStudyScreenState();
}

class _ChapterStudyScreenState extends State<ChapterStudyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ChapterGuide? _chapter;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChapterData();
  }

  Future<void> _loadChapterData() async {
    final service = Provider.of<BookGuideService>(context, listen: false);
    final data = await service.loadChapter(widget.chapterSummary.jsonAssetPath);
    if (mounted) {
      setState(() {
        _chapter = data;
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
          'Kapitel ${widget.chapterSummary.chapterNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'Wortschatz'),
            Tab(text: 'Dialoge'),
            Tab(text: 'Redemittel'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chapter == null
              ? const Center(child: Text('Could not load chapter data.'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVocabularyTab(context),
                    _buildDialoguesTab(context),
                    _buildRedemittelTab(context),
                  ],
                ),
    );
  }

  Widget _buildVocabularyTab(BuildContext context) {
    final vocabList = _chapter!.vocabulary.where((v) {
      if (_searchQuery.isEmpty) return true;
      return v.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.exampleSentence.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search vocabulary in Chapter ${_chapter!.chapterNumber}...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: vocabList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = vocabList[index];
              return _buildVocabCard(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVocabCard(BuildContext context, VocabularyGuideItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color badgeColor = colorScheme.secondary;
    if (item.article == 'der') badgeColor = Colors.blue.shade700;
    if (item.article == 'die') badgeColor = Colors.pink.shade600;
    if (item.article == 'das') badgeColor = Colors.teal.shade700;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.article.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.article,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          if (item.article.isNotEmpty) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.word,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (item.exampleSentence.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.exampleSentence,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialoguesTab(BuildContext context) {
    final dialogues = _chapter!.dialogues;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: dialogues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final d = dialogues[index];
        return _buildDialogueCard(context, d);
      },
    );
  }

  Widget _buildDialogueCard(BuildContext context, DialogueGuideItem dialogue) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Hörtext ${dialogue.trackNumber}',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.volume_up_rounded, color: colorScheme.primary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dialogue.transcript,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedemittelTab(BuildContext context) {
    final redemittel = _chapter!.redemittel;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: redemittel.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final group = redemittel[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              ...group.phrases.map((phrase) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            phrase,
                            style: const TextStyle(fontSize: 14, height: 1.3),
                          ),
                        ),
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
