import 'package:flutter/material.dart';
import '../../models/shadowing_sentence.dart';
import '../../services/analytics_service.dart';
import '../../services/shadowing_service.dart';
import '../../services/sound_service.dart';
import '../../services/speaking_recording_service.dart';
import '../../services/profile_service.dart';
import '../../services/tts_service.dart';
import '../../services/app_logger.dart';
import '../../widgets/capped_width.dart';

enum _RecordingState { idle, recording, uploading, scored }

/// Shadowing practice: shows a target German sentence, the user records
/// themselves reading it aloud, and gets word-level pronunciation/accuracy
/// feedback back from the OmniScribe backend's Whisper-based scoring.
class SpeakingPracticeScreen extends StatefulWidget {
  const SpeakingPracticeScreen({super.key});

  @override
  State<SpeakingPracticeScreen> createState() => _SpeakingPracticeScreenState();
}

class _SpeakingPracticeScreenState extends State<SpeakingPracticeScreen> {
  static const int _passingScore = 70;

  final ShadowingService _shadowingService = ShadowingService();
  final SpeakingRecordingService _recordingService = SpeakingRecordingService();

  ShadowingSentence? _sentence;
  _RecordingState _state = _RecordingState.idle;
  ShadowingResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNextSentence();
  }

  @override
  void dispose() {
    _recordingService.dispose();
    super.dispose();
  }

  Future<void> _loadNextSentence() async {
    final next = await _shadowingService.randomSentence(excludeId: _sentence?.id);
    if (!mounted) return;
    setState(() {
      _sentence = next;
      _state = _RecordingState.idle;
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _listen() async {
    final sentence = _sentence;
    if (sentence == null) return;
    await TtsService().speak(sentence.german);
  }

  Future<void> _toggleRecording() async {
    if (_state == _RecordingState.recording) {
      await _stopAndScore();
      return;
    }

    final hasPermission = await _recordingService.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Microphone permission is required to practice speaking.');
      return;
    }

    setState(() {
      _state = _RecordingState.recording;
      _errorMessage = null;
    });
    await _recordingService.start();
  }

  Future<void> _stopAndScore() async {
    final sentence = _sentence;
    if (sentence == null) return;

    setState(() => _state = _RecordingState.uploading);

    try {
      final recorded = await _recordingService.stop();
      if (recorded == null) {
        throw Exception('No recording captured');
      }
      final (bytes, filename) = recorded;
      final result = await _recordingService.uploadForScoring(
        bytes: bytes,
        filename: filename,
        targetText: sentence.german,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _state = _RecordingState.scored;
      });

      AnalyticsService.logEvent('speaking_practice_attempt', params: {
        'sentence_id': sentence.id,
        'score': result.score,
      });

      ProfileService().recordActivityToday(review: true);

      if (result.score >= _passingScore) {
        SoundService().playCorrect();
      } else {
        SoundService().playIncorrect();
      }
    } catch (e, st) {
      AppLogger.error('Error scoring shadowing recording', error: e, stackTrace: st, tag: 'SpeakingPractice');
      if (!mounted) return;
      setState(() {
        _state = _RecordingState.idle;
        _errorMessage = 'Could not score recording. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentence = _sentence;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CappedWidth(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: sentence == null
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 128),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'SHADOWING · LEVEL ${sentence.level}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSentenceCard(context, sentence),
                            const SizedBox(height: 24),
                            if (_errorMessage != null) ...[
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.colorScheme.error),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_state == _RecordingState.scored && _result != null)
                              _buildResult(context, _result!)
                            else
                              _buildRecordControl(context),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Text(
            'Sprechen',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceCard(BuildContext context, ShadowingSentence sentence) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.volume_up_rounded, color: theme.colorScheme.primary),
                tooltip: 'Listen',
                onPressed: _listen,
              ),
            ],
          ),
          Text(
            sentence.german,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sentence.english,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordControl(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = _state == _RecordingState.recording;
    final isUploading = _state == _RecordingState.uploading;

    return Column(
      children: [
        GestureDetector(
          onTap: isUploading ? null : _toggleRecording,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
            alignment: Alignment.center,
            child: isUploading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isUploading
              ? 'Scoring your pronunciation…'
              : isRecording
                  ? 'Tap to stop'
                  : 'Tap to record yourself reading the sentence aloud',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, ShadowingResult result) {
    final theme = Theme.of(context);
    final passed = result.score >= _passingScore;

    return Column(
      children: [
        Text(
          '${result.score}%',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: passed ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          passed ? 'Nicely done!' : 'Keep practicing',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: result.targetWords.map((w) => _wordChip(context, w.word, w.status)).toList(),
        ),
        if (result.extraWords.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Also heard: ${result.extraWords.join(' ')}',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loadNextSentence,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Next sentence', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _wordChip(BuildContext context, String word, String status) {
    final theme = Theme.of(context);
    final Color color;
    switch (status) {
      case 'correct':
        color = Colors.green;
        break;
      case 'substituted':
        color = Colors.orange;
        break;
      default:
        color = theme.colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(word, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
