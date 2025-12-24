import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/dictionary_service.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DictionaryService _dictionaryService = DictionaryService();
  
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedWord;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Pre-load default word "Schmetterling" logic or just start empty
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
      });
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
                          if (_selectedWord!['forms'] != null && (_selectedWord!['forms'] as List).isNotEmpty)
                             _buildDeclensionTable(context, _selectedWord!),
                          const SizedBox(height: 16),
                         // _buildCompoundCard(context), // Only show if compound data exists (TODO)
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
              onPressed: () {}, // No backnav context here usually, or mock pop
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
            child: IconButton(
              icon: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onPressed: () {},
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
                         onPressed: () {},
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Theme.of(context).colorScheme.primary,
                           padding: const EdgeInsets.symmetric(vertical: 12),
                           elevation: 4,
                           shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         ),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             const Icon(Icons.add_circle_outline_rounded, size: 20),
                             const SizedBox(width: 8),
                             Text(
                               'Add to Learning List',
                               style: TextStyle(
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
          _buildTabItem(context, 'Declension', isActive: true),
          const SizedBox(width: 24),
          _buildTabItem(context, 'Examples'),
          const SizedBox(width: 24),
          _buildTabItem(context, 'Related'),
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String title, {bool isActive = false}) {
    return Container(
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
    );
  }

  Widget _buildDeclensionTable(BuildContext context, Map<String, dynamic> wordData) {
    // This assumes specific structure or just renders what we have. 
    // For now, let's just make a placeholder table if we don't parse forms specifically into declension grid
    // Or try to find nom/gen etc from list.
    
    // Simplification for demo: Just list forms found
    final forms = wordData['forms'] as List;
    
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text("Forms found:", style: TextStyle(fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           Wrap(
             spacing: 8, runSpacing: 8,
             children: forms.take(10).map<Widget>((f) {
               return Chip(label: Text(f['form'] ?? ''));
             }).toList(),
           )
         ],
       )
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), // slightly less to fit
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('CASE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(flex: 2, child: Text('SINGULAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(flex: 2, child: Text('PLURAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ],
      ),
    );
  }

  Widget _buildTableRow(String caseName, String sArt, String sNoun, String pArt, String pNoun, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(caseName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          
          Expanded(
            flex: 2 ,
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                children: [
                  TextSpan(text: '$sArt ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.genderMasc)),
                  TextSpan(text: sNoun.substring(0, sNoun.length - (suffix != null && caseName == 'Gen' ? 1 : 0))),
                  if (suffix != null && caseName == 'Gen') TextSpan(text: suffix, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),
          
          Expanded(
            flex: 2,
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                children: [
                  TextSpan(text: '$pArt ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF97316))), // Orange for Plural
                  TextSpan(text: pNoun.substring(0, pNoun.length - (suffix != null && caseName == 'Dat' ? 1 : 0))),
                  if (suffix != null && caseName == 'Dat') TextSpan(text: suffix, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompoundCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // bg-gradient-to-br from-indigo-50 to-purple-50
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEEF2FF), Color(0xFFFAF5FF)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)), // indigo-100
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.extension_rounded, color: Color(0xFF6366F1)), // indigo-500
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compound Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Schmetter (Smash) + ling (Suffix)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFA5B4FC)), // indigo-300
        ],
      ),
    );
  }
}
