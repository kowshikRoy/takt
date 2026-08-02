import 'dart:ui';
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
import 'package:provider/provider.dart';
import 'package:takt/services/media_library_service.dart';
import 'package:takt/config.dart';
import 'package:takt/widgets/glance_word_sheet.dart';

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
  bool _isPlayerMinimized = false;
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
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.hasError) {
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
        if (_currentSubtitleIndex != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentSubtitle();
          });
        }
      });
    }
  }

  void _scrollToCurrentSubtitle() {
    if (_currentSubtitleIndex == -1 ||
        _currentSubtitleIndex >= _subtitleKeys.length)
      return;

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
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: 'Back',
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
      body: SafeArea(child: _buildFoldAwareBody(context)),
    );
  }

  /// Detects a vertical fold hinge (book-style foldable, unfolded) via
  /// [MediaQueryData.displayFeatures] and lays the video out to its left
  /// and the subtitle transcript to its right, so neither pane straddles
  /// the hinge itself. Falls back to the normal stacked layout otherwise.
  /// See design doc §7 "Foldable-specific".
  Widget _buildFoldAwareBody(BuildContext context) {
    final videoColumn = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _isPlayerMinimized
          ? _buildMiniPlayer(context)
          : _buildVideoPlayer(context),
    );

    final transcriptContent = _subtitles.isEmpty
        ? _buildNoSubtitlesMessage(context)
        : _buildTranscriptList(context);

    final mediaQuery = MediaQuery.of(context);
    DisplayFeature? hinge;
    for (final feature in mediaQuery.displayFeatures) {
      if (feature.type == DisplayFeatureType.hinge ||
          feature.type == DisplayFeatureType.fold) {
        hinge = feature;
        break;
      }
    }

    final isVerticalHinge =
        hinge != null && hinge.bounds.height >= hinge.bounds.width;

    if (isVerticalHinge) {
      final leftWidth = hinge.bounds.left;
      final rightWidth = mediaQuery.size.width - hinge.bounds.right;
      if (leftWidth > 200 && rightWidth > 200) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftWidth,
              child: Column(
                children: [
                  videoColumn,
                  if (widget.processedVideo == null) _buildUrlInput(context),
                  if (_errorMessage != null) _buildErrorMessage(context),
                ],
              ),
            ),
            SizedBox(
              width: hinge.bounds.width,
            ), // straddle the hinge with empty space, not content
            SizedBox(width: rightWidth, child: transcriptContent),
          ],
        );
      }
    }

    return Column(
      children: [
        videoColumn,
        if (widget.processedVideo == null) _buildUrlInput(context),
        if (_errorMessage != null) _buildErrorMessage(context),
        Expanded(child: transcriptContent),
      ],
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
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'Back',
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
                icon: const Icon(
                  Icons.unfold_less_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
    final totalDuration =
        _videoPlayerController?.value.duration ?? Duration.zero;
    final progress = totalDuration.inMilliseconds > 0
        ? (currentPos.inMilliseconds / totalDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    String currentLine = 'Media Article Mode';
    if (_currentSubtitleIndex != -1 &&
        _currentSubtitleIndex < _subtitles.length) {
      currentLine = _subtitles[_currentSubtitleIndex].original;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: colorScheme.onSurface,
                    size: 20,
                  ),
                  tooltip: 'Back',
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
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                    tooltip: isPlaying ? 'Pause' : 'Play',
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
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
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
                  icon: Icon(
                    Icons.unfold_more_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
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
        playerHeight = screenHeight * 0.45;
      } else {
        playerHeight = screenWidth * 9 / 16;
        if (playerHeight > 340) playerHeight = 340;
      }
    } else {
      playerHeight = screenWidth * 9 / 16;
      if (playerHeight > 340) playerHeight = 340;
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
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.orangeAccent,
                      size: 44,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Media Stream Link Expired',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'YouTube/Media direct streams expire after a few hours.\nRefresh link to stream video again.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    if (widget.processedVideo != null)
                      ElevatedButton.icon(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          _isLoading
                              ? 'Refreshing Link...'
                              : 'Refresh Stream Link',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                final mediaLibraryService =
                                    Provider.of<MediaLibraryService>(
                                      context,
                                      listen: false,
                                    );
                                final ok = await mediaLibraryService
                                    .refreshVideoUrl(
                                      widget.processedVideo!.id,
                                      widget.processedVideo!.url,
                                    );
                                if (ok && mounted) {
                                  final index = mediaLibraryService
                                      .processedVideos
                                      .indexWhere(
                                        (v) =>
                                            v.id == widget.processedVideo!.id,
                                      );
                                  if (index != -1) {
                                    _directVideoUrl = mediaLibraryService
                                        .processedVideos[index]
                                        .videoUrl;
                                    setState(() {
                                      _isLoading = false;
                                      _errorMessage = null;
                                    });
                                    _videoPlayerController?.dispose();
                                    _videoPlayerController =
                                        VideoPlayerController.networkUrl(
                                          Uri.parse(_directVideoUrl!),
                                        );
                                    await _videoPlayerController!.initialize();
                                    _videoPlayerController!.play();
                                    return;
                                  }
                                }
                                if (mounted) {
                                  setState(() {
                                    _isLoading = false;
                                    _errorMessage =
                                        'Could not refresh link. Please check network.';
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
                    if (_videoPlayerController!.value.size.width > 0 &&
                        _videoPlayerController!.value.size.height > 0)
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
                        final hasVideoTrack =
                            (_videoPlayerController?.value.size.width ?? 0) >
                                0 &&
                            (_videoPlayerController?.value.size.height ?? 0) >
                                0;
                        if (hasVideoTrack) {
                          return Center(
                            child: AspectRatio(
                              aspectRatio:
                                  (_videoPlayerController?.value.aspectRatio ??
                                          0) >
                                      0
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
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh,
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
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.graphic_eq_rounded,
                                    size: 48,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Audio Media Stream',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
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
            tooltip: _videoPlayerController!.value.isPlaying ? 'Pause' : 'Play',
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
            initialValue: _playbackSpeed,
            tooltip: '${_playbackSpeed}x Playback Speed',
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
              _isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: Colors.white,
              size: 22,
            ),
            tooltip: _isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bookmark_rounded,
                          color: colorScheme.primary,
                        ),
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
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
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
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: words.length,
                          separatorBuilder: (context, index) =>
                              Divider(color: colorScheme.outlineVariant),
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
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  if (item.contextSentence != null &&
                                      item.contextSentence!.isNotEmpty)
                                    Text(
                                      'Context: "${item.contextSentence}"',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: colorScheme.error,
                                  size: 20,
                                ),
                                tooltip: 'Remove word',
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

  Widget _buildTappableLine(String text, TextStyle style) {
    final words = text.split(' ');
    return RichText(
      text: TextSpan(
        children: words.map((word) {
          return WidgetSpan(
            child: GestureDetector(
              onTap: () => _showWordInfoDialog(word, text),
              child: Text('$word ', style: style),
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
      builder: (context) => const Center(child: CircularProgressIndicator()),
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
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

  Widget _buildTranscriptList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    "Transcript & Article",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_subtitles.length} cues',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _hideTranslations
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: _hideTranslations
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: _hideTranslations
                        ? "Show Translations"
                        : "Hide Translations (Active Recall)",
                    onPressed: () {
                      setState(() {
                        _hideTranslations = !_hideTranslations;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.bookmark_border_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    tooltip: "Saved Vocabulary",
                    onPressed: _showSavedVocabularySheet,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    tooltip: "AI Summary",
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            itemCount: _subtitles.length,
            itemBuilder: (context, index) {
              final cue = _subtitles[index];
              final bool isCurrent = _currentSubtitleIndex == index;
              return GestureDetector(
                onTap: () => _seekToSubtitle(cue.start),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    key: _subtitleKeys[index],
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: isCurrent
                            ? colorScheme.primary
                            : colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: isCurrent ? 1.5 : 0.8,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isCurrent)
                            Container(
                              width: 4,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTappableLine(
                                    cue.original,
                                    TextStyle(
                                      fontSize: isCurrent ? 17 : 16,
                                      height: 1.5,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isCurrent
                                          ? colorScheme.primary
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6.0),
                                  _hideTranslations
                                      ? Text(
                                          "••••••••••••••••••••",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.5),
                                            letterSpacing: 2,
                                          ),
                                        )
                                      : _buildTappableLine(
                                          cue.translated,
                                          TextStyle(
                                            fontSize: 14,
                                            height: 1.4,
                                            fontWeight: isCurrent
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isCurrent
                                                ? colorScheme.primary
                                                      .withValues(alpha: 0.8)
                                                : colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
