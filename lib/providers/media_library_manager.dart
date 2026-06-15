import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  
  bool _isAppLocked = false;
  String? _appLockPin;
  ThemeMode _themeMode = ThemeMode.system;

  List<MediaItem> get mediaItems => _mediaItems;
  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;

  bool get isAppLocked => _isAppLocked;
  String? get appLockPin => _appLockPin;
  ThemeMode get themeMode => _themeMode;

  final _uuid = const Uuid();

  MediaLibraryManager() {
    _loadLibrary();
  }

  void lockApp() {
    if (_appLockPin != null && _appLockPin!.isNotEmpty) {
      _isAppLocked = true;
      notifyListeners();
    }
  }

  void unlockApp() {
    _isAppLocked = false;
    notifyListeners();
  }

  Future<void> setAppLockPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lock_pin', pin);
    _appLockPin = pin;
    _isAppLocked = false; // Unlock immediately after setup
    notifyListeners();
  }

  Future<void> disableAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_lock_pin');
    _appLockPin = null;
    _isAppLocked = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  // Update absolute paths to match the current app documents directory (deals with iOS sandbox UUID changes)
  String _normalizePath(String savedPath, String currentDocsPath) {
    if (savedPath.contains('/Documents/')) {
      final parts = savedPath.split('/Documents/');
      if (parts.length > 1) {
        return '$currentDocsPath/${parts.last}';
      }
    }
    return savedPath;
  }

  bool _isUuidName(String name) {
    final baseName = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    final uuidRegExp = RegExp(r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$');
    return uuidRegExp.hasMatch(baseName);
  }

  // Load from SharedPreferences
  Future<void> _loadLibrary() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final appDir = await getApplicationDocumentsDirectory();
      final currentDocsPath = appDir.path;
      
      final mediaJson = prefs.getString('media_library');
      if (mediaJson != null) {
        final List<dynamic> decoded = jsonDecode(mediaJson);
        _mediaItems = decoded.map((item) {
          final media = MediaItem.fromJson(item);
          final normalizedPath = _normalizePath(media.path, currentDocsPath);
          final normalizedThumb = media.thumbnailPath != null 
              ? _normalizePath(media.thumbnailPath!, currentDocsPath)
              : null;
          return media.copyWith(path: normalizedPath, thumbnailPath: normalizedThumb);
        }).toList();
      }

      final playlistJson = prefs.getString('playlists');
      if (playlistJson != null) {
        final List<dynamic> decoded = jsonDecode(playlistJson);
        _playlists = decoded.map((item) {
          final playlist = Playlist.fromJson(item);
          final normalizedItems = playlist.items.map((media) {
            final normalizedPath = _normalizePath(media.path, currentDocsPath);
            final normalizedThumb = media.thumbnailPath != null 
                ? _normalizePath(media.thumbnailPath!, currentDocsPath)
                : null;
            return media.copyWith(path: normalizedPath, thumbnailPath: normalizedThumb);
          }).toList();
          return playlist.copyWith(items: normalizedItems);
        }).toList();
      }

      // De-duplicate items pointing to the same filename in documents
      final Map<String, MediaItem> uniqueFileItems = {};
      bool libraryDeduplicated = false;
      for (var item in _mediaItems) {
        final fileName = item.path.split('/').last.toLowerCase();
        if (uniqueFileItems.containsKey(fileName)) {
          final existing = uniqueFileItems[fileName]!;
          if (_isUuidName(existing.title) && !_isUuidName(item.title)) {
            uniqueFileItems[fileName] = item;
          }
          libraryDeduplicated = true;
        } else {
          uniqueFileItems[fileName] = item;
        }
      }
      
      if (libraryDeduplicated) {
        _mediaItems = uniqueFileItems.values.toList();
        // Clean playlists too (prune removed items)
        final validIds = _mediaItems.map((e) => e.id).toSet();
        for (var i = 0; i < _playlists.length; i++) {
          final updatedItems = List<MediaItem>.from(_playlists[i].items)
            ..removeWhere((e) => !validIds.contains(e.id));
          _playlists[i] = _playlists[i].copyWith(items: updatedItems);
        }
        await _saveLibrary();
      }

      // Load app lock passcode
      _appLockPin = prefs.getString('app_lock_pin');
      if (_appLockPin != null && _appLockPin!.isNotEmpty) {
        _isAppLocked = true;
      }

      // Load theme mode
      final themeStr = prefs.getString('theme_mode') ?? 'system';
      _themeMode = ThemeMode.values.firstWhere((e) => e.name == themeStr, orElse: () => ThemeMode.system);

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
      String extension = '';
      if (originalName.contains('.')) {
        extension = originalName.substring(originalName.lastIndexOf('.'));
      }
      
      String sourceExt = '';
      if (sourcePath.contains('.')) {
        sourceExt = sourcePath.substring(sourcePath.lastIndexOf('.'));
      }
      
      if (sourceExt.isNotEmpty && (extension.isEmpty || (extension.toLowerCase() == '.mp3' && sourceExt.toLowerCase() != '.mp3'))) {
        extension = sourceExt;
      }
      
      if (extension.isEmpty) {
        extension = type == MediaType.video ? '.mp4' : '.mp3';
      }
      
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
    CancelToken? cancelToken,
    Function(double)? onProgress,
  }) async {
    _isLoading = true;
    notifyListeners();

    String? tempPathToDelete;

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
          tempPathToDelete = tempPath;
          final tempFile = File(tempPath);
          final fileStream = tempFile.openWrite();

          final stream = yt.videos.streamsClient.get(streamInfo);
          final totalBytes = streamInfo.size.totalBytes;
          var downloadedBytes = 0;

          try {
            await for (final chunk in stream) {
              if (cancelToken != null && cancelToken.isCancelled) {
                throw DioException(
                  requestOptions: RequestOptions(path: url),
                  type: DioExceptionType.cancel,
                  error: "Download cancelled by user",
                );
              }
              downloadedBytes += chunk.length;
              fileStream.add(chunk);
              if (totalBytes > 0 && onProgress != null) {
                onProgress(downloadedBytes / totalBytes);
              }
            }
          } finally {
            await fileStream.flush();
            await fileStream.close();
          }

          final newItem = await addMediaItem(
            sourcePath: tempPath,
            originalName: finalFileName,
            type: type,
          );

          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          tempPathToDelete = null;

          return newItem;
        } finally {
          yt.close();
        }
      } else {
        String downloadUrl = url;
        String? resolvedFileName;

        if (_isGoogleDriveUrl(url)) {
          final resolved = await _resolveGoogleDriveUrl(url);
          if (resolved != null) {
            downloadUrl = resolved.url;
            resolvedFileName = resolved.filename;
          }
        } else if (_isDropboxUrl(url)) {
          final resolved = _resolveDropboxUrl(url);
          downloadUrl = resolved.url;
          resolvedFileName = resolved.filename;
        } else if (_isTwitterOrInstagramUrl(url)) {
          final resolved = await _resolveCobaltUrl(url, type);
          if (resolved != null) {
            downloadUrl = resolved.url;
            resolvedFileName = resolved.filename;
          }
        }

        final defaultExtension = type == MediaType.video ? '.mp4' : '.mp3';
        final tempPath = '${appDir.path}/temp_${_uuid.v4()}$defaultExtension';
        tempPathToDelete = tempPath;
        
        final dio = Dio();
        final response = await dio.download(
          downloadUrl,
          tempPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total != -1 && onProgress != null) {
              onProgress(received / total);
            }
          },
        );

        // Try to resolve original filename from response headers (Content-Disposition) if not already provided
        String? headerFileName;
        final contentDisposition = response.headers.value('content-disposition');
        if (contentDisposition != null) {
          final match = RegExp(r'filename="?([^";]+)"?').firstMatch(contentDisposition);
          if (match != null && match.groupCount >= 1) {
            headerFileName = Uri.decodeComponent(match.group(1)!);
          }
        }

        String finalFileName = fileName ?? resolvedFileName ?? headerFileName ?? '';
        if (finalFileName.isEmpty) {
          finalFileName = downloadUrl.split('/').last;
          if (finalFileName.contains('?')) {
            finalFileName = finalFileName.split('?').first;
          }
        }
        if (finalFileName.isEmpty) {
          finalFileName = 'downloaded_file';
        }

        // Deduce appropriate extension (either from the filename, or from content-type header, or default)
        String ext = '';
        if (finalFileName.contains('.')) {
          ext = finalFileName.substring(finalFileName.lastIndexOf('.'));
        }
        if (ext.isEmpty) {
          final contentType = response.headers.value('content-type');
          if (contentType != null) {
            if (contentType.contains('video/quicktime')) {
              ext = '.mov';
            } else if (contentType.contains('video/mp4')) {
              ext = '.mp4';
            } else if (contentType.contains('audio/mpeg')) {
              ext = '.mp3';
            } else if (contentType.contains('audio/x-m4a') || contentType.contains('audio/m4a')) {
              ext = '.m4a';
            } else if (contentType.contains('audio/wav') || contentType.contains('audio/x-wav')) {
              ext = '.wav';
            }
          }
        }
        if (ext.isEmpty) {
          ext = defaultExtension;
        }

        if (!finalFileName.toLowerCase().endsWith(ext.toLowerCase())) {
          finalFileName = '$finalFileName$ext';
        }

        // Standard logic requires using correct extension for adding media item
        String savePath = tempPath;
        if (ext != defaultExtension) {
          final correctTempPath = '${appDir.path}/temp_${_uuid.v4()}$ext';
          await File(tempPath).rename(correctTempPath);
          savePath = correctTempPath;
          tempPathToDelete = correctTempPath;
        }

        // If type is Audio, but the resolved download is a video container, convert/extract audio natively
        final videoExtensions = {'.mp4', '.mov', '.m4v', '.avi', '.3gp', '.mkv'};
        if (type == MediaType.audio && videoExtensions.contains(ext.toLowerCase())) {
          final extractedPath = await _extractAudioNatively(savePath);
          if (extractedPath != null) {
            final videoFile = File(savePath);
            if (await videoFile.exists()) {
              await videoFile.delete();
            }
            savePath = extractedPath;
            tempPathToDelete = extractedPath;
            ext = '.m4a';
            final basename = finalFileName.contains('.') 
                ? finalFileName.substring(0, finalFileName.lastIndexOf('.'))
                : finalFileName;
            finalFileName = '$basename.m4a';
          }
        }

        // Now add using our standard path copy and duration extraction
        final newItem = await addMediaItem(
          sourcePath: savePath,
          originalName: finalFileName,
          type: type,
        );

        // Delete the temp downloaded file
        final tempFile = File(savePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        tempPathToDelete = null;

        return newItem;
      }
    } catch (e) {
      debugPrint("Error downloading media: $e");
      if (tempPathToDelete != null) {
        try {
          final file = File(tempPathToDelete);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
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

  // Rename Media Item
  Future<void> renameMediaItem(String id, String newTitle) async {
    final index = _mediaItems.indexWhere((element) => element.id == id);
    if (index != -1) {
      _mediaItems[index] = _mediaItems[index].copyWith(title: newTitle);
      
      // Also update in playlists
      for (var i = 0; i < _playlists.length; i++) {
        final playlist = _playlists[i];
        final pIndex = playlist.items.indexWhere((e) => e.id == id);
        if (pIndex != -1) {
          final updatedItems = List<MediaItem>.from(playlist.items);
          updatedItems[pIndex] = updatedItems[pIndex].copyWith(title: newTitle);
          _playlists[i] = playlist.copyWith(items: updatedItems);
        }
      }
      
      await _saveLibrary();
      notifyListeners();
    }
  }

  bool _isGoogleDriveUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('drive.google.com') || host.contains('docs.google.com');
  }

  bool _isDropboxUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('dropbox.com');
  }

  String? _extractGoogleDriveId(String url) {
    final regExp1 = RegExp(r'/d/([a-zA-Z0-9-_]+)');
    final match1 = regExp1.firstMatch(url);
    if (match1 != null && match1.groupCount >= 1) {
      return match1.group(1);
    }
    
    final regExp2 = RegExp(r'[?&]id=([a-zA-Z0-9-_]+)');
    final match2 = regExp2.firstMatch(url);
    if (match2 != null && match2.groupCount >= 1) {
      return match2.group(1);
    }
    return null;
  }

  Future<_ResolvedMedia?> _resolveGoogleDriveUrl(String url) async {
    final fileId = _extractGoogleDriveId(url);
    if (fileId == null) return null;
    
    final baseUrl = 'https://docs.google.com/uc?export=download&id=$fileId';
    String downloadUrl = baseUrl;
    String? filename;
    
    try {
      final dio = Dio();
      final response = await dio.get(
        baseUrl,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
        ),
      );
      
      if (response.statusCode == 200) {
        final body = response.data.toString();
        
        final confirmRegExp = RegExp(r'confirm=([^&"]+)');
        final match = confirmRegExp.firstMatch(body);
        if (match != null && match.groupCount >= 1) {
          final token = match.group(1);
          downloadUrl = '$baseUrl&confirm=$token';
        } else {
          final confirmInputRegExp = RegExp(r'name="confirm"\s+value="([a-zA-Z0-9-_]+)"');
          final inputMatch = confirmInputRegExp.firstMatch(body);
          if (inputMatch != null && inputMatch.groupCount >= 1) {
            final token = inputMatch.group(1);
            downloadUrl = '$baseUrl&confirm=$token';
          }
        }
        
        final titleRegExp = RegExp(r'<span class="uc-name-size"><a href="[^"]+"><b>([^<]+)</b></a>');
        final titleMatch = titleRegExp.firstMatch(body);
        if (titleMatch != null && titleMatch.groupCount >= 1) {
          filename = titleMatch.group(1);
        }
      }
    } catch (e) {
      debugPrint("Error resolving Google Drive: $e");
    }
    
    return _ResolvedMedia(downloadUrl, filename);
  }

  _ResolvedMedia _resolveDropboxUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return _ResolvedMedia(url, null);
    
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['dl'] = '1';
    final downloadUrl = uri.replace(queryParameters: queryParams).toString();
    
    String? filename;
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final last = pathSegments.last;
      if (last.contains('.')) {
        filename = Uri.decodeComponent(last);
      }
    }
    
    return _ResolvedMedia(downloadUrl, filename);
  }

  bool _isTwitterOrInstagramUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('twitter.com') ||
        host.contains('x.com') ||
        host.contains('instagram.com') ||
        host.contains('tiktok.com');
  }

  static const _converterChannel = MethodChannel('com.videoplayermax.media/converter');

  Future<String?> _extractAudioNatively(String inputPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final outputPath = '${appDir.path}/extracted_${_uuid.v4()}.m4a';
      final String? path = await _converterChannel.invokeMethod<String>('extractAudio', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return path;
    } catch (e) {
      debugPrint("Error extracting audio natively: $e");
      return null;
    }
  }

  Future<_ResolvedMedia?> _resolveCobaltUrl(String url, MediaType type) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        'https://api.cobalt.tools/',
        data: {
          'url': url,
          'audioOnly': type == MediaType.audio,
          'aFormat': 'mp3',
          'vQuality': '720',
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status == 'stream' || status == 'redirect' || status == 'tunnel') {
          final resolvedUrl = data['url'] as String?;
          final filename = data['filename'] as String?;
          if (resolvedUrl != null) {
            return _ResolvedMedia(resolvedUrl, filename);
          }
        }
      }
    } catch (e) {
      debugPrint("Cobalt resolution error: $e");
    }
    return null;
  }
}

class _ResolvedMedia {
  final String url;
  final String? filename;
  _ResolvedMedia(this.url, this.filename);
}
