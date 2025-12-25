import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../models/compound_word.dart';
import '../../services/compound_service.dart';

class CompoundPracticeScreen extends StatefulWidget {
  const CompoundPracticeScreen({super.key});

  @override
  State<CompoundPracticeScreen> createState() => _CompoundPracticeScreenState();
}

class _CompoundPracticeScreenState extends State<CompoundPracticeScreen> {
  final CompoundService _compoundService = CompoundService();
  late CompoundWord _currentWord;
  late List<String> _options;

  bool _isAnswered = false;
  bool _isCorrect = false;
  String? _selectedOption;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _loadNextWord();
  }

  void _loadNextWord() {
    setState(() {
      _currentWord = _compoundService.getRandomWord();
      final distractors = _compoundService.getDistractors(_currentWord.fullMeaning, 3);
      _options = [...distractors, _currentWord.fullMeaning];
      _options.shuffle();

      _isAnswered = false;
      _isCorrect = false;
      _selectedOption = null;
    });
  }

  void _handleAnswer(String answer) {
    if (_isAnswered) return;

    setState(() {
      _selectedOption = answer;
      _isAnswered = true;
      _isCorrect = answer == _currentWord.fullMeaning;
      if (_isCorrect) {
        _score++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 128),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'COMPOUND WORD PUZZLE',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'What does this word mean?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        _buildWordSplitVisual(context),
                        
                        const SizedBox(height: 32),
                        
                        // If answered and correct, show the breakdown.
                        // Otherwise, maybe hide it or show it only on result?
                        // The original design showed it as part of the "learning".
                        // Let's show it only if answered (correct or incorrect) to explain the word.
                        if (_isAnswered) ...[
                            _buildChoiceGrid(context),
                            const SizedBox(height: 16),
                        ] else ...[
                            // Placeholder or empty space if we want to keep layout stable?
                            // No, let's just let it appear.
                        ],
                        
                        if (!_isAnswered)
                          _buildOptionsGrid(context)
                        else
                          _buildResultCard(context),
                        
                        const SizedBox(height: 32),
                        
                        // Hint / Fun Fact
                        if (!_isAnswered)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                            boxShadow: const [
                              BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1))
                            ],
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Hint: ',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(text: 'Combine the meanings of the two parts!'),
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 6, offset: Offset(0, -4))
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isAnswered ? _loadNextWord : null, // Disable if not answered? Or let them exit?
                  // If not answered, button should probably be disabled or "Skip"?
                  // Let's make it "Check" if we selected an option? No, selection is instant.
                  // So only active if answered.
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAnswered ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
                    elevation: _isAnswered ? 4 : 0,
                    shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isAnswered ? 'Continue' : 'Select an answer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isAnswered ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (_isAnswered) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_rounded, size: 24, color: Colors.white),
                      ]
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
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
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
                icon: Icon(Icons.close_rounded, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_score % 10) / 10 + 0.1, // Keep existing logic map
                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                color: Theme.of(context).colorScheme.primary,
                minHeight: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: const [
                BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1)),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$_score',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
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
               top: 50,
               child: SizedBox(
                 width: 200,
                 height: 64,
                 child: Stack(
                   children: [
                     // Left dashed line
                     Positioned(
                       left: 40,
                       top: 0, bottom: 0,
                       child: Transform.rotate(
                         angle: -0.2,
                         child: CustomPaint(
                           size: const Size(2, 64),
                           painter: DashedLinePainter(color: Theme.of(context).colorScheme.secondary),
                         ),
                       ),
                     ),
                     // Right dashed line
                     Positioned(
                       right: 40,
                       top: 0, bottom: 0,
                       child: Transform.rotate(
                         angle: 0.2,
                         child: CustomPaint(
                           size: const Size(2, 64),
                           painter: DashedLinePainter(color: Theme.of(context).colorScheme.tertiary),
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
             ), // Added missing closing parenthesis and comma
             // Word Parts
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 // Part 1
                 CustomPaint(
                   painter: PuzzlePiecePainter(
                     isLeft: true,
                     colorStart: Theme.of(context).colorScheme.secondaryContainer,
                     colorEnd: Theme.of(context).colorScheme.secondaryContainer,
                     borderColor: Theme.of(context).colorScheme.secondary,
                   ),
                   child: Container(
                     padding: const EdgeInsets.fromLTRB(28, 20, 48, 20),
                     child: Text(
                       _currentWord.part1,
                       style: TextStyle(
                         fontSize: 30,
                         fontWeight: FontWeight.bold,
                         letterSpacing: 0.5,
                         color: Theme.of(context).colorScheme.onSecondaryContainer,
                       ),
                     ),
                   ),
                 ),
                 // Part 2
                 Transform.translate(
                   offset: const Offset(-1, 0), // Slight overlap for seamless visual join
                   child: CustomPaint(
                     painter: PuzzlePiecePainter(
                       isLeft: false,
                       colorStart: Theme.of(context).colorScheme.tertiaryContainer,
                       colorEnd: Theme.of(context).colorScheme.tertiaryContainer,
                       borderColor: Theme.of(context).colorScheme.tertiary,
                     ),
                     child: Container(
                       padding: const EdgeInsets.fromLTRB(48, 20, 28, 20),
                       child: Text(
                         _currentWord.part2,
                         style: TextStyle(
                           fontSize: 30,
                           fontWeight: FontWeight.bold,
                           letterSpacing: 0.5,
                           color: Theme.of(context).colorScheme.onTertiaryContainer,
                         ),
                       ),
                     ),
                   ),
                 ),
               ],
             )
          ],
        ).animate(key: ValueKey(_currentWord.fullWord)).scale(duration: 800.ms, curve: Curves.elasticOut),
      ],
    );
  }

  Widget _buildChoiceGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildChoiceCard(
          context, 
          'Part 1', 
          _currentWord.part1Icon ?? Icons.help_outline, 
          _currentWord.part1Meaning, 
          _currentWord.part1Subtitle, 
          Theme.of(context).colorScheme.secondaryContainer,
          Theme.of(context).colorScheme.onSecondaryContainer,
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildChoiceCard(
          context, 
          'Part 2', 
          _currentWord.part2Icon ?? Icons.help_outline, 
          _currentWord.part2Meaning, 
          _currentWord.part2Subtitle, 
          Theme.of(context).colorScheme.tertiaryContainer,
          Theme.of(context).colorScheme.onTertiaryContainer,
        )),
      ],
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }

  Widget _buildChoiceCard(BuildContext context, String label, IconData icon, String title, String subtitle, Color color, Color onColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
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
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: onColor,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Icon(icon, size: 40, color: onColor),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.1,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _options.map((option) {
            final width = (constraints.maxWidth - 12) / 2;
            return SizedBox(
              width: width,
              child: _buildOptionButton(context, option),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOptionButton(BuildContext context, String text) {
    Color backgroundColor = Theme.of(context).cardColor;
    Color textColor = Theme.of(context).colorScheme.onSurface;
    Color borderColor = Theme.of(context).dividerColor;

    if (_isAnswered) {
      if (text == _currentWord.fullMeaning) {
        // Correct Answer
        backgroundColor = Colors.green[50]!;
        borderColor = Colors.green;
        textColor = Colors.green[800]!;
      } else if (text == _selectedOption && text != _currentWord.fullMeaning) {
        // Wrong Selection
        backgroundColor = Colors.red[50]!;
        borderColor = Colors.red;
        textColor = Colors.red[800]!;
      } else {
        // Other options
        textColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
      }
    }

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _isAnswered ? null : () => _handleAnswer(text),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: 300.ms,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: _isAnswered && (text == _currentWord.fullMeaning || text == _selectedOption) ? 2 : 1),
            boxShadow: const [
              BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 2, offset: Offset(0, 1))
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    final color = _isCorrect ? Colors.green : Colors.red;
    final icon = _isCorrect ? Icons.check_rounded : Icons.close_rounded;
    final title = _isCorrect ? 'Correct!' : 'Incorrect';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, const Color(0xFFF8FAFC)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: const [
           BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.1), blurRadius: 15, offset: Offset(0, 10), spreadRadius: -3)
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
                        Theme.of(context).colorScheme.tertiaryContainer,
                        Theme.of(context).colorScheme.tertiary
                      ]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Icon(_currentWord.fullIcon ?? Icons.lightbulb_rounded, color: Theme.of(context).colorScheme.onTertiary, size: 36),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: _getGenderColor(_currentWord.gender), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(
                              _getGenderLabel(_currentWord.gender),
                              style: TextStyle(
                                color: _getGenderColor(_currentWord.gender),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentWord.fullMeaning,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          '${_currentWord.gender} ${_currentWord.fullWord}',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            )
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }

  Color _getGenderColor(String gender) {
    switch (gender.toLowerCase()) {
      case 'die': return AppTheme.genderFem;
      case 'der': return AppTheme.genderMasc;
      case 'das': return AppTheme.genderNeu;
      default: return AppTheme.genderNeu;
    }
  }

  String _getGenderLabel(String gender) {
    switch (gender.toLowerCase()) {
      case 'die': return 'FEMININE';
      case 'der': return 'MASCULINE';
      case 'das': return 'NEUTER';
      default: return 'NEUTER';
    }
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
    
    // Config for standard puzzle tab
    double bumpSize = 16.0;   // How far it sticks out
    double neckSize = 12.0;   // Width at the neck (base)
    double headSize = 22.0;   // Width at the widest part
    
    double radius = 16.0;
    double borderHeight = 0.0; // Flat 2D
    double centerY = size.height / 2;
    
    // Circular Tab Config
    double tabRadius = 12.0;

    if (isLeft) {
      // LEFT PIECE (Has Right Tab)
      path.moveTo(radius, 0);
      path.lineTo(size.width, 0); // Straight line to Top-Right (No corner radius)
      
      // Right edge down to Tab start
      path.lineTo(size.width, centerY - tabRadius);
      
      // Draw Circular Tab (Outwards)
      // arcToPoint uses the end point. We want a semi-circle protruding right.
      path.arcToPoint(
        Offset(size.width, centerY + tabRadius),
        radius: Radius.circular(tabRadius),
        clockwise: true,
      );
      
      path.lineTo(size.width, size.height - borderHeight); // Straight line to Bottom-Right (No corner radius)
      
      // Bottom edge
      path.lineTo(radius, size.height - borderHeight);
      
      // Bottom-left corner
      path.quadraticBezierTo(0, size.height - borderHeight, 0, size.height - borderHeight - radius);
      
      // Left edge
      path.lineTo(0, radius);
      // Top-left corner
      path.quadraticBezierTo(0, 0, radius, 0);
      
    } else {
      // RIGHT PIECE (Has Left Socket)
      path.moveTo(0, 0); // Top-Left starts sharp (0,0) as opposed to (radius, 0)
      path.lineTo(size.width - radius, 0);
      
      // Top-right corner
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      
      // Right edge
      path.lineTo(size.width, size.height - borderHeight - radius);
      
      // Bottom-right corner
      path.quadraticBezierTo(size.width, size.height - borderHeight, size.width - radius, size.height - borderHeight);
      
      // Bottom edge
      path.lineTo(0, size.height - borderHeight); // Bottom-Left ends sharp
      
      // Left edge with SOCKET (Indents Inwards)
      // Drawn Bottom-to-Top
      path.lineTo(0, centerY + tabRadius);
      
      // Socket Shape (Inside)
      // arcToPoint to create inward semi-circle
      path.arcToPoint(
        Offset(0, centerY - tabRadius),
        radius: Radius.circular(tabRadius),
        clockwise: true, // Clockwise from (0, +12) to (0, -12) creates an INWARD arc
      );
      
      path.lineTo(0, 0); // Back to top-left start
    }

    path.close();

    // 1. Draw Main Shape (Fill)
    canvas.drawPath(path, paint);

    // 2. Draw Border Stroke (Boundary)
    // Draw on top to ensure distinct edge
    canvas.drawPath(path, Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
    );

  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
