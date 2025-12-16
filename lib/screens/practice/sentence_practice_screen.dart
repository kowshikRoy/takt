import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SentencePracticeScreen extends StatelessWidget {
  const SentencePracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    child: Column(
                      children: [
                        Text('PRACTICE', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold)),
                        const Text('Case Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: const Icon(Icons.lightbulb, color: AppTheme.primary, size: 20),
                  )
                ],
              ),
            ),
            // Progress Bar
            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24),
               child: Container(
                 height: 6,
                 decoration: BoxDecoration(
                   color: Theme.of(context).dividerColor.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(3),
                 ),
                 child: Row(
                   children: [
                     Expanded(
                       flex: 2,
                       child: Container(
                         decoration: BoxDecoration(
                           gradient: const LinearGradient(colors: [Colors.orange, AppTheme.primary]),
                           borderRadius: BorderRadius.circular(3),
                         ),
                       ),
                     ),
                     const Expanded(flex: 1, child: SizedBox()),
                   ],
                 ),
               ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Main Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).dividerColor),
                         boxShadow: [
                             BoxShadow(
                               color: Colors.black.withOpacity(0.05),
                               blurRadius: 10,
                               offset: const Offset(0, 4),
                             )
                          ],
                      ),
                      child: Column(
                        children: [
                          Text('Translate this sentence', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          const Text(
                            '"The father gives the child the apple."',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 24),
                           Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Theme.of(context).dividerColor),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: const [
                                  Icon(Icons.face_3, size: 32, color: AppTheme.genderMasc),
                                  Icon(Icons.arrow_forward, color: Colors.grey),
                                  Icon(Icons.child_care, size: 32, color: AppTheme.genderNeu),
                                  Icon(Icons.arrow_forward, color: Colors.grey),
                                  Text('🍎', style: TextStyle(fontSize: 24)),
                                ],
                              ),
                           )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Slots Display (Static representation of filled state from HTML)
                    Wrap(
                      spacing: 8,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.end, // Align to bottom
                      children: [
                         _buildSlot(context, 'Subject', 'Der\nVater', Colors.blue, isFilled: true, tag: 'NOM'),
                         _buildSlot(context, 'Verb', 'gibt', Colors.grey, isFilled: true, isSimple: true),
                         _buildSlot(context, 'Receiver', 'dem\nKind', AppTheme.genderNeu, isFilled: true, tag: 'DAT'),
                         _buildSlot(context, 'Object', '', Colors.pink, isDashed: true), // Empty slot
                      ],
                    ),

                    const SizedBox(height: 32),
                     Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('DRAG WORDS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Drag Choices
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildDragChip(context, 'Apfel', AppTheme.genderMasc),
                        _buildDragChip(context, 'Mutter', AppTheme.genderFem),
                        _buildDragChip(context, 'Buch', AppTheme.genderNeu),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    // Tip
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.amber),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color, fontSize: 12),
                                children: const [
                                  TextSpan(text: 'Color Tip! ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                  TextSpan(text: 'The slots change the article automatically!'),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  OutlinedButton(onPressed: (){}, child: const Text('Top')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: null, // Disabled
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
                      child: const Text('Check Answer'),
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

  Widget _buildSlot(BuildContext context, String label, String text, Color color, {bool isFilled = false, bool isDashed = false, bool isSimple = false, String? tag}) {
     return Column(
       children: [
         Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
             const SizedBox(width: 4),
             Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
           ],
         ),
         const SizedBox(height: 4),
         Container(
           width: isSimple ? 80 : 100,
           height: 56,
           alignment: Alignment.center,
           decoration: BoxDecoration(
             color: Theme.of(context).cardColor,
             borderRadius: BorderRadius.circular(12),
             border: isDashed 
               ? Border.all(color: color.withOpacity(0.5), style: BorderStyle.none) // Dashed border implementation requires custom painter usually, simplifying
               : Border.all(color: isFilled ? color : Theme.of(context).dividerColor, width: 2),
             boxShadow: isFilled ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))] : null,
           ),
           child: Stack(
             children: [
               if (isSimple || isFilled)
                 Center(
                   child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                 ),
               if (isDashed)
                 Center(child: Icon(Icons.add, color: color.withOpacity(0.5))),
               if (tag != null)
                 Positioned(
                   top: 0,
                   right: 0,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                     decoration: BoxDecoration(
                       color: color,
                       borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                     ),
                     child: Text(tag, style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                   ),
                 )
             ],
           ),
         ),
       ],
     );
  }

  Widget _buildDragChip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
         boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset:const Offset(0, 2))
         ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
