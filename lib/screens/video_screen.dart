import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:takt/models/processed_video.dart';
import 'package:takt/models/processing_status.dart';
import 'package:takt/models/subtitle_cue.dart';
import 'package:takt/services/ondevice_ai_service.dart';
import 'package:takt/models/saved_word.dart';
import 'package:takt/services/dictionary_service.dart';
import 'package:takt/services/vocabulary_service.dart';
import 'package:takt/services/tts_service.dart';
import 'package:takt/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:takt/services/media_library_service.dart';
import 'package:takt/config.dart';
import 'package:takt/widgets/glance_word_sheet.dart';
import 'package:takt/l10n/app_localizations.dart';

class KeyMediaVocab {
  final String word;
  final String? baseForm;
  final String? pos;
  final String? gender;
  final String primaryDefinition;
  final String? ipa;
  final int cueIndex;
  final double cueStartTime;
  final String cueOriginal;
  final String cueTranslated;
  final int? freqRank;
  final String difficultyLabel;

  KeyMediaVocab({
    required this.word,
    this.baseForm,
    this.pos,
    this.gender,
    required this.primaryDefinition,
    this.ipa,
    required this.cueIndex,
    required this.cueStartTime,
    required this.cueOriginal,
    required this.cueTranslated,
    this.freqRank,
    this.difficultyLabel = 'B1',
  });

  String get article {
    final g = (gender ?? '').toLowerCase();
    if (g == 'm' || g == 'masculine') return 'der';
    if (g == 'f' || g == 'feminine') return 'die';
    if (g == 'n' || g == 'neuter') return 'das';
    return '';
  }

  String get fullWordWithArticle => article.isNotEmpty ? '$article $word' : word;
}

class VideoScreen extends StatefulWidget {
  final ProcessedVideo? processedVideo;

  const VideoScreen({super.key, this.processedVideo});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  final TextEditingController _urlController = TextEditingController();
  final TtsService _ttsService = TtsService();
  final VocabularyService _vocabService = VocabularyService();

  bool _isLoading = false;
  String? _errorMessage;
  List<SubtitleCue> _subtitles = [];
  String? _directVideoUrl;
  final ScrollController _scrollController = ScrollController();
  int _currentSubtitleIndex = -1;
  List<GlobalKey> _subtitleKeys = [];
  late AnimationController _animationController;
  bool _isFullscreen = false;
  bool _isPlayerMinimized = false;
  double _playbackSpeed = 1.0;
  bool _hideTranslations = true;
  final Set<int> _activeActionCues = {};
  final List<SavedWord> _inMemorySavedWords = [];
  bool _showControls = true;
  Timer? _controlsTimer;

