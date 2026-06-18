import 'package:flutter/services.dart';
import 'media_library_manager.dart';
import 'playback_manager.dart';
import '../models/media_item.dart';

class CarPlayManager {
  static const MethodChannel _channel = MethodChannel('com.videoplayermax.media/carplay');

  static void init() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'getPlaylists':
          return _getPlaylists();
        case 'getPlaylistItems':
          final playlistId = call.arguments['playlistId'] as String;
          return _getPlaylistItems(playlistId);
        case 'getVideos':
          return _getVideos();
        case 'playItem':
          final itemId = call.arguments['itemId'] as String;
          final playlistId = call.arguments['playlistId'] as String?;
          return await _playItem(itemId, playlistId);
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: 'carplay_manager: ${call.method} is not implemented',
          );
      }
    });
  }

  static List<Map<String, dynamic>> _getPlaylists() {
    final library = MediaLibraryManager.instance;
    if (library == null) return [];
    return library.playlists.map((playlist) => {
      'id': playlist.id,
      'name': playlist.name,
      'itemCount': playlist.items.where((item) => item.isVideo).length,
    }).toList();
  }

  static List<Map<String, dynamic>> _getPlaylistItems(String playlistId) {
    final library = MediaLibraryManager.instance;
    if (library == null) return [];
    try {
      final playlist = library.playlists.firstWhere((p) => p.id == playlistId);
      // As requested: "use the playlist and the videos only" -> Filter to videos
      return playlist.items
          .where((item) => item.isVideo)
          .map((item) => {
            'id': item.id,
            'title': item.title,
            'durationMs': item.duration.inMilliseconds,
          }).toList();
    } catch (e) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _getVideos() {
    final library = MediaLibraryManager.instance;
    if (library == null) return [];
    // Only return videos
    return library.mediaItems
        .where((item) => item.isVideo)
        .map((item) => {
          'id': item.id,
          'title': item.title,
          'durationMs': item.duration.inMilliseconds,
        }).toList();
  }

  static Future<bool> _playItem(String itemId, String? playlistId) async {
    final library = MediaLibraryManager.instance;
    final playback = PlaybackManager.instance;
    if (library == null || playback == null) return false;

    List<MediaItem> playQueue = [];
    int startIndex = -1;

    if (playlistId != null) {
      try {
        final playlist = library.playlists.firstWhere((p) => p.id == playlistId);
        playQueue = playlist.items.where((item) => item.isVideo).toList();
        startIndex = playQueue.indexWhere((item) => item.id == itemId);
      } catch (_) {}
    }

    if (startIndex == -1) {
      // Fallback: play from all videos
      playQueue = library.mediaItems.where((item) => item.isVideo).toList();
      startIndex = playQueue.indexWhere((item) => item.id == itemId);
    }

    if (startIndex == -1 || playQueue.isEmpty) return false;

    await playback.setPlaylist(playQueue, startIndex);
    return true;
  }

  static void reloadCarPlay() {
    _channel.invokeMethod('reloadCarPlay').catchError((e) {
      // Silently ignore if CarPlay is not connected
      // print('CarPlay reload error: $e');
    });
  }
}
