import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../constants/styles.dart';
import '../providers/playback_manager.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_container.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isPlayerLocked = false;
  BoxFit _videoBoxFit = BoxFit.contain;

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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      isScrollControlled: true,
      builder: (context) {
        return Consumer<PlaybackManager>(
          builder: (context, pm, child) {
            return GlassContainer(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              opacity: 0.14,
              blur: 24.0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Playing Queue",
                            style: TextStyle(color: AppStyles.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              "Done", 
                              style: TextStyle(color: AppStyles.primaryRed, fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 0.5, color: AppStyles.getDividerColor(context)),
                    Container(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        itemCount: pm.playlist.length,
                        onReorder: (oldIndex, newIndex) {
                          pm.reorderQueue(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final item = pm.playlist[index];
                          final isPlaying = pm.currentIndex == index;
                          return ListTile(
                            key: Key('${item.id}_queue'),
                            leading: Icon(
                              item.isVideo ? CupertinoIcons.video_camera : CupertinoIcons.music_note,
                              color: isPlaying ? AppStyles.primaryRed : AppStyles.getIconColor(context),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isPlaying ? AppStyles.primaryRed : AppStyles.getTextColor(context),
                                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              _formatDuration(item.duration),
                              style: TextStyle(color: AppStyles.getSubtextColor(context).withValues(alpha: 0.6)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPlaying)
                                  const Icon(Icons.volume_up, color: AppStyles.primaryRed, size: 20),
                                const SizedBox(width: 8),
                                const Icon(Icons.drag_handle, color: Colors.white30),
                              ],
                            ),
                            onTap: () {
                              pm.setPlaylist(pm.playlist, index);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Glass Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: GlassContainer(
                  height: 50,
                  borderRadius: BorderRadius.circular(25),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Hide',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w500,
                          ),
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
                            style: TextStyle(
                              fontSize: 17,
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showPlaylistDrawer(context),
                        child: Icon(
                          Icons.playlist_play,
                          color: AppStyles.getTextColor(context),
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Central Viewport (Video rendering or Premium audio visualizer)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(24),
                    opacity: 0.05,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        playbackManager.isVideoActive && playbackManager.videoController != null
                            ? Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _videoBoxFit == BoxFit.cover
                                      ? SizedBox.expand(
                                          child: FittedBox(
                                            fit: BoxFit.cover,
                                            clipBehavior: Clip.hardEdge,
                                            child: SizedBox(
                                              width: playbackManager.videoController!.value.size.width,
                                              height: playbackManager.videoController!.value.size.height,
                                              child: VideoPlayer(playbackManager.videoController!),
                                            ),
                                          ),
                                        )
                                      : AspectRatio(
                                          aspectRatio: playbackManager.videoController!.value.aspectRatio,
                                          child: VideoPlayer(playbackManager.videoController!),
                                        ),
                                ),
                              )
                            : _buildAudioPlayerVisuals(item.title, playbackManager.isPlaying),

                        // Tiny unlock floating overlay if locked
                        if (_isPlayerLocked)
                          Positioned(
                            top: 20,
                            right: 20,
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
                      ],
                    ),
                  ),
                ),
              ),

              // Controls Panel Wrapper
              if (!_isPlayerLocked)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(12),
                    opacity: 0.08,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Seek Slider & Duration Labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(playbackManager.position),
                              style: TextStyle(color: AppStyles.getSubtextColor(context), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Theme.of(context).brightness == Brightness.light
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
                                  inactiveTrackColor: Theme.of(context).brightness == Brightness.light
                                      ? const Color(0xFFE2E8F0)
                                      : Colors.white12,
                                  thumbColor: Theme.of(context).brightness == Brightness.light
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
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
                              style: TextStyle(color: AppStyles.getSubtextColor(context), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        
                        // Action Icons Row (Repeat, Aspect ratio, Lock, Shuffle)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Repeat Mode
                            GestureDetector(
                              onTap: playbackManager.toggleRepeatMode,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    color: playbackManager.repeatMode != PlaybackRepeatMode.none
                                        ? AppStyles.primaryRed
                                        : AppStyles.getIconColor(context),
                                    size: 22,
                                  ),
                                  if (playbackManager.repeatMode == PlaybackRepeatMode.one)
                                    const Positioned(
                                      top: 6,
                                      child: Text(
                                        "1",
                                        style: TextStyle(color: AppStyles.primaryRed, fontSize: 7, fontWeight: FontWeight.bold),
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
                              },
                              child: Icon(
                                Icons.aspect_ratio,
                                color: _videoBoxFit == BoxFit.cover
                                    ? AppStyles.primaryRed
                                    : AppStyles.getIconColor(context),
                                size: 22,
                              ),
                            ),

                            // Lock Screen Toggle
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isPlayerLocked = true;
                                });
                              },
                              child: Icon(
                                Icons.lock_open,
                                color: AppStyles.getIconColor(context),
                                size: 22,
                              ),
                            ),

                            // Shuffle Toggle
                            GestureDetector(
                              onTap: playbackManager.toggleShuffle,
                              child: Icon(
                                Icons.shuffle,
                                color: playbackManager.isShuffle ? AppStyles.primaryRed : AppStyles.getIconColor(context),
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Volume Controller Glass Panel
              if (!_isPlayerLocked)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: GlassContainer(
                    height: 44,
                    borderRadius: BorderRadius.circular(22),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    opacity: 0.08,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (playbackManager.volume > 0.0) {
                              playbackManager.setVolume(0.0);
                            } else {
                              playbackManager.setVolume(1.0);
                            }
                          },
                          child: Icon(
                            playbackManager.volume == 0.0
                                ? CupertinoIcons.volume_mute
                                : (playbackManager.volume < 0.5
                                    ? CupertinoIcons.volume_down
                                    : CupertinoIcons.volume_up),
                            color: AppStyles.getIconColor(context),
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppStyles.primaryRed,
                              inactiveTrackColor: Theme.of(context).brightness == Brightness.light
                                  ? const Color(0xFFE2E8F0)
                                  : Colors.white12,
                              thumbColor: Theme.of(context).brightness == Brightness.light
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                              trackHeight: 3.0,
                            ),
                            child: Slider(
                              value: playbackManager.volume,
                              onChanged: (val) {
                                playbackManager.setVolume(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Control Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: GlassContainer(
                  height: 80,
                  borderRadius: BorderRadius.circular(40),
                  opacity: 0.12,
                  child: IgnorePointer(
                    ignoring: _isPlayerLocked,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(CupertinoIcons.gobackward_15, color: AppStyles.getIconColor(context), size: 24),
                          onPressed: () => playbackManager.seekRelative(const Duration(seconds: -15)),
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_previous, color: AppStyles.getTextColor(context), size: 30),
                          onPressed: playbackManager.previous,
                        ),
                        GestureDetector(
                          onTap: playbackManager.togglePlay,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).brightness == Brightness.light
                                  ? Colors.black.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.15),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.light
                                    ? Colors.black26
                                    : Colors.white38,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              playbackManager.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: AppStyles.getTextColor(context),
                              size: 32,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next, color: AppStyles.getTextColor(context), size: 30),
                          onPressed: playbackManager.next,
                        ),
                        IconButton(
                          icon: Icon(CupertinoIcons.goforward_15, color: AppStyles.getIconColor(context), size: 24),
                          onPressed: () => playbackManager.seekRelative(const Duration(seconds: 15)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Visual panel for MP3 files
  Widget _buildAudioPlayerVisuals(String title, bool isPlaying) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
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
                    color: AppStyles.primaryRed.withValues(alpha: 0.4),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white12,
                width: 6,
              ),
            ),
            child: Center(
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(CupertinoIcons.music_note, color: AppStyles.primaryRed, size: 20),
                ),
              ),
            ),
          ),
          ),
          const SizedBox(height: 32),
          
          // Glass text card for title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              borderRadius: BorderRadius.circular(16),
              opacity: 0.1,
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Playing Audio Mode",
                    style: TextStyle(
                      color: AppStyles.primaryRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
