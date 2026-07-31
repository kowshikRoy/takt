import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:takt/models/processed_video.dart';
import 'package:takt/models/processing_status.dart';
import 'package:takt/models/subtitle_cue.dart';
import 'package:takt/services/on_device_ai_service.dart';
// no hive
import 'package:takt/models/saved_word.dart';
import 'package:takt/services/dictionary_service.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:takt/services/lesson_service.dart';
import 'package:takt/config.dart';

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
  bool _isLoading = false;
  String? _errorMessage;
  List<SubtitleCue> _subtitles = [];
  String? _directVideoUrl;
  final ScrollController _scrollController = ScrollController();
  int _currentSubtitleIndex = -1;
  List<GlobalKey> _subtitleKeys = [];
  late AnimationController _animationController;
  bool _isFullscreen = false;
  double _playbackSpeed = 1.0;
  bool _hideTranslations = false;
  final List<SavedWord> _inMemorySavedWords = [];
  bool _showControls = true;
  Timer? _controlsTimer;

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
    if (_directVideoUrl != null && _directVideoUrl!.isNotEmpty) {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(_directVideoUrl!));
      
      _videoPlayerController!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
          _videoPlayerController?.play();
          _animationController.forward();
        }
      }).catchError((error) {
        print('VideoPlayer initialization error: $error');
        if (mounted) {
          setState(() {
            _errorMessage = 'Media stream expired or invalid format. Tap Refresh Stream to reload.';
          });
        }
      });
      _videoPlayerController?.addListener(_onVideoPlayerUpdate);
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
      final err = _videoPlayerController!.value.errorDescription;
      print('Video player runtime error: $err');
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

    // Update the UI when the video finishes
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
        if (_currentSubtitleIndex != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentSubtitle();
          });
        }
      });
    }
  }

  void _scrollToCurrentSubtitle() {
    if (_currentSubtitleIndex == -1) return;

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
        Uri.parse(
          '${Config.backendUrl}/submit-media',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': _urlController.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final taskId = data['task_id'];

        final processedVideo = ProcessedVideo(id: taskId ?? "task_1", status: ProcessingStatus.processing, subtitles: [],
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
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
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          _buildVideoPlayer(),
          if (widget.processedVideo == null) _buildUrlInput(),
          if (_errorMessage != null) _buildErrorMessage(),
          Expanded(
            child: _subtitles.isEmpty
                ? _buildNoSubtitlesMessage()
                : _buildTranscriptList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 12.0, left: 12.0),
      alignment: Alignment.topLeft,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Iconsax.arrow_left, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    double playerHeight;
    bool isPortraitVideo = false;

    if (_videoPlayerController?.value.isInitialized ?? false) {
      final videoAspectRatio = _videoPlayerController!.value.aspectRatio;
      isPortraitVideo = videoAspectRatio < 1.0;

      if (isPortraitVideo) {
        playerHeight = screenHeight * 0.55;
      } else {
        playerHeight = screenWidth * 9 / 16;
      }
    } else {
      playerHeight = screenWidth * 9 / 16;
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
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                final lessonService = Provider.of<LessonService>(context, listen: false);
                                final ok = await lessonService.refreshVideoUrl(
                                  widget.processedVideo!.id,
                                  widget.processedVideo!.url,
                                );
                                if (ok && mounted) {
                                  final index = lessonService.processedVideos.indexWhere((v) => v.id == widget.processedVideo!.id);
                                  if (index != -1) {
                                    _directVideoUrl = lessonService.processedVideos[index].videoUrl;
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
                        // Ambient Blurred Backdrop for side bars on portrait videos
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
                        // Main Video / Audio Player
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
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
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
                                        color: Colors.white.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.graphic_eq_rounded,
                                        size: 48,
                                        color: Color(0xFF2BBAA5),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Audio Media Stream',
                                      style: TextStyle(
                                        color: Colors.white,
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
                          child: _buildVideoHeader(),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: AnimatedOpacity(
                            opacity: _showControls ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: IgnorePointer(
                              ignoring: !_showControls,
                              child: _buildVideoControls(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              _videoPlayerController!.value.isPlaying
                  ? Iconsax.pause
                  : Iconsax.play,
              color: Colors.white,
              size: 22,
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
              colors: const VideoProgressColors(
                playedColor: Color(0xFF6C5CE7),
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
            icon: const Icon(Iconsax.setting_2, color: Colors.white, size: 20),
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
              _isFullscreen ? Iconsax.minus : Iconsax.maximize_3,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Media URL',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 16.0),
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
                : const Icon(Icons.smart_display),
            label: const Text('Process Media'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNoSubtitlesMessage() {
    return const Center(child: Text('No subtitles available.'));
  }

  void _showSavedVocabularySheet() {
    final words = _inMemorySavedWords.reversed.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final words = _inMemorySavedWords.reversed.toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Iconsax.bookmark, color: Color(0xFF6C5CE7)),
                        SizedBox(width: 8),
                        Text(
                          'Saved Vocabulary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: words.isEmpty
                      ? const Center(
                          child: Text(
                            'No saved German words yet.\nTap any German word in the transcript to bookmark it!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          itemCount: words.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = words[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item.germanWord,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Color(0xFF6C5CE7),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.translation,
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                  if (item.contextSentence != null && item.contextSentence!.isNotEmpty)
                                    Text(
                                      'Context: "${item.contextSentence}"',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Iconsax.trash, color: Colors.redAccent, size: 20),
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

  void _showWordInfoDialog(String rawWord, [String contextSentence = ""]) async {
    final cleanedWord = rawWord.replaceAll(RegExp(r'[^\wäöüßÄÖÜ]'), '');
    if (cleanedWord.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
      isScrollControlled: true,
    );

    try {
      String translation = "German Vocabulary Word";
      Map<String, dynamic>? wordData;

      // Primary: Fast local SQLite lookup with base_form resolution
      final localDetails = await DictionaryService().lookupWord(cleanedWord);
      if (localDetails != null && localDetails['definitions'] != null && (localDetails['definitions'] as List).isNotEmpty) {
        wordData = localDetails;
        translation = (localDetails['definitions'] as List).first.toString();
      } else {
        // Fallback: Backend /word-info/
        try {
          final response = await http.get(
            Uri.parse('${Config.backendUrl}/word-info/$cleanedWord'),
          );
          if (response.statusCode == 200) {
            wordData = jsonDecode(response.body);
            if (wordData != null && wordData['definitions'] != null && wordData['definitions'].isNotEmpty) {
              translation = wordData['definitions'][0]['definition'] ?? translation;
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context); // Dismiss loading
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => StatefulBuilder(
            builder: (context, setModalState) {
              final words = _inMemorySavedWords.reversed.toList();
              final bool isSaved = _inMemorySavedWords.any((w) => w.germanWord.toLowerCase() == cleanedWord.toLowerCase());

              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cleanedWord,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Iconsax.bookmark,
                            color: isSaved ? const Color(0xFF6C5CE7) : Colors.grey,
                          ),
                          onPressed: () {
                            if (isSaved) {
                              final existing = _inMemorySavedWords.firstWhere(
                                (w) => w.germanWord.toLowerCase() == cleanedWord.toLowerCase(),
                              );
                              _inMemorySavedWords.remove(existing);
                            } else {
                              _inMemorySavedWords.add(SavedWord(
                                id: cleanedWord.toLowerCase().trim(),
                                word: cleanedWord,
                                primaryDefinition: translation,
                                contextSentence: contextSentence,
                                createdAt: DateTime.now(),
                              ));
                            }
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    if (wordData != null && wordData['base_form'] != null && wordData['base_form'].toString().toLowerCase() != cleanedWord.toLowerCase())
                      Text('Base form: ${wordData['base_form']}', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 14)),
                    const SizedBox(height: 12),
                    if (wordData != null && wordData['definitions'] != null && (wordData['definitions'] as List).isNotEmpty)
                      ...(wordData['definitions'] as List).take(3).map((def) {
                        String defText = def is Map ? (def['definition'] ?? '') : def.toString();
                        String posText = def is Map ? (def['part_of_speech'] ?? '') : (wordData?['pos'] ?? '');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (posText.isNotEmpty)
                                Text(
                                  '($posText)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6C5CE7)),
                                ),
                              Text('• $defText', style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final aiService = OnDeviceAIService();
                              final exp = await aiService.explainWord(cleanedWord, contextSentence);
                              if (mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('✨ Gemini Nano Analysis'),
                                    content: Text(exp),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Iconsax.cpu, size: 16, color: Color(0xFF6C5CE7)),
                            label: const Text('✨ Ask Gemini Nano'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6C5CE7),
                              side: const BorderSide(color: Color(0xFF6C5CE7)),
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
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching word info: $e')),
        );
      }
    }
  }

  Widget _buildTappableLine(String text, TextStyle style) {
    final words = text.split(' ');
    return RichText(
      text: TextSpan(
        children: words.map((word) {
          return WidgetSpan(
            child: GestureDetector(
              onTap: () => _showWordInfoDialog(word, text),
              child: Text(
                '$word ',
                style: style,
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

    if (mounted) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Iconsax.cpu, color: Color(0xFF6C5CE7)),
                  SizedBox(width: 8),
                  Text(
                    'Gemini Nano On-Device AI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
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

  Widget _buildTranscriptList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Transcript",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _hideTranslations ? Iconsax.eye_slash : Iconsax.eye,
                      size: 20,
                      color: _hideTranslations ? const Color(0xFF6C5CE7) : Colors.grey[600],
                    ),
                    tooltip: _hideTranslations ? "Show Translations" : "Hide Translations (Active Recall)",
                    onPressed: () {
                      setState(() {
                        _hideTranslations = !_hideTranslations;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.bookmark, size: 20, color: Color(0xFF6C5CE7)),
                    tooltip: "Saved Vocabulary",
                    onPressed: _showSavedVocabularySheet,
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.cpu, size: 20, color: Color(0xFF6C5CE7)),
                    tooltip: "Gemini Nano AI Summary",
                    onPressed: _showOnDeviceSummaryDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: _subtitles.length,
            itemBuilder: (context, index) {
              final cue = _subtitles[index];
              final bool isCurrent = _currentSubtitleIndex == index;
              return GestureDetector(
                onTap: () => _seekToSubtitle(cue.start),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  key: _subtitleKeys[index],
                  margin: const EdgeInsets.only(bottom: 10.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFFF1F5F9) : Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: isCurrent
                        ? const Border(
                            left: BorderSide(color: Color(0xFF6C5CE7), width: 4.0),
                          )
                        : Border.all(color: Colors.grey.shade200, width: 0.8),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6C5CE7).withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTappableLine(
                        cue.original,
                        TextStyle(
                          fontSize: isCurrent ? 17 : 16,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent ? const Color(0xFF1E1B4B) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      _hideTranslations
                          ? Text(
                              "••••••••••••••••••••",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                                letterSpacing: 2,
                              ),
                            )
                          : _buildTappableLine(
                              cue.translated,
                              TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                color: isCurrent
                                    ? const Color(0xFF6C5CE7)
                                    : Colors.grey.shade600,
                              ),
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
