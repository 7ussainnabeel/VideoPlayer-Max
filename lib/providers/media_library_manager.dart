import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';

class MediaLibraryManager with ChangeNotifier {
  List<MediaItem> _mediaItems = [];
  List<Playlist> _playlists = [];
  bool _isLoading = false;

  List<MediaItem> get mediaItems => _mediaItems;
  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;

  final _uuid = const Uuid();

  MediaLibraryManager() {
    _loadLibrary();
  }

  // Load from SharedPreferences
  Future<void> _loadLibrary() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final mediaJson = prefs.getString('media_library');
      if (mediaJson != null) {
        final List<dynamic> decoded = jsonDecode(mediaJson);
        _mediaItems = decoded.map((item) => MediaItem.fromJson(item)).toList();
      }

      final playlistJson = prefs.getString('playlists');
      if (playlistJson != null) {
        final List<dynamic> decoded = jsonDecode(playlistJson);
        _playlists = decoded.map((item) => Playlist.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint("Error loading library: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save to SharedPreferences
  Future<void> _saveLibrary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('media_library', jsonEncode(_mediaItems.map((e) => e.toJson()).toList()));
      await prefs.setString('playlists', jsonEncode(_playlists.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint("Error saving library: $e");
    }
  }

  // Add Item to Library (copies to local storage first)
  Future<MediaItem?> addMediaItem({
    required String sourcePath,
    required String originalName,
    required MediaType type,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Copy file to App Documents directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final extension = originalName.contains('.') 
          ? originalName.substring(originalName.lastIndexOf('.'))
          : (type == MediaType.video ? '.mp4' : '.mp3');
      
      final newFileName = '${_uuid.v4()}$extension';
      final savedFile = File('${appDir.path}/$newFileName');
      
      await File(sourcePath).copy(savedFile.path);

      // 2. Resolve media duration
      Duration duration = Duration.zero;
      if (type == MediaType.video) {
        final controller = VideoPlayerController.file(savedFile);
        await controller.initialize();
        duration = controller.value.duration;
        await controller.dispose();
      } else {
        final audioPlayer = AudioPlayer();
        final durationRes = await audioPlayer.setFilePath(savedFile.path);
        duration = durationRes ?? Duration.zero;
        await audioPlayer.dispose();
      }

      // 3. Create MediaItem
      final newItem = MediaItem(
        id: _uuid.v4(),
        title: originalName,
        path: savedFile.path,
        type: type,
        duration: duration,
        addedDate: DateTime.now(),
      );

      _mediaItems.insert(0, newItem);
      await _saveLibrary();
      notifyListeners();
      return newItem;
    } catch (e) {
      debugPrint("Error adding media item: $e");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Download File from URL
  Future<MediaItem?> downloadMedia({
    required String url,
    required String fileName,
    required MediaType type,
    Function(double)? onProgress,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final extension = type == MediaType.video ? '.mp4' : '.mp3';
      
      // Ensure file name has extension
      String finalFileName = fileName;
      if (!fileName.endsWith(extension)) {
        finalFileName = '$fileName$extension';
      }

      final tempPath = '${appDir.path}/temp_${_uuid.v4()}$extension';
      
      final dio = Dio();
      await dio.download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // Now add using our standard path copy and duration extraction
      final newItem = await addMediaItem(
        sourcePath: tempPath,
        originalName: finalFileName,
        type: type,
      );

      // Delete the temp downloaded file
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return newItem;
    } catch (e) {
      debugPrint("Error downloading media: $e");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete Media Item
  Future<void> deleteMediaItem(String id) async {
    try {
      final index = _mediaItems.indexWhere((element) => element.id == id);
      if (index != -1) {
        final item = _mediaItems[index];
        // 1. Delete physical file
        final file = File(item.path);
        if (await file.exists()) {
          await file.delete();
        }
        
        // 2. Remove from playlists
        for (var i = 0; i < _playlists.length; i++) {
          final updatedItems = List<MediaItem>.from(_playlists[i].items)
            ..removeWhere((e) => e.id == id);
          _playlists[i] = _playlists[i].copyWith(items: updatedItems);
        }

        // 3. Remove from library list
        _mediaItems.removeAt(index);
        await _saveLibrary();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error deleting media item: $e");
    }
  }

  // Create Playlist
  Future<void> createPlaylist(String name) async {
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name,
      items: [],
    );
    _playlists.add(playlist);
    await _saveLibrary();
    notifyListeners();
  }

  // Add Item to Playlist
  Future<void> addMediaToPlaylist(String playlistId, MediaItem item) async {
    final index = _playlists.indexWhere((element) => element.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      if (!playlist.items.any((e) => e.id == item.id)) {
        final updatedItems = List<MediaItem>.from(playlist.items)..add(item);
        _playlists[index] = playlist.copyWith(items: updatedItems);
        await _saveLibrary();
        notifyListeners();
      }
    }
  }

  // Remove Item from Playlist
  Future<void> removeMediaFromPlaylist(String playlistId, String itemId) async {
    final index = _playlists.indexWhere((element) => element.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      final updatedItems = List<MediaItem>.from(playlist.items)
        ..removeWhere((e) => e.id == itemId);
      _playlists[index] = playlist.copyWith(items: updatedItems);
      await _saveLibrary();
      notifyListeners();
    }
  }

  // Delete Playlist
  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((e) => e.id == playlistId);
    await _saveLibrary();
    notifyListeners();
  }
}
