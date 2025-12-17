import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart'; // Keep if used for special things, otherwise remove if unused. Keeping for now as other imports might use it in project.
import 'practice/gender_practice_screen.dart';
import 'practice/compound_practice_screen.dart';
import 'practice/sentence_practice_screen.dart';
import 'practice/vocabulary_practice_screen.dart';

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
                    color: AppTheme.textMainLight,
                  ),
                ),
                Text(
                  'View All',
                  style: TextStyle(
                    color: AppTheme.primary,
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
        color: AppTheme.backgroundLight.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: AppTheme.borderLight.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderLight, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1)),
                  ],
                  image: const DecorationImage(
                    image: AssetImage('assets/images/profile.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guten Morgen!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMainLight, height: 1.1),
                  ),
                  Text(
                    'Level 4 · Explorer',
                    style: TextStyle(
                      color: AppTheme.textSubLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 4),
                Text(
                  '12 Days',
                  style: TextStyle(
                    color: const Color(0xFFEA580C), // orange-600
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      // relative overflow-hidden group
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
           BoxShadow(
             color: Color.fromRGBO(0, 0, 0, 0.05),
             blurRadius: 6,
             offset: Offset(0, 4),
           ),
           BoxShadow(
             color: Color.fromRGBO(0, 0, 0, 0.03),
             blurRadius: 4,
             offset: Offset(0, 2),
           ),
        ],
      ),
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
                 color: AppTheme.primary.withValues(alpha: 0.1),
                 shape: BoxShape.circle,
               ),
               // Approximation of blur-xl
             )
          ),
          Column(
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.textMainLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep your streak alive!',
                        style: TextStyle(
                              color: AppTheme.textSubLight,
                              fontSize: 14,
                            ),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: AppTheme.primary, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 20), // space-y-3 approx
              
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
              
              const SizedBox(height: 12),
              
              // Core Lesson Item (Active)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary, width: 2),
                    ),
                    child: Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle))),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textMainLight,
                              ),
                            ),
                            Text(
                              '60%',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.borderLight,
                            borderRadius: BorderRadius.circular(999), 
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Locked Item
              _buildSessionItem(
                context,
                iconWidget: Container(
                   width: 24, height: 24,
                   decoration: BoxDecoration(
                     border: Border.all(color: AppTheme.borderLight, width: 2),
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSubLight, size: 14),
                ),
                title: 'Daily Review',
                isLocked: true
              ),

              const SizedBox(height: 20), // mt-5
              
              SizedBox(
                width: double.infinity,
                height: 52, // py-3 implies roughly 48-56 height
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    elevation: 4,
                    shadowColor: AppTheme.primary.withValues(alpha: 0.2), // shadow-lg shadow-primary/20
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // rounded-xl
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue Lesson',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isLocked ? AppTheme.textSubLight : AppTheme.textSubLight.withValues(alpha: 0.8), // text-sub-light/80
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            decorationColor: AppTheme.borderDark,
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
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEFF6FF), Color(0xFFFDF2F8)]),
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
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF7ED), Color(0xFFFEFCE8)]),
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
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompoundPracticeScreen())),
      child: Container(
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           // bg-gradient-to-r from-emerald-50 to-teal-50
           gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFF0FDFA)]),
           borderRadius: BorderRadius.circular(16), // rounded-2xl
           border: Border.all(color: const Color(0xFFD1FAE5)), // border-emerald-100
           boxShadow: const [
             BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1)) // shadow-sm
           ]
         ),
       child: Row(
         children: [
           Container(
             width: 48,
             height: 48,
             alignment: Alignment.center,
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(8), // rounded-lg
               boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1))
               ],
             ),
             child: const Icon(Icons.extension_rounded, color: Color(0xFF059669), size: 24), // emerald-600
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   'Compound Puzzle', 
                   style: TextStyle(
                     fontWeight: FontWeight.bold, 
                     fontSize: 18, 
                     color: const Color(0xFF1E293B) // slate-800
                   )
                 ),
                 Text(
                   'Build massive words', 
                   style: TextStyle(
                     color: const Color(0xFF64748B), // slate-500
                     fontSize: 12,
                     fontWeight: FontWeight.w500,
                   )
                 ),
               ],
             ),
           ),
           const Icon(Icons.chevron_right_rounded, color: Color(0xFF34D399), size: 28), // emerald-400
         ],
       ),
    ),
   );
  }

  Widget _buildPracticeCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Gradient gradient, required Color borderColor, required Color iconColor, required Widget child}) {
    return Container(
      height: 160, // h-40 = 10rem = 160px
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16), // rounded-2xl
        border: Border.all(color: borderColor),
        boxShadow: const [
           BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1)) 
        ],
      ),
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
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(8), // rounded-lg
                   boxShadow: const [
                     BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1)) // shadow-sm
                   ]
                 ),
                 child: Icon(icon, color: iconColor, size: 20),
               ),
               const SizedBox(height: 12), // mb-3 (applied to icon wrapper but space below works differently in Flex)
               Text(
                 title,                  style: TextStyle(
                     fontWeight: FontWeight.bold, 
                     fontSize: 18, 
                     height: 1.1, // leading-tight
                     color: const Color(0xFF1E293B) // slate-800
                  )
               ),
               const SizedBox(height: 4),
               Text(
                 subtitle,                  style: TextStyle(
                     fontSize: 12, 
                     fontWeight: FontWeight.w500,
                     color: const Color(0xFF64748B) // slate-500
                  )
               ),
             ],
           ),
           child,
         ],
      ),
    );
  }


}
