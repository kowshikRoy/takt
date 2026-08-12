import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/article_model.dart';


class CompactArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final VoidCallback? onMore;  // Optional: opens the same long-press/3-dot action sheet media items use
  final double width;

  const CompactArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    this.onMore,  // Optional
    this.width = 160,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onMore,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Badge
            Stack(
              children: [
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: article.imageUrl.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: article.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) {
                            return Image.asset('assets/images/story_desert.png', fit: BoxFit.cover);
                          },
                        )
                      : Image.asset(
                          article.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset('assets/images/story_desert.png', fit: BoxFit.cover);
                          },
                        ),
                ),
                // Level badge (hide for imported articles)
                if (article.level != 'Imported')
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        article.level,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // 3-dot action button (if onMore provided) — same affordance as the media
                // library's action sheet trigger, for a consistent long-press-or-tap UX.
                if (onMore != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onMore,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
