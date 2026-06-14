import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/styles.dart';
import '../models/media_item.dart';
import '../providers/media_library_manager.dart';
import '../providers/playback_manager.dart';
import 'player_screen.dart';
import '../widgets/video_preview_widget.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isScreenLocked = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToPlayer() {
    final playbackManager = Provider.of<PlaybackManager>(context, listen: false);
    if (playbackManager.currentItem != null) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => const PlayerScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No media currently playing"),
          backgroundColor: AppStyles.primaryRed,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "${duration.inMinutes}:$twoDigitSeconds";
  }

  void _showMediaInfo(BuildContext context, MediaItem item) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(item.title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Type: ${item.type == MediaType.video ? 'Video' : 'Audio (MP3)'}"),
              const SizedBox(height: 4),
              Text("Duration: ${_formatDuration(item.duration)}"),
              const SizedBox(height: 4),
              Text("Added: ${item.addedDate.toString().substring(0, 10)}"),
              const SizedBox(height: 4),
              Text("Path: ${item.path}", style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Delete", style: TextStyle(color: CupertinoColors.destructiveRed)),
            onPressed: () {
              Provider.of<MediaLibraryManager>(context, listen: false).deleteMediaItem(item.id);
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryManager = Provider.of<MediaLibraryManager>(context);
    final playbackManager = Provider.of<PlaybackManager>(context);

    // Filter list by search query
    final filteredItems = libraryManager.mediaItems.where((item) {
      return item.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppStyles.scaffoldBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          color: AppStyles.primaryRed,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isScreenLocked = !_isScreenLocked;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isScreenLocked ? "Screen Locked" : "Screen Unlocked"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Text(
                      _isScreenLocked ? "Unlock" : "Lock",
                      style: AppStyles.headerActionStyle,
                    ),
                  ),
                  const Text(
                    'Videos',
                    style: AppStyles.headerTitleStyle,
                  ),
                  GestureDetector(
                    onTap: _navigateToPlayer,
                    child: const Text(
                      'Playing',
                      style: AppStyles.headerActionStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IgnorePointer(
        ignoring: _isScreenLocked,
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              color: Colors.white,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(CupertinoIcons.search, color: Colors.grey, size: 18),
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            
            // Shuffle bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppStyles.dividerColor, width: 0.5),
                  bottom: BorderSide(color: AppStyles.dividerColor, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Shuffle',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppStyles.textDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      playbackManager.toggleShuffle();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(playbackManager.isShuffle ? "Shuffle Enabled" : "Shuffle Disabled"),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.shuffle,
                      color: playbackManager.isShuffle ? AppStyles.primaryRed : Colors.grey,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Media list
            Expanded(
              child: libraryManager.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        await libraryManager.syncItunesFiles();
                      },
                      color: AppStyles.primaryRed,
                      child: filteredItems.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.5,
                                  child: Center(
                                    child: Text(
                                      _searchQuery.isEmpty 
                                          ? 'No media imported yet.\nGo to the Imports tab to add videos or audio!\n\n(Or drag down to scan iTunes files)' 
                                          : 'No matching items found',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppStyles.textGray, fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredItems.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 0.5,
                            indent: 90, // indentation after the thumbnail to match iOS
                            color: AppStyles.dividerColor,
                          ),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isCurrentPlaying = playbackManager.currentItem?.id == item.id;

                            return Container(
                              color: Colors.white,
                              height: 80,
                              child: Row(
                                children: [
                                  // Thumbnail section
                                  Container(
                                    width: 75,
                                    height: 75,
                                    margin: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: item.isVideo
                                          ? VideoPreviewWidget(videoPath: item.path)
                                          : (item.thumbnailPath != null
                                              ? Image.file(
                                                  File(item.thumbnailPath!),
                                                  fit: BoxFit.cover,
                                                )
                                              : _buildThumbnailPlaceholder(item)),
                                    ),
                                  ),
                                  
                                  // Text details
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () {
                                        // Play item
                                        playbackManager.setPlaylist(filteredItems, index);
                                        // Navigate to player
                                        Navigator.push(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (context) => const PlayerScreen(),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppStyles.mediaTitleStyle,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDuration(item.duration),
                                              style: AppStyles.mediaDurationStyle,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Play state indicator
                                  if (isCurrentPlaying)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Icon(
                                        Icons.play_arrow,
                                        color: AppStyles.primaryRed,
                                        size: 20,
                                      ),
                                    ),

                                  // Info button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.info_outline,
                                      color: AppStyles.primaryRed,
                                      size: 26,
                                    ),
                                    onPressed: () => _showMediaInfo(context, item),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(MediaItem item) {
    final isVideo = item.isVideo;
    final gradient = isVideo
        ? const LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFF39C12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
      ),
      child: Center(
        child: Icon(
          isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.music_note_2,
          color: Colors.white.withValues(alpha: 0.8),
          size: 32,
        ),
      ),
    );
  }
}
