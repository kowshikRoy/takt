import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/media_library_service.dart';
import '../models/article_model.dart';
import '../models/processed_video.dart';
import '../models/processing_status.dart';
import '../widgets/article_card.dart';
import '../widgets/compact_article_card.dart';
import 'story_reader_screen.dart';
import 'video_screen.dart';
import 'create/text_input_screen.dart';
import 'create/url_import_screen.dart';
import 'skill_tree_screen.dart';
import '../theme/books_modernist_style.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _selectedLevel = 'All';
  final List<String> _levels = ['All', 'A1', 'A2', 'B1', 'B2', 'C1'];

  // Mock Data - New Stories
  final List<Article> _articles = [
    Article(
      id: '1',
      title: 'The cultural significance of long hair',
      description: 'In vielen Teilen von Lateinamerika ist langes Haar sehr wichtig. Menschen in kleinen Dörfern und großen Städten...',
      level: 'A2',
      date: DateTime(2025, 12, 17),
      imageUrl: 'assets/images/story_hair.png', 
    ),
    Article(
      id: '2',
      title: "'Sock ball': Egypt's humble game turned street celebration",
      description: 'Sockenball ist ein Spiel aus Ägypten. Man macht einen Ball mit alten Socken, Klebeband und Faden.',
      level: 'A1',
      date: DateTime(2025, 12, 16),
      imageUrl: 'assets/images/story_soccer.png', 
    ),
    Article(
      id: '3',
      title: 'Desert Landscapes of the World',
      description: 'Wüsten sind faszinierende Orte mit extremer Hitze und Kälte.',
      level: 'B1',
      date: DateTime(2025, 12, 15),
      imageUrl: 'assets/images/story_desert.png', 
    ),
  ];

  // Mock Data - Continue Learning
  final List<Article> _continueLearningArticles = [
    Article(
      id: 'cl1',
      title: 'Wüsten der Welt: Die Sahara',
      description: 'Extremtemperaturen und faszinierende Dünenlandschaften.',
      level: 'B1',
      date: DateTime.now(),
      imageUrl: 'assets/images/story_desert.png',
    ),
    Article(
      id: 'cl2',
      title: 'Straßenfußball in Kairo',
      description: 'Sockenball ist ein beliebtes Straßenspiel in Ägypten.',
      level: 'A2',
      date: DateTime.now(),
      imageUrl: 'assets/images/story_soccer.png', 
    ),
  ];

  List<Article> get _filteredArticles {
    if (_selectedLevel == 'All') return _articles;
    return _articles.where((a) => a.level == _selectedLevel).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mediaLibraryService = Provider.of<MediaLibraryService>(context);

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            floatingActionButton: AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                if (tabController.index != 1) return const SizedBox.shrink();
                return FloatingActionButton(
                  onPressed: () => _showCreateOptions(context),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                );
              },
            ),
            body: SafeArea(
              child: Column(
                children: [
                  TabBar(
                    tabs: const [Tab(text: 'Path'), Tab(text: 'Library')],
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        const SkillTreeScreen(),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isDesktop = constraints.maxWidth > 700;
                            return isDesktop
                                ? _buildDesktopLayout(context, mediaLibraryService)
                                : _buildMobileLayout(context, mediaLibraryService);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, MediaLibraryService mediaLibraryService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Content Area (Stories Grid)
          Expanded(
            flex: 65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Level Filter Pills
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Explore Stories',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    _buildFilterPills(context),
                  ],
                ),
                const SizedBox(height: 20),

                // Responsive Grid for Stories
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredArticles.length,
                  itemBuilder: (context, index) {
                    final article = _filteredArticles[index];
                    return ArticleCard(
                      article: article,
                      onTap: () => _openReader(article),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),

          // Sidebar Column (Continue Reading, Imported, Media)
          Expanded(
            flex: 35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Action Banner
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_link_rounded, size: 28, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Import Any Content',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'YouTube, Web articles, or custom text',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _showCreateOptions(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                        ),
                        child: const Text('Import', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Continue Learning Section
                Text(
                  'CONTINUE LEARNING',
                  style: BooksModernist.body(
                    size: 11,
                    weight: FontWeight.w800,
                    color: BooksModernist.accentDark,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _continueLearningArticles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final article = _continueLearningArticles[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: Image.asset(article.imageUrl, width: 44, height: 44, fit: BoxFit.cover),
                        ),
                        title: Text(article.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Level ${article.level}', style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => _openReader(article),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Imported Articles
                if (mediaLibraryService.importedArticles.isNotEmpty) ...[
                  Text(
                    'YOUR IMPORTS',
                    style: BooksModernist.body(
                      size: 11,
                      weight: FontWeight.w800,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mediaLibraryService.importedArticles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final article = mediaLibraryService.importedArticles[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: ListTile(
                          title: Text(article.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(article.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: 'Delete article',
                            onPressed: () => _confirmDelete(context, article, mediaLibraryService),
                          ),
                          onTap: () => _openReader(article),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Transcribed Media
                if (mediaLibraryService.processedVideos.isNotEmpty) ...[
                  Text(
                    'TRANSCRIBED MEDIA',
                    style: BooksModernist.body(
                      size: 11,
                      weight: FontWeight.w800,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mediaLibraryService.processedVideos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final video = mediaLibraryService.processedVideos[index];
                      final isFailed = video.status == ProcessingStatus.failed;
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: isFailed
                                ? Theme.of(context).colorScheme.error.withValues(alpha: 0.5)
                                : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: ListTile(
                          leading: Icon(
                            isFailed ? Icons.error_outline_rounded : Icons.video_library_rounded,
                            color: isFailed ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(video.effectiveTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(
                            isFailed
                                ? (video.errorMessage ?? video.stageMessage ?? 'Transcript fetch failed')
                                : video.status.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isFailed ? Theme.of(context).colorScheme.error : null,
                            ),
                          ),
                          trailing: isFailed
                              ? IconButton(
                                  icon: const Icon(Icons.refresh_rounded, size: 20),
                                  tooltip: 'Retry',
                                  onPressed: () => mediaLibraryService.retryProcessingTask(
                                    video.taskId ?? video.id,
                                    video.url,
                                  ),
                                )
                              : null,
                          onTap: () {
                            if (video.status == ProcessingStatus.completed) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(processedVideo: video)));
                            }
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPills(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _levels.map((level) {
          final isSelected = _selectedLevel == level;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedLevel = level;
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, MediaLibraryService mediaLibraryService) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Continue Learning Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              'CONTINUE LEARNING',
              style: BooksModernist.body(
                size: 11,
                weight: FontWeight.w800,
                color: BooksModernist.accentDark,
              ),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _continueLearningArticles.length,
              itemBuilder: (context, index) {
                return CompactArticleCard(
                  article: _continueLearningArticles[index],
                  onTap: () => _openReader(_continueLearningArticles[index]),
                );
              },
            ),
          ),

          // Transcribed Media Section
          if (mediaLibraryService.processedVideos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                'TRANSCRIBED MEDIA',
                style: BooksModernist.body(
                  size: 11,
                  weight: FontWeight.w800,
                  color: BooksModernist.accentDark,
                ),
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: mediaLibraryService.processedVideos.length,
                itemBuilder: (context, index) {
                  final video = mediaLibraryService.processedVideos[index];
                  return _buildVideoCard(context, video, mediaLibraryService);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Imported Section
          if (mediaLibraryService.importedArticles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                'IMPORTED',
                style: BooksModernist.body(
                  size: 11,
                  weight: FontWeight.w800,
                  color: BooksModernist.accentDark,
                ),
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: mediaLibraryService.importedArticles.length,
                itemBuilder: (context, index) {
                  final article = mediaLibraryService.importedArticles[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: CompactArticleCard(
                      article: article,
                      onTap: () => _openReader(article),
                      onDelete: () => _confirmDelete(context, article, mediaLibraryService),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // New Stories Section Header & Filters
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXPLORE STORIES',
                  style: BooksModernist.body(
                    size: 11,
                    weight: FontWeight.w800,
                    color: BooksModernist.accentDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildFilterPills(context)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredArticles.length,
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final article = _filteredArticles[index];
              return ArticleCard(
                article: article,
                onTap: () => _openReader(article),
              );
            },
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompleted = video.status == ProcessingStatus.completed;
    final isFailed = video.status == ProcessingStatus.failed;
    final isProcessing = !isCompleted && !isFailed;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: isFailed
              ? colorScheme.error.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6.0),
          onTap: () {
            if (isCompleted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(processedVideo: video)));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6.0)),
                      child: CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: Colors.grey.shade800),
                      ),
                    ),
                    if (isCompleted)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    if (isProcessing)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          ),
                        ),
                      ),
                    if (isFailed)
                      Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 26),
                            const SizedBox(height: 6),
                            Text(
                              video.errorMessage ?? video.stageMessage ?? 'Transcript fetch failed',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => mediaLibraryService.retryProcessingTask(
                                video.taskId ?? video.id,
                                video.url,
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                              label: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  video.effectiveTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReader(Article article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryReaderScreen(article: article),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Article article, MediaLibraryService mediaLibraryService) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Lesson'),
          content: Text('Are you sure you want to delete "${article.title}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                mediaLibraryService.deleteImportedArticle(article.id);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  bool _isShowingSheet = false;

  void _showCreateOptions(BuildContext context) {
    if (_isShowingSheet) return;
    _isShowingSheet = true;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6.0)),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create & Import',
              style: BooksModernist.heading(size: 18, context: context),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Icon(Icons.link_rounded, color: colorScheme.primary, size: 20),
                ),
                title: const Text('Import Web Article or YouTube Video', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Enter a URL to process and auto-generate transcript', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UrlImportScreen()));
                },
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: colorScheme.secondary, size: 20),
                ),
                title: const Text('Paste Custom Text', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Add your own German text to practice', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TextInputScreen()));
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ).whenComplete(() {
      _isShowingSheet = false;
    });
  }
}
