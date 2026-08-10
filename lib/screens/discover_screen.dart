import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'transcribed_media_grid_screen.dart';
import '../theme/books_modernist_style.dart';
import '../widgets/responsive_grid.dart';

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
            // Desktop already surfaces "Import" via the sidebar's Import Any
            // Content banner — the FAB there would be a second button doing
            // the exact same thing. Keep it only where it's the sole entry
            // point: mobile, and only on the Library tab.
            floatingActionButton: AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                if (tabController.index != 0) return const SizedBox.shrink();
                if (MediaQuery.sizeOf(context).width > 700) return const SizedBox.shrink();
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
                    tabs: const [Tab(text: 'Library'), Tab(text: 'Path')],
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isDesktop = constraints.maxWidth > 700;
                            return isDesktop
                                ? _buildDesktopLayout(context, mediaLibraryService)
                                : _buildMobileLayout(context, mediaLibraryService);
                          },
                        ),
                        const SkillTreeScreen(),
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

                // Responsive Grid for Stories — column count scales with
                // WindowClass instead of a hardcoded 2, so this ~65%-width
                // pane uses the extra room on Large desktop viewports.
                // childAspectRatio taken from origin/main's fix (0.78, up
                // from 0.85) — same tweak, just carried onto this widget
                // since main's version predates the switch to ResponsiveGrid.
                ResponsiveGrid(
                  childAspectRatio: 0.78,
                  mediumColumns: 2,
                  expandedColumns: 2,
                  largeColumns: 3,
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

                // My Content — one merged list instead of three separately
                // headed sections (Continue Learning / Your Imports /
                // Transcribed Media) that overlapped without a clear rule
                // for which list a given piece of content belonged in.
                ..._buildMyContentSection(context, mediaLibraryService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMyContentSection(BuildContext context, MediaLibraryService mediaLibraryService) {
    final rows = <Widget>[
      ..._continueLearningArticles.map((a) => _buildContinueLearningRow(context, a)),
      ...mediaLibraryService.importedArticles.map((a) => _buildImportedArticleRow(context, a, mediaLibraryService)),
      ...mediaLibraryService.processedVideos.map((v) => _buildDesktopVideoRow(context, v, mediaLibraryService)),
    ];

    if (rows.isEmpty) {
      return [
        Text(
          'MY CONTENT',
          style: BooksModernist.body(size: 11, weight: FontWeight.w800, color: BooksModernist.accentDark),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
          ),
          child: Text(
            'Nothing here yet — import an article or video above to get started.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ];
    }

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'MY CONTENT',
            style: BooksModernist.body(size: 11, weight: FontWeight.w800, color: BooksModernist.accentDark),
          ),
          if (mediaLibraryService.processedVideos.isNotEmpty)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TranscribedMediaGridScreen()),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'All Videos',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      for (int i = 0; i < rows.length; i++) ...[
        rows[i],
        if (i != rows.length - 1) const SizedBox(height: 10),
      ],
    ];
  }

  Widget _buildContinueLearningRow(BuildContext context, Article article) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4.0),
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
      ),
    );
  }

  Widget _buildImportedArticleRow(BuildContext context, Article article, MediaLibraryService mediaLibraryService) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4.0),
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
      ),
    );
  }

  Widget _buildDesktopVideoRow(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
    final isCompleted = video.status == ProcessingStatus.completed;
    final isFailed = video.status == ProcessingStatus.failed;
    final isProcessing = !isCompleted && !isFailed;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: isFailed
              ? colorScheme.error.withValues(alpha: 0.4)
              : isProcessing
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isProcessing ? 1.0 : 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(4.0),
        onTap: () {
          if (isCompleted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(processedVideo: video)));
          }
        },
        onLongPress: () => _showMediaActionSheet(context, video, mediaLibraryService),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Thumbnail with live processing overlay
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 52,
                      height: 38,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (video.thumbnail != null && video.thumbnail!.isNotEmpty)
                            Image.network(
                              video.thumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: isFailed
                                    ? colorScheme.error.withValues(alpha: 0.12)
                                    : colorScheme.primary.withValues(alpha: 0.12),
                              ),
                            )
                          else
                            Container(
                              color: isFailed
                                  ? colorScheme.error.withValues(alpha: 0.12)
                                  : isCompleted
                                      ? const Color(0xFF2C5E3B).withValues(alpha: 0.15)
                                      : colorScheme.primary.withValues(alpha: 0.12),
                            ),
                          if (isProcessing)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          else if (isCompleted)
                            Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                              ),
                            )
                          else
                            Center(
                              child: Icon(video.statusIcon, size: 18, color: colorScheme.error),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title and Status Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.effectiveTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Modernist Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFailed
                                    ? colorScheme.error.withValues(alpha: 0.12)
                                    : isCompleted
                                        ? const Color(0xFF2C5E3B).withValues(alpha: 0.15)
                                        : colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: isFailed
                                      ? colorScheme.error.withValues(alpha: 0.3)
                                      : isCompleted
                                          ? const Color(0xFF2C5E3B).withValues(alpha: 0.3)
                                          : colorScheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isProcessing) ...[
                                    SizedBox(
                                      width: 9,
                                      height: 9,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    isProcessing
                                        ? '${video.statusShortLabel} · ${video.effectiveProgress}%'
                                        : video.statusShortLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                      color: isFailed
                                          ? colorScheme.error
                                          : isCompleted
                                              ? const Color(0xFF2C5E3B)
                                              : colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (video.category != null && video.category!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: colorScheme.secondary.withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  video.category!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),

                            // Descriptive subtitle text
                            Expanded(
                              child: Text(
                                isFailed
                                    ? (video.errorMessage ?? video.stageMessage ?? 'Processing failed')
                                    : (video.stageMessage ?? 'Ready to practice'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isFailed
                                      ? colorScheme.error
                                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFailed)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          tooltip: 'Retry',
                          onPressed: () => mediaLibraryService.retryProcessingTask(
                            video.taskId ?? video.id,
                            video.url,
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDeleteVideo(context, video, mediaLibraryService),
                      ),
                    ],
                  ),
                ],
              ),

              // Linear Progress Bar if processing
              if (isProcessing) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: video.effectiveProgress / 100.0,
                    minHeight: 3,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
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

          // My Content — one merged section instead of three separately
          // headed strips (Continue Learning / Transcribed Media /
          // Imported) that overlapped without a clear rule for which one a
          // given piece of content belonged in. Reading items (continue
          // learning + imports) share one horizontal strip since they're
          // the same card type; videos get their own strip right below
          // since they're a different shape, but under the same header.
          ..._buildMobileMyContentSection(context, mediaLibraryService),

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

  List<Widget> _buildMobileMyContentSection(BuildContext context, MediaLibraryService mediaLibraryService) {
    final readingItems = <Widget>[
      ..._continueLearningArticles.map(
        (a) => Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CompactArticleCard(article: a, onTap: () => _openReader(a)),
        ),
      ),
      ...mediaLibraryService.importedArticles.map(
        (a) => Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CompactArticleCard(
            article: a,
            onTap: () => _openReader(a),
            onDelete: () => _confirmDelete(context, a, mediaLibraryService),
          ),
        ),
      ),
    ];
    final videos = mediaLibraryService.processedVideos;

    if (readingItems.isEmpty && videos.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Text(
            'MY CONTENT',
            style: BooksModernist.body(size: 11, weight: FontWeight.w800, color: BooksModernist.accentDark),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Text(
              'Nothing here yet — import an article or video to get started.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'MY CONTENT',
              style: BooksModernist.body(size: 11, weight: FontWeight.w800, color: BooksModernist.accentDark),
            ),
            if (videos.isNotEmpty)
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TranscribedMediaGridScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'All Videos',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      if (readingItems.isNotEmpty)
        SizedBox(
          height: 150,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            children: readingItems,
          ),
        ),
      if (videos.isNotEmpty) ...[
        if (readingItems.isNotEmpty) const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            itemBuilder: (context, index) => _buildVideoCard(context, videos[index], mediaLibraryService),
          ),
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget _buildVideoCard(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = video.status == ProcessingStatus.completed;
    final isFailed = video.status == ProcessingStatus.failed;
    final isProcessing = !isCompleted && !isFailed;

    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFailed
              ? colorScheme.error.withValues(alpha: 0.4)
              : isProcessing
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isProcessing ? 1.0 : 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (isCompleted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(processedVideo: video)));
            } else if (isFailed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(video.errorMessage ?? 'Processing failed. Long-press to retry.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          onLongPress: () => _showMediaActionSheet(context, video, mediaLibraryService),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 16:9 Thumbnail with cues badge overlay
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: isFailed
                              ? colorScheme.error.withValues(alpha: 0.12)
                              : colorScheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      // Gradient overlay
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 32,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Top Right 3-Dots Action Button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _showMediaActionSheet(context, video, mediaLibraryService),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.more_vert_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Status / Cues badge at bottom
                      Positioned(
                        left: 6,
                        bottom: 4,
                        right: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.subtitles_rounded, size: 10, color: Colors.white),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${video.subtitles.length} cues',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    if (video.estimatedDurationLabel.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      const Text('•', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                      const SizedBox(width: 4),
                                      Text(
                                        video.estimatedDurationLabel,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            else if (isProcessing)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '${video.effectiveProgress}%',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: colorScheme.error.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'FAILED',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            if (isCompleted)
                              const Icon(Icons.play_circle_filled_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Details Padding
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title
                      Text(
                        video.effectiveTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                      ),

                      // Tags & Status Row
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (video.category != null && video.category!.trim().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                video.category!.trim().toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                          ],
                          Text(
                            isCompleted
                                ? (video.estimatedDurationLabel.isNotEmpty
                                    ? 'Ready • ${video.estimatedDurationLabel}'
                                    : 'Ready to learn')
                                : (video.stageMessage ?? video.statusShortLabel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isFailed ? colorScheme.error : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaActionSheet(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with thumbnail, title and URL
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 48,
                        height: 34,
                        child: CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: Colors.grey.shade800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.effectiveTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            video.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 4),

                // 1. Edit Title
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: const Icon(Icons.edit_outlined, size: 19),
                  title: const Text('Edit Title', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditTitleDialog(context, video, mediaLibraryService);
                  },
                ),

                // 2. Set Category
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: const Icon(Icons.label_outline_rounded, size: 19),
                  title: const Text('Set Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: video.category?.isNotEmpty == true
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            video.category!.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditCategoryDialog(context, video, mediaLibraryService);
                  },
                ),

                // 3. Copy Link
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: const Icon(Icons.copy_rounded, size: 19),
                  title: const Text('Copy Link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Clipboard.setData(ClipboardData(text: video.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard!'), duration: Duration(seconds: 2)),
                    );
                  },
                ),

                // 4. Submit URL Again / Re-process
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: Icon(Icons.refresh_rounded, size: 19, color: colorScheme.primary),
                  title: const Text('Submit URL Again', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    mediaLibraryService.submitMediaProcessingTaskInBackground(video.url);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Re-submitting media for processing...'), duration: Duration(seconds: 3)),
                    );
                  },
                ),

                // 5. Delete Lesson
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: Icon(Icons.delete_outline_rounded, size: 19, color: colorScheme.error),
                  title: Text('Delete Lesson', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.error)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDeleteVideo(context, video, mediaLibraryService);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditTitleDialog(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
    final controller = TextEditingController(text: video.effectiveTitle);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter lesson title',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            FilledButton(
              child: const Text('Save'),
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  mediaLibraryService.updateVideoDetails(video.id, title: newTitle);
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title updated!'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditCategoryDialog(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
    final defaultCategories = ['Conversation', 'Grammar', 'Vocabulary', 'Travel', 'Stories', 'News', 'Business', 'Pronunciation'];
    final controller = TextEditingController(text: video.category ?? '');

    // Extract recently created custom categories from all videos in user's library
    final recentCategories = <String>[];
    for (final v in mediaLibraryService.processedVideos) {
      final cat = v.category?.trim();
      if (cat != null && cat.isNotEmpty) {
        final formatted = cat.substring(0, 1).toUpperCase() + (cat.length > 1 ? cat.substring(1) : '');
        if (!recentCategories.any((c) => c.toLowerCase() == formatted.toLowerCase())) {
          recentCategories.add(formatted);
        }
      }
    }

    final remainingPresets = defaultCategories
        .where((preset) => !recentCategories.any((r) => r.toLowerCase() == preset.toLowerCase()))
        .toList();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final selected = controller.text.trim();
            return AlertDialog(
              title: const Text('Set Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recentCategories.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.history_rounded, size: 13, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          const Text('Recent Categories:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: recentCategories.map((cat) {
                          final isSelected = selected.toLowerCase() == cat.toLowerCase();
                          return ChoiceChip(
                            label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                            selected: isSelected,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                            onSelected: (val) {
                              setDialogState(() {
                                controller.text = val ? cat : '';
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Text('Preset Suggestions:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: remainingPresets.map((cat) {
                        final isSelected = selected.toLowerCase() == cat.toLowerCase();
                        return ChoiceChip(
                          label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                          selected: isSelected,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                          onSelected: (val) {
                            setDialogState(() {
                              controller.text = val ? cat : '';
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Or enter custom category',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                FilledButton(
                  child: const Text('Save'),
                  onPressed: () {
                    final newCategory = controller.text.trim();
                    mediaLibraryService.updateVideoDetails(video.id, category: newCategory);
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(newCategory.isNotEmpty ? 'Category set to $newCategory' : 'Category cleared'), duration: const Duration(seconds: 2)),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteVideo(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Transcribed Media'),
          content: Text('Are you sure you want to delete "${video.effectiveTitle}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                mediaLibraryService.deleteProcessedVideo(video.id);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
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
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(4.0),
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
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(4.0),
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
