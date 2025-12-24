import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/article_model.dart';
import '../story_reader_screen.dart';
import '../../services/lesson_service.dart';
import '../../services/backend_service.dart';

class UrlImportScreen extends StatefulWidget {
  const UrlImportScreen({super.key});

  @override
  State<UrlImportScreen> createState() => _UrlImportScreenState();
}

class _UrlImportScreenState extends State<UrlImportScreen> {
  final TextEditingController _urlController = TextEditingController();
  final BackendService _backendService = BackendService();
  bool _isLoading = false;
  String? _errorMessage;

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  void _importFromUrl() async {
    final url = _urlController.text.trim();
    
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL';
      });
      return;
    }

    if (!_isValidUrl(url)) {
      setState(() {
        _errorMessage = 'Please enter a valid HTTP or HTTPS URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _backendService.importFromUrl(url);

      if (!mounted) return;

      if (result == null || result.containsKey('error')) {
        setState(() {
          _errorMessage = result?['error'] ?? 'Failed to import content';
          _isLoading = false;
        });
        return;
      }

      // Successfully imported
      final title = result['title'] as String;
      final content = result['content'] as String;
      final description = result['description'] as String;
      final wasTranslated = result['was_translated'] as bool? ?? false;
      final originalLanguage = result['original_language'] as String? ?? 'unknown';

      final newArticle = Article(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: description,
        level: 'Imported',
        date: DateTime.now(),
        imageUrl: 'assets/images/story_soccer.png',
      );

      final lessonService = Provider.of<LessonService>(context, listen: false);
      await lessonService.addImportedArticle(newArticle, content);

      if (mounted) {
        // Show translation notification if content was translated
        if (wasTranslated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Content translated from ${originalLanguage.toUpperCase()} to German'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StoryReaderScreen(article: newArticle),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Import from URL',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the URL of any article, blog post, or story. English content will be automatically translated to German.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'https://example.com/article',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              keyboardType: TextInputType.url,
              enabled: !_isLoading,
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const LinearProgressIndicator(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _importFromUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Import',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tips',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Works best with article-style pages\n'
                    '• English content will be auto-translated to German\n'
                    '• Try German news sites like Deutsche Welle\n'
                    '• Some websites may block content extraction',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
