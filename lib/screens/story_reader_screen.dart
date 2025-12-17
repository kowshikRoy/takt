import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';

import '../models/article_model.dart';

class StoryReaderScreen extends StatefulWidget {
  final Article? article;
  final String? customContent;

  const StoryReaderScreen({super.key, this.article, this.customContent});

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  final DictionaryService _dictionaryService = DictionaryService();
  final VocabularyService _vocabularyService = VocabularyService();
  Map<String, String> _wordGenders = {};
  bool _isLoadingGenders = true;

  @override
  void initState() {
    super.initState();
    _loadWordGenders();
  }

  Future<void> _loadWordGenders() async {
      // Collect all words from static content (and custom if needed)
      // For MVP, we'll just extract from the hardcoded strings we know are there or simple split
      // Ideally this should be dynamic based on the article content
      
      List<String> textChunks = [];
      if (widget.customContent != null) {
          textChunks.add(widget.customContent!);
      } else {
          // Add the static content pieces
          textChunks.add('Es war ein kalter, nebliger Morgen. Hannah stand vor dem alten Haus ihrer Großmutter. Die Fenster waren dunkel und das Tor quietschte im Wind. Sie hatte Angst, aber sie musste hineingehen.');
          textChunks.add('Langsam öffnete sie die schwere Eichentür. Der Flur roch nach Staub und alten Büchern. Auf dem kleinen Tisch im Flur lag etwas Glänzendes.');
          textChunks.add('Hannah ging näher heran. Es war ein kleiner, goldener Schmetterling aus Metall.');
          textChunks.add('"Warum liegt das hier?", flüsterte sie. Plötzlich hörte sie ein Geräusch aus dem ersten Stock. War sie wirklich allein?');
          textChunks.add('Ihr Herz klopfte schneller. Sie nahm den Gegenstand und steckte ihn in ihre Tasche.');
      }

      Set<String> allWords = {};
      for (var chunk in textChunks) {
          // Split by non-word chars roughly
          chunk.split(RegExp(r'[^\wäöüÄÖÜß]+')).forEach((w) {
              if (w.isNotEmpty) allWords.add(w);
          });
      }

      final genders = await _dictionaryService.getGendersForWords(allWords.toList());
      
      if (mounted) {
          setState(() {
              _wordGenders = genders;
              _isLoadingGenders = false;
          });
      }
  }

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
                onPressed: () => Navigator.of(context).pop(), 
              ),
            ),
            // Title

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
      return _buildInteractiveParagraph(context, widget.customContent!);
    }
    
    // Fallback to static content if no custom content provided (existing logic)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Im alten Haus', Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        _buildInteractiveParagraph(
          context,
          'Es war ein kalter, nebliger Morgen. Hannah stand vor dem alten Haus ihrer Großmutter. Die Fenster waren dunkel und das Tor quietschte im Wind. Sie hatte Angst, aber sie musste hineingehen.'
        ),
        const SizedBox(height: 32),
        
        _buildInteractiveParagraph(
          context,
          'Langsam öffnete sie die schwere Eichentür. Der Flur roch nach Staub und alten Büchern. Auf dem kleinen Tisch im Flur lag etwas Glänzendes.'
        ),
        const SizedBox(height: 32),
        
        _buildInteractiveParagraph(
           context,
           'Hannah ging näher heran. Es war ein kleiner, goldener Schmetterling aus Metall.'
        ),

        const SizedBox(height: 40),
        
         _buildSectionTitle(context, 'Das Geheimnis', const Color(0xFFFF9F43)), // secondary
         const SizedBox(height: 12),
         _buildInteractiveParagraph(
           context,
           '"Warum liegt das hier?", flüsterte sie. Plötzlich hörte sie ein Geräusch aus dem ersten Stock. War sie wirklich allein?'
         ),
         const SizedBox(height: 16),
         _buildInteractiveParagraph(
           context,
           'Ihr Herz klopfte schneller. Sie nahm den Gegenstand und steckte ihn in ihre Tasche.'
         ),
         
         const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInteractiveParagraph(BuildContext context, String text) {
    // Basic tokenization by space to separate words
    // We also want to handle punctuation attached to words without breaking the lookup
    List<String> rawTokens = text.split(' ');
    List<InlineSpan> spans = [];

    for (int i = 0; i < rawTokens.length; i++) {
        String token = rawTokens[i];
        
        // Simple regex to separate punctuation from the word
        // Matches: (prefix punctuation?)(word)(suffix punctuation?)
        final match = RegExp(r'^([^\wäöüÄÖÜß]*)([\wäöüÄÖÜß]+)([^\wäöüÄÖÜß]*)$').firstMatch(token);

        if (match != null) {
            String prefix = match.group(1) ?? '';
            String word = match.group(2) ?? '';
            String suffix = match.group(3) ?? '';

            if (prefix.isNotEmpty) {
                spans.add(TextSpan(text: prefix));
            }

            Color wordColor = Theme.of(context).colorScheme.onSurface;
            FontWeight wordWeight = FontWeight.normal;
            
            // Gender coloring logic
            if (!_isLoadingGenders) {
                // Try exact match first, then lowercase
                String? gender = _wordGenders[word] ?? _wordGenders[word.toLowerCase()];
                if (gender != null) {
                    wordWeight = FontWeight.w500; // make slightly bolder
                    if (gender.toLowerCase() == 'm' || gender.toLowerCase() == 'masc') {
                        wordColor = AppTheme.genderMasc;
                    } else if (gender.toLowerCase() == 'f' || gender.toLowerCase() == 'fem') {
                        wordColor = AppTheme.genderFem;
                    } else if (gender.toLowerCase() == 'n' || gender.toLowerCase() == 'neu') {
                        wordColor = AppTheme.genderNeu;
                    }
                }
            }

            spans.add(
              TextSpan(
                text: word,
                style: TextStyle(
                  color: wordColor,
                  fontWeight: wordWeight,
                //   decoration: TextDecoration.underline,
                //   decorationStyle: TextDecorationStyle.dotted,
                //   decorationColor: Colors.grey,
                ),
                recognizer: TapGestureRecognizer()..onTapUp = (details) {
                    _handleWordTap(word, details.globalPosition);
                },
              )
            );

            if (suffix.isNotEmpty) {
                spans.add(TextSpan(text: suffix));
            }
        } else {
            // Fallback for complex tokens or just whitespace/symbols
            spans.add(TextSpan(text: token));
        }

        // Add space back unless it's the last word
        if (i < rawTokens.length - 1) {
            spans.add(const TextSpan(text: ' '));
        }
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 20, // text-xl
          height: 1.6, // leading-9
          color: Theme.of(context).colorScheme.onSurface,
          // fontFamily: GoogleFonts.outfit().fontFamily, // Removed to match app theme (Spline Sans)
        ),
        children: spans,
      ),
    );
  }

  void _handleWordTap(String word, Offset tapPosition) async {
      print("DEBUG: Tapped word: '$word' at $tapPosition");
      // Show loading or immediate feedback?
      // For now, let's just query
      final details = await _dictionaryService.lookupWord(word);
      
      if (!mounted) return;

      if (details != null) {
          _showContextualPopup(context, word, details, tapPosition);
      } else {
        // Optional: Show "Word not found" toast or similar if needed.
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No definition found for "$word"'), duration: const Duration(milliseconds: 500)),
        );
      }
  }

  void _showContextualPopup(BuildContext context, String word, Map<String, dynamic> details, Offset tapPosition) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.1), // Subtle dimming
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
         return StatefulBuilder(
           builder: (context, setPopupState) {
              return Stack(
                children: [
                   FutureBuilder<bool>(
                      future: _vocabularyService.isWordSaved(word),
                      builder: (context, snapshot) {
                        final isSaved = snapshot.data ?? false;
                        
                        // Calculate position
                        final screenHeight = MediaQuery.of(context).size.height;
                        final screenWidth = MediaQuery.of(context).size.width;
                        final isTopHalf = tapPosition.dy < screenHeight / 2;
                        
                        // Add some margin from edges
                        const horizontalMargin = 16.0;
                        const cardWidth = 300.0; // Fixed width for popup usually better or clamp
                        
                        // Clamp horizontal position to keep on screen
                        // Simple approach: Center horizontally or use tap X but clamp
                        // Let's Center horizontally for better mobile UX on small screens, OR
                        // try to align with tap but clamp.
                        // "Contextual" usually implies near the tap.
                        
                        // Let's try centering heavily but constrained, or clamp x centered on tap.
                        double left = tapPosition.dx - (screenWidth - 2 * horizontalMargin) / 2;
                         // Actually, standard "tooltip" style usually centers on screen or clamps. 
                         // Let's just use a Card that is horizontally centered with margins, 
                         // but vertically positioned near tap.
                         
                         double top;
                         double? bottom;
                         
                         if (isTopHalf) {
                             top = tapPosition.dy + 20; // Show below
                             bottom = null;
                         } else {
                             bottom = screenHeight - tapPosition.dy + 20; // Show above
                             top = 0; // ignored if using bottom
                         }
                         
                         // Calculate max available height
                         double availableHeight;
                         if (isTopHalf) {
                           availableHeight = screenHeight - top! - 32; // Bottom margin padding
                         } else {
                           availableHeight = screenHeight - bottom! - 32; // Top margin padding (approx)
                              // Actually if bottom is set, top of box is at (screenHeight - bottom - height).
                              // Max height is (screenHeight - bottom - safeAreaTop).
                              // Let's just say max 50% of screen or available space.
                              availableHeight = tapPosition.dy - 60; // Space above tap
                         }
                         
                        return Stack(
                          children: [
                            Positioned(
                              top: isTopHalf ? tapPosition.dy : null, // Start AT tap for arrow
                              bottom: !isTopHalf ? (screenHeight - tapPosition.dy) : null,
                              left: horizontalMargin,
                              right: horizontalMargin,
                              child: Material(
                                color: Colors.transparent,
                                child: CustomPaint(
                                  painter: TooltipShapePainter(
                                    color: Theme.of(context).cardColor,
                                    isTop: isTopHalf,
                                    arrowX: tapPosition.dx - horizontalMargin,
                                  ),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxHeight: availableHeight > 400 ? 400 : availableHeight,
                                    ),
                                    // Add extra padding for the arrow area
                                    padding: EdgeInsets.only(
                                        left: 20, 
                                        right: 20, 
                                        top: isTopHalf ? 16 + 12.0 : 16, // Arrow is top
                                        bottom: !isTopHalf ? 16 + 12.0 : 16 // Arrow is bottom
                                    ),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                           Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        details['word'] ?? word,
                                                        style: TextStyle(
                                                          fontSize: 22, // Compact Title
                                                          fontWeight: FontWeight.bold,
                                                          color: Theme.of(context).colorScheme.onSurface,
                                                          height: 1.2,
                                                        ),
                                                      ),
                                                      if (details['pos'] != null)
                                                       Container(
                                                        margin: const EdgeInsets.only(left: 8),
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          details['pos'],
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Theme.of(context).colorScheme.primary,
                                                          ),
                                                        ),
                                                      ),
                                                      if (details['gender'] != null && details['gender'].toString().isNotEmpty)
                                                        Builder(
                                                          builder: (context) {
                                                            final gender = details['gender'].toString().toLowerCase();
                                                            Color badgeColor;
                                                            if (gender.contains('masc')) {
                                                              badgeColor = Colors.blue;
                                                            } else if (gender.contains('fem')) {
                                                              badgeColor = Colors.red;
                                                            } else if (gender.contains('neut')) {
                                                              badgeColor = Colors.green;
                                                            } else {
                                                              badgeColor = Colors.grey;
                                                            }

                                                            return Container(
                                                              margin: const EdgeInsets.only(left: 6),
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: badgeColor.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                details['gender'],
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: badgeColor,
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        ),
                                                    ],
                                                  ),
                                                  if (details['base_form'] != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0),
                                                      child: Text(
                                                        'Base form: ${details['base_form']}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontStyle: FontStyle.italic,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.volume_up_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                             onPressed: () {
                                               // TTS placeholder
                                             },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Definitions',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          letterSpacing: 0.5, 
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (details['definitions'] != null)
                                         ...((details['definitions'] as List).map((def) => Padding(
                                           padding: const EdgeInsets.only(bottom: 6.0),
                                           child: Text(
                                             '• $def',
                                             style: TextStyle(
                                               fontSize: 15,
                                               height: 1.3,
                                               color: Theme.of(context).colorScheme.onSurface,
                                             ),
                                           ),
                                         )).toList())
                                      else
                                          const Text('No definition available'),

                                      const SizedBox(height: 20),
                                      
                                      SizedBox(
                                        width: double.infinity,
                                        height: 44, // Compact Button
                                        child: ElevatedButton(
                                          onPressed: () async {
                                              if (isSaved) {
                                                await _vocabularyService.removeWord(word);
                                              } else {
                                                await _vocabularyService.saveWord(word);
                                              }
                                              setPopupState(() {}); // Refresh local popup state
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isSaved ? Theme.of(context).cardColor : Theme.of(context).colorScheme.primary,
                                            elevation: 0,
                                            side: isSaved ? BorderSide(color: Theme.of(context).dividerColor) : null,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                isSaved ? Icons.check_circle_rounded : Icons.playlist_add_rounded,
                                                color: isSaved ? Theme.of(context).colorScheme.primary : Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                isSaved ? 'Saved to Vocabulary' : 'Add to Vocabulary',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSaved ? Theme.of(context).colorScheme.primary : Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4), 
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                          ],
                        );
                      }
                  )
                ]
              );
           }
         );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: child, // Simple fade, could add ScaleTransition from tap point
        );
      },
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
}

