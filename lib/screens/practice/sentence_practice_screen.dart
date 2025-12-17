import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class SentencePracticeScreen extends StatelessWidget {
  const SentencePracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: 0.65,
                          backgroundColor: Theme.of(context).dividerColor.withOpacity(0.3),
                          color: Theme.of(context).colorScheme.primary,
                          minHeight: 12,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('5', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Main Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.1),
                            blurRadius: 15,
                            offset: Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/cat.png', height: 80),
                              Image.asset('assets/images/sofa.png', height: 80),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Translate this sentence',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '"The small cat sleeps on the sofa."',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Tip: 'auf' (location) requires Dative case.",
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Sentence construction
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildWordChip(context, 'Die', isArticle: true),
                        _buildWordChip(context, 'kleine'),
                        _buildWordChip(context, 'Katze', isNoun: true),
                        _buildWordChip(context, 'schläft'),
                        _buildWordChip(context, 'auf'),
                        _buildEmptySlot(context),
                        _buildWordChip(context, 'Sofa', isNoun: true),
                      ],
                    ),
                    const Spacer(),
                    // Choices
                    Text(
                      'Choose the missing article:',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.5,
                      children: [
                        _buildChoiceButton(context, 'der'),
                        _buildChoiceButton(context, 'die'),
                        _buildChoiceButton(context, 'den'),
                        _buildChoiceButton(context, 'dem', isSelected: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.flag_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  label: Text('Report', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                TextButton.icon(
                  onPressed: () {},
                  label: Text('Skip', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  icon: Icon(Icons.skip_next, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Check Answer', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordChip(BuildContext context, String word, {bool isArticle = false, bool isNoun = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isArticle || isNoun ? Theme.of(context).cardColor : Colors.transparent,
        border: isArticle || isNoun ? Border.all(color: Theme.of(context).dividerColor) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        word,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  Widget _buildEmptySlot(BuildContext context) {
    return Container(
      width: 80,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 2, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildChoiceButton(BuildContext context, String text, {bool isSelected = false}) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
