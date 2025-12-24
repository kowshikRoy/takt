import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lesson_service.dart';
import '../theme/app_theme.dart';
import '../models/article_model.dart';
import '../widgets/article_card.dart';
import '../widgets/section_header.dart';
import '../widgets/compact_article_card.dart';
import 'story_reader_screen.dart';
import 'create/text_input_screen.dart';
import 'create/url_import_screen.dart';


class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  // Filter state removed

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
      imageUrl: 'assets/images/story_desert.png', // Reusing placeholder
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


  @override
  Widget build(BuildContext context) {
    final lessonService = Provider.of<LessonService>(context);
    final importedArticles = lessonService.importedArticles;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptions(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16), 

              // Continue Learning Section
              SectionHeader(title: 'Continue Learning', onViewAll: () {}),
              SizedBox(
                height: 150, // Card height + padding
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

              // Imported Section
              SectionHeader(title: 'Imported', onViewAll: () {}),
               SizedBox(
                height: 150,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: importedArticles.length,
                  itemBuilder: (context, index) {
                    return CompactArticleCard(
                      article: importedArticles[index],
                      onTap: () => _openReader(importedArticles[index]),
                    );
                  },
                ),
              ),


              // New Stories Section
              SectionHeader(title: 'New Stories'),
              // _buildFilters() removed
              ListView.separated(
                padding: const EdgeInsets.all(20),
                shrinkWrap: true, // Needed inside SingleChildScrollView
                physics: const NeverScrollableScrollPhysics(), // Disable internal scrolling
                itemCount: _articles.length,
                separatorBuilder: (context, index) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final article = _articles[index];
                  return ArticleCard(
                    article: article,
                    onTap: () => _openReader(article),
                  );
                },
              ),
              
              const SizedBox(height: 80), // Bottom padding for FAB
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




  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Lesson',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.paste_rounded, color: Colors.blue),
                ),
                title: Text('Paste Text', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text('Create from clipboard', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(context); // Close modal
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TextInputScreen()));
                },
              ),
              ListTile(
                leading: Container(
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(8)),
                   child: const Icon(Icons.link_rounded, color: Colors.purple),
                ),
                title: Text('Web Article', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text('Import from URL', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(context); // Close modal
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UrlImportScreen()));
                },
              ),
              ListTile(
                 leading: Container(
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                   child: const Icon(Icons.upload_file_rounded, color: Colors.orange),
                ),
                title: Text('Upload PDF', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text('Import from file (Coming Soon)', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                onTap: () {}, 
                 enabled: false,
              ),
            ],
          ),
        );
      },
    );
  }
}
