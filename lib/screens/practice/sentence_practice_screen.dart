import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class SentencePracticeScreen extends StatelessWidget {
  const SentencePracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
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
                          backgroundColor: Colors.grey[300],
                          color: AppTheme.primary,
                          minHeight: 12,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.favorite, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text('5', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
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
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.borderLight),
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
                          const Text(
                            'Translate this sentence',
                            style: TextStyle(color: AppTheme.textSubLight, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '"The small cat sleeps on the sofa."',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Tip: 'auf' (location) requires Dative case.",
                              style: TextStyle(color: AppTheme.textSubLight),
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
                    const Text(
                      'Choose the missing article:',
                      style: TextStyle(color: AppTheme.textSubLight),
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
          color: AppTheme.surfaceLight,
          border: Border(top: BorderSide(color: AppTheme.borderLight)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.flag_outlined, color: AppTheme.textSubLight),
                  label: const Text('Report', style: TextStyle(color: AppTheme.textSubLight)),
                ),
                TextButton.icon(
                  onPressed: () {},
                  label: const Text('Skip', style: TextStyle(color: AppTheme.textSubLight)),
                  icon: const Icon(Icons.skip_next, color: AppTheme.textSubLight),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Check Answer', style: TextStyle(fontSize: 16)),
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
        color: isArticle || isNoun ? AppTheme.surfaceLight : Colors.transparent,
        border: isArticle || isNoun ? Border.all(color: AppTheme.borderLight) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        word,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptySlot(BuildContext context) {
    return Container(
      width: 80,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 2, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildChoiceButton(BuildContext context, String text, {bool isSelected = false}) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primary.withOpacity(0.05) : AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.borderLight, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isSelected ? AppTheme.primary : AppTheme.textMainLight,
        ),
      ),
    );
  }
}
