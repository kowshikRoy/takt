import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Renders an [Article.imageUrl] regardless of its source: a bundled asset
/// path, a network URL, or a `data:image/...;base64,...` URI (used by
/// AI-generated story thumbnails, since there's no server to host those).
class ArticleThumbnail extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const ArticleThumbnail({super.key, required this.imageUrl, this.fit = BoxFit.cover});

  static const _fallbackAsset = 'assets/images/story_desert.png';

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Part = imageUrl.substring(imageUrl.indexOf(',') + 1);
        return Image.memory(
          base64Decode(base64Part),
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Image.asset(_fallbackAsset, fit: fit),
        );
      } catch (_) {
        return Image.asset(_fallbackAsset, fit: fit);
      }
    }
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        errorWidget: (context, url, error) => Image.asset(_fallbackAsset, fit: fit),
      );
    }
    return Image.asset(
      imageUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Image.asset(_fallbackAsset, fit: fit),
    );
  }
}
