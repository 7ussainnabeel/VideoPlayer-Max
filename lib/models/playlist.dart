import 'media_item.dart';

class Playlist {
  final String id;
  final String name;
  final List<MediaItem> items;

  Playlist({
    required this.id,
    required this.name,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      items: (json['items'] as List<dynamic>)
          .map((itemJson) => MediaItem.fromJson(itemJson as Map<String, dynamic>))
          .toList(),
    );
  }

  Playlist copyWith({
    String? name,
    List<MediaItem>? items,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }
}
