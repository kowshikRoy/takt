import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/article_model.dart';
import 'article_thumbnail.dart';


class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final VoidCallback? onDelete;  // Optional delete callback

  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    this.onDelete,  // Optional
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(6.0),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: ArticleThumbnail(imageUrl: article.imageUrl, fit: BoxFit.cover),
                  ),
                  if (onDelete != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _buildLevelBadge(context, article.level),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('d MMM yyyy').format(article.date),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        article.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: article.isLiked ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                    maxLines: 2,
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

  Widget _buildLevelBadge(BuildContext context, String level) {
    Color bg;
    Color text;

    // Adapting to use M3 colors loosely or stick to the semantic colors
    switch (level) {
      case 'A1':
      case 'A2':
        bg = const Color(0xFFDCFCE7); // green-100
        text = const Color(0xFF166534); // green-800
        break;
      case 'B1':
      case 'B2':
        bg = const Color(0xFFFEF9C3); // yellow-100
        text = const Color(0xFF854D0E); // yellow-800
        break;
      case 'C1':
      case 'C2':
        bg = const Color(0xFFFEE2E2); // red-100
        text = const Color(0xFF991B1B); // red-800
        break;
      default:
        bg = Theme.of(context).colorScheme.surfaceContainerHigh;
        text = Theme.of(context).colorScheme.onSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4), // slightly more rounded
      ),
      child: Text(
        level,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: text,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
