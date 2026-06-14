import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import '../models/media_item.dart';

enum PlaybackRepeatMode { none, one, all }

class PlaybackManager with ChangeNotifier {
  // Playlist State
  List<MediaItem> _playlist = [];
  int _currentIndex = -1;
  List<int> _shuffledIndices = [];
  bool _isShuffle = false;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.none;

  // Active Players
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isVideoActive = false;

  // Position Tracking
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _positionTimer;

  // Status
  bool _isPlaying = false;
  double _volume = 1.0;

  // Getters
  List<MediaItem> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  MediaItem? get currentItem => 
      (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex] : null;
  bool get isShuffle => _isShuffle;
  PlaybackRepeatMode get repeatMode => _repeatMode;
  bool get isVideoActive => _isVideoActive;
  VideoPlayerController? get videoController => _videoController;
  AudioPlayer? get audioPlayer => _audioPlayer;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  // Set Playlist and Play Item
  Future<void> setPlaylist(List<MediaItem> items, int startIndex) async {
    _playlist = List<MediaItem>.from(items);
    _currentIndex = startIndex;
    _generateShuffleIndices();
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      await _playCurrentItem();
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _generateShuffleIndices();
    notifyListeners();
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case PlaybackRepeatMode.none:
        _repeatMode = PlaybackRepeatMode.all;
        break;
      case PlaybackRepeatMode.all:
        _repeatMode = PlaybackRepeatMode.one;
        break;
      case PlaybackRepeatMode.one:
        _repeatMode = PlaybackRepeatMode.none;
        break;
    }
    notifyListeners();
  }

  void _generateShuffleIndices() {
    _shuffledIndices = List<int>.generate(_playlist.length, (i) => i);
    if (_isShuffle) {
      _shuffledIndices.shuffle();
      // Keep current index as the first one if we are already playing
      if (_currentIndex != -1) {
        _shuffledIndices.remove(_currentIndex);
        _shuffledIndices.insert(0, _currentIndex);
      }
    }
  }

  // Play Active Item
  Future<void> _playCurrentItem() async {
    final item = currentItem;
    if (item == null) return;

    // Clean up existing players
    await _cleanupPlayers();

    _position = Duration.zero;
    _duration = item.duration;
    _isPlaying = true;
    notifyListeners();

    try {
      if (item.isVideo) {
        _isVideoActive = true;
        _videoController = VideoPlayerController.file(File(item.path));
        
        await _videoController!.initialize();
        await _videoController!.setVolume(_volume);
        _duration = _videoController!.value.duration;
        await _videoController!.play();

        // Listen for video end
        _videoController!.addListener(_videoListener);
        _startPositionTimer();
      } else {
        _isVideoActive = false;
        _audioPlayer = AudioPlayer();
        await _audioPlayer!.setVolume(_volume);
        final durationRes = await _audioPlayer!.setFilePath(item.path);
        _duration = durationRes ?? item.duration;
        
        _audioPlayer!.playbackEventStream.listen((event) {
          if (_audioPlayer == null) return;
          _isPlaying = _audioPlayer!.playing;
          _position = _audioPlayer!.position;
          notifyListeners();
        });

        _audioPlayer!.processingStateStream.listen((state) {
          if (state == ProcessingState.completed) {
            _onItemCompleted();
          }
        });

        await _audioPlayer!.play();
      }
    } catch (e) {
      debugPrint("Playback error: $e");
      // Fallback: move to next item
      _onItemCompleted();
    }
    notifyListeners();
  }

  void _videoListener() {
    if (_videoController == null) return;
    
    final value = _videoController!.value;
    _isPlaying = value.isPlaying;
    _position = value.position;
    
    if (value.position >= value.duration && value.duration > Duration.zero) {
      // Completed playback
      _videoController!.removeListener(_videoListener);
      _onItemCompleted();
    }
    notifyListeners();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_videoController != null && _isPlaying) {
        _position = _videoController!.value.position;
        notifyListeners();
      }
    });
  }

  // Handle media complete
  void _onItemCompleted() {
    if (_repeatMode == PlaybackRepeatMode.one) {
      seek(Duration.zero);
      play();
    } else {
      next();
    }
  }

  // Unified Play controls
  Future<void> play() async {
    if (_isPlaying) return;
    try {
      if (_isVideoActive && _videoController != null) {
        await _videoController!.play();
        _isPlaying = true;
      } else if (!_isVideoActive && _audioPlayer != null) {
        await _audioPlayer!.play();
        _isPlaying = true;
      }
    } catch (e) {
      debugPrint("Error resuming: $e");
    }
    notifyListeners();
  }

  Future<void> pause() async {
    if (!_isPlaying) return;
    try {
      if (_isVideoActive && _videoController != null) {
        await _videoController!.pause();
        _isPlaying = false;
      } else if (!_isVideoActive && _audioPlayer != null) {
        await _audioPlayer!.pause();
        _isPlaying = false;
      }
    } catch (e) {
      debugPrint("Error pausing: $e");
    }
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    try {
      if (_isVideoActive && _videoController != null) {
        await _videoController!.seekTo(position);
        _position = position;
      } else if (!_isVideoActive && _audioPlayer != null) {
        await _audioPlayer!.seek(position);
        _position = position;
      }
    } catch (e) {
      debugPrint("Error seeking: $e");
    }
    notifyListeners();
  }

  Future<void> seekRelative(Duration offset) async {
    final newPos = _position + offset;
    final targetPos = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _duration ? _duration : newPos);
    await seek(targetPos);
  }

  // Next Item
  Future<void> next() async {
    if (_playlist.isEmpty) return;

    if (_isShuffle) {
      final currentShufflePos = _shuffledIndices.indexOf(_currentIndex);
      if (currentShufflePos != -1 && currentShufflePos < _shuffledIndices.length - 1) {
        _currentIndex = _shuffledIndices[currentShufflePos + 1];
      } else {
        if (_repeatMode == PlaybackRepeatMode.all) {
          _currentIndex = _shuffledIndices.first;
        } else {
          // End of playlist
          await pause();
          return;
        }
      }
    } else {
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
      } else {
        if (_repeatMode == PlaybackRepeatMode.all) {
          _currentIndex = 0;
        } else {
          // End of playlist
          await pause();
          return;
        }
      }
    }

    await _playCurrentItem();
  }

  // Previous Item
  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    // If we are past 3 seconds of playing, just restart the current item
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_isShuffle) {
      final currentShufflePos = _shuffledIndices.indexOf(_currentIndex);
      if (currentShufflePos > 0) {
        _currentIndex = _shuffledIndices[currentShufflePos - 1];
      } else {
        if (_repeatMode == PlaybackRepeatMode.all) {
          _currentIndex = _shuffledIndices.last;
        } else {
          await seek(Duration.zero);
          return;
        }
      }
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
      } else {
        if (_repeatMode == PlaybackRepeatMode.all) {
          _currentIndex = _playlist.length - 1;
        } else {
          await seek(Duration.zero);
          return;
        }
      }
    }

    await _playCurrentItem();
  }

  // Cleanup players
  Future<void> _cleanupPlayers() async {
    _positionTimer?.cancel();
    
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      await _videoController!.dispose();
      _videoController = null;
    }
    
    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
      _audioPlayer = null;
    }

    _isVideoActive = false;
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    try {
      if (_isVideoActive && _videoController != null) {
        await _videoController!.setVolume(_volume);
      } else if (!_isVideoActive && _audioPlayer != null) {
        await _audioPlayer!.setVolume(_volume);
      }
    } catch (e) {
      debugPrint("Error setting volume: $e");
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final playingItem = currentItem;
    final item = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, item);
    if (playingItem != null) {
      _currentIndex = _playlist.indexWhere((element) => element.id == playingItem.id);
    }
    _generateShuffleIndices();
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _cleanupPlayers();
    super.dispose();
  }
}