class TooltipShapePainter extends CustomPainter {
  final Color color;
  final bool isTop; // If true, arrow points up (popup is below tap). Else points down.
  final double arrowX; // X offset within the popup logic coordinates
  final double arrowSize;
  final double radius;

  TooltipShapePainter({
    required this.color,
    required this.isTop,
    required this.arrowX,
    this.arrowSize = 12.0,
    this.radius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // We can draw shadow too if we want, but Container shadow is easier if we match shape.
    // For CustomPainter, shadow is manual.
    // Let's rely on standard box shadow for the main box if we can, but simpler:
    // Draw the whole shape with shadow.
    
    final path = Path();
    final width = size.width;
    final height = size.height;
    
    // The "box" part starts at y=arrowSize if isTop, else at y=0.
    final boxTop = isTop ? arrowSize : 0.0;
    final boxBottom = isTop ? height : height - arrowSize;
    
    // Clamp arrowX to be within safe bounds (radius + arrow width)
    final safeArrowX = arrowX.clamp(radius + arrowSize, width - radius - arrowSize);

    // Start top-left
    path.moveTo(radius, boxTop);
    
    if (isTop) {
       // Top Line with Arrow pointing UP
       // We are moving clockwise from Top-Left
       
       // Top Left Corner
       path.quadraticBezierTo(0, boxTop, 0, boxTop + radius);
       
       // Left Wall
       path.lineTo(0, boxBottom - radius);
       
       // Bottom Left Corner
       path.quadraticBezierTo(0, boxBottom, radius, boxBottom);
       
       // Bottom Wall
       path.lineTo(width - radius, boxBottom);
       
       // Bottom Right Corner
       path.quadraticBezierTo(width, boxBottom, width, boxBottom - radius);
       
       // Right Wall
       path.lineTo(width, boxTop + radius);
       
       // Top Right Corner
       path.quadraticBezierTo(width, boxTop, width - radius, boxTop);
       
       // Top Wall back to arrow
       path.lineTo(safeArrowX + arrowSize / 1.5, boxTop);
       path.lineTo(safeArrowX, 0); // Tip
       path.lineTo(safeArrowX - arrowSize / 1.5, boxTop);
       
       path.close();
    } else {
       // Arrow pointing DOWN (at the bottom)
       
       // Top Left Corner
       path.quadraticBezierTo(0, boxTop, 0, boxTop + radius);
       
       // Left Wall
       path.lineTo(0, boxBottom - radius);
       
       // Bottom Left Corner
       path.quadraticBezierTo(0, boxBottom, radius, boxBottom);
       
        // Bottom Wall with Arrow
       path.lineTo(safeArrowX - arrowSize / 1.5, boxBottom);
       path.lineTo(safeArrowX, height); // Tip
       path.lineTo(safeArrowX + arrowSize / 1.5, boxBottom);
       
       path.lineTo(width - radius, boxBottom);
       
       // Bottom Right Corner
       path.quadraticBezierTo(width, boxBottom, width, boxBottom - radius);
       
       // Right Wall
       path.lineTo(width, boxTop + radius);
       
       // Top Right Corner
       path.quadraticBezierTo(width, boxTop, width - radius, boxTop);
       
       path.close();
    }
    
    canvas.drawShadow(path, Colors.black.withOpacity(0.2), 6.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

