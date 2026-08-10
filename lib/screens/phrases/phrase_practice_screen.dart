import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/german_phrase.dart';
import '../../services/phrase_service.dart';
import '../../services/profile_service.dart';
import '../../services/sound_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/capped_width.dart';

class PhrasePracticeScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialLevel;
  final bool autoPlayAudio;
  final List<PhraseExercise>? initialExercises;

  const PhrasePracticeScreen({
    super.key,
    this.initialCategory,
    this.initialLevel,
    this.autoPlayAudio = true,
    this.initialExercises,
  });

  @override
  State<PhrasePracticeScreen> createState() => _PhrasePracticeScreenState();
}

class _PhrasePracticeScreenState extends State<PhrasePracticeScreen> {
  static const int _sessionTotal = 10;

  List<PhraseExercise> _exercises = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isAnswered = false;
  bool _isCorrect = false;
  String? _selectedOption;
  bool _isSessionCompleted = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _startNewSession(isInitial: true);
    }
  }

  void _startNewSession({bool isInitial = false}) {
    List<PhraseExercise> exercises = [];
    if (widget.initialExercises != null && widget.initialExercises!.isNotEmpty) {
      exercises = widget.initialExercises!;
    } else {
      final phraseService = Provider.of<PhraseService>(context, listen: false);
      if (!phraseService.isInitialized) {
        phraseService.init().then((_) {
          if (mounted) _startNewSession();
        });
        return;
      }

      exercises = phraseService.generatePracticeSession(
        count: _sessionTotal,
        category: widget.initialCategory,
        level: widget.initialLevel,
      );
    }

    if (isInitial) {
      _exercises = exercises;
      _currentIndex = 0;
      _score = 0;
      _isAnswered = false;
      _isCorrect = false;
      _selectedOption = null;
      _isSessionCompleted = false;
    } else {
      setState(() {
        _exercises = exercises;
        _currentIndex = 0;
        _score = 0;
        _isAnswered = false;
        _isCorrect = false;
        _selectedOption = null;
        _isSessionCompleted = false;
      });
    }

    if (widget.autoPlayAudio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _exercises.isNotEmpty &&
            _exercises[_currentIndex].type == PhraseExerciseType.audioListening) {
          _playCurrentAudio();
        }
      });
    }
  }

  void _playCurrentAudio() {
    if (_currentIndex < _exercises.length) {
      final current = _exercises[_currentIndex];
      try {
        TtsService().speak(current.targetPhrase.german);
      } catch (_) {}
    }
  }

  void _handleAnswer(String option) {
    if (_isAnswered || _currentIndex >= _exercises.length) return;

    final current = _exercises[_currentIndex];
    final isCorrect = option == current.correctAnswer;

    setState(() {
      _selectedOption = option;
      _isAnswered = true;
      _isCorrect = isCorrect;
      if (isCorrect) {
        _score++;
      }
    });

    ProfileService().recordActivityToday(review: true);

    if (isCorrect) {
      SoundService().playCorrect();
    } else {
      SoundService().playIncorrect();
    }
  }

  void _nextQuestion() {
    if (_currentIndex + 1 >= _exercises.length) {
      setState(() {
        _isSessionCompleted = true;
      });
      SoundService().playLevelUp();
    } else {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _isCorrect = false;
        _selectedOption = null;
      });

      if (_exercises[_currentIndex].type == PhraseExerciseType.audioListening) {
        _playCurrentAudio();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF181614) : const Color(0xFFFAF6F0);
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final rustAccent = const Color(0xFF8C2D19);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          'Phrasen-Trainer',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
        ),
      ),
      body: CappedWidth(
        child: _exercises.isEmpty
            ? Center(
                child: Text(
                  'No practice questions available for this category.',
                  style: TextStyle(color: inkColor),
                ),
              )
            : _isSessionCompleted
                ? _buildCompletionScreen(context, inkColor, rustAccent)
                : _buildExerciseView(context, isDark, inkColor, rustAccent),
      ),
    );
  }

  Widget _buildExerciseView(
    BuildContext context,
    bool isDark,
    Color inkColor,
    Color rustAccent,
  ) {
    final current = _exercises[_currentIndex];
    final progress = (_currentIndex + 1) / _exercises.length;

    return Column(
      children: [
        // Bauhaus Progress Bar
        Container(
          height: 4,
          width: double.infinity,
          color: inkColor.withValues(alpha: 0.1),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(color: rustAccent),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Meta
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'QUESTION ${_currentIndex + 1} OF ${_exercises.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: rustAccent,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: rustAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Score: $_score',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: rustAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Question Prompt
                Text(
                  current.prompt,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: inkColor,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),

                // Speaker / Context Card (if present)
                if (current.speakerContext != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF241F1A)
                          : const Color(0xFFF3ECE0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: inkColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.record_voice_over_rounded,
                            size: 20, color: rustAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            current.speakerContext!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: inkColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up_rounded, size: 20),
                          onPressed: () {
                            if (current.targetPhrase.dialogue != null) {
                              TtsService().speak(
                                  current.targetPhrase.dialogue!.speakerA);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Audio Button for Audio Type
                if (current.type == PhraseExerciseType.audioListening) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rustAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        icon: const Icon(Icons.volume_up_rounded, size: 24),
                        label: const Text(
                          'Listen Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _playCurrentAudio,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Multiple Choice Options
                ...current.options.map((option) {
                  final isSelected = _selectedOption == option;
                  final isCorrectOption = option == current.correctAnswer;

                  Color optionBg = isDark
                      ? const Color(0xFF221E1A)
                      : const Color(0xFFFAF6F0);
                  Color borderColor = inkColor.withValues(alpha: 0.2);
                  Color textColor = inkColor;

                  if (_isAnswered) {
                    if (isCorrectOption) {
                      optionBg = const Color(0xFF2E7D32).withValues(alpha: 0.15);
                      borderColor = const Color(0xFF2E7D32);
                      textColor = isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);
                    } else if (isSelected) {
                      optionBg = const Color(0xFFC62828).withValues(alpha: 0.15);
                      borderColor = const Color(0xFFC62828);
                      textColor = isDark ? const Color(0xFFEF9A9A) : const Color(0xFFB71C1C);
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: _isAnswered ? null : () => _handleAnswer(option),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: optionBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: borderColor,
                            width: isSelected || (_isAnswered && isCorrectOption)
                                ? 2
                                : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (_isAnswered && isCorrectOption)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF2E7D32),
                              )
                            else if (_isAnswered && isSelected)
                              const Icon(
                                Icons.cancel_rounded,
                                color: Color(0xFFC62828),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Explanation Banner after answer
                if (_isAnswered) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isCorrect
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                          : const Color(0xFFBB3E03).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _isCorrect
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                            : const Color(0xFFBB3E03).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCorrect ? 'EXCELLENT!' : 'CORRECT ANSWER:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: _isCorrect
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFBB3E03),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current.explanation,
                          style: TextStyle(
                            fontSize: 13,
                            color: inkColor.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom Continue Button
        if (_isAnswered)
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: rustAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _nextQuestion,
                child: Text(
                  _currentIndex + 1 >= _exercises.length
                      ? 'FINISH SESSION'
                      : 'CONTINUE',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompletionScreen(
    BuildContext context,
    Color inkColor,
    Color rustAccent,
  ) {
    final pct = (_score / _exercises.length * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: rustAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: rustAccent, width: 2),
              ),
              child: Icon(
                pct >= 70 ? Icons.emoji_events_rounded : Icons.thumb_up_rounded,
                size: 40,
                color: rustAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SESSION COMPLETE!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: rustAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score / ${_exercises.length} Correct ($pct%)',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: inkColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              pct >= 80
                  ? 'Ausgezeichnet! You have strong situational German phrasing skills.'
                  : 'Gute Arbeit! Keep practicing to master authentic German expressions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: inkColor.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: inkColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: inkColor.withValues(alpha: 0.3)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Catalog'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: rustAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _startNewSession,
                    child: const Text('Practice Again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
