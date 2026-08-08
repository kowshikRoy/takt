import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/media_library_service.dart';
import '../models/processed_video.dart';
import '../models/processing_status.dart';
import '../theme/books_modernist_style.dart';
import 'video_screen.dart';
import 'create/url_import_screen.dart';

class TranscribedMediaGridScreen extends StatefulWidget {
  final String? initialCategory;

  const TranscribedMediaGridScreen({super.key, this.initialCategory});

  @override
  State<TranscribedMediaGridScreen> createState() => _TranscribedMediaGridScreenState();
}

class _TranscribedMediaGridScreenState extends State<TranscribedMediaGridScreen> {
  late String _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _groupByCategory = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'All';
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transcribed Media',
              style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
            ),
            Consumer<MediaLibraryService>(
              builder: (ctx, mediaService, child) {
                final count = mediaService.processedVideos.length;
                return Text(
                  '$count ${count == 1 ? "lesson" : "lessons"} available',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _groupByCategory ? 'Continuous Grid' : 'Group by Category',
            icon: Icon(_groupByCategory ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
            onPressed: () {
              setState(() {
                _groupByCategory = !_groupByCategory;
              });
            },
          ),
          IconButton(
            tooltip: 'Import Media URL',
            icon: const Icon(Icons.add_link_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UrlImportScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<MediaLibraryService>(
        builder: (context, mediaService, child) {
          final allVideos = mediaService.processedVideos;

          if (allVideos.isEmpty) {
            return _buildEmptyState(context);
          }

          // Extract all unique categories with counts
          final Map<String, int> categoryCounts = {};
          int uncategorizedCount = 0;
          for (final video in allVideos) {
            final cat = video.category?.trim();
            if (cat != null && cat.isNotEmpty) {
              final formattedCat = cat.substring(0, 1).toUpperCase() + cat.substring(1).toLowerCase();
              categoryCounts[formattedCat] = (categoryCounts[formattedCat] ?? 0) + 1;
            } else {
              uncategorizedCount++;
            }
          }

          final sortedCategories = categoryCounts.keys.toList()..sort();

          // Filter videos by search and category
          final filteredVideos = allVideos.where((v) {
            // Search filter
            if (_searchQuery.isNotEmpty) {
              final matchesTitle = v.effectiveTitle.toLowerCase().contains(_searchQuery);
              final matchesUrl = v.url.toLowerCase().contains(_searchQuery);
              final matchesCat = (v.category ?? '').toLowerCase().contains(_searchQuery);
              if (!matchesTitle && !matchesUrl && !matchesCat) return false;
            }

            // Category filter
            if (_selectedCategory == 'All') return true;
            if (_selectedCategory == 'Uncategorized') {
              return v.category == null || v.category!.trim().isEmpty;
            }
            return (v.category?.trim().toLowerCase()) == _selectedCategory.toLowerCase();
          }).toList();

          return Column(
            children: [
              // Search Field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by title or topic...',
                    hintStyle: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),

              // Category Filter Bar
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      count: allVideos.length,
                      isSelected: _selectedCategory == 'All',
                      onSelected: () => setState(() => _selectedCategory = 'All'),
                    ),
                    const SizedBox(width: 8),
                    ...sortedCategories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          label: cat,
                          count: categoryCounts[cat] ?? 0,
                          isSelected: _selectedCategory.toLowerCase() == cat.toLowerCase(),
                          onSelected: () => setState(() => _selectedCategory = cat),
                        ),
                      );
                    }),
                    if (uncategorizedCount > 0)
                      _buildFilterChip(
                        label: 'Uncategorized',
                        count: uncategorizedCount,
                        isSelected: _selectedCategory == 'Uncategorized',
                        onSelected: () => setState(() => _selectedCategory = 'Uncategorized'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Content: Grouped by Category or Continuous Grid
              Expanded(
                child: filteredVideos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_list_off_rounded, size: 40, color: colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No lessons found',
                              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try clearing filters or search query',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : _groupByCategory && _selectedCategory == 'All' && _searchQuery.isEmpty
                        ? _buildGroupedCategoryView(context, allVideos, mediaService)
                        : _buildContinuousGridView(context, filteredVideos, mediaService),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.onPrimary.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedCategoryView(
    BuildContext context,
    List<ProcessedVideo> allVideos,
    MediaLibraryService mediaService,
  ) {
    // Group videos by category
    final Map<String, List<ProcessedVideo>> groups = {};
    for (final video in allVideos) {
      final cat = (video.category != null && video.category!.trim().isNotEmpty)
          ? video.category!.trim().toUpperCase()
          : 'UNCATEGORIZED';
      groups.putIfAbsent(cat, () => []).add(video);
    }

    final sortedKeys = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final groupName = sortedKeys[index];
        final videosInGroup = groups[groupName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    groupName,
                    style: BooksModernist.body(
                      size: 12,
                      weight: FontWeight.w800,
                      color: BooksModernist.accentDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${videosInGroup.length})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: videosInGroup.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (context, vIndex) {
                return _buildVideoGridCard(context, videosInGroup[vIndex], mediaService);
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildContinuousGridView(
    BuildContext context,
    List<ProcessedVideo> videos,
    MediaLibraryService mediaService,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: videos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemBuilder: (context, index) {
        return _buildVideoGridCard(context, videos[index], mediaService);
      },
    );
  }

  Widget _buildVideoGridCard(
    BuildContext context,
    ProcessedVideo video,
    MediaLibraryService mediaService,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = video.status == ProcessingStatus.completed;
    final isFailed = video.status == ProcessingStatus.failed;
    final isProcessing = !isCompleted && !isFailed;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(8),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (isCompleted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VideoScreen(processedVideo: video)),
            );
          } else if (isFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(video.errorMessage ?? 'Processing failed. Long-press to retry.'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        onLongPress: () => _showMediaActionSheet(context, video, mediaService),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFailed
                  ? colorScheme.error.withValues(alpha: 0.4)
                  : isProcessing
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isProcessing ? 1.0 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 16:9 Thumbnail with cues badge overlay
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (c, u, e) => Container(
                          color: isFailed
                              ? colorScheme.error.withValues(alpha: 0.12)
                              : colorScheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      // Gradient overlay
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 32,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Top Right 3-Dots Action Button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _showMediaActionSheet(context, video, mediaService),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.more_vert_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Status / Cues badge at bottom
                      Positioned(
                        left: 6,
                        bottom: 4,
                        right: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.subtitles_rounded, size: 10, color: Colors.white),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${video.subtitles.length} cues',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    if (video.estimatedDurationLabel.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      const Text('•', style: TextStyle(fontSize: 8, color: Colors.white70)),
                                      const SizedBox(width: 4),
                                      Text(
                                        video.estimatedDurationLabel,
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            else if (isProcessing)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '${video.effectiveProgress}%',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: colorScheme.error.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'FAILED',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            if (isCompleted)
                              const Icon(Icons.play_circle_filled_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Details Padding
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title
                      Text(
                        video.effectiveTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, height: 1.2),
                      ),

                      // Tags & Status Row
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (video.category != null && video.category!.trim().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                video.category!.trim().toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                          ],
                          Text(
                            isCompleted
                                ? (video.estimatedDurationLabel.isNotEmpty
                                    ? 'Ready • ${video.estimatedDurationLabel}'
                                    : 'Ready to learn')
                                : (video.stageMessage ?? video.statusShortLabel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isFailed ? colorScheme.error : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No Transcribed Media Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Import YouTube videos, Shorts, or audio links to generate interactive synchronized language lessons.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UrlImportScreen()),
                );
              },
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Import Media URL'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaActionSheet(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
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
                          errorWidget: (c, u, e) => Container(color: Colors.grey.shade800),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
                  title: const Text('Edit Title', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
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
                  title: const Text('Set Category', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  trailing: video.category?.isNotEmpty == true
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            video.category!.toUpperCase(),
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer),
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
                  title: const Text('Copy Link', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
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
                  title: const Text('Submit URL Again', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
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
                  title: Text('Delete Lesson', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colorScheme.error)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDeleteVideo(context, video, mediaLibraryService);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditTitleDialog(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
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

  void _showEditCategoryDialog(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
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
                          const Text('Recent Categories:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: recentCategories.map((cat) {
                          final isSelected = selected.toLowerCase() == cat.toLowerCase();
                          return ChoiceChip(
                            label: Text(cat, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
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
                    const Text('Preset Suggestions:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: remainingPresets.map((cat) {
                        final isSelected = selected.toLowerCase() == cat.toLowerCase();
                        return ChoiceChip(
                          label: Text(cat, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
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

  void _confirmDeleteVideo(BuildContext context, ProcessedVideo video, MediaLibraryService mediaLibraryService) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Transcribed Media'),
          content: Text('Are you sure you want to delete "${video.effectiveTitle}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                mediaLibraryService.deleteProcessedVideo(video.id);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
