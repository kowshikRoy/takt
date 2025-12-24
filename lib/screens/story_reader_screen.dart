import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import '../services/lesson_service.dart';
import '../services/backend_service.dart';
import '../services/tts_service.dart';

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
  final TtsService _ttsService = TtsService();
  Map<String, String> _wordGenders = {};
  Map<int, Map<String, dynamic>> _paragraphAnalysisData = {}; // index -> {analysis, translation}
  bool _isLoadingGenders = true;
  bool _isLoadingAnalysis = false;
  String? _loadedContent;
  TtsProgress? _currentTtsProgress;
  StreamSubscription? _ttsSubscription;
  final Set<int> _visibleParagraphTranslations = {};

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (widget.customContent != null) {
      _loadedContent = widget.customContent;
    } else if (widget.article != null && widget.article!.id.startsWith('custom_')) {
      final lessonService = Provider.of<LessonService>(context, listen: false);
      _loadedContent = await lessonService.getCustomContent(widget.article!.id);
      if (mounted) setState(() {});
    }

    _loadWordGenders();
    _fetchContextualAnalysis();
    _ttsSubscription = _ttsService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentTtsProgress = progress;
        });
      }
    });
  }

  @override
  void dispose() {
    _ttsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchContextualAnalysis() async {
    setState(() {
      _isLoadingAnalysis = true;
      _paragraphAnalysisData = {}; // Clear existing data
    });

    String contentToProcess = _loadedContent ?? 
      'Es war ein kalter, nebliger Morgen. Hannah stand vor dem alten Haus ihrer Großmutter. Die Fenster waren dunkel und das Tor quietschte im Wind. Sie hatte Angst, aber sie musste hineingehen.\n\n'
      'Langsam öffnete sie die schwere Eichentür. Der Flur roch nach Staub und alten Büchern. Auf dem kleinen Tisch im Flur lag etwas Glänzendes.\n\n'
      'Hannah ging näher heran. Es war ein kleiner, goldener Schmetterling aus Metall.\n\n'
      '"Warum liegt das hier?", flüsterte sie. Plötzlich hörte sie ein Geräusch aus dem ersten Stock. War sie wirklich allein?\n\n'
      'Ihr Herz klopfte schneller. Sie nahm den Gegenstand und steckte ihn in ihre Tasche.';

    try {
      final backend = BackendService();
      
      // Use streaming for progressive loading
      await for (var event in backend.processFullArticleStream(contentToProcess, lang: 'de')) {
        if (!mounted) break;
        
        final type = event['type'] as String?;
        
        if (type == 'metadata') {
          // Initial metadata received
          final totalParagraphs = event['total_paragraphs'] as int?;
          print('Starting to process $totalParagraphs paragraphs');
        } else if (type == 'paragraph') {
          // Paragraph processed - add to UI immediately
          final index = event['index'] as int;
          final original = event['original'] as String;
          final translation = event['translation'] as String? ?? '';
          final sourceLang = event['source_lang'] as String? ?? 'de';
          
          setState(() {
            _paragraphAnalysisData[index] = {
              'german_analysis': event['german_analysis'] ?? [],
              'german_text': sourceLang == 'en' ? translation : original,  // German text to display
              'original_text': original,  // Original text (for reference)
              'english_translation': sourceLang == 'de' ? translation : '',  // English translation if source was German
              'source_lang': sourceLang,
            };
          });
          print('Received paragraph $index');
        } else if (type == 'complete') {
          // All paragraphs processed
          if (mounted) {
            setState(() {
              _isLoadingAnalysis = false;
            });
          }
          print('Processing complete');
        } else if (type == 'error') {
          // Error occurred
          print('Stream error: ${event['error']}');
          if (mounted) {
            setState(() {
              _isLoadingAnalysis = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching contextual analysis: $e');
      if (mounted) {
        setState(() {
          _isLoadingAnalysis = false;
        });
      }
    }
  }

  Future<void> _loadWordGenders() async {
      // Collect all words from static content (and custom if needed)
      // For MVP, we'll just extract from the hardcoded strings we know are there or simple split
      // Ideally this should be dynamic based on the article content
      
      List<String> textChunks = [];
      if (_loadedContent != null) {
          textChunks.add(_loadedContent!);
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
              if (_isLoadingAnalysis)
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
              SliverToBoxAdapter(child: _buildProgressBar(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96), // pb-32 approx
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildTitleSection(context),
                    const SizedBox(height: 24),
                    _buildStoryContent(context),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
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
                onPressed: () => Navigator.pop(context),
              ),
            ),
            
            // Right Side Controls
            Row(
              children: [
                if (_isLoadingAnalysis)
                  const Padding(
                    padding: EdgeInsets.only(right: 12.0),
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                    ),
                  ),
                if (!_isLoadingAnalysis && _paragraphAnalysisData.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(right: 12.0),
                    child: Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                  ),
                IconButton(
                  icon: Icon(Icons.play_circle_fill_rounded, 
                      size: 28, color: Theme.of(context).colorScheme.primary),
                  onPressed: () {
                    // Collect all text from paragraphs
                    List<String> textChunks = [];
                    if (_loadedContent != null) {
                      textChunks = _loadedContent!.split(RegExp(r'\n\s*\n'));
                    } else {
                      textChunks = [
                        'Es war ein kalter, nebliger Morgen. Hannah stand vor dem alten Haus ihrer Großmutter. Die Fenster waren dunkel und das Tor quietschte im Wind. Sie hatte Angst, aber sie musste hineingehen.',
                        'Langsam öffnete sie die schwere Eichentür. Der Flur roch nach Staub und alten Büchern. Auf dem kleinen Tisch im Flur lag etwas Glänzendes.',
                        'Hannah ging näher heran. Es war ein kleiner, goldener Schmetterling aus Metall.',
                        '"Warum liegt das hier?", flüsterte sie. Plötzlich hörte sie ein Geräusch aus dem ersten Stock. War sie wirklich allein?',
                        'Ihr Herz klopfte schneller. Sie nahm den Gegenstand und steckte ihn in ihre Tasche.'
                      ];
                    }
                    _ttsService.speak(textChunks.join(' '));
                  },
                ),
                IconButton(
                  icon: Icon(Icons.stop_circle_rounded, 
                      size: 28, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  onPressed: () => _ttsService.stop(),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: IconButton(
                    icon: Icon(Icons.brightness_6_rounded, 
                        size: 24, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () {
                      Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                    },
                  ),
                ),
              ],
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
      padding: const EdgeInsets.only(bottom: 16),
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.article?.title ?? 'Der verlorene Schlüssel',
            style: TextStyle(
              fontSize: 24, // text-3xl
              fontWeight: FontWeight.w800, // extrabold
              height: 1.1,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.article != null ? '' : 'The Lost Key', // Hide subtitle for custom articles for now
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryContent(BuildContext context) {
    if (_loadedContent != null) {
      // Split loaded content into paragraphs assuming \n\n
      List<String> paragraphs = _loadedContent!.split(RegExp(r'\n\s*\n'));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(paragraphs.length, (index) {
          // Use German text from analysis if available, otherwise use original
          final germanText = _paragraphAnalysisData[index]?['german_text'] as String? ?? paragraphs[index];
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: _buildInteractiveParagraph(context, germanText, index),
          );
        }),
      );
    }
    
    // Static content case
    List<String> staticParagraphs = [
      'Es war ein kalter, nebliger Morgen. Hannah stand vor dem alten Haus ihrer Großmutter. Die Fenster waren dunkel und das Tor quietschte im Wind. Sie hatte Angst, aber sie musste hineingehen.',
      'Langsam öffnete sie die schwere Eichentür. Der Flur roch nach Staub und alten Büchern. Auf dem kleinen Tisch im Flur lag etwas Glänzendes.',
      'Hannah ging näher heran. Es war ein kleiner, goldener Schmetterling aus Metall.',
      '"Warum liegt das hier?", flüsterte sie. Plötzlich hörte sie ein Geräusch aus dem ersten Stock. War sie wirklich allein?',
      'Ihr Herz klopfte schneller. Sie nahm den Gegenstand und steckte ihn in ihre Tasche.'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Im alten Haus', Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        ...List.generate(staticParagraphs.length, (index) {
           return Column(
             children: [
               _buildInteractiveParagraph(context, staticParagraphs[index], index),
               const SizedBox(height: 24),
             ],
           );
        }),
      ],
    );
  }

  Widget _buildInteractiveParagraph(BuildContext context, String text, int index) {
    final englishTranslation = _paragraphAnalysisData[index]?['english_translation'] as String?;
    final isTranslationVisible = _visibleParagraphTranslations.contains(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                // Speaker icon
                InkWell(
                  onTap: () => _ttsService.speak(text),
                  child: Icon(Icons.volume_up_rounded, size: 18, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 8),
                // Translation toggle button
                IconButton(
                  onPressed: englishTranslation != null && englishTranslation.isNotEmpty ? () {
                    setState(() {
                      if (_visibleParagraphTranslations.contains(index)) {
                        _visibleParagraphTranslations.remove(index);
                      } else {
                        _visibleParagraphTranslations.add(index);
                      }
                    });
                  } : null,
                  icon: Icon(
                    isTranslationVisible ? Icons.translate_rounded : Icons.g_translate_rounded,
                    size: 16,
                    color: translation != null 
                        ? (isTranslationVisible ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withValues(alpha: 0.4))
                        : Colors.transparent,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      children: _buildParagraphSpans(context, text, index),
                    ),
                  ),
                  if (isTranslationVisible && translation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        translation,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<InlineSpan> _buildParagraphSpans(BuildContext context, String text, int paragraphIndex) {
    // Basic tokenization by space to separate words
    List<String> rawTokens = text.split(' ');
    List<InlineSpan> spans = [];
    int currentCharacterOffset = 0;
    
    final paragraphData = _paragraphAnalysisData[paragraphIndex];
    final paragraphTokens = (paragraphData?['german_analysis'] as List<dynamic>?) ?? [];
    int tokenSearchIndex = 0;
    
    if (paragraphTokens.isEmpty && !_isLoadingAnalysis) {
        print("DEBUG: No analysis found for paragraph $paragraphIndex");
    }

    for (int i = 0; i < rawTokens.length; i++) {
        String token = rawTokens[i];
        
        // Simple regex to separate punctuation from the word
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
            
            // CONTEXTUAL HIGHLIGHT (POS/GENDER)
            String? contextGender;
            String? contextPos;

            // Simple alignment heuristic: find the next matching word in analysis
            while (tokenSearchIndex < paragraphTokens.length) {
                final aToken = paragraphTokens[tokenSearchIndex];
                if (aToken['word'].toString().toLowerCase() == word.toLowerCase()) {
                    contextGender = aToken['gender'];
                    contextPos = aToken['pos'];
                    tokenSearchIndex++; // Move search forward
                    break;
                } else {
                    // Lookahead a bit or just break if distant?
                    // For now, if current analysis token doesn't match word, 
                    // it might be a token we skipped (puncts/spaces) or a mismatch.
                    // Let's just move one step to try and catch up if it's a skip.
                    tokenSearchIndex++;
                    if (tokenSearchIndex >= paragraphTokens.length) break;
                    // re-check
                    if (paragraphTokens[tokenSearchIndex]['word'].toString().toLowerCase() == word.toLowerCase()) {
                        contextGender = paragraphTokens[tokenSearchIndex]['gender'];
                        contextPos = paragraphTokens[tokenSearchIndex]['pos'];
                        tokenSearchIndex++;
                        break;
                    }
                }
            }

            // Word-level TTS highlighting
            bool isHighlighted = false;
            if (_currentTtsProgress != null && _currentTtsProgress!.text == text) {
                int wordStart = currentCharacterOffset + prefix.length;
                int wordEnd = wordStart + word.length;
                if (wordStart >= _currentTtsProgress!.start && wordEnd <= _currentTtsProgress!.end) {
                    isHighlighted = true;
                }
            }

            // Coloring based on context
            if (contextPos == 'noun') {
                String? finalGender = contextGender;
                
                // Fallback: If context knows it's a noun but no gender, check DB
                if (finalGender == null) {
                    finalGender = _wordGenders[word] ?? _wordGenders[word.toLowerCase()];
                }

                if (finalGender != null) {
                    wordWeight = FontWeight.bold; 
                    if (finalGender == 'm') wordColor = AppTheme.genderMasc;
                    else if (finalGender == 'f') wordColor = AppTheme.genderFem;
                    else if (finalGender == 'n') wordColor = AppTheme.genderNeu;
                }
            }

            spans.add(
              TextSpan(
                text: word,
                style: TextStyle(
                  color: isHighlighted ? Colors.white : wordColor,
                  fontWeight: wordWeight,
                  backgroundColor: isHighlighted 
                    ? Theme.of(context).colorScheme.primary 
                    : null,
                ),
                recognizer: TapGestureRecognizer()..onTapDown = (details) {
                    _handleWordTap(word, text, details.globalPosition, paragraphIndex);
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

        currentCharacterOffset += token.length;

        // Add space back unless it's the last word
        if (i < rawTokens.length - 1) {
            spans.add(const TextSpan(text: ' '));
            currentCharacterOffset += 1; // for the space
        }
    }
    return spans;
  }

  final BackendService _backendService = BackendService();

  void _handleWordTap(String word, String contextText, Offset tapPosition, int paragraphIndex) async {
      print("DEBUG: Tapped word: '$word' in paragraph $paragraphIndex at $tapPosition");
      
      // 1. Initial local lookup (fast) - fetch all possible POS versions
      var allPotentialDetails = await _dictionaryService.lookupWordAllPOS(word);
      
      if (!mounted) return;

      // 2. Check if we have cached analysis for this paragraph
      Future<Map<String, dynamic>?> backendFuture;
      if (_paragraphAnalysisData.containsKey(paragraphIndex)) {
        print("DEBUG: Using client-cached data for word lookup");
        backendFuture = Future.value(_paragraphAnalysisData[paragraphIndex]);
      } else {
        backendFuture = _backendService.processText(contextText, lang: 'de');
      }

      // Even if not in dict, we show popup (maybe vocab or just for backend translation)
      _showContextualPopup(context, word, contextText, allPotentialDetails, tapPosition, backendFuture);
  }

  void _showContextualPopup(BuildContext context, String word, String contextText, List<Map<String, dynamic>> allPotentialDetails, Offset tapPosition, Future<Map<String, dynamic>?> backendFuture) {
    bool isTranslationVisible = false; // Moved state variable here
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.1),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
          return StatefulBuilder(
            builder: (context, setPopupState) {
               return Stack(
                 children: [
                    FutureBuilder<Map<String, dynamic>?>(
                      future: backendFuture,
                      builder: (context, backendSnapshot) {
                        final backendData = backendSnapshot.data;
                        // Extract specific word analysis if available
                        Map<String, dynamic>? specificAnalysis;
                        String? translatedSentence;
                        
                        if (backendData != null) {
                           translatedSentence = backendData['translated_text'];
                           List<dynamic> analysis = backendData['german_analysis'] ?? [];
                           // Find our word
                           try {
                              var match = analysis.firstWhere(
                                (w) => w['word'].toString().toLowerCase() == word.toLowerCase(),
                                orElse: () => null
                              );
                              if (match != null) specificAnalysis = match;
                           } catch (_) {}
                        }
                        
                        // RELEVANT DEFINITION LOGIC:
                        // If we have backend analysis, try to find the dictionary entry that matches that POS
                        Map<String, dynamic> displayDetails;
                        if (specificAnalysis != null) {
                           String backendPos = specificAnalysis['pos'].toString().toLowerCase();
                           try {
                              displayDetails = allPotentialDetails.firstWhere(
                                (d) => d['pos'].toString().toLowerCase() == backendPos,
                                orElse: () => allPotentialDetails.isNotEmpty ? allPotentialDetails.first : {'word': word, 'definitions': []}
                              );
                           } catch (_) {
                              displayDetails = allPotentialDetails.isNotEmpty ? allPotentialDetails.first : {'word': word, 'definitions': []};
                           }
                           // Override POS display with specific tag if available
                           displayDetails['pos'] = specificAnalysis['pos_detailed'] ?? specificAnalysis['pos'];
                           if (specificAnalysis['gender'] != null) {
                             displayDetails['gender'] = specificAnalysis['gender'];
                           }
                         } else {
                           displayDetails = allPotentialDetails.isNotEmpty ? allPotentialDetails.first : {'word': word, 'definitions': []};
                        }

                        return FutureBuilder<bool>(
                           future: _vocabularyService.isWordSaved(word),
                           builder: (context, snapshot) {
                             final isSaved = snapshot.data ?? false;
                             
                             // Calculate position (simple clamp logic from before)
                             final screenHeight = MediaQuery.of(context).size.height;
                             final screenWidth = MediaQuery.of(context).size.width;
                             final isTopHalf = tapPosition.dy < screenHeight / 2;
                             const horizontalMargin = 16.0;
                             const cardWidth = 300.0;
                             
                             double top;
                             double? bottom;
                             if (isTopHalf) {
                                 top = tapPosition.dy + 20; 
                                 bottom = null;
                             } else {
                                 bottom = screenHeight - tapPosition.dy + 20;
                                 top = 0; 
                             }
                             
                             double availableHeight = isTopHalf ? screenHeight - top - 32 : tapPosition.dy - 60;
                             
                             return Stack(
                               children: [
                                 Positioned(
                                   top: isTopHalf ? tapPosition.dy : null,
                                   bottom: !isTopHalf ? (screenHeight - tapPosition.dy) : null,
                                   left: horizontalMargin,
                                   right: horizontalMargin,
                                   child: Material(
                                     color: Colors.transparent,
                                     child: CustomPaint(
                                       painter: TooltipShapePainter(
                                         color: Theme.of(context).cardColor,
                                         borderColor: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                                         isTop: isTopHalf,
                                         arrowX: tapPosition.dx - horizontalMargin,
                                       ),
                                       child: Container(
                                         constraints: BoxConstraints(
                                           maxWidth: cardWidth,
                                           maxHeight: availableHeight > 500 ? 500 : availableHeight, // Increased height for translation
                                         ),
                                         padding: EdgeInsets.only(
                                             left: 20, 
                                             right: 20, 
                                             top: isTopHalf ? 30.0 : 20, 
                                             bottom: !isTopHalf ? 30.0 : 20
                                         ),
                                         child: SingleChildScrollView(
                                           child: Column(
                                             mainAxisSize: MainAxisSize.min,
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                                // Word Details
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
                                                                displayDetails['word'] ?? word,
                                                                style: TextStyle(
                                                                  fontSize: 18, 
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Theme.of(context).colorScheme.onSurface,
                                                                  height: 1.2,
                                                                ),
                                                              ),
                                                              if (displayDetails['gender'] != null && (displayDetails['pos']?.toString().toLowerCase().contains('noun') ?? false))
                                                                Container(
                                                                  margin: const EdgeInsets.only(left: 6),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                                                  decoration: BoxDecoration(
                                                                    color: _getGenderColor(displayDetails['gender']).withValues(alpha: 0.1),
                                                                    borderRadius: BorderRadius.circular(4),
                                                                  ),
                                                                  child: Text(
                                                                    displayDetails['gender'].toString().toUpperCase(),
                                                                    style: TextStyle(
                                                                      fontSize: 10,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: _getGenderColor(displayDetails['gender']),
                                                                    ),
                                                                  ),
                                                                ),
                                                              if (displayDetails['pos'] != null)
                                                                Container(
                                                                  margin: const EdgeInsets.only(left: 8),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                                                    borderRadius: BorderRadius.circular(4),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                        Text(
                                                                          displayDetails['pos'].toString().toLowerCase(),
                                                                          style: TextStyle(
                                                                            fontSize: 10,
                                                                            fontWeight: FontWeight.bold,
                                                                            color: Theme.of(context).colorScheme.primary,
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                          // Lemma
                                                          if (displayDetails['base_form'] != null || specificAnalysis?['lemma'] != null)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 2.0),
                                                              child: Text(
                                                                'Lemma: ${specificAnalysis?['lemma'] ?? displayDetails['base_form']}',
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
                                                     Column(
                                                       mainAxisSize: MainAxisSize.min,
                                                       children: [
                                                         IconButton(
                                                           icon: Icon(Icons.volume_up_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                                                           padding: EdgeInsets.zero,
                                                           constraints: const BoxConstraints(),
                                                           onPressed: () {
                                                             _ttsService.speak(displayDetails['word'] ?? word);
                                                           },
                                                         ),
                                                     ],
                                                       ),

                                                  ],
                                                ),
                                           const SizedBox(height: 8),
                                           // Removed redundant Contextual Analysis text block as it's now in the badge/dictionary entry
                                           // Defs
                                           Text(
                                             'Definitions',
                                             style: TextStyle(
                                               fontSize: 12,
                                               fontWeight: FontWeight.bold,
                                               color: Theme.of(context).colorScheme.onSurfaceVariant,
                                             ),
                                           ),
                                           const SizedBox(height: 6),
                                           if (displayDetails['definitions'] != null && (displayDetails['definitions'] as List).isNotEmpty)
                                              ...((displayDetails['definitions'] as List).map((def) => Padding(
                                                padding: const EdgeInsets.only(bottom: 6.0),
                                                child: Text(
                                                  '• $def',
                                                  style: TextStyle(
                                                    fontSize: 14,
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
                                             height: 44, 
                                             child: ElevatedButton(
                                               onPressed: () async {
                                                   if (isSaved) {
                                                     await _vocabularyService.removeWord(word);
                                                   } else {
                                                     await _vocabularyService.saveWord(word);
                                                   }
                                                   setPopupState(() {}); 
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
                                                     isSaved ? 'Saved' : 'Save Word',
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
                         },
                      );
                    },
                  ),
                ],
              );
            },
          );
    },
    transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
    },
    );
  }

  Color _getGenderColor(dynamic gender) {
    if (gender == null) return Colors.grey;
    String g = gender.toString().toLowerCase();
    if (g == 'm' || g == 'masc') return AppTheme.genderMasc;
    if (g == 'f' || g == 'fem') return AppTheme.genderFem;
    if (g == 'n' || g == 'neu') return AppTheme.genderNeu;
    return Colors.grey;
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
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
  final Color borderColor;
  final bool isTop; 
  final double arrowX; 
  final double arrowSize;
  final double radius;

  TooltipShapePainter({
    required this.color,
    required this.borderColor,
    required this.isTop,
    required this.arrowX,
    this.arrowSize = 10.0,
    this.radius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final width = size.width;
    final height = size.height;
    
    final boxTop = isTop ? arrowSize : 0.0;
    final boxBottom = isTop ? height : height - arrowSize;
    
    // Smooth arrow curve parameters
    const arrowWidthFactor = 2.4; 
    final aw = arrowSize * arrowWidthFactor;
    final safeArrowX = arrowX.clamp(radius + aw, width - radius - aw);

    if (isTop) {
      path.moveTo(radius, boxTop);
      
      // Arrow pointing up
      path.lineTo(safeArrowX - aw / 2, boxTop);
      path.cubicTo(
        safeArrowX - aw / 4, boxTop, 
        safeArrowX - aw / 8, 0, 
        safeArrowX, 0
      );
      path.cubicTo(
        safeArrowX + aw / 8, 0, 
        safeArrowX + aw / 4, boxTop, 
        safeArrowX + aw / 2, boxTop
      );

      path.lineTo(width - radius, boxTop);
      path.quadraticBezierTo(width, boxTop, width, boxTop + radius);
      path.lineTo(width, boxBottom - radius);
      path.quadraticBezierTo(width, boxBottom, width - radius, boxBottom);
      path.lineTo(radius, boxBottom);
      path.quadraticBezierTo(0, boxBottom, 0, boxBottom - radius);
      path.lineTo(0, boxTop + radius);
      path.quadraticBezierTo(0, boxTop, radius, boxTop);
    } else {
      path.moveTo(radius, boxTop);
      path.lineTo(width - radius, boxTop);
      path.quadraticBezierTo(width, boxTop, width, boxTop + radius);
      path.lineTo(width, boxBottom - radius);
      path.quadraticBezierTo(width, boxBottom, width - radius, boxBottom);
      
      // Arrow pointing down
      path.lineTo(safeArrowX + aw / 2, boxBottom);
      path.cubicTo(
        safeArrowX + aw / 4, boxBottom, 
        safeArrowX + aw / 8, height, 
        safeArrowX, height
      );
      path.cubicTo(
        safeArrowX - aw / 8, height, 
        safeArrowX - aw / 4, boxBottom, 
        safeArrowX - aw / 2, boxBottom
      );

      path.lineTo(radius, boxBottom);
      path.quadraticBezierTo(0, boxBottom, 0, boxBottom - radius);
      path.lineTo(0, boxTop + radius);
      path.quadraticBezierTo(0, boxTop, radius, boxTop);
    }
    
    path.close();

    // Shadow
    canvas.drawShadow(path.shift(const Offset(0, 4)), Colors.black.withValues(alpha: 0.15), 12.0, false);
    
    // Fill
    canvas.drawPath(path, paint);
    
    // Border
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant TooltipShapePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isTop != isTop || oldDelegate.arrowX != arrowX;
  }
}

