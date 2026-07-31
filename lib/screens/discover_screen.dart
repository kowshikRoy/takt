import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lesson_service.dart';
import '../models/article_model.dart';
import '../models/processed_video.dart';
import '../models/processing_status.dart';
import '../widgets/article_card.dart';
import '../widgets/section_header.dart';
import '../widgets/compact_article_card.dart';
import 'story_reader_screen.dart';
import 'video_screen.dart';
import 'create/text_input_screen.dart';
import 'create/url_import_screen.dart';

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
      title: 'Die Berliner Mauer',
      description: '',
      level: 'B1',
      date: DateTime.now(),
      imageUrl: 'assets/images/story_desert.png',
    ),
    Article(
      id: 'cl2',
      title: 'Kaffee im Büro',
      description: '',
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
    final lessonService = Provider.of<LessonService>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptions(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 700;
            return isDesktop
                ? _buildDesktopLayout(context, lessonService)
                : _buildMobileLayout(context, lessonService);
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, LessonService lessonService) {
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
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Import', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Continue Learning Section
                Text(
                  'Continue Learning',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _continueLearningArticles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final article = _continueLearningArticles[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
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
                if (lessonService.importedArticles.isNotEmpty) ...[
                  Text(
                    'Your Imports',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: lessonService.importedArticles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final article = lessonService.importedArticles[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          title: Text(article.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(article.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _confirmDelete(context, article, lessonService),
                          ),
                          onTap: () => _openReader(article),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Transcribed Media
                if (lessonService.processedVideos.isNotEmpty) ...[
                  Text(
                    'Transcribed Media',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: lessonService.processedVideos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final video = lessonService.processedVideos[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.video_library_rounded, color: Colors.teal),
                          title: Text(video.effectiveTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(video.status.name, style: const TextStyle(fontSize: 11)),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _levels.map((level) {
          final isSelected = _selectedLevel == level;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: FilterChip(
              label: Text(level),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedLevel = level;
                });
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, LessonService lessonService) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Continue Learning Section
          SectionHeader(title: 'Continue Learning', onViewAll: () {}),
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
          if (lessonService.processedVideos.isNotEmpty) ...[
            SectionHeader(title: 'Transcribed Media'),
            SizedBox(
              height: 220,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: lessonService.processedVideos.length,
                itemBuilder: (context, index) {
                  final video = lessonService.processedVideos[index];
                  return _buildVideoCard(context, video, lessonService);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Imported Section
          if (lessonService.importedArticles.isNotEmpty) ...[
            SectionHeader(title: 'Imported', onViewAll: () {}),
            SizedBox(
              height: 150,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: lessonService.importedArticles.length,
                itemBuilder: (context, index) {
                  final article = lessonService.importedArticles[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: CompactArticleCard(
                      article: article,
                      onTap: () => _openReader(article),
                      onDelete: () => _confirmDelete(context, article, lessonService),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // New Stories Section Header & Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New Stories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildVideoCard(BuildContext context, ProcessedVideo video, LessonService lessonService) {
    final isCompleted = video.status == ProcessingStatus.completed;
    final isFailed = video.status == ProcessingStatus.failed;
    final isProcessing = !isCompleted && !isFailed;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade800),
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

  void _confirmDelete(BuildContext context, Article article, LessonService lessonService) {
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
              child: const TextStyle(color: Colors.red) != null
                  ? const Text('Delete', style: TextStyle(color: Colors.red))
                  : const Text('Delete'),
              onPressed: () {
                lessonService.deleteImportedArticle(article.id);
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create & Import',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Colors.blue),
              title: const Text('Import Web Article or YouTube Video'),
              subtitle: const Text('Enter a URL to process and auto-generate transcript'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UrlImportScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded, color: Colors.green),
              title: const Text('Paste Custom Text'),
              subtitle: const Text('Add your own German text to practice'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TextInputScreen()));
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      _isShowingSheet = false;
    });
  }
}
