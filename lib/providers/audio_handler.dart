import 'package:audio_service/audio_service.dart';
import 'playback_manager.dart';

class VideoPlayerMaxAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static VideoPlayerMaxAudioHandler? instance;
  PlaybackManager? playbackManager;

  VideoPlayerMaxAudioHandler() {
    instance = this;
  }

  @override
  Future<void> play() async {
    if (playbackManager != null) {
      await playbackManager!.play();
    }
  }

  @override
  Future<void> pause() async {
    if (playbackManager != null) {
      await playbackManager!.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (playbackManager != null) {
      await playbackManager!.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (playbackManager != null) {
      await playbackManager!.next();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (playbackManager != null) {
      await playbackManager!.previous();
    }
  }

  void updatePlaybackState(PlaybackState state) {
    playbackState.add(state);
  }

  void setMediaItem(MediaItem item) {
    mediaItem.add(item);
  }
}
