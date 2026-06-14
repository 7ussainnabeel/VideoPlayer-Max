import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../constants/styles.dart';
import '../providers/playback_manager.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isPlayerLocked = false;
  BoxFit _videoBoxFit = BoxFit.contain; // Fit aspect ratio

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "${duration.inMinutes}:$twoDigitSeconds";
  }

  String _formatRemainingDuration(Duration position, Duration total) {
    final remaining = total - position;
    if (remaining.isNegative || remaining == Duration.zero) {
      return "0:00";
    }
    return "-${_formatDuration(remaining)}";
  }

  void _showPlaylistDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return Consumer<PlaybackManager>(
          builder: (context, pm, child) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Queue",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text("Done", style: TextStyle(color: AppStyles.primaryRed, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  Expanded(
                    child: ListView.builder(
                      itemCount: pm.playlist.length,
                      itemBuilder: (context, index) {
                        final item = pm.playlist[index];
                        final isPlaying = pm.currentIndex == index;
                        return ListTile(
                          leading: Icon(
                            item.isVideo ? CupertinoIcons.video_camera : CupertinoIcons.music_note,
                            color: isPlaying ? AppStyles.primaryRed : Colors.white60,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isPlaying ? AppStyles.primaryRed : Colors.white,
                              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            _formatDuration(item.duration),
                            style: const TextStyle(color: Colors.white38),
                          ),
                          trailing: isPlaying
                              ? const Icon(Icons.volume_up, color: AppStyles.primaryRed)
                              : null,
                          onTap: () {
                            pm.setPlaylist(pm.playlist, index);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playbackManager = Provider.of<PlaybackManager>(context);
    final item = playbackManager.currentItem;

    if (item == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("No media loaded", style: TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              CupertinoButton(
                color: AppStyles.primaryRed,
                child: const Text("Back"),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        ),
      );
    }

    final double progress = playbackManager.duration.inMilliseconds > 0
        ? playbackManager.position.inMilliseconds / playbackManager.duration.inMilliseconds
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false, // Make sure red header spans into the status bar area
        child: Column(
          children: [
            // Red Header
            Container(
              color: AppStyles.primaryRed,
              padding: const EdgeInsets.only(top: 50, bottom: 12, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Hide',
                      style: AppStyles.headerActionStyle,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        item.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.headerTitleStyle,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showPlaylistDrawer(context),
                    child: const Icon(
                      Icons.playlist_play,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            // Controls Sub-header (Seek slider & Duration labels)
            if (!_isPlayerLocked)
              Container(
                color: const Color(0xFF1C1C1E),
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(playbackManager.position),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.grey.shade700,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                              trackHeight: 3.0,
                            ),
                            child: Slider(
                              value: progress.clamp(0.0, 1.0),
                              onChanged: (val) {
                                final targetMs = (val * playbackManager.duration.inMilliseconds).toInt();
                                playbackManager.seek(Duration(milliseconds: targetMs));
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatRemainingDuration(playbackManager.position, playbackManager.duration),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Action icons row (Repeat, Size, Lock, Shuffle)
            if (!_isPlayerLocked)
              Container(
                color: const Color(0xFF121212),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Repeat Mode
                    GestureDetector(
                      onTap: playbackManager.toggleRepeatMode,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            playbackManager.repeatMode == PlaybackRepeatMode.none
                                ? Icons.repeat
                                : Icons.repeat,
                            color: playbackManager.repeatMode != PlaybackRepeatMode.none
                                ? AppStyles.primaryRed
                                : Colors.white60,
                            size: 24,
                          ),
                          if (playbackManager.repeatMode == PlaybackRepeatMode.one)
                            const Positioned(
                              top: 8,
                              child: Text(
                                "1",
                                style: TextStyle(color: AppStyles.primaryRed, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            )
                        ],
                      ),
                    ),

                    // Aspect Ratio Toggle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _videoBoxFit = _videoBoxFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_videoBoxFit == BoxFit.cover ? "Aspect Mode: Crop to Fill" : "Aspect Mode: Fit Screen"),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white60,
                        size: 24,
                      ),
                    ),

                    // Lock overlay
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isPlayerLocked = true;
                        });
                      },
                      child: const Icon(
                        Icons.lock_open,
                        color: Colors.white60,
                        size: 24,
                      ),
                    ),

                    // Shuffle
                    GestureDetector(
                      onTap: playbackManager.toggleShuffle,
                      child: Icon(
                        Icons.shuffle,
                        color: playbackManager.isShuffle ? AppStyles.primaryRed : Colors.white60,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

            // Central Viewport (Video rendering or Premium audio visualizer)
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Player Content
                  playbackManager.isVideoActive && playbackManager.videoController != null
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: playbackManager.videoController!.value.aspectRatio,
                            child: FittedBox(
                              fit: _videoBoxFit,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: playbackManager.videoController!.value.size.width,
                                height: playbackManager.videoController!.value.size.height,
                                child: VideoPlayer(playbackManager.videoController!),
                              ),
                            ),
                          ),
                        )
                      : _buildAudioPlayerVisuals(item.title, playbackManager.isPlaying),

                  // Tiny unlock floating overlay if locked
                  if (_isPlayerLocked)
                    Positioned(
                      top: 20,
                      right: 20,
                      child: SafeArea(
                        child: CupertinoButton(
                          padding: const EdgeInsets.all(12),
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(30),
                          child: const Icon(Icons.lock, color: AppStyles.primaryRed, size: 24),
                          onPressed: () {
                            setState(() {
                              _isPlayerLocked = false;
                            });
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Control Bar
            Container(
              color: AppStyles.bottomNavBg,
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: IgnorePointer(
                ignoring: _isPlayerLocked,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Seek -15s
                    IconButton(
                      icon: const Icon(CupertinoIcons.gobackward_15, color: Colors.white, size: 30),
                      onPressed: () => playbackManager.seekRelative(const Duration(seconds: -15)),
                    ),

                    // Previous Item
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                      onPressed: playbackManager.previous,
                    ),

                    // Play/Pause
                    GestureDetector(
                      onTap: playbackManager.togglePlay,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          playbackManager.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),

                    // Next Item
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                      onPressed: playbackManager.next,
                    ),

                    // Seek +15s
                    IconButton(
                      icon: const Icon(CupertinoIcons.goforward_15, color: Colors.white, size: 30),
                      onPressed: () => playbackManager.seekRelative(const Duration(seconds: 15)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Visual panel for MP3 files - Glassmorphism, spinning disc & blurred background
  Widget _buildAudioPlayerVisuals(String title, bool isPlaying) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0D0F), Color(0xFF1B1B1F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Album Art Vinyl disc
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.0, end: isPlaying ? 360.0 : 0.0),
            duration: const Duration(seconds: 10),
            builder: (context, double angle, child) {
              return Transform.rotate(
                angle: angle * (3.14159 / 180),
                child: child,
              );
            },
            onEnd: () {
              // Loop rotation if playing
              if (isPlaying) {
                setState(() {});
              }
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF2C3E50), Colors.black],
                  stops: [0.6, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppStyles.primaryRed.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
                border: Border.all(color: Colors.grey.shade800, width: 6),
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(CupertinoIcons.music_note, color: AppStyles.primaryRed, size: 24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          // Waveform indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Playing Audio File",
            style: TextStyle(
              color: AppStyles.primaryRed,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
