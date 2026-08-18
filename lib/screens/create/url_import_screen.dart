import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/processing_status.dart';
import '../../services/media_library_service.dart';
import '../video_screen.dart';
import '../transcribed_media_grid_screen.dart';
import '../../widgets/capped_width.dart';

class UrlImportScreen extends StatefulWidget {
  const UrlImportScreen({super.key});

  @override
  State<UrlImportScreen> createState() => _UrlImportScreenState();
}

class _UrlImportScreenState extends State<UrlImportScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String _statusMessage = 'Processing URL...';

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  bool _isMediaUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('facebook.com') ||
        lower.contains('fb.watch') ||
        lower.contains('tiktok.com') ||
        lower.contains('instagram.com') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.webm');
  }

  void _importFromUrl() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL';
      });
      return;
    }

    if (!_isValidUrl(url)) {
      setState(() {
        _errorMessage = 'Please enter a valid HTTP or HTTPS URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Connecting to backend...';
    });

    if (_isMediaUrl(url)) {
      _processMediaUrl(url);
    } else {
      _processWebArticleUrl(url);
    }
  }

  void _processMediaUrl(String url) async {
    final mediaLibraryService = Provider.of<MediaLibraryService>(context, listen: false);
    
    // If the media was already processed and completed, open it immediately
    final existingCompleted = mediaLibraryService.processedVideos.where(
      (v) => v.url.trim().toLowerCase() == url.trim().toLowerCase() && v.status == ProcessingStatus.completed,
    ).firstOrNull;

    if (existingCompleted != null) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(processedVideo: existingCompleted)));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening existing lesson ⚡'),
            backgroundColor: Color(0xFF2C5E3B),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Launch non-blocking background media submission
    unawaited(mediaLibraryService.submitMediaProcessingTaskInBackground(url));

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Media submitted! Transcribing & processing in the background...'),
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _processWebArticleUrl(String url) async {
    final mediaLibraryService = Provider.of<MediaLibraryService>(context, listen: false);
    
    // Launch non-blocking background import task
    unawaited(mediaLibraryService.importWebArticleInBackground(url));

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Article submitted! Importing content in the background...'),
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Import Media or Article',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: CappedWidth(
          maxWidth: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Enter any Video, Audio, or Article URL (YouTube, Facebook Reels, TikTok, MP4/MP3, or Web Articles).',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?... or https://example.com',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              keyboardType: TextInputType.url,
              enabled: !_isLoading,
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _importFromUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Import & Transcribe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Consumer<MediaLibraryService>(
              builder: (context, mediaService, _) {
                final recentVideos = mediaService.processedVideos.take(4).toList();
                if (recentVideos.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RECENT & FAILED IMPORTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TranscribedMediaGridScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View All',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentVideos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final video = recentVideos[idx];
                        final isFailed = video.status == ProcessingStatus.failed;
                        final isCompleted = video.status == ProcessingStatus.completed;
                        final isProcessing = !isFailed && !isCompleted;
                        final colorScheme = Theme.of(context).colorScheme;

                        return Material(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isFailed
                                    ? colorScheme.error.withValues(alpha: 0.4)
                                    : isProcessing
                                        ? colorScheme.primary.withValues(alpha: 0.3)
                                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 44,
                                height: 32,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: video.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Container(
                                        color: isFailed
                                            ? colorScheme.error.withValues(alpha: 0.12)
                                            : colorScheme.primary.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    if (isProcessing)
                                      Container(
                                        color: Colors.black45,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            title: Text(
                              video.effectiveTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              isFailed
                                  ? (video.errorMessage ?? 'Failed · Tap Retry')
                                  : isProcessing
                                      ? '${video.statusShortLabel} · ${video.effectiveProgress}%'
                                      : 'Ready to learn',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isFailed ? colorScheme.error : colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: isFailed
                                ? FilledButton.tonalIcon(
                                    onPressed: () {
                                      _urlController.text = video.url;
                                      mediaService.retryProcessingTask(video.taskId ?? video.id, video.url);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Retrying media transcription...'),
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 14),
                                    label: const Text('Retry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                : isCompleted
                                    ? const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF2C5E3B))
                                    : null,
                            onTap: () {
                              if (isCompleted) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(processedVideo: video)));
                              } else {
                                _urlController.text = video.url;
                              }
                            },
                            onLongPress: () => _showMediaActionSheet(context, video, mediaService),
                          ),
                        ),
                      );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Supported Media & Links',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• YouTube Videos & Shorts\n'
                    '• Facebook Videos & Reels\n'
                    '• TikTok & Instagram Reels\n'
                    '• Direct MP4 / MP3 links\n'
                    '• German & English Web Articles',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
      ),
    ),
  );
}

  void _showMediaActionSheet(BuildContext context, dynamic video, MediaLibraryService mediaLibraryService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with thumbnail, title and URL
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 48,
                        height: 34,
                        child: CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(color: Colors.grey.shade800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.effectiveTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            video.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 4),

                // 1. Edit Title
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: const Icon(Icons.edit_outlined, size: 19),
                  title: const Text('Edit Title', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditTitleDialog(context, video, mediaLibraryService);
                  },
                ),

                // 2. Set Category
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: const Icon(Icons.label_outline_rounded, size: 19),
                  title: const Text('Set Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: video.category?.isNotEmpty == true
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            video.category!.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditCategoryDialog(context, video, mediaLibraryService);
                  },
                ),

                // 3. Copy Link
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: const Icon(Icons.copy_rounded, size: 19),
                  title: const Text('Copy Link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Clipboard.setData(ClipboardData(text: video.url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard!'), duration: Duration(seconds: 2)),
                    );
                  },
                ),

                // 4. Submit URL Again / Re-process
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: Icon(Icons.refresh_rounded, size: 19, color: colorScheme.primary),
                  title: const Text('Submit URL Again', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _urlController.text = video.url;
                    mediaLibraryService.submitMediaProcessingTaskInBackground(video.url);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Re-submitting media for processing...'), duration: Duration(seconds: 3)),
                    );
                  },
                ),

                // 5. Delete Lesson
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: Icon(Icons.delete_outline_rounded, size: 19, color: colorScheme.error),
                  title: Text('Delete Lesson', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.error)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    mediaLibraryService.deleteProcessedVideo(video.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lesson deleted'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditTitleDialog(BuildContext context, dynamic video, MediaLibraryService mediaLibraryService) {
    final controller = TextEditingController(text: video.effectiveTitle);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter lesson title',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            FilledButton(
              child: const Text('Save'),
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  mediaLibraryService.updateVideoDetails(video.id, title: newTitle);
                }
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title updated!'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditCategoryDialog(BuildContext context, dynamic video, MediaLibraryService mediaLibraryService) {
    final defaultCategories = ['Conversation', 'Grammar', 'Vocabulary', 'Travel', 'Stories', 'News', 'Business', 'Pronunciation'];
    final controller = TextEditingController(text: video.category ?? '');

    // Extract recently created custom categories from all videos in user's library
    final recentCategories = <String>[];
    for (final v in mediaLibraryService.processedVideos) {
      final cat = v.category?.trim();
      if (cat != null && cat.isNotEmpty) {
        final formatted = cat.substring(0, 1).toUpperCase() + (cat.length > 1 ? cat.substring(1) : '');
        if (!recentCategories.any((c) => c.toLowerCase() == formatted.toLowerCase())) {
          recentCategories.add(formatted);
        }
      }
    }

    final remainingPresets = defaultCategories
        .where((preset) => !recentCategories.any((r) => r.toLowerCase() == preset.toLowerCase()))
        .toList();
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final selected = controller.text.trim();
            return AlertDialog(
              title: const Text('Set Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recentCategories.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.history_rounded, size: 13, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          const Text('Recent Categories:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: recentCategories.map((cat) {
                          final isSelected = selected.toLowerCase() == cat.toLowerCase();
                          return ChoiceChip(
                            label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                            selected: isSelected,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                            onSelected: (val) {
                              setDialogState(() {
                                controller.text = val ? cat : '';
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Text('Preset Suggestions:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: remainingPresets.map((cat) {
                        final isSelected = selected.toLowerCase() == cat.toLowerCase();
                        return ChoiceChip(
                          label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                          selected: isSelected,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                          onSelected: (val) {
                            setDialogState(() {
                              controller.text = val ? cat : '';
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Or enter custom category',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                FilledButton(
                  child: const Text('Save'),
                  onPressed: () {
                    final newCategory = controller.text.trim();
                    mediaLibraryService.updateVideoDetails(video.id, category: newCategory);
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(newCategory.isNotEmpty ? 'Category set to $newCategory' : 'Category cleared'), duration: const Duration(seconds: 2)),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
