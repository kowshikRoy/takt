import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class CompoundPracticeScreen extends StatelessWidget {
  const CompoundPracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 128), // 24=px-6, 128=pb-32
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8), // mt-2
                        Text(
                          'COMPOUND WORD PUZZLE',
                          style: GoogleFonts.splineSans(
                            color: AppTheme.textSubLight,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2, // tracking-wider
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'What does this word mean?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.splineSans(
                            color: AppTheme.textMainLight,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 40), // mb-10
                        
                        _buildWordSplitVisual(context),
                        
                        const SizedBox(height: 32), // mb-8 (gap between visual and grid)
                        
                        _buildChoiceGrid(context),
                        
                        const SizedBox(height: 16), // mt-4
                        
                        _buildResultCard(context),
                        
                        const SizedBox(height: 32),
                        
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderLight),
                            boxShadow: const [
                              BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1))
                            ],
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.splineSans(
                                color: AppTheme.textSubLight,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Fun Fact: ',
                                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(text: 'German uses descriptive words to name new inventions!'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sticky Bottom Nav
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), // pb-8 + safe area approx
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                border: const Border(top: BorderSide(color: AppTheme.borderLight)),
                boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 6, offset: Offset(0, -4))
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    elevation: 4,
                    shadowColor: AppTheme.primary.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: GoogleFonts.splineSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded, size: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight.withValues(alpha: 0.95),
      ),
      child: Row(
        children: [
          Transform.translate(
            offset: const Offset(-8, 0),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 24, color: AppTheme.textSubLight),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.06), blurRadius: 4, offset: Offset(0, 2), spreadRadius: 0) // inset shadow approx
                ],
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.65,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.genderNeu, // green
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                           BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.1), blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      child: Stack(
                        children: [
                          Container(
                             decoration: BoxDecoration(
                               gradient: LinearGradient(
                                 begin: Alignment.topCenter,
                                 end: Alignment.bottomCenter,
                                 colors: [Colors.white.withValues(alpha: 0.2), Colors.transparent]
                               ),
                               borderRadius: BorderRadius.circular(999),
                             ),
                          ),
                          Positioned(
                             top: 4, right: 8, left: 12,
                             child: Container(height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(999),)), // blur-[1px]
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: const [
                BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 4),
                Text(
                  '5',
                  style: GoogleFonts.splineSans(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordSplitVisual(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
             // Connector lines
             Positioned(
               top: 50, // Top full
               child: SizedBox(
                 width: 200,
                 height: 64,
                 child: Stack(
                   children: [
                     // Left dashed line (-rotate-12)
                     Positioned(
                       left: 40,
                       top: 0, bottom: 0,
                       child: Transform.rotate(
                         angle: -0.2, // ~ -12 deg
                         child: CustomPaint(
                           size: const Size(2, 64),
                           painter: DashedLinePainter(color: Colors.amber[300]!),
                         ),
                       ),
                     ),
                     // Right dashed line (rotate-12)
                     Positioned(
                       right: 40,
                       top: 0, bottom: 0,
                       child: Transform.rotate(
                         angle: 0.2, // ~ 12 deg
                         child: CustomPaint(
                           size: const Size(2, 64),
                           painter: DashedLinePainter(color: Colors.lime[300]!),
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
             // Word Parts
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 // Part 1 (Left Piece with Bump)
                 CustomPaint(
                   painter: PuzzlePiecePainter(
                     isLeft: true,
                     colorStart: Colors.amber[300]!,
                     colorEnd: Colors.amber[400]!,
                     borderColor: Colors.amber[600]!,
                   ),
                   child: Container(
                     padding: const EdgeInsets.fromLTRB(28, 20, 48, 20), // Extra right padding for knob
                     child: Text(
                       'Glüh',
                       style: GoogleFonts.splineSans(
                         fontSize: 30, // text-3xl
                         fontWeight: FontWeight.bold,
                         letterSpacing: 0.5,
                         color: const Color(0xFF78350F), // amber-900
                       ),
                     ),
                   ),
                 ),
                 // Part 2 (Right Piece with Dent)
                 Transform.translate(
                   offset: const Offset(-2, 0), // Slight overlap to hide seam
                   child: CustomPaint(
                     painter: PuzzlePiecePainter(
                       isLeft: false,
                       colorStart: Colors.lime[400]!,
                       colorEnd: Colors.lime[500]!,
                       borderColor: Colors.lime[700]!,
                     ),
                     child: Container(
                       padding: const EdgeInsets.fromLTRB(48, 20, 28, 20), // Extra left padding for dent
                       child: Text(
                         'birne',
                         style: GoogleFonts.splineSans(
                           fontSize: 30,
                           fontWeight: FontWeight.bold,
                           letterSpacing: 0.5,
                           color: const Color(0xFF365314), // lime-900
                         ),
                       ),
                     ),
                   ),
                 ),
               ],
             )
          ],
        ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
      ],
    );
  }

  Widget _buildChoiceGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildChoiceCard(context, 'Part 1', Icons.local_fire_department_rounded, 'Glow', '"Glüh-"', Colors.amber)),
        const SizedBox(width: 16),
        Expanded(child: _buildChoiceCard(context, 'Part 2', Icons.eco_rounded, 'Pear', '"-birne"', Colors.lime)),
      ],
    );
  }

  Widget _buildChoiceCard(BuildContext context, String label, IconData icon, String title, String subtitle, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color[100]!, width: 2),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color[100],
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.splineSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: color[700],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Icon(icon, size: 40, color: color[500]),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.splineSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.textMainLight,
                  height: 1.1,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.splineSans(
                  fontSize: 12,
                  color: AppTheme.textSubLight.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF8FAFC)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: const [
           BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.1), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.yellow[300]!, Colors.amber[500]!]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.genderFem, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          'FEMININE',
                          style: GoogleFonts.splineSans(
                            color: AppTheme.genderFem,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lightbulb',
                      style: GoogleFonts.splineSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: AppTheme.textMainLight,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'Die Glühbirne',
                      style: GoogleFonts.splineSans(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSubLight,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.green[50], // green-100
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: Colors.green[600], size: 20),
            )
          ],
        ),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    var max = size.height;
    var dashWidth = 5;
    var dashSpace = 3;
    double currentY = 0;

    while (currentY < max) {
      canvas.drawLine(Offset(0, currentY), Offset(0, currentY + dashWidth), paint);
      currentY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class PuzzlePiecePainter extends CustomPainter {
  final bool isLeft;
  final Color colorStart;
  final Color colorEnd;
  final Color borderColor;

  PuzzlePiecePainter({
    required this.isLeft,
    required this.colorStart,
    required this.colorEnd,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colorStart, colorEnd],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    Path path = Path();
    double knobSize = 16.0;
    double radius = 16.0;
    double borderHeight = 4.0;

    if (isLeft) {
      // Start top-left
      path.moveTo(radius, 0);
      path.lineTo(size.width, 0); // No inset for right side yet
      
      // Top-right corner (curved down)
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      
      // Right edge with KNOB (Protrusion)
      path.lineTo(size.width, size.height / 2 - knobSize / 1.5);
      path.cubicTo(
        size.width + knobSize, size.height / 2 - knobSize / 1.5, // Control point 1
        size.width + knobSize, size.height / 2 + knobSize / 1.5, // Control point 2
        size.width, size.height / 2 + knobSize / 1.5 // End point
      );
      path.lineTo(size.width, size.height - radius - borderHeight);
      
      // Bottom-right corner
      path.quadraticBezierTo(size.width, size.height - borderHeight, size.width - radius, size.height - borderHeight);
      
      // Bottom edge
      path.lineTo(radius, size.height - borderHeight);
      // Bottom-left corner
      path.quadraticBezierTo(0, size.height - borderHeight, 0, size.height - borderHeight - radius);
      
      // Left edge
      path.lineTo(0, radius);
      // Top-left corner
      path.quadraticBezierTo(0, 0, radius, 0);
      
    } else {
      // RIGHT PIECE
      // Start top-left (with socket offset)
      path.moveTo(radius, 0);
      path.lineTo(size.width - radius, 0);
      
      // Top-right corner
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      
      // Right edge
      path.lineTo(size.width, size.height - borderHeight - radius);
      
      // Bottom-right corner
      path.quadraticBezierTo(size.width, size.height - borderHeight, size.width - radius, size.height - borderHeight);
      
      // Bottom edge
      path.lineTo(radius, size.height - borderHeight);
      
      // Bottom-left corner
      path.quadraticBezierTo(0, size.height - borderHeight, 0, size.height - borderHeight - radius);
      
      // Left edge with SOCKET (Indentation)
      path.lineTo(0, size.height / 2 + knobSize / 1.5);
      path.cubicTo(
        knobSize, size.height / 2 + knobSize / 1.5, // Control 1 (convex into shape)
        knobSize, size.height / 2 - knobSize / 1.5, // Control 2
        0, size.height / 2 - knobSize / 1.5 // End
      );
      path.lineTo(0, radius);
      
      // Top-left corner
      path.quadraticBezierTo(0, 0, radius, 0);
    }

    path.close();

    // 1. Draw "3D" border (bottom thickness)
    // We shift the path down and draw it with border color
    canvas.drawPath(path.shift(Offset(0, borderHeight)), Paint()..color = borderColor);

    // 2. Draw Shadow (optional, but good for depth)
    canvas.drawShadow(path.shift(Offset(0, 2)), Colors.black.withOpacity(0.1), 4.0, true);

    // 3. Draw Main Shape
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
