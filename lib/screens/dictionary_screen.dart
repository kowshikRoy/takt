import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/dictionary_service.dart';
import '../services/vocabulary_service.dart';
import 'vocabulary_list_screen.dart';

class DictionaryScreen extends StatefulWidget {
  final String? initialWord;
  const DictionaryScreen({super.key, this.initialWord});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DictionaryService _dictionaryService = DictionaryService();
  final VocabularyService _vocabularyService = VocabularyService();
  
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedWord;
  bool _isSearching = false;
  bool _isSaved = false;
  int _selectedTabIndex = 0; // 0: Declension, 1: Examples, 2: Related

  @override
  void initState() {
    super.initState();
    if (widget.initialWord != null) {
      _loadInitialWord(widget.initialWord!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialWord(String word) async {
      final lookup = await _dictionaryService.lookupWord(word);
      if (lookup != null && mounted) {
        setState(() {
          _selectedWord = lookup;
          _searchController.text = lookup['word'] ?? '';
        });
        _checkIfSaved();
      }
  }

  Future<void> _checkIfSaved() async {
    if (_selectedWord == null) {
        setState(() => _isSaved = false);
        return;
    }
    final saved = await _vocabularyService.isWordSaved(_selectedWord!['word']);
    if (mounted) {
      setState(() => _isSaved = saved);
    }
  }

  Future<void> _toggleSaved() async {
    if (_selectedWord == null) return;
    final word = _selectedWord!['word'];

    if (_isSaved) {
      await _vocabularyService.removeWord(word);
    } else {
      await _vocabularyService.saveWord(word);
    }
    await _checkIfSaved();
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    
    // Simple debounce could go here, but for now direct query
    final results = await _dictionaryService.search(query);
    
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  void _onResultSelected(Map<String, dynamic> result) async {
    // Fetch full details
    final fullWord = await _dictionaryService.getWordDetails(result['id']);
    if (mounted) {
      setState(() {
        _selectedWord = fullWord;
        _isSearching = false;
        _searchController.text = fullWord?['word'] ?? '';
        // Reset tab to 0 on new word selection
        _selectedTabIndex = 0;
      });
      _checkIfSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 96), // pb-24
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildSearchBar(context),
                        const SizedBox(height: 24),
                        if (_selectedWord != null) ...[
                          _buildMainCard(context, _selectedWord!),
                          const SizedBox(height: 24),
                          _buildTabs(context),
                          const SizedBox(height: 16),
                          _buildTabContent(),
                          const SizedBox(height: 16),
                        ] else ...[
                           Center(child: Text("Search for a word", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                        ]
                      ],
                    ),
                  ),

                  // Search Results Overlay
                  if (_isSearching && _searchResults.isNotEmpty)
                    Positioned(
                      top: 80, // Below search bar roughly
                      left: 20, right: 20,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final word = _searchResults[index];
                            return ListTile(
                              title: Text(word['word'], style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                              subtitle: Text(word['pos'] ?? 'unknown', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              onTap: () => _onResultSelected(word),
                            );
                          },
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          Text(
            'Dictionary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onSelected: (value) {
                if (value == 'vocabulary') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyListScreen()));
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'vocabulary',
                  child: Row(
                    children: [
                       Icon(Icons.book, size: 20),
                       SizedBox(width: 8),
                       Text('My Vocabulary'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 2),
        boxShadow: const [
           BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
          suffixIcon: IconButton(
            icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _isSearching = false;
                _selectedWord = null;
                _isSaved = false;
              });
            },
          ),
          hintText: 'Search German or English...',
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildMainCard(BuildContext context, Map<String, dynamic> wordData) {
    final gender = wordData['gender'];
    final word = wordData['word'];
    final ipa = wordData['ipa'];
    final defs = wordData['definitions'] as List?;
    final definition = (defs != null && defs.isNotEmpty) ? defs.first : 'No definition found';

    Color genderColor = Theme.of(context).colorScheme.primary; // Default/Fem
    String genderText = "TERM";
    String article = "";
    
    if (gender == 'masculine' || gender == 'm') {
      genderColor = AppTheme.genderMasc;
      genderText = "MASCULINE";
      article = "Der";
    } else if (gender == 'feminine' || gender == 'f') {
      genderColor = AppTheme.genderFem;
      genderText = "FEMININE";
      article = "Die";
    } else if (gender == 'neuter' || gender == 'n') {
      genderColor = AppTheme.genderNeu;
      genderText = "NEUTER";
      article = "Das";
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.1), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)
        ],
      ),
      child: Stack(
        children: [
           // Background shapes
           Positioned(
             top: -32, right: -32,
             child: Container(
               width: 128, height: 128,
               decoration: BoxDecoration(
                 color: genderColor.withValues(alpha: 0.05),
                 borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(100)),
               ),
             ),
           ),
           Positioned(
             bottom: -32, left: -32,
             child: Container(
               width: 96, height: 96,
               decoration: BoxDecoration(
                 color: genderColor.withValues(alpha: 0.05),
                 borderRadius: const BorderRadius.only(topRight: Radius.circular(80)),
               ),
             ),
           ),
           
           Padding(
             padding: const EdgeInsets.all(24),
             child: Column(
               children: [
                 // Icon Stack (Placeholder icon)
                 SizedBox(
                   width: 96, height: 96,
                   child: Stack(
                     alignment: Alignment.center,
                     children: [
                       Transform.rotate(
                         angle: 0.1, 
                         child: Container(
                           width: 96, height: 96,
                           decoration: BoxDecoration(
                             color: genderColor.withValues(alpha: 0.2), 
                             borderRadius: BorderRadius.circular(16),
                           ),
                         ),
                       ),
                       Transform.rotate(
                         angle: -0.05, 
                         child: Container(
                           width: 96, height: 96,
                           decoration: BoxDecoration(
                             color: Theme.of(context).cardColor,
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: genderColor.withValues(alpha: 0.3)),
                             boxShadow: const [
                               BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 4, offset: Offset(0, 2))
                             ],
                           ),
                           alignment: Alignment.center,
                           child: Text(word.toString().substring(0, 1).toUpperCase(), style: TextStyle(fontSize: 48, color: Theme.of(context).colorScheme.onSurface)),
                         ),
                       ),
                     ],
                   ).animate().fade().scale(duration: 500.ms),
                 ),
                 
                 const SizedBox(height: 20),
                 
                 // Gender Tag
                 Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Container(width: 8, height: 8, decoration: BoxDecoration(color: genderColor, shape: BoxShape.circle)),
                     const SizedBox(width: 6),
                     Text(
                       genderText,
                       style: TextStyle(
                         color: genderColor,
                         fontSize: 12,
                         fontWeight: FontWeight.bold,
                         letterSpacing: 1.5,
                       ),
                     ),
                   ],
                 ),
                 
                 const SizedBox(height: 4),
                 
                 // Title
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.baseline,
                   textBaseline: TextBaseline.alphabetic,
                   children: [
                     if (article.isNotEmpty)
                     Text(
                       article,
                       style: TextStyle(
                         fontSize: 24,
                         fontWeight: FontWeight.bold,
                         color: genderColor,
                       ),
                     ),
                     const SizedBox(width: 8),
                     Flexible(
                       child: Text(
                         word,
                         style: TextStyle(
                           fontSize: 30,
                           fontWeight: FontWeight.bold,
                           color: Theme.of(context).colorScheme.onSurface,
                         ),
                       ),
                     ),
                   ],
                 ),
                 
                 const SizedBox(height: 0),
                 
                 // Phonetic & Meaning
                 if (ipa != null && ipa.isNotEmpty)
                 Text(
                   ipa,
                   style: GoogleFonts.notoSans( 
                     fontSize: 14,
                     color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                   ),
                 ),
                 const SizedBox(height: 4),
                 Text(
                   definition,
                   textAlign: TextAlign.center,
                   maxLines: 2,
                   overflow: TextOverflow.ellipsis,
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.w500,
                     color: Theme.of(context).colorScheme.onSurface,
                   ),
                 ),
                 
                 const SizedBox(height: 24),
                 
                 // Action Buttons
                 Row(
                   children: [
                     Expanded(
                       child: ElevatedButton(
                         onPressed: _toggleSaved,
                         style: ElevatedButton.styleFrom(
                           backgroundColor: _isSaved ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
                           padding: const EdgeInsets.symmetric(vertical: 12),
                           elevation: 4,
                           shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         ),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(_isSaved ? Icons.check_rounded : Icons.add_circle_outline_rounded, size: 20),
                             const SizedBox(width: 8),
                             Text(
                               _isSaved ? 'Saved to List' : 'Add to Learning List',
                               style: const TextStyle(
                                 fontSize: 14,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                           ],
                         ),
                       ),
                     ),
                     const SizedBox(width: 12),
                     Container(
                       width: 48, height: 48,
                       decoration: BoxDecoration(
                         color: Theme.of(context).cardColor,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5), width: 2),
                       ),
                       child: IconButton(
                         icon: Icon(Icons.volume_up_rounded, color: Theme.of(context).colorScheme.primary),
                         onPressed: () {},
                       ),
                     ),
                   ],
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildTabItem(context, 'Declension', index: 0),
          const SizedBox(width: 24),
          _buildTabItem(context, 'Examples', index: 1),
          const SizedBox(width: 24),
          _buildTabItem(context, 'Related', index: 2),
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String title, {required int index}) {
    bool isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTabIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: isActive ? Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)) : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedWord == null) return const SizedBox.shrink();

    switch (_selectedTabIndex) {
      case 0:
        if (_selectedWord!['forms'] != null && (_selectedWord!['forms'] as List).isNotEmpty) {
          return _buildDeclensionTable(context, _selectedWord!);
        } else {
           return const Padding(
             padding: EdgeInsets.all(16.0),
             child: Center(child: Text("No declension forms found.")),
           );
        }
      case 1:
        return _buildExamplesContent();
      case 2:
        return _buildRelatedContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildExamplesContent() {
    // If examples are not in the main word object, we can't show them yet.
    // Assuming a future update will add them, or we can check definitions for example usage.
    // For now, if 'examples' is present (list of strings), show them.
    final examples = _selectedWord!['examples'] as List<dynamic>?;

    if (examples != null && examples.isNotEmpty) {
       return ListView.separated(
         shrinkWrap: true,
         physics: const NeverScrollableScrollPhysics(),
         padding: const EdgeInsets.all(16),
         itemCount: examples.length,
         separatorBuilder: (_, __) => const SizedBox(height: 12),
         itemBuilder: (context, index) {
           return Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Theme.of(context).cardColor,
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
             ),
             child: Text(examples[index].toString(), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
           );
         },
       );
    }

    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(child: Text("No examples found.")),
    );
  }

  Widget _buildRelatedContent() {
    final synonyms = _selectedWord!['synonyms'] as List<dynamic>? ?? [];
    final antonyms = _selectedWord!['antonyms'] as List<dynamic>? ?? [];
    final related = _selectedWord!['related'] as List<dynamic>? ?? [];

    if (synonyms.isEmpty && antonyms.isEmpty && related.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text("No related words found.")),
      );
    }

    return Column(
      children: [
        if (synonyms.isNotEmpty) _buildRelationSection('Synonyms', synonyms),
        if (antonyms.isNotEmpty) _buildRelationSection('Antonyms', antonyms),
        if (related.isNotEmpty) _buildRelationSection('Related', related),
      ],
    );
  }

  Widget _buildRelationSection(String title, List<dynamic> words) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
         width: double.infinity,
         decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: words.map((w) => ActionChip(
                label: Text(w.toString()),
                onPressed: () {
                   _searchController.text = w.toString();
                   _onSearchChanged(w.toString());
                   // Or directly trigger lookup:
                   _loadInitialWord(w.toString());
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclensionTable(BuildContext context, Map<String, dynamic> wordData) {
    final forms = wordData['forms'] as List;
    
    // Attempt to categorize forms by case/number from tags
    // Tags example: "Masc.Nom.Sg", "Fem.Gen.Pl", "Dat" etc.
    // We want a table with rows: Nom, Gen, Dat, Acc
    // Columns: Singular, Plural

    Map<String, String> singular = {}; // Key: Case (Nom, Gen, Dat, Acc)
    Map<String, String> plural = {};

    for (var f in forms) {
      String form = f['form'] ?? '';
      String tags = f['tags'] ?? '';

      if (tags.isEmpty) continue;

      String? caseKey;
      if (tags.contains('Nom')) caseKey = 'Nom';
      else if (tags.contains('Gen')) caseKey = 'Gen';
      else if (tags.contains('Dat')) caseKey = 'Dat';
      else if (tags.contains('Acc')) caseKey = 'Acc';

      if (caseKey != null) {
        if (tags.contains('Sg') || tags.contains('Sing')) {
          singular[caseKey] = form;
        } else if (tags.contains('Pl')) {
          plural[caseKey] = form;
        }
      }
    }

    // If we couldn't parse enough, fallback to list
    if (singular.isEmpty && plural.isEmpty) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text("Forms found:", style: TextStyle(fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               Wrap(
                 spacing: 8, runSpacing: 8,
                 children: forms.take(20).map<Widget>((f) {
                   return Chip(label: Text(f['form'] ?? ''));
                 }).toList(),
               )
             ],
           )
        );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          const Divider(height: 1),
          _buildTableRow('Nom', singular['Nom'] ?? '-', plural['Nom'] ?? '-'),
          _buildTableRow('Gen', singular['Gen'] ?? '-', plural['Gen'] ?? '-'),
          _buildTableRow('Dat', singular['Dat'] ?? '-', plural['Dat'] ?? '-'),
          _buildTableRow('Acc', singular['Acc'] ?? '-', plural['Acc'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('CASE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(flex: 2, child: Text('SINGULAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(flex: 2, child: Text('PLURAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ],
      ),
    );
  }

  Widget _buildTableRow(String caseName, String sNoun, String pNoun) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(caseName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSubLight))),
          
          Expanded(
            flex: 2,
            child: Text(sNoun, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMainLight)),
          ),
          
          Expanded(
            flex: 2,
            child: Text(pNoun, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }
}
