import 'processing_status.dart';
import 'subtitle_cue.dart';

class ProcessedVideo {
  final String id;
  final String? taskId;
  final String url;
  final ProcessingStatus status;
  final String? stageMessage;
  final String? errorMessage;
  final List<SubtitleCue> subtitles;
  final String? videoUrl;
  final String mediaType;
  final String? thumbnail;
  final String? title;

  static const String defaultThumbnail = 'assets/images/story_soccer.png';

  String get effectiveThumbnail {
    if (thumbnail != null && thumbnail!.isNotEmpty) {
      return thumbnail!;
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

  ProcessedVideo({
    required this.id,
    this.taskId,
    required this.url,
    required this.status,
    this.stageMessage,
    this.errorMessage,
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
      subtitles: subList,
      videoUrl: json['videoUrl'] as String?,
      mediaType: json['mediaType'] as String? ?? 'video',
      thumbnail: json['thumbnail'] as String?,
      title: json['title'] as String?,
    );
  }
}
