enum MediaType { video, audio }

class MediaItem {
  final String id;
  final String title;
  final String path;
  final MediaType type;
  final Duration duration;
  final String? thumbnailPath;
  final DateTime addedDate;

  MediaItem({
    required this.id,
    required this.title,
    required this.path,
    required this.type,
    required this.duration,
    this.thumbnailPath,
    required this.addedDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'path': path,
      'type': type.name,
      'durationMs': duration.inMilliseconds,
      'thumbnailPath': thumbnailPath,
      'addedDate': addedDate.toIso8601String(),
    };
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      title: json['title'] as String,
      path: json['path'] as String,
      type: MediaType.values.byName(json['type'] as String),
      duration: Duration(milliseconds: json['durationMs'] as int),
      thumbnailPath: json['thumbnailPath'] as String?,
      addedDate: DateTime.parse(json['addedDate'] as String),
    );
  }

  MediaItem copyWith({
    String? id,
    String? title,
    String? path,
    MediaType? type,
    Duration? duration,
    String? thumbnailPath,
    DateTime? addedDate,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      addedDate: addedDate ?? this.addedDate,
    );
  }

  bool get isVideo => type == MediaType.video;
  bool get isAudio => type == MediaType.audio;
}