  // Key Vocabulary Extraction State
  List<KeyMediaVocab> _keyVocabList = [];
  bool _isLoadingVocab = false;
  int _activeViewIndex = 0; // 0: Key Vocabulary, 1: Full Transcript Cues
  Set<String> _savedVocabIds = {};

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_videoPlayerController?.value.isPlaying ?? false)) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.processedVideo != null &&
        widget.processedVideo!.status == ProcessingStatus.completed) {
      _loadProcessedVideo();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _loadProcessedVideo() {
    final video = widget.processedVideo;
    if (video == null) return;
    _directVideoUrl = video.videoUrl;
    _subtitles = video.subtitles;
    _subtitleKeys = List.generate(_subtitles.length, (_) => GlobalKey());

    // Extract Key Vocabulary from Subtitle Cues
    _extractKeyVocabulary();

    if (_directVideoUrl != null && _directVideoUrl!.isNotEmpty) {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(_directVideoUrl!),
      );

      _videoPlayerController!
          .initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _errorMessage = null;
              });
              _videoPlayerController?.play();
              _animationController.forward();
            }
          })
          .catchError((error) {
            if (mounted) {
              setState(() {
                _errorMessage =
                    'Media stream expired or invalid format. Tap Refresh Stream to reload.';
              });
            }
          });
      _videoPlayerController?.addListener(_onVideoPlayerUpdate);
    }
  }

  Future<void> _extractKeyVocabulary() async {
    if (_subtitles.isEmpty) return;

    setState(() {
      _isLoadingVocab = true;
    });

    final dictService = DictionaryService();
    final savedWords = await _vocabService.getSavedWords();
    final savedSet = savedWords.map((w) => w.word.toLowerCase().trim()).toSet();

    final Set<String> seenWords = {};
    final List<KeyMediaVocab> extracted = [];

    // Stop words filter
    final stopWords = {
      'der', 'die', 'das', 'dem', 'den', 'des', 'ein', 'eine', 'einen', 'einem',
      'einer', 'eines', 'und', 'oder', 'aber', 'ist', 'sind', 'war', 'waren',
      'in', 'im', 'zu', 'zum', 'zur', 'mit', 'von', 'aus', 'bei', 'nach',
      'über', 'unter', 'vor', 'hinter', 'neben', 'auf', 'an', 'für', 'um',
      'durch', 'gegen', 'ohne', 'nicht', 'ja', 'nein', 'so', 'dass', 'daß',
      'wie', 'als', 'auch', 'noch', 'nur', 'schon', 'mehr', 'sehr', 'viel',
      'ich', 'du', 'er', 'sie', 'es', 'wir', 'ihr', 'mich', 'dich',
      'ihn', 'uns', 'euch', 'ihnen', 'mein', 'dein', 'sein', 'unser',
      'euer', 'sich', 'was', 'wer', 'wo', 'wann', 'warum', 'dies',
      'diese', 'dieser', 'dieses', 'diesen', 'diesem', 'alle', 'alles', 'man'
    };

    for (int cueIdx = 0; cueIdx < _subtitles.length; cueIdx++) {
      final cue = _subtitles[cueIdx];
      final tokens = cue.original
          .replaceAll(RegExp(r'[^\wäöüßÄÖÜ\s-]'), '')
          .split(RegExp(r'\s+'));

      for (final rawToken in tokens) {
        final cleanToken = rawToken.trim();
        final lower = cleanToken.toLowerCase();

        if (cleanToken.length < 3) continue;
        if (stopWords.contains(lower)) continue;
        if (seenWords.contains(lower)) continue;

        // Perform fast dictionary lookup
        final matches = await dictService.lookupWordFast(cleanToken);
        if (matches.isNotEmpty) {
          final first = matches.first;
          final defs = (first['definitions'] as List?) ?? [];
          String def = defs.isNotEmpty ? defs.first.toString() : '';
          if (def.isEmpty && first['definition'] != null) {
            def = first['definition'].toString();
          }
          if (def.isEmpty) continue;

          seenWords.add(lower);

          final pos = (first['pos'] as String? ?? '').toLowerCase();
          final gender = first['gender'] as String?;
          final baseForm = first['base_form'] as String?;
          final ipa = first['ipa'] as String?;
          final freqRank = first['freq_rank'] is int ? first['freq_rank'] as int : null;

          String difficulty = 'B1';
          if (freqRank != null) {
            if (freqRank <= 300) difficulty = 'A1';
            else if (freqRank <= 1000) difficulty = 'A2';
            else if (freqRank <= 3000) difficulty = 'B1';
            else if (freqRank <= 8000) difficulty = 'B2';
            else difficulty = 'C1';
          }

          extracted.add(
            KeyMediaVocab(
              word: first['word'] as String? ?? cleanToken,
              baseForm: baseForm,
              pos: pos,
              gender: gender,
              primaryDefinition: def,
              ipa: ipa,
              cueIndex: cueIdx,
              cueStartTime: cue.start,
              cueOriginal: cue.original,
              cueTranslated: cue.translated,
              freqRank: freqRank,
              difficultyLabel: difficulty,
            ),
          );

          if (extracted.length >= 25) break;
        }
      }
      if (extracted.length >= 25) break;
    }

    if (mounted) {
      setState(() {
        _keyVocabList = extracted;
        _savedVocabIds = savedSet;
        _isLoadingVocab = false;
      });
    }
  }

  Future<void> _toggleSaveVocab(KeyMediaVocab vocab) async {
    final wordId = vocab.word.toLowerCase().trim();
    final isSaved = _savedVocabIds.contains(wordId);

    if (isSaved) {
      await _vocabService.removeWord(wordId);
      setState(() {
        _savedVocabIds.remove(wordId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "${vocab.word}" from Learning Deck')),
        );
      }
    } else {
      final saved = SavedWord(
        id: wordId,
        word: vocab.word,
        baseForm: vocab.baseForm,
        pos: vocab.pos,
        gender: vocab.gender,
        primaryDefinition: vocab.primaryDefinition,
        definitions: [vocab.primaryDefinition],
        ipa: vocab.ipa,
        contextSentence: vocab.cueOriginal,
        sourceTitle: widget.processedVideo?.title ?? 'Media Lesson',
        category: VocabCategory.learning,
      );
      await _vocabService.upsertWord(saved);
      setState(() {
        _savedVocabIds.add(wordId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${vocab.fullWordWithArticle}" to Learning Deck! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _addAllVocabToLearning() async {
    if (_keyVocabList.isEmpty) return;

    int addedCount = 0;
    for (final vocab in _keyVocabList) {
      final wordId = vocab.word.toLowerCase().trim();
      if (!_savedVocabIds.contains(wordId)) {
        final saved = SavedWord(
          id: wordId,
          word: vocab.word,
          baseForm: vocab.baseForm,
          pos: vocab.pos,
          gender: vocab.gender,
          primaryDefinition: vocab.primaryDefinition,
          definitions: [vocab.primaryDefinition],
          ipa: vocab.ipa,
          contextSentence: vocab.cueOriginal,
          sourceTitle: widget.processedVideo?.title ?? 'Media Lesson',
          category: VocabCategory.learning,
        );
        await _vocabService.upsertWord(saved);
        _savedVocabIds.add(wordId);
        addedCount++;
      }
    }

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $addedCount German terms to Learning Deck! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_onVideoPlayerUpdate);
    _videoPlayerController?.dispose();
    _urlController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullscreen() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return;
    }
    final isPortrait = _videoPlayerController!.value.aspectRatio < 1.0;

    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        if (isPortrait) {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    });
  }

  void _onVideoPlayerUpdate() {
    if (!mounted) return;
    if (_videoPlayerController != null && _videoPlayerController!.value.hasError) {
      if (_errorMessage == null) {
        setState(() {
          _errorMessage = 'Media stream error or link expired.';
        });
      }
      return;
    }
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return;
    }

    if (_videoPlayerController!.value.position >=
        _videoPlayerController!.value.duration) {
      setState(() {});
    }

    if (_subtitles.isEmpty) {
      return;
    }

    final currentTime =
        _videoPlayerController!.value.position.inMilliseconds / 1000.0;

    int foundIndex = -1;
    for (int i = 0; i < _subtitles.length; i++) {
      final cue = _subtitles[i];
      if (currentTime >= cue.start && currentTime <= cue.end) {
        foundIndex = i;
        break;
      }
    }

    if (foundIndex != _currentSubtitleIndex) {
      setState(() {
        _currentSubtitleIndex = foundIndex;
        if (_currentSubtitleIndex != -1 && _activeViewIndex == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentSubtitle();
          });
        }
      });
    } else if (_videoPlayerController!.value.isPlaying && _currentSubtitleIndex != -1) {
      setState(() {});
    }
  }

  void _scrollToCurrentSubtitle() {
    if (_currentSubtitleIndex == -1 || _currentSubtitleIndex >= _subtitleKeys.length) return;

    final context = _subtitleKeys[_currentSubtitleIndex].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  Future<void> _processMedia() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${Config.backendUrl}/submit-media'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': _urlController.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final taskId = data['task_id'];

        final processedVideo = ProcessedVideo(
          id: taskId ?? "task_1",
          status: ProcessingStatus.processing,
          subtitles: [],
          url: _urlController.text,
          taskId: taskId,
          mediaType: 'video',
        );
        if (mounted) {
          Navigator.pop(context, processedVideo);
        }
      } else {
        _errorMessage = 'Failed to submit media: ${response.body}';
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _seekToSubtitle(double startTime) {
    _videoPlayerController?.seekTo(
      Duration(milliseconds: (startTime * 1000).toInt()),
    );
    _videoPlayerController?.play();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes);
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                VideoPlayer(_videoPlayerController!),
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                _buildVideoControls(),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isPlayerMinimized ? _buildMiniPlayer(context) : _buildVideoPlayer(context),
            ),
            if (!_isPlayerMinimized && (_videoPlayerController?.value.isInitialized ?? false))
              _buildExternalMediaControlBar(context),
            if (widget.processedVideo == null) _buildUrlInput(context),
            if (_errorMessage != null) _buildErrorMessage(context),
            Expanded(
              child: _subtitles.isEmpty
                  ? _buildNoSubtitlesMessage(context)
                  : _buildTranscriptList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0),
      alignment: Alignment.topLeft,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.unfold_less_rounded, color: Colors.white, size: 22),
                tooltip: 'Minimize to Article Mode',
                onPressed: () {
                  setState(() {
                    _isPlayerMinimized = true;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlaying = _videoPlayerController?.value.isPlaying ?? false;
    final currentPos = _videoPlayerController?.value.position ?? Duration.zero;
    final totalDuration = _videoPlayerController?.value.duration ?? Duration.zero;
    final progress = totalDuration.inMilliseconds > 0
        ? (currentPos.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    String currentLine = 'Media Vocabulary & Insights Mode';
    if (_currentSubtitleIndex != -1 && _currentSubtitleIndex < _subtitles.length) {
      currentLine = _subtitles[_currentSubtitleIndex].original;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                    onPressed: () async {
                      if (_videoPlayerController == null) return;
                      if (isPlaying) {
                        await _videoPlayerController!.pause();
                      } else {
                        await _videoPlayerController!.play();
                      }
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${_formatDuration(currentPos)} / ${_formatDuration(totalDuration)}',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Article Mode',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.unfold_more_rounded, color: colorScheme.primary, size: 22),
                  tooltip: 'Expand Media Player',
                  onPressed: () {
                    setState(() {
                      _isPlayerMinimized = false;
                    });
                  },
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.surfaceContainerHigh,
            color: colorScheme.primary,
            minHeight: 2.5,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    double playerHeight;
    bool isPortraitVideo = false;

    if (_videoPlayerController?.value.isInitialized ?? false) {
      final videoAspectRatio = _videoPlayerController!.value.aspectRatio;
      isPortraitVideo = videoAspectRatio < 1.0;

      if (isPortraitVideo) {
        playerHeight = screenHeight * 0.42;
      } else {
        playerHeight = screenWidth * 9 / 16;
        if (playerHeight > 320) playerHeight = 320;
      }
    } else {
      playerHeight = screenWidth * 9 / 16;
      if (playerHeight > 320) playerHeight = 320;
    }

    return Container(
      height: playerHeight,
      width: screenWidth,
      color: Colors.black,
      child: ClipRect(
        child: _errorMessage != null
            ? Container(
                color: const Color(0xFF1A1D24),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 44),
                    const SizedBox(height: 10),
                    const Text(
                      'Media Stream Link Expired',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'YouTube/Media direct streams expire after a few hours.\nRefresh link to stream video again.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    if (widget.processedVideo != null)
                      ElevatedButton.icon(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(_isLoading ? 'Refreshing Link...' : 'Refresh Stream Link'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                final mediaService = Provider.of<MediaLibraryService>(context, listen: false);
                                final ok = await mediaService.refreshVideoUrl(
                                  widget.processedVideo!.id,
                                  widget.processedVideo!.url,
                                );
                                if (ok && mounted) {
                                  final index = mediaService.processedVideos.indexWhere((v) => v.id == widget.processedVideo!.id);
                                  if (index != -1) {
                                    _directVideoUrl = mediaService.processedVideos[index].videoUrl;
                                    setState(() {
                                      _isLoading = false;
                                      _errorMessage = null;
                                    });
                                    _videoPlayerController?.dispose();
                                    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(_directVideoUrl!));
                                    await _videoPlayerController!.initialize();
                                    _videoPlayerController!.play();
                                    return;
                                  }
                                }
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                    _errorMessage = 'Could not refresh link. Please check network.';
                                  });
                                }
                              },
                      ),
                  ],
                ),
              )
            : (_videoPlayerController?.value.isInitialized ?? false)
                ? GestureDetector(
                    onTap: _toggleControls,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (_videoPlayerController!.value.size.width > 0 && _videoPlayerController!.value.size.height > 0)
                          FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoPlayerController!.value.size.width,
                              height: _videoPlayerController!.value.size.height,
                              child: Opacity(
                                opacity: 0.35,
                                child: VideoPlayer(_videoPlayerController!),
                              ),
                            ),
                          ),
                        Builder(
                          builder: (context) {
                            final hasVideoTrack = (_videoPlayerController?.value.size.width ?? 0) > 0 &&
                                                  (_videoPlayerController?.value.size.height ?? 0) > 0;
                            if (hasVideoTrack) {
                              return Center(
                                child: AspectRatio(
                                  aspectRatio: (_videoPlayerController?.value.aspectRatio ?? 0) > 0 
                                      ? _videoPlayerController!.value.aspectRatio 
                                      : (16 / 9),
                                  child: VideoPlayer(_videoPlayerController!),
                                ),
                              );
                            } else {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primaryContainer,
                                      Theme.of(context).colorScheme.surfaceContainerHigh,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.graphic_eq_rounded,
                                        size: 48,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Audio Media Stream',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildVideoHeader(context),
                        ),
                      ],
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildExternalMediaControlBar(BuildContext context) {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Scrubber and Primary Playback Controls
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  _videoPlayerController!.value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: primaryColor,
                  size: 34,
                ),
                onPressed: () async {
                  if (_videoPlayerController == null) return;
                  if (_videoPlayerController!.value.isPlaying) {
                    await _videoPlayerController!.pause();
                  } else {
                    if (_videoPlayerController!.value.position >=
                        _videoPlayerController!.value.duration) {
                      await _videoPlayerController!.seekTo(Duration.zero);
                    }
                    await _videoPlayerController!.play();
                  }
                  setState(() {});
                },
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder(
                valueListenable: _videoPlayerController!,
                builder: (context, VideoPlayerValue value, child) {
                  return Text(
                    _formatDuration(value.position),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              Expanded(
                child: VideoProgressIndicator(
                  _videoPlayerController!,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  colors: VideoProgressColors(
                    playedColor: primaryColor,
                    bufferedColor: primaryColor.withValues(alpha: 0.25),
                    backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Text(
                _formatDuration(_videoPlayerController!.value.duration),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<double>(
                tooltip: 'Playback Speed',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                onSelected: (speed) {
                  setState(() {
                    _playbackSpeed = speed;
                    _videoPlayerController?.setPlaybackSpeed(speed);
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 0.5, child: Text('0.5x Speed')),
                  const PopupMenuItem(value: 0.75, child: Text('0.75x Speed')),
                  const PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                  const PopupMenuItem(value: 1.25, child: Text('1.25x Speed')),
                  const PopupMenuItem(value: 1.5, child: Text('1.5x Speed')),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  Icons.fullscreen_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                tooltip: 'Fullscreen',
                onPressed: _toggleFullscreen,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Row 2: Subtitle Tools & Navigation (Keywords, Full Subtitles, Translation Toggle, Replay 5s)
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        selected: _activeViewIndex == 0,
                        avatar: Icon(
                          Icons.key_rounded,
                          size: 15,
                          color: _activeViewIndex == 0
                              ? colorScheme.onPrimary
                              : colorScheme.primary,
                        ),
                        label: Text(
                          '${AppLocalizations.of(context)?.titleKeyVocab ?? "Keywords"} (${_keyVocabList.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _activeViewIndex == 0
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                        selectedColor: colorScheme.primary,
                        onSelected: (_) => setState(() => _activeViewIndex = 0),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selected: _activeViewIndex == 1,
                        avatar: Icon(
                          Icons.subtitles_rounded,
                          size: 15,
                          color: _activeViewIndex == 1
                              ? colorScheme.onPrimary
                              : colorScheme.primary,
                        ),
                        label: Text(
                          '${AppLocalizations.of(context)?.titleFullCues ?? "Full Subtitles"} (${_subtitles.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _activeViewIndex == 1
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                        selectedColor: colorScheme.primary,
                        onSelected: (_) => setState(() => _activeViewIndex = 1),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                icon: Icon(
                  Icons.replay_5_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Replay 5s',
                onPressed: () async {
                  if (_videoPlayerController == null) return;
                  final current = _videoPlayerController!.value.position;
                  final target = current - const Duration(seconds: 5);
                  await _videoPlayerController!.seekTo(target < Duration.zero ? Duration.zero : target);
                },
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                icon: Icon(
                  _hideTranslations
                      ? Icons.g_translate_rounded
                      : Icons.translate_rounded,
                  size: 20,
                  color: !_hideTranslations
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                tooltip: _hideTranslations
                    ? (AppLocalizations.of(context)?.actionShowTranslation ?? 'Show Translations')
                    : (AppLocalizations.of(context)?.actionHideTranslation ?? 'Hide Translations'),
                onPressed: () {
                  setState(() {
                    _hideTranslations = !_hideTranslations;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              _videoPlayerController!.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              if (_videoPlayerController == null) return;

              if (_videoPlayerController!.value.isPlaying) {
                await _videoPlayerController!.pause();
              } else {
                if (_videoPlayerController!.value.position >=
                    _videoPlayerController!.value.duration) {
                  await _videoPlayerController!.seekTo(Duration.zero);
                }
                await _videoPlayerController!.play();
                _startControlsTimer();
              }
              setState(() {});
            },
          ),
          ValueListenableBuilder(
            valueListenable: _videoPlayerController!,
            builder: (context, VideoPlayerValue value, child) {
              return Text(
                _formatDuration(value.position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
          Expanded(
            child: VideoProgressIndicator(
              _videoPlayerController!,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              colors: VideoProgressColors(
                playedColor: primaryColor,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
          Text(
            _formatDuration(_videoPlayerController!.value.duration),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<double>(
            icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            onSelected: (speed) {
              setState(() {
                _playbackSpeed = speed;
                _videoPlayerController?.setPlaybackSpeed(speed);
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0.5, child: Text('0.5x Speed')),
              const PopupMenuItem(value: 0.75, child: Text('0.75x Speed')),
              const PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
              const PopupMenuItem(value: 1.25, child: Text('1.25x Speed')),
              const PopupMenuItem(value: 1.5, child: Text('1.5x Speed')),
            ],
          ),
          IconButton(
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Media URL',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              prefixIcon: Icon(Icons.link_rounded, color: colorScheme.primary),
            ),
          ),
          const SizedBox(height: 14.0),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _processMedia,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.smart_display_rounded),
            label: const Text('Process Media'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        _errorMessage!,
        style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNoSubtitlesMessage(BuildContext context) {
    return Center(
      child: Text(
        'No transcript cues available.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  void _showSavedVocabularySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final words = _inMemorySavedWords.reversed.toList();
          final colorScheme = Theme.of(context).colorScheme;

          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bookmark_rounded, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Saved Vocabulary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: words.isEmpty
                      ? Center(
                          child: Text(
                            'No saved German words yet.\nTap any German word in the transcript to bookmark it!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          itemCount: words.length,
                          separatorBuilder: (context, index) => Divider(color: colorScheme.outlineVariant),
                          itemBuilder: (context, index) {
                            final item = words[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item.germanWord,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: colorScheme.primary,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.translation,
                                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                                  ),
                                  if (item.contextSentence != null && item.contextSentence!.isNotEmpty)
                                    Text(
                                      'Context: "${item.contextSentence}"',
                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error, size: 20),
                                onPressed: () {
                                  _inMemorySavedWords.remove(item);
                                  setModalState(() {});
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWordInfoDialog(String rawWord, [String contextSentence = ""]) {
    final cleanedWord = rawWord.replaceAll(RegExp(r'[^\wäöüßÄÖÜ]'), '');
    if (cleanedWord.isEmpty) return;

    GlanceWordSheet.show(
      context,
      word: cleanedWord,
      contextSentence: contextSentence,
      sourceTitle: 'Media Transcript',
    );
  }

  Widget _buildTappableLine(
    String text,
    TextStyle style, {
    bool isCurrentCue = false,
    double cueStart = 0,
    double cueEnd = 0,
  }) {
    final words = text.split(' ');
    int activeWordIndex = -1;

    if (isCurrentCue &&
        _videoPlayerController != null &&
        _videoPlayerController!.value.isPlaying &&
        cueEnd > cueStart) {
      final currentPosSec = _videoPlayerController!.value.position.inMilliseconds / 1000.0;
      if (currentPosSec >= cueStart && currentPosSec <= cueEnd) {
        final progress = (currentPosSec - cueStart) / (cueEnd - cueStart);
        activeWordIndex = (progress * words.length).floor().clamp(0, words.length - 1);
      }
    }

    final colorScheme = Theme.of(context).colorScheme;

    return RichText(
      text: TextSpan(
        children: words.asMap().entries.map((entry) {
          final wordIndex = entry.key;
          final word = entry.value;
          final isHighlighted = isCurrentCue && wordIndex == activeWordIndex;

          return WidgetSpan(
            child: GestureDetector(
              onTap: () => _showWordInfoDialog(word, text),
              child: Container(
                padding: isHighlighted
                    ? const EdgeInsets.symmetric(horizontal: 3, vertical: 1)
                    : EdgeInsets.zero,
                decoration: isHighlighted
                    ? BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: Text(
                  '$word ',
                  style: isHighlighted
                      ? style.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        )
                      : style,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showOnDeviceSummaryDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final aiService = OnDeviceAIService();
    final summary = await aiService.summarizeTranscript(_subtitles);
    final colorScheme = Theme.of(context).colorScheme;

    if (mounted) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'AI Smart Transcript Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: TextStyle(fontSize: 15, height: 1.5, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _startMediaVocabPracticeSheet() {
    if (_keyVocabList.isEmpty) return;
    int practiceIndex = 0;
    bool showAnswer = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final colorScheme = Theme.of(context).colorScheme;
          final item = _keyVocabList[practiceIndex];
          final isSaved = _savedVocabIds.contains(item.word.toLowerCase().trim());

          Color genderColor = colorScheme.primary;
          if (item.gender == 'm' || item.gender == 'masculine') genderColor = AppTheme.genderMasc;
          if (item.gender == 'f' || item.gender == 'feminine') genderColor = AppTheme.genderFem;
          if (item.gender == 'n' || item.gender == 'neuter') genderColor = AppTheme.genderNeu;

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology_rounded, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Practice Media Deck',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                    Text(
                      '${practiceIndex + 1} of ${_keyVocabList.length}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (practiceIndex + 1) / _keyVocabList.length,
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 24),

                // Flashcard Area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (item.article.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: genderColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  item.article,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: genderColor),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Text(
                              item.word,
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            ),
                            IconButton(
                              icon: Icon(Icons.volume_up_rounded, color: colorScheme.primary),
                              onPressed: () => _ttsService.speak(item.fullWordWithArticle, lang: 'de-DE'),
                            ),
                          ],
                        ),
                        if (item.ipa != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.ipa!,
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (!showAnswer)
                          OutlinedButton.icon(
                            onPressed: () => setSheetState(() => showAnswer = true),
                            icon: const Icon(Icons.flip_rounded),
                            label: const Text('Reveal Meaning & Context'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          )
                        else ...[
                          Text(
                            item.primaryDefinition,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '"${item.cueOriginal}"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.cueTranslated,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Navigation & Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleSaveVocab(item),
                        icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                        label: Text(isSaved ? 'Saved' : 'Bookmark'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (practiceIndex < _keyVocabList.length - 1) {
                            setSheetState(() {
                              practiceIndex++;
                              showAnswer = false;
                            });
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🎉 Media Vocabulary Practice Completed!')),
                            );
                          }
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(practiceIndex < _keyVocabList.length - 1 ? 'Next Word' : 'Finish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeyVocabularyView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoadingVocab) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Extracting key vocabulary...',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_keyVocabList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No key vocabulary extracted yet.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _extractKeyVocabulary,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Extract Vocabulary'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        // Minimalist Header Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppLocalizations.of(context)?.titleKeyVocab ?? "Key Vocabulary"} (${_keyVocabList.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)?.subtitleKeyVocab ?? 'Important German vocabulary from transcript',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addAllVocabToLearning,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        AppLocalizations.of(context)?.actionAddAllToLearning ?? 'Add all to Learning',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: BorderSide(color: colorScheme.primary),
                        foregroundColor: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _startMediaVocabPracticeSheet,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: BorderSide(color: colorScheme.outlineVariant),
                      foregroundColor: colorScheme.onSurface,
                    ),
                    child: Text(
                      AppLocalizations.of(context)?.actionPractice ?? 'Practice',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Vocabulary Cards List
        ..._keyVocabList.map((vocab) {
          Color genderColor = colorScheme.primary;
          if (vocab.gender == 'm' || vocab.gender == 'masculine') genderColor = AppTheme.genderMasc;
          if (vocab.gender == 'f' || vocab.gender == 'feminine') genderColor = AppTheme.genderFem;
          if (vocab.gender == 'n' || vocab.gender == 'neuter') genderColor = AppTheme.genderNeu;

          return Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Word & Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (vocab.article.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: genderColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          vocab.article,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: genderColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        vocab.word,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (vocab.pos != null && vocab.pos!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          vocab.pos!.toUpperCase(),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        vocab.difficultyLabel,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Primary Definition
                Text(
                  vocab.primaryDefinition,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),

                // Context Snippet Card
                GestureDetector(
                  onTap: () => _seekToSubtitle(vocab.cueStartTime),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '"${vocab.cueOriginal}"',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                              ),
                              if (vocab.cueTranslated.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  vocab.cueTranslated,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(Duration(seconds: vocab.cueStartTime.toInt())),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Bottom Actions Toolbar
                Row(
                  children: [
                    InkWell(
                      onTap: () => _ttsService.speak(vocab.fullWordWithArticle, lang: 'de-DE'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.volume_up_rounded, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)?.actionListen ?? 'Listen',
                              style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => GlanceWordSheet.show(
                        context,
                        word: vocab.word,
                        contextSentence: vocab.cueOriginal,
                        sourceTitle: widget.processedVideo?.title ?? 'Media Lesson',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.menu_book_rounded, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)?.actionGrammarForms ?? 'Grammar & Forms',
                              style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _deleteCue(int index) {
    if (index < 0 || index >= _subtitles.length) return;
    setState(() {
      _subtitles.removeAt(index);
      if (index < _subtitleKeys.length) {
        _subtitleKeys.removeAt(index);
      }
      _activeActionCues.remove(index);
    });
    _extractKeyVocabulary();
  }

  void _editCue(int index) async {
    if (index < 0 || index >= _subtitles.length) return;
    final cue = _subtitles[index];
    final originalController = TextEditingController(text: cue.original);
    final translatedController = TextEditingController(text: cue.translated);

    final result = await showModalBottomSheet<SubtitleCue>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        bool isTranslating = false;

        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final colorScheme = Theme.of(sheetContext).colorScheme;

            Future<void> generateTranslation() async {
              final originalText = originalController.text.trim();
              if (originalText.isEmpty) return;

              setModalState(() {
                isTranslating = true;
              });

              try {
                final translation = await DictionaryService().translateSentence(originalText);
                if (translation.isNotEmpty) {
                  translatedController.text = translation;
                }
              } finally {
                setModalState(() {
                  isTranslating = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(sheetContext)?.actionEdit ?? 'Edit Subtitle Cue',
                          style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        TextButton.icon(
                          key: const Key('generate_translation_button'),
                          onPressed: isTranslating ? null : generateTranslation,
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: isTranslating
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: Text(
                            isTranslating ? 'Translating...' : 'Translate',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('edit_cue_original_field'),
                      controller: originalController,
                      autofocus: true,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Original Text',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('edit_cue_translated_field'),
                      controller: translatedController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Translation',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          key: const Key('translate_suffix_icon'),
                          icon: isTranslating
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                              : Icon(Icons.translate_rounded, color: colorScheme.primary),
                          tooltip: 'Generate Translation',
                          onPressed: isTranslating ? null : generateTranslation,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          key: const Key('save_cue_button'),
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                              SubtitleCue(
                                start: cue.start,
                                end: cue.end,
                                original: originalController.text.trim(),
                                translated: translatedController.text.trim(),
                              ),
                            );
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      if (!mounted) return;
      setState(() {
        _subtitles[index] = result;
        _activeActionCues.remove(index);
      });
      _extractKeyVocabulary();
      if (widget.processedVideo != null) {
        try {
          context.read<MediaLibraryService>().updateProcessedVideoSubtitles(
                widget.processedVideo!.id,
                _subtitles,
              );
        } catch (_) {}
      }
    }
  }

  Widget _buildFullTranscriptView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_activeActionCues.isNotEmpty) {
          setState(() {
            _activeActionCues.clear();
          });
        }
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        itemCount: _subtitles.length,
        itemBuilder: (context, index) {
          final cue = _subtitles[index];
          final bool isCurrent = _currentSubtitleIndex == index;
          final bool isActionsVisible = _activeActionCues.contains(index);

          return GestureDetector(
            onTap: () => _seekToSubtitle(cue.start),
            onLongPress: () {
              setState(() {
                if (_activeActionCues.contains(index)) {
                  _activeActionCues.remove(index);
                } else {
                  _activeActionCues.add(index);
                }
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                key: _subtitleKeys[index],
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: isActionsVisible
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: isActionsVisible ? 1.5 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTappableLine(
                        cue.original,
                        TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        isCurrentCue: isCurrent,
                        cueStart: cue.start,
                        cueEnd: cue.end,
                      ),
                      if (!_hideTranslations) ...[
                        const SizedBox(height: 6.0),
                        _buildTappableLine(
                          cue.translated,
                          TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (isActionsVisible) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => _editCue(index),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 14, color: colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context)?.actionEdit ?? 'Edit',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(height: 12, width: 1, color: colorScheme.outlineVariant),
                              InkWell(
                                onTap: () => _deleteCue(index),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context)?.actionDelete ?? 'Delete',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildTranscriptList(BuildContext context) {
    final showInternalBar = _isPlayerMinimized || (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized);

    if (showInternalBar) {
      final colorScheme = Theme.of(context).colorScheme;

      return Column(
        children: [
          // Mode Switcher Header Bar for Minimized / Standalone mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          selected: _activeViewIndex == 0,
                          avatar: Icon(
                            Icons.key_rounded,
                            size: 15,
                            color: _activeViewIndex == 0
                                ? colorScheme.onPrimary
                                : colorScheme.primary,
                          ),
                          label: Text(
                            '${AppLocalizations.of(context)?.titleKeyVocab ?? "Keywords"} (${_keyVocabList.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _activeViewIndex == 0
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                            ),
                          ),
                          selectedColor: colorScheme.primary,
                          onSelected: (_) => setState(() => _activeViewIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          selected: _activeViewIndex == 1,
                          avatar: Icon(
                            Icons.subtitles_rounded,
                            size: 15,
                            color: _activeViewIndex == 1
                                ? colorScheme.onPrimary
                                : colorScheme.primary,
                          ),
                          label: Text(
                            '${AppLocalizations.of(context)?.titleFullCues ?? "Full Subtitles"} (${_subtitles.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _activeViewIndex == 1
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                            ),
                          ),
                          selectedColor: colorScheme.primary,
                          onSelected: (_) => setState(() => _activeViewIndex = 1),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _hideTranslations
                        ? Icons.g_translate_rounded
                        : Icons.translate_rounded,
                    size: 20,
                    color: !_hideTranslations
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  tooltip: _hideTranslations
                      ? (AppLocalizations.of(context)?.actionShowTranslation ?? 'Show Translations')
                      : (AppLocalizations.of(context)?.actionHideTranslation ?? 'Hide Translations'),
                  onPressed: () {
                    setState(() {
                      _hideTranslations = !_hideTranslations;
                    });
                  },
                ),
              ],
            ),
          ),

          // Sub View Content
          Expanded(
            child: _activeViewIndex == 0
                ? _buildKeyVocabularyView(context)
                : _buildFullTranscriptView(context),
          ),
        ],
      );
    }

    return _activeViewIndex == 0
        ? _buildKeyVocabularyView(context)
        : _buildFullTranscriptView(context);
  }
}
