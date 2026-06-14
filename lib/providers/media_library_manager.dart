import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;
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

      // Automatically sync iTunes / Finder files on startup
      await syncItunesFiles();
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

  // Sync iTunes / Finder shared files in the Documents directory
  Future<void> syncItunesFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(appDir.path);
      if (!await dir.exists()) return;

      final List<FileSystemEntity> entities = await dir.list().toList();
      final List<File> files = entities.whereType<File>().toList();

      final existingPaths = _mediaItems.map((item) => item.path.toLowerCase()).toSet();
      bool updated = false;

      // 1. Import files that exist on disk but are missing from SharedPreferences
      for (var file in files) {
        final path = file.path;
        final name = file.path.split('/').last;

        // Skip temp downloader files
        if (name.startsWith('temp_')) continue;

        if (existingPaths.contains(path.toLowerCase())) {
          continue;
        }

        // Determine type based on extension
        final nameLower = name.toLowerCase();
        MediaType? type;
        if (nameLower.endsWith('.mp4') || nameLower.endsWith('.mov') || nameLower.endsWith('.avi')) {
          type = MediaType.video;
        } else if (nameLower.endsWith('.mp3') || nameLower.endsWith('.m4a') || nameLower.endsWith('.wav')) {
          type = MediaType.audio;
        }

        if (type != null) {
          // Resolve duration for the manually added file
          Duration duration = Duration.zero;
          try {
            if (type == MediaType.video) {
              final controller = VideoPlayerController.file(file);
              await controller.initialize();
              duration = controller.value.duration;
              await controller.dispose();
            } else {
              final audioPlayer = AudioPlayer();
              final durationRes = await audioPlayer.setFilePath(path);
              duration = durationRes ?? Duration.zero;
              await audioPlayer.dispose();
            }
          } catch (e) {
            debugPrint("Error extracting duration for iTunes file $name: $e");
          }

          final newItem = MediaItem(
            id: _uuid.v4(),
            title: name,
            path: path,
            type: type,
            duration: duration,
            addedDate: DateTime.now(),
          );

          _mediaItems.insert(0, newItem);
          existingPaths.add(path.toLowerCase());
          updated = true;
        }
      }

      // 2. Clean up files in library metadata that no longer exist on disk (deleted from iTunes)
      final List<MediaItem> toRemove = [];
      for (var item in _mediaItems) {
        if (item.path.startsWith(appDir.path)) {
          final file = File(item.path);
          if (!await file.exists()) {
            toRemove.add(item);
          }
        }
      }

      if (toRemove.isNotEmpty) {
        for (var item in toRemove) {
          _mediaItems.removeWhere((e) => e.id == item.id);
          // Also clean up from playlists
          for (var i = 0; i < _playlists.length; i++) {
            final updatedItems = List<MediaItem>.from(_playlists[i].items)
              ..removeWhere((e) => e.id == item.id);
            _playlists[i] = _playlists[i].copyWith(items: updatedItems);
          }
        }
        updated = true;
      }

      if (updated) {
        await _saveLibrary();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error syncing iTunes files: $e");
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

  bool _isYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host.contains('youtube.com') || uri.host.contains('youtu.be');
  }

  // Download File from URL (supports YouTube URLs natively)
  Future<MediaItem?> downloadMedia({
    required String url,
    String? fileName,
    required MediaType type,
    Function(double)? onProgress,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final appDir = await getApplicationDocumentsDirectory();

      if (_isYouTubeUrl(url)) {
        final yt = yt_explode.YoutubeExplode();
        try {
          final video = await yt.videos.get(url);
          final manifest = await yt.videos.streamsClient.getManifest(video.id);

          yt_explode.StreamInfo streamInfo;
          String extension;
          if (type == MediaType.video) {
            if (manifest.muxed.isEmpty) {
              throw Exception("No playable video streams found.");
            }
            streamInfo = manifest.muxed.withHighestBitrate();
            extension = '.mp4';
          } else {
            if (manifest.audioOnly.isEmpty) {
              throw Exception("No playable audio streams found.");
            }
            streamInfo = manifest.audioOnly.withHighestBitrate();
            extension = '.m4a'; // M4A container for YouTube high bitrate audio
          }

          // Determine filename from custom parameter or YouTube metadata
          String finalFileName = fileName ?? '';
          if (finalFileName.isEmpty) {
            finalFileName = video.title;
          }
          // Sanitize filename to remove characters invalid for OS file systems
          finalFileName = finalFileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
          if (!finalFileName.endsWith(extension)) {
            finalFileName = '$finalFileName$extension';
          }

          final tempPath = '${appDir.path}/temp_${_uuid.v4()}$extension';
          final tempFile = File(tempPath);
          final fileStream = tempFile.openWrite();

          final stream = yt.videos.streamsClient.get(streamInfo);
          final totalBytes = streamInfo.size.totalBytes;
          var downloadedBytes = 0;

          await for (final chunk in stream) {
            downloadedBytes += chunk.length;
            fileStream.add(chunk);
            if (totalBytes > 0 && onProgress != null) {
              onProgress(downloadedBytes / totalBytes);
            }
          }

          await fileStream.flush();
          await fileStream.close();

          final newItem = await addMediaItem(
            sourcePath: tempPath,
            originalName: finalFileName,
            type: type,
          );

          if (await tempFile.exists()) {
            await tempFile.delete();
          }

          return newItem;
        } finally {
          yt.close();
        }
      } else {
        final extension = type == MediaType.video ? '.mp4' : '.mp3';
        
        // Ensure file name has extension
        String finalFileName = fileName ?? '';
        if (finalFileName.isEmpty) {
          finalFileName = url.split('/').last;
          if (finalFileName.contains('?')) {
            finalFileName = finalFileName.split('?').first;
          }
        }
        if (finalFileName.isEmpty) {
          finalFileName = 'downloaded_file';
        }
        if (!finalFileName.endsWith(extension)) {
          finalFileName = '$finalFileName$extension';
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
      }
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

  // Reorder Item inside Playlist
  Future<void> reorderPlaylist(String playlistId, int oldIndex, int newIndex) async {
    final index = _playlists.indexWhere((element) => element.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      final updatedItems = List<MediaItem>.from(playlist.items);
      
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = updatedItems.removeAt(oldIndex);
      updatedItems.insert(newIndex, item);
      
      _playlists[index] = playlist.copyWith(items: updatedItems);
      await _saveLibrary();
      notifyListeners();
    }
  }
}
