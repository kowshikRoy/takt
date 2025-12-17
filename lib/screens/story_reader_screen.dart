import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

import '../models/article_model.dart';

class StoryReaderScreen extends StatefulWidget {
  final Article? article;
  final String? customContent;

  const StoryReaderScreen({super.key, this.article, this.customContent});

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  // State for the interactive word tooltip
  bool _isTooltipVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 0) // shadow-glow
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.translate_rounded,
                    color: Theme.of(context).colorScheme.primary),
                onPressed: () {},
              ),
            ),
          ),

          // Tooltip Overlay (Custom implementation for simplicity without OverlayEntry complexity for this demo)
          if (_isTooltipVisible)
            Positioned(
              // Position relative to the screen, hardcoded estimate from "Schmetterling" position or dynamic if needed.
              // For a robust implementation, we'd use CompositedTransformTarget, but here we can try a Stack alignment or just center/fixed for the demo since it's a specific "Mock" from HTML.
              // However, since it points to "Schmetterling", let's make it look right.
              // I'll wrap the word in a widget that updates the position or just position it near the text.
              // Let's assume the text is roughly in the middle.
              top: 350,
              left: 24,
              right: 24, // width constraint
              child: _buildTooltipCard(context),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
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
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () {}, // No-op or pop
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Short Stories',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            // Settings Button
             Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(Icons.brightness_6_rounded, // Changed icon to represent theme toggle better
                    size: 24, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () {
                  Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                },
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
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3), // bg-gray-200 equivalentish
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.32,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(999)),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.article?.level ?? 'KAPITEL 3',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.article?.title ?? 'Der verlorene Schlüssel',
            style: TextStyle(
              fontSize: 30, // text-3xl
              fontWeight: FontWeight.w800, // extrabold
              height: 1.1,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.article != null ? '' : 'The Lost Key', // Hide subtitle for custom articles for now
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryContent(BuildContext context) {
    if (widget.customContent != null) {
      return _buildParagraph(context, widget.customContent!);
    }
    
    // Fallback to static content if no custom content provided (existing logic)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Im alten Haus', Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        _buildParagraph(
          context,
          'Es war ein kalter, nebliger Morgen. Hannah stand vor dem alten Haus ihrer Großmutter. Die Fenster waren dunkel und das Tor quietschte im Wind. Sie hatte Angst, aber sie musste hineingehen.'
        ),
        const SizedBox(height: 32),
        
        _buildParagraph(
          context,
          'Langsam öffnete sie die schwere Eichentür. Der Flur roch nach Staub und alten Büchern. Auf dem kleinen Tisch im Flur lag etwas Glänzendes.'
        ),
        const SizedBox(height: 32),
        
        // Interactive Paragraph
        RichText(
          text: TextSpan(
             style: TextStyle(
                fontSize: 20, // text-xl
                height: 1.6, // leading-9 approx
                color: Theme.of(context).colorScheme.onSurface,
             ),
             children: [
               const TextSpan(text: 'Hannah ging näher heran. Es war ein kleiner, goldener '),
               WidgetSpan(
                 alignment: PlaceholderAlignment.baseline,
                 baseline: TextBaseline.alphabetic,
                 child: GestureDetector(
                   onTap: () {
                     setState(() {
                       _isTooltipVisible = !_isTooltipVisible;
                       // Hack to make sure we don't float forever if this moves
                     });
                   },
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                     decoration: BoxDecoration(
                       color: _isTooltipVisible ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : null,
                       borderRadius: BorderRadius.circular(4),
                       border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4), width: 2, style: BorderStyle.solid)), 
                     ),
                     child: Text(
                       'Schmetterling',
                         style: TextStyle(
                           fontSize: 20,
                           fontWeight: FontWeight.w600,
                           color: Theme.of(context).colorScheme.primary,
                         ),
                     ),
                   ),
                 ),
               ),
               const TextSpan(text: ' aus Metall.'),
             ]
          ),
        ),

        const SizedBox(height: 40),
        
         _buildSectionTitle(context, 'Das Geheimnis', const Color(0xFFFF9F43)), // secondary
         const SizedBox(height: 12),
         _buildParagraph(
           context,
           '"Warum liegt das hier?", flüsterte sie. Plötzlich hörte sie ein Geräusch aus dem ersten Stock. War sie wirklich allein?'
         ),
         const SizedBox(height: 16),
         _buildParagraph(
           context,
           'Ihr Herz klopfte schneller. Sie nahm den Gegenstand und steckte ihn in ihre Tasche.'
         ),
         
         const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 20, // text-xl
        height: 1.6, // leading-9
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color dotColor) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTooltipCard(BuildContext context) {
    return Center(
      child: Container(
        width: 280, // w-64 approx
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
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
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Schmetterling',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Masc',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.volume_up_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onPressed: () {},
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
                    '(noun) Butterfly',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        elevation: 4,
                        shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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

