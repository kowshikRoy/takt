import 'package:flutter/material.dart';
import 'processing_status.dart';
import 'subtitle_cue.dart';

class ProcessedVideo {
  final String id;
  final String? taskId;
  final String url;
  final ProcessingStatus status;
  final String? stageMessage;
  final String? errorMessage;
  final int progressPercentage;
  final List<SubtitleCue> subtitles;
  final String? videoUrl;
  final String mediaType;
  final String? thumbnail;
  final String? title;

  static String? extractYouTubeThumbnail(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (id != null && id.isNotEmpty) return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
      }
      if (uri.pathSegments.contains('shorts')) {
        final idx = uri.pathSegments.indexOf('shorts');
        if (idx + 1 < uri.pathSegments.length) {
          final id = uri.pathSegments[idx + 1];
          if (id.isNotEmpty) return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
        }
      }
      if (uri.queryParameters.containsKey('v')) {
        final id = uri.queryParameters['v'];
        if (id != null && id.isNotEmpty) return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
      }
    } catch (_) {}
    return null;
  }

  String get effectiveThumbnail {
    if (thumbnail != null && thumbnail!.isNotEmpty && !thumbnail!.contains('picsum.photos')) {
      return thumbnail!;
    }
    final ytThumb = extractYouTubeThumbnail(url);
    if (ytThumb != null && ytThumb.isNotEmpty) {
      return ytThumb;
    }
    final hash = id.hashCode.abs() % 1000;
    return 'https://picsum.photos/seed/$hash/400/225';
  }

  String get thumbnailUrl => effectiveThumbnail;

  String get effectiveTitle {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return 'YouTube Lesson';
    }
    return 'Media Lesson';
  }

  int get effectiveProgress {
    if (status == ProcessingStatus.completed) return 100;
    if (status == ProcessingStatus.failed) return 0;
    if (progressPercentage > 0) return progressPercentage;
    final msg = (stageMessage ?? '').toLowerCase();
    if (msg.contains('cache')) return 10;
    if (msg.contains('subtitle') || msg.contains('caption')) return 25;
    if (msg.contains('title') || msg.contains('thumbnail')) return 40;
    if (msg.contains('download')) return 55;
    if (msg.contains('analyz') || msg.contains('format')) return 70;
    if (msg.contains('whisper') || msg.contains('transcrib')) return 85;
    if (msg.contains('finaliz')) return 95;
    return 30;
  }

  IconData get statusIcon {
    if (status == ProcessingStatus.completed) return Icons.check_circle_rounded;
    if (status == ProcessingStatus.failed) return Icons.error_outline_rounded;
    final msg = (stageMessage ?? '').toLowerCase();
    if (msg.contains('cache') || msg.contains('connect')) return Icons.link_rounded;
    if (msg.contains('subtitle') || msg.contains('caption')) return Icons.subtitles_rounded;
    if (msg.contains('title') || msg.contains('thumbnail')) return Icons.info_outline_rounded;
    if (msg.contains('download') || msg.contains('audio')) return Icons.cloud_download_rounded;
    if (msg.contains('analyz') || msg.contains('format')) return Icons.graphic_eq_rounded;
    if (msg.contains('whisper') || msg.contains('transcrib')) return Icons.auto_awesome_rounded;
    if (msg.contains('finaliz')) return Icons.check_circle_outline_rounded;
    return Icons.sync_rounded;
  }

  String get statusShortLabel {
    if (status == ProcessingStatus.completed) return 'Ready';
    if (status == ProcessingStatus.failed) return 'Failed';
    final msg = (stageMessage ?? '').toLowerCase();
    if (msg.contains('cache') || msg.contains('connect')) return 'Connecting';
    if (msg.contains('subtitle') || msg.contains('caption')) return 'Captions';
    if (msg.contains('title') || msg.contains('thumbnail')) return 'Metadata';
    if (msg.contains('download') || msg.contains('audio')) return 'Downloading';
    if (msg.contains('analyz') || msg.contains('format')) return 'Analyzing';
    if (msg.contains('whisper') || msg.contains('transcrib')) return 'AI Transcribing';
    if (msg.contains('finaliz')) return 'Finalizing';
    return 'Processing';
  }

  ProcessedVideo({
    required this.id,
    this.taskId,
    required this.url,
    required this.status,
    this.stageMessage,
    this.errorMessage,
    this.progressPercentage = 0,
    required this.subtitles,
    this.videoUrl,
    this.mediaType = 'video',
    this.thumbnail,
    this.title,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'url': url,
      'status': status.name,
      'stageMessage': stageMessage,
      'errorMessage': errorMessage,
      'progressPercentage': progressPercentage,
      'subtitles': subtitles.map((s) => {
        'start': s.start,
        'end': s.end,
        'original': s.original,
        'translated': s.translated,
      }).toList(),
      'videoUrl': videoUrl,
      'mediaType': mediaType,
      'thumbnail': thumbnail,
      'title': title,
    };
  }

  factory ProcessedVideo.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String?)?.toLowerCase();
    ProcessingStatus statusEnum = ProcessingStatus.processing;
    if (statusStr == 'completed') {
      statusEnum = ProcessingStatus.completed;
    } else if (statusStr == 'failed') {
      statusEnum = ProcessingStatus.failed;
    } else if (statusStr == 'downloading') {
      statusEnum = ProcessingStatus.downloading;
    } else if (statusStr == 'transcribing') {
      statusEnum = ProcessingStatus.transcribing;
    } else if (statusStr == 'translating') {
      statusEnum = ProcessingStatus.translating;
    } else if (statusStr == 'finalizing') {
      statusEnum = ProcessingStatus.finalizing;
    }

    final subList = (json['subtitles'] as List<dynamic>? ?? []).map((cue) {
      return SubtitleCue(
        start: (cue['start'] as num).toDouble(),
        end: (cue['end'] as num).toDouble(),
        original: cue['original'] as String,
        translated: cue['translated'] as String,
      );
    }).toList();

    return ProcessedVideo(
      id: json['id'] as String,
      taskId: json['taskId'] as String?,
      url: json['url'] as String,
      status: statusEnum,
      stageMessage: json['stageMessage'] as String?,
      errorMessage: json['errorMessage'] as String?,
      progressPercentage: (json['progressPercentage'] as num?)?.toInt() ?? 0,
      subtitles: subList,
      videoUrl: json['videoUrl'] as String?,
      mediaType: json['mediaType'] as String? ?? 'video',
      thumbnail: json['thumbnail'] as String?,
      title: json['title'] as String?,
    );
  }
}
