import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/story.dart';

class StoryScreen extends StatefulWidget {
  final Story story;
  const StoryScreen({super.key, required this.story});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  // State for the interactive word tooltip
  bool _isTooltipVisible = false;
  String _selectedWord = '';
  String _selectedTranslation = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Stack(
        children: [
          // Content
          CustomScrollView(
            slivers: [
              _buildStickyHeader(context),
              SliverToBoxAdapter(child: _buildProgressBar(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 128), // pb-32 approx
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildTitleSection(context),
                    const SizedBox(height: 32),
                    _buildStoryContent(context),
                  ]),
                ),
              ),
            ],
          ),

          // Floating Action Button
          Positioned(
            bottom: 96, // Above bottom nav
            right: 24,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
                boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(234, 46, 51, 0.15), blurRadius: 20, spreadRadius: 0) // shadow-glow
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.translate_rounded, color: AppTheme.primary),
                onPressed: () {},
              ),
            ),
          ),
          
          // Tooltip Overlay
          if (_isTooltipVisible)
            Positioned(
              // Simple positioning for demo purposes
              top: MediaQuery.of(context).size.height / 2,
              left: 24,
              right: 24,
              child: _buildTooltipCard(context),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.backgroundLight.withValues(alpha: 0.95),
      elevation: 0,
       automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back Button
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textMainLight),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            // Title
            Column(
              children: [
                Text(
                  'LIBRARY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: AppTheme.textSubLight,
                  ),
                ),
                Text(
                  'Short Stories',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMainLight,
                  ),
                ),
              ],
            ),
            // Settings Button
             Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.text_fields_rounded, size: 24, color: AppTheme.textMainLight),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return Container(
      height: 4,
      width: double.infinity,
      color: Colors.grey[200], // bg-gray-200
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.32,
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(999)),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.story.difficulty.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.story.title,
            style: TextStyle(
              fontSize: 30, // text-3xl
              fontWeight: FontWeight.w800, // extrabold
              height: 1.1,
              color: AppTheme.textMainLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.story.englishTitle,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSubLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryContent(BuildContext context) {
    // This splits the content by vocab words to make them interactive.
    // This is a naive implementation. In a real app, we'd want more robust parsing.

    List<InlineSpan> spans = [];
    String remainingText = widget.story.content;

    // Sort keys by length desc to match longest first
    final vocabKeys = widget.story.vocabulary.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    // Simple matching loop - this is inefficient but works for small stories
    // Ideally we would use regex with all keys

    // For this demo, let's just make the whole text readable and only specific words clickable if we can find them
    // Or just parse the whole string

    // Simpler approach: Split by space and check if word exists in vocab
    // Note: this misses multi-word phrases and punctuation handling

    final words = widget.story.content.split(' ');

    for (var wordWithPunct in words) {
       // Extract the core word and surrounding punctuation using Regex
       // This regex captures: Group 1 (prefix punctuation), Group 2 (word), Group 3 (suffix punctuation)
       final match = RegExp(r'^([^\w\u00C0-\u00FF]*)([\w\u00C0-\u00FF]+)([^\w\u00C0-\u00FF]*)$').firstMatch(wordWithPunct);

       String prefix = '';
       String word = wordWithPunct;
       String suffix = '';

       if (match != null) {
         prefix = match.group(1) ?? '';
         word = match.group(2) ?? '';
         suffix = match.group(3) ?? '';
       } else {
         // Fallback if no match (e.g. only punctuation or strange chars)
         // Try to strip non-word chars for lookup
         word = wordWithPunct.replaceAll(RegExp(r'[^\w\s\u00C0-\u00FF]'), '');
       }

       // Check if there is a match in vocabulary
       String? translation = widget.story.vocabulary[word];

       if (prefix.isNotEmpty) {
          spans.add(TextSpan(text: prefix));
       }

       if (translation != null) {
         spans.add(
           WidgetSpan(
             alignment: PlaceholderAlignment.baseline,
             baseline: TextBaseline.alphabetic,
             child: GestureDetector(
               onTap: () {
                 setState(() {
                   _selectedWord = word;
                   _selectedTranslation = translation;
                   _isTooltipVisible = true;
                 });
               },
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                 decoration: BoxDecoration(
                   color: (_isTooltipVisible && _selectedWord == word) ? AppTheme.primary.withValues(alpha: 0.1) : null,
                   borderRadius: BorderRadius.circular(4),
                   border: Border(bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4), width: 2, style: BorderStyle.solid)),
                 ),
                 child: Text(
                   word,
                     style: TextStyle(
                       fontSize: 20,
                       fontWeight: FontWeight.w600,
                       color: AppTheme.primary,
                     ),
                 ),
               ),
             ),
           )
         );
       } else {
         spans.add(TextSpan(text: word));
       }

       if (suffix.isNotEmpty) {
          spans.add(TextSpan(text: suffix));
       }

       spans.add(const TextSpan(text: ' '));
    }

    return RichText(
      text: TextSpan(
         style: TextStyle(
            fontSize: 20,
            height: 1.6,
            color: AppTheme.textMainLight,
         ),
         children: spans,
      ),
    );
  }


  Widget _buildTooltipCard(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: const [
             BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.1), blurRadius: 20, offset: Offset(0, 10))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        _selectedWord,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMainLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _isTooltipVisible = false;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedTranslation,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSubLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                         setState(() {
                           _isTooltipVisible = false;
                         });
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Vocabulary!')));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        elevation: 4,
                        shadowColor: AppTheme.primary.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.playlist_add_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Add to Vocabulary',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
}
