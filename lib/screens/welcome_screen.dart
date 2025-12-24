import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'main_scaffold.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                   Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: Icon(Icons.language, color: Theme.of(context).colorScheme.primary, size: 30),
                  ),
                  Expanded(
                    child: Text(
                      'DeutschApp',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance for centering
                ],
              ),
            ),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Hero Text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          Text(
                            'German grammar,\nfinally demystified.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                              children: [
                                TextSpan(text: 'Learn with our unique color-coded method for genders: '),
                                TextSpan(
                                  text: 'Masculine',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                      ? AppTheme.genderMascDark 
                                      : AppTheme.genderMasc, 
                                    fontWeight: FontWeight.w600
                                  ),
                                ),
                                TextSpan(text: ', '),
                                TextSpan(
                                  text: 'Feminine',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                      ? AppTheme.genderFemDark 
                                      : AppTheme.genderFem, 
                                    fontWeight: FontWeight.w600
                                  ),
                                ),
                                TextSpan(text: ', and '),
                                TextSpan(
                                  text: 'Neutral',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                      ? AppTheme.genderNeuDark 
                                      : AppTheme.genderNeu, 
                                    fontWeight: FontWeight.w600
                                  ),
                                ),
                                TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Visual Hero (Simulated with Containers as layout)
                    Container(
                      height: 320,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                         color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
                         borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                           // Simplified: No transforms initially to debug
                           Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               _buildGenderCard(context, 'Der', 
                                 Theme.of(context).brightness == Brightness.dark ? AppTheme.genderMascDark : AppTheme.genderMasc, 
                                 80
                               ),
                               const SizedBox(height: 12),
                               _buildGenderCard(context, 'Die', 
                                 Theme.of(context).brightness == Brightness.dark ? AppTheme.genderFemDark : AppTheme.genderFem, 
                                 96
                               ),
                               const SizedBox(height: 12),
                               _buildGenderCard(context, 'Das', 
                                 Theme.of(context).brightness == Brightness.dark ? AppTheme.genderNeuDark : AppTheme.genderNeu, 
                                 64
                               ),
                             ],
                           ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Carousel Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'WHY DEUTSCHAPP?',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Carousel
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          _buildCarouselItem(
                            context,
                            Theme.of(context).brightness == Brightness.dark ? AppTheme.genderMascDark : AppTheme.genderMasc,
                            'Master Der, Die, Das',
                            'Visualize genders with colors immediately.',
                          ),
                          const SizedBox(width: 16),
                          _buildCarouselItem(
                            context,
                            Theme.of(context).brightness == Brightness.dark ? AppTheme.genderFemDark : AppTheme.genderFem,
                            'Conquer Cases',
                            'Learn nominative to genitive naturally.',
                          ),
                          const SizedBox(width: 16),
                          _buildCarouselItem(
                            context,
                            Theme.of(context).brightness == Brightness.dark ? AppTheme.genderNeuDark : AppTheme.genderNeu,
                            'Compound Words',
                            'Break down complex vocabulary.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MainScaffold()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        elevation: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.arrow_forward),
                          SizedBox(width: 8),
                          Text('Los geht’s (Get Started)'),
                        ],
                      ),
                    ),
                  ),
                   const SizedBox(height: 12),
                   TextButton(
                     onPressed: () {},
                     child: Text(
                       'I already have an account',
                       style: TextStyle(
                         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard(BuildContext context, String label, Color color, double barWidth) {
    return Container(
      width: 192, 
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label.substring(0, 1),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                height: 4,
                width: barWidth,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(BuildContext context, Color color, String title, String subtitle) {
    return Container(
      width: 180,
      height: 140, // Fixed height for carousel items
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.class_, color: color, size: 16),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
           Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
