import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart'; // Keep if used for special things, otherwise remove if unused. Keeping for now as other imports might use it in project.
import 'practice/gender_practice_screen.dart';
import 'practice/compound_practice_screen.dart';
import 'practice/sentence_practice_screen.dart';
import 'practice/vocabulary_practice_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),

          const SizedBox(height: 24),

          // Daily Session Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _buildDailySessionCard(context),
          ),

          const SizedBox(height: 24),

          // Practice Tools Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Practice Tools',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'View All',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _buildPracticeGrid(context),
          ),


        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/profile.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guten Morgen!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Level 4 · Explorer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 4),
                Text(
                  '12 Days',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFEA580C), // orange-600
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDailySessionCard(BuildContext context) {
    return Card(
      elevation: 0,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24), // Expressive Large Card
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Blur effect background
          Positioned(
             right: -24,
             top: -24,
             child: Container(
               width: 96,
               height: 96,
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                 shape: BoxShape.circle,
               ),
             )
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Session',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                             fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keep your streak alive!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Warm-up Item
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VocabularyPracticeScreen())),
                  child: _buildSessionItem(
                    context,
                    iconWidget: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle), // green-500
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                    title: 'Warm-up: Vocabulary',
                    isCompleted: true,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Core Lesson Item (Active)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                      child: Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Core Lesson: Dative Case',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                   color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '60%',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: 0.6,
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Locked Item
                _buildSessionItem(
                  context,
                  iconWidget: Container(
                     width: 24, height: 24,
                     decoration: BoxDecoration(
                       border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(Icons.lock_outline_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 14),
                  ),
                  title: 'Daily Review',
                  isLocked: true
                ),

                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {},
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue Lesson'),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, {required Widget iconWidget, required String title, bool isCompleted = false, bool isLocked = false}) {
    return Row(
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
             color: isLocked ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
             decoration: isCompleted ? TextDecoration.lineThrough : null,
             decorationColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GenderPracticeScreen())),
                child: _buildPracticeCard(
                  context,
                  title: 'Der Die Das',
                  subtitle: 'Gender Trainer',
                  icon: Icons.swipe_rounded, 
                  // bg-gradient-to-br from-blue-50 to-pink-50
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
                    Theme.of(context).brightness == Brightness.light ? const Color(0xFFEFF6FF) : const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                    Theme.of(context).brightness == Brightness.light ? const Color(0xFFFDF2F8) : const Color(0xFF831843).withValues(alpha: 0.3),
                  ]),
                  borderColor: const Color(0xFFDBEAFE), // border-blue-100
                  iconColor: const Color(0xFF3B82F6), // blue-500
                  child: Row(
                    children: const [
                      CircleAvatar(radius: 3, backgroundColor: AppTheme.genderMasc),
                      SizedBox(width: 4),
                      CircleAvatar(radius: 3, backgroundColor: AppTheme.genderFem),
                      SizedBox(width: 4),
                      CircleAvatar(radius: 3, backgroundColor: AppTheme.genderNeu),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12), // gap-3 is 12px
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SentencePracticeScreen())),
                child: _buildPracticeCard(
                  context,
                  title: 'Case Color',
                  subtitle: 'Sentence Builder',
                  icon: Icons.palette_rounded,
                  // bg-gradient-to-br from-orange-50 to-yellow-50
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
                    Theme.of(context).brightness == Brightness.light ? const Color(0xFFFFF7ED) : const Color(0xFF7C2D12).withValues(alpha: 0.3),
                    Theme.of(context).brightness == Brightness.light ? const Color(0xFFFEFCE8) : const Color(0xFF713F12).withValues(alpha: 0.3),
                  ]),
                   borderColor: const Color(0xFFFFEDD5), // border-orange-100
                  iconColor: const Color(0xFFF97316), // orange-500
                  child: SizedBox(
                    height: 16,
                    width: 48,
                    child: Stack(
                      children: [
                        Positioned(left: 0, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFFFACC15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)))),
                        Positioned(left: 12, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFF60A5FA), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)))),
                        Positioned(left: 24, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFFF87171), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCompoundPracticeCard(context),
      ],
    );
  }

  Widget _buildCompoundPracticeCard(BuildContext context) {
    return Card(
       elevation: 0,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(16),
         side: BorderSide(color: const Color(0xFFD1FAE5)), // Custom color for visual distinctiveness
       ),
       clipBehavior: Clip.antiAlias,
       child: Container(
         decoration: BoxDecoration(
           gradient: LinearGradient(colors: [
             Theme.of(context).brightness == Brightness.light ? const Color(0xFFECFDF5) : const Color(0xFF064E3B).withValues(alpha: 0.3),
             Theme.of(context).brightness == Brightness.light ? const Color(0xFFF0FDFA) : const Color(0xFF134E4A).withValues(alpha: 0.3),
           ]),
         ),
         child: InkWell(
           onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompoundPracticeScreen())),
           child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: const Icon(Icons.extension_rounded, color: Color(0xFF059669), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compound Puzzle', 
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Build massive words', 
                         style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF34D399), size: 28),
              ],
            ),
           ),
         ),
       ),
    );
  }

  Widget _buildPracticeCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Gradient gradient, required Color borderColor, required Color iconColor, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
         height: 160,
         decoration: BoxDecoration(gradient: gradient),
         child: InkWell(
           onTap: null, // Tap is handled by parent, but we want InkWell effect? Parent GestureDetector handles nav. To get ripple we should move nav here.
           // Actually parent GestureDetector handles it. Let's rely on that for now or move it.
           // Since the parent passed 'child' which is building the route, we can't easily move it inside without changing the caller.
           // We'll leave the container as is but inside a Card.
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(height: 16), 
                      Text(
                        title,                  
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,                  
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  child,
                ],
              ),
            ),
         ),
      ),
    );
  }


}
