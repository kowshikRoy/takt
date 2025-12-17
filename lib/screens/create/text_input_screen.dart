import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/article_model.dart';
import '../story_reader_screen.dart';

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({super.key});

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  void _createLesson() {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both title and content')),
      );
      return;
    }

    final newArticle = Article(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text,
      description: _contentController.text.substring(0, _contentController.text.length > 50 ? 50 : _contentController.text.length) + '...',
      level: 'Custom',
      date: DateTime.now(),
      imageUrl: 'assets/images/story_desert.png', // Use placeholder for now
      // Logic for providing full content needs to be handled in StoryReader
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => StoryReaderScreen(article: newArticle, customContent: _contentController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('New Lesson', style: TextStyle(color: AppTheme.textMainLight, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textMainLight),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Lesson Title',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Paste your German text here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _createLesson,
                style: ElevatedButton.styleFrom(
                   backgroundColor: AppTheme.primary,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Lesson', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
