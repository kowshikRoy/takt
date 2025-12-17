import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/article_model.dart';
import '../theme/app_theme.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                image: DecorationImage(
                  image: AssetImage(article.imageUrl), // In real app, NetworkImage
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                   // Gradient overlay for text readability if needed, or just plain image as per design
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: AppTheme.textMainLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSubLight,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildLevelBadge(article.level),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('d MMMM yyyy').format(article.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSubLight,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        article.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: article.isLiked ? Colors.red : AppTheme.textSubLight.withOpacity(0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String level) {
    Color bg;
    Color text;

    // Simple logic for badge colors
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
        bg = Colors.grey[200]!;
        text = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
