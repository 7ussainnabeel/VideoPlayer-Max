import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../constants/styles.dart';
import '../models/media_item.dart';
import '../providers/media_library_manager.dart';
import '../providers/playback_manager.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import '../widgets/video_preview_widget.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_container.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
      _showSnackbar("No media currently playing", isError: true);
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

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.redAccent.withValues(alpha: 0.9) : Colors.green.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Action Menu Bottom Sheet
  void _showVideoActionsMenu(BuildContext context, MediaItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      isScrollControlled: true,
      builder: (context) {
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
                // Drag handle indicator
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppStyles.getDividerColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header (title of the video)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        item.isVideo ? Icons.movie_creation_outlined : Icons.music_note_outlined,
                        color: AppStyles.primaryRed,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 0.5, color: AppStyles.getDividerColor(context)),
                
                // Actions List
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      _buildActionItem(
                        context,
                        icon: Icons.share_outlined,
                        title: 'Share Video',
                        onTap: () {
                          Navigator.pop(context);
                          _shareMedia(item);
                        },
                      ),
                      _buildActionItem(
                        context,
                        icon: Icons.save_alt_outlined,
                        title: 'Save to Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _saveToGallery(item);
                        },
                      ),
                      _buildActionItem(
                        context,
                        icon: Icons.music_note_outlined,
                        title: 'Convert to MP3',
                        onTap: () {
                          Navigator.pop(context);
                          _convertToMp3(item);
                        },
                      ),
                      _buildActionItem(
                        context,
                        icon: Icons.launch_outlined,
                        title: 'Export / Open In',
                        onTap: () {
                          Navigator.pop(context);
                          _shareMedia(item); 
                        },
                      ),
                      _buildActionItem(
                        context,
                        icon: Icons.edit_outlined,
                        title: 'Rename',
                        onTap: () {
                          Navigator.pop(context);
                          _renameMedia(item);
                        },
                      ),
                      _buildActionItem(
                        context,
                        icon: Icons.playlist_add,
                        title: 'Add to Playlist',
                        onTap: () {
                          Navigator.pop(context);
                          _addToPlaylist(item);
                        },
                      ),
                      _buildActionItem(
                        context,
                        icon: Icons.info_outline,
                        title: 'File Information',
                        onTap: () {
                          Navigator.pop(context);
                          _showMediaInfo(context, item);
                        },
                      ),
                      _buildActionItem(
                        context,
                        icon: Icons.delete_outline,
                        title: 'Delete',
                        textColor: Colors.redAccent,
                        iconColor: Colors.redAccent,
                        onTap: () {
                          Navigator.pop(context);
                          _confirmDelete(item);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final finalTextColor = textColor ?? AppStyles.getTextColor(context);
    final finalIconColor = iconColor ?? AppStyles.getIconColor(context);

    return ListTile(
      leading: Icon(icon, color: finalIconColor, size: 22),
      title: Text(
        title,
        style: TextStyle(color: finalTextColor, fontSize: 15, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }

  Future<void> _shareMedia(MediaItem item) async {
    try {
      final file = File(item.path);
      if (!await file.exists()) {
        _showSnackbar('File not found on disk', isError: true);
        return;
      }

      // Get temporary directory to copy file into
      final tempDir = await getTemporaryDirectory();

      // Clean the title from invalid OS file characters
      var cleanTitle = item.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      // Make sure the title ends with the correct extension
      final extension = item.path.contains('.')
          ? item.path.substring(item.path.lastIndexOf('.'))
          : (item.type == MediaType.video ? '.mp4' : '.mp3');

      if (!cleanTitle.toLowerCase().endsWith(extension.toLowerCase())) {
        cleanTitle = '$cleanTitle$extension';
      }

      final tempFilePath = '${tempDir.path}/$cleanTitle';

      // Perform the file copy
      await file.copy(tempFilePath);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFilePath)],
          text: item.title,
        ),
      );
    } catch (e) {
      _showSnackbar('Error sharing file: $e', isError: true);
    }
  }

  Future<void> _saveToGallery(MediaItem item) async {
    _showSnackbar('Saving video to gallery...');
    try {
      if (item.isVideo) {
        await Gal.putVideo(item.path);
        _showSnackbar('Video saved to photos gallery!');
      } else {
        _showSnackbar('Saving audio files to Gallery is not supported.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Failed to save: $e', isError: true);
    }
  }

  Future<void> _convertToMp3(MediaItem item) async {
    _showSnackbar('Converting to Audio item...');
    try {
      final lib = Provider.of<MediaLibraryManager>(context, listen: false);
      final file = File(item.path);
      if (!await file.exists()) {
        _showSnackbar('Original file not found on disk.', isError: true);
        return;
      }

      final nameWithoutExt = item.title.contains('.') 
          ? item.title.substring(0, item.title.lastIndexOf('.'))
          : item.title;
      
      final newName = '[Audio] $nameWithoutExt.mp3';
      
      final appDir = await getApplicationDocumentsDirectory();
      final newFileName = '${const Uuid().v4()}.mp3';
      final savedFile = File('${appDir.path}/$newFileName');
      
      await file.copy(savedFile.path);

      final newItem = await lib.addMediaItem(
        sourcePath: savedFile.path,
        originalName: newName,
        type: MediaType.audio,
      );

      if (await savedFile.exists() && newItem != null) {
        await savedFile.delete();
      }

      if (newItem != null) {
        _showSnackbar('Successfully converted to Audio item!');
      } else {
        _showSnackbar('Failed to register audio item.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Error converting file: $e', isError: true);
    }
  }

  void _renameMedia(MediaItem item) {
    final controller = TextEditingController(text: item.title);
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Rename File'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'Enter new name',
              style: const TextStyle(color: Colors.black),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              child: const Text('Save'),
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(context);
                  await Provider.of<MediaLibraryManager>(context, listen: false)
                      .renameMediaItem(item.id, newName);
                  _showSnackbar('File renamed successfully.');
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _addToPlaylist(MediaItem item) {
    final libraryManager = Provider.of<MediaLibraryManager>(context, listen: false);
    if (libraryManager.playlists.isEmpty) {
      _showSnackbar('No playlists available. Create one first.', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          opacity: 0.15,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Select Playlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Divider(height: 0.5, color: Colors.white10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: libraryManager.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = libraryManager.playlists[index];
                      return ListTile(
                        leading: Icon(Icons.playlist_add, color: AppStyles.getIconColor(context)),
                        title: Text(playlist.name, style: TextStyle(color: AppStyles.getTextColor(context))),
                        onTap: () {
                          Navigator.pop(context);
                          libraryManager.addMediaToPlaylist(playlist.id, item);
                          _showSnackbar('Added to: ${playlist.name}');
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
  }

  void _confirmDelete(MediaItem item) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to permanently delete "${item.title}"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              Provider.of<MediaLibraryManager>(context, listen: false).deleteMediaItem(item.id);
              _showSnackbar('File deleted.');
            },
          ),
        ],
      ),
    );
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
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: Column(
          children: [
            // Custom Glass AppBar
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: GlassContainer(
                  height: 50,
                  borderRadius: BorderRadius.circular(25),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        'Videos',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _navigateToPlayer,
                        child: Text(
                          'Playing',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Glass Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: GlassContainer(
                height: 44,
                borderRadius: BorderRadius.circular(22),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: TextStyle(color: AppStyles.getTextColor(context), fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: Icon(CupertinoIcons.search, color: AppStyles.getIconColor(context), size: 18),
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: AppStyles.getSubtextColor(context).withValues(alpha: 0.5), fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
            
            // Glass Shuffle Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: GlassContainer(
                height: 46,
                borderRadius: BorderRadius.circular(23),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shuffle Playback',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        playbackManager.toggleShuffle();
                        _showSnackbar(playbackManager.isShuffle ? "Shuffle Enabled" : "Shuffle Disabled");
                      },
                      child: Icon(
                        Icons.shuffle,
                        color: playbackManager.isShuffle ? AppStyles.primaryRed : AppStyles.getIconColor(context),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Glass Media Cards List
            Expanded(
              child: libraryManager.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppStyles.primaryRed))
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
                                      style: TextStyle(color: AppStyles.getSubtextColor(context), fontSize: 15),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(top: 8, bottom: 100),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final isCurrentPlaying = playbackManager.currentItem?.id == item.id;

                                return GlassContainer(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  padding: const EdgeInsets.all(8.0),
                                  borderRadius: BorderRadius.circular(16),
                                  opacity: isCurrentPlaying ? 0.16 : 0.07,
                                  border: Border.all(
                                    color: isCurrentPlaying 
                                        ? AppStyles.primaryRed.withValues(alpha: 0.4) 
                                        : (Theme.of(context).brightness == Brightness.light
                                            ? Colors.black.withValues(alpha: 0.08)
                                            : Colors.white.withValues(alpha: 0.1)),
                                    width: 1,
                                  ),
                                  child: Row(
                                    children: [
                                      // Thumbnail
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
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
                                      
                                      // Text Details
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTap: () {
                                            playbackManager.setPlaylist(filteredItems, index);
                                            Navigator.push(
                                              context,
                                              CupertinoPageRoute(
                                                builder: (context) => const PlayerScreen(),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: AppStyles.getTextColor(context),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      item.isVideo ? Icons.movie_outlined : Icons.audiotrack_outlined,
                                                      size: 14,
                                                      color: AppStyles.getSubtextColor(context),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatDuration(item.duration),
                                                      style: TextStyle(
                                                        color: AppStyles.getSubtextColor(context),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Playing dot
                                      if (isCurrentPlaying)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppStyles.primaryRed,
                                          ),
                                        ),

                                      // More actions info button
                                      IconButton(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: AppStyles.getIconColor(context),
                                          size: 22,
                                        ),
                                        onPressed: () => _showVideoActionsMenu(context, item),
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
            colors: [Color(0xFF1E293B), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFF5252), Color(0xFFFF7E5F)],
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
          size: 28,
        ),
      ),
    );
  }
}
