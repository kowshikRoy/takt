import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MeaningPracticeScreen extends StatelessWidget {
  const MeaningPracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          value: 0.6,
                          backgroundColor: AppTheme.borderLight,
                          color: AppTheme.primary,
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ),
                  const Text('12 / 20', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSubLight)),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset('assets/images/butterfly.png', width: 60), // Placeholder
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Der Schmetterling',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '/ˈʃmɛtɐlɪŋ/',
                            style: TextStyle(color: AppTheme.textSubLight, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.volume_up, color: AppTheme.genderMasc),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Select the correct meaning:',
                      style: TextStyle(color: AppTheme.textSubLight, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildMeaningOption(context, 'The Dragonfly', false),
                    _buildMeaningOption(context, 'The Butterfly', true),
                    _buildMeaningOption(context, 'The Ladybug', false),
                    _buildMeaningOption(context, 'The Caterpillar', false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
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
    );
  }

  Widget _buildMeaningOption(BuildContext context, String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.borderLight, width: 2),
          backgroundColor: isSelected ? AppTheme.primary.withOpacity(0.05) : AppTheme.surfaceLight,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.textMainLight,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primary)
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderLight, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
