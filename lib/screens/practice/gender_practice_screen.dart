import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GenderPracticeScreen extends StatelessWidget {
  const GenderPracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
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
                          value: 0.6,
                          backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                          color: Theme.of(context).colorScheme.primary,
                          minHeight: 12,
                        ),
                      ),
                    ),
                  ),
                  Text('12 / 20', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {},
                  ),
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
                    Animate(
                      effects: const [FadeEffect(), ScaleEffect()],
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(32),
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
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              alignment: Alignment.center,
                              child: Image.asset('assets/images/bicycle.png', width: 80),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '?',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Fahrrad',
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '/ˈfaːɐ̯ˌraːt/',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              'The Bicycle',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer / Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  Text(
                    'SELECT THE ARTICLE',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildGenderButton(context, 'Der', 'MASC', AppTheme.genderMasc),
                      const SizedBox(width: 16),
                      _buildGenderButton(context, 'Die', 'FEM', AppTheme.genderFem),
                      const SizedBox(width: 16),
                      _buildGenderButton(context, 'Das', 'NEU', AppTheme.genderNeu),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderButton(BuildContext context, String label, String subLabel, Color color) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          backgroundColor: color.withOpacity(0.05),
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
