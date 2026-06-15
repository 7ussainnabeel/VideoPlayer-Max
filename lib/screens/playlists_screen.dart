import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/styles.dart';
import '../models/playlist.dart';
import '../providers/media_library_manager.dart';
import '../providers/playback_manager.dart';
import 'player_screen.dart';
import '../widgets/video_preview_widget.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_container.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
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
        SnackBar(
          content: const Text("No media currently playing"),
          backgroundColor: AppStyles.primaryRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 90, left: 20, right: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // Create playlist dialog
  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("New Playlist"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: "Playlist Name",
            autofocus: true,
            style: const TextStyle(color: Colors.black),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text("Create"),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Provider.of<MediaLibraryManager>(context, listen: false).createPlaylist(name);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryManager = Provider.of<MediaLibraryManager>(context);

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
                        onTap: _showCreatePlaylistDialog,
                        child: Icon(
                          Icons.add,
                          color: AppStyles.getTextColor(context),
                          size: 26,
                        ),
                      ),
                      Text(
                        'Playlists',
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

            // Content List
            Expanded(
              child: libraryManager.playlists.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.playlist_add, size: 64, color: AppStyles.getSubtextColor(context)),
                          const SizedBox(height: 12),
                          Text(
                            "No playlists created yet.\nTap '+' in the top left to create one.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppStyles.getSubtextColor(context), fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 100),
                      itemCount: libraryManager.playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = libraryManager.playlists[index];
                        return Dismissible(
                          key: Key(playlist.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            libraryManager.deletePlaylist(playlist.id);
                          },
                          child: GlassContainer(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            borderRadius: BorderRadius.circular(16),
                            opacity: 0.08,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: const Icon(Icons.playlist_play, color: AppStyles.primaryRed, size: 28),
                              title: Text(
                                playlist.name, 
                                style: TextStyle(color: AppStyles.getTextColor(context), fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                              subtitle: Text(
                                "${playlist.items.length} items", 
                                style: TextStyle(color: AppStyles.getSubtextColor(context))
                              ),
                              trailing: Icon(CupertinoIcons.chevron_right, color: AppStyles.getChevronColor(context), size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => PlaylistDetailScreen(playlistId: playlist.id),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "${duration.inMinutes}:$twoDigitSeconds";
  }

  void _showAddItemsScreen(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => PlaylistAddItemsScreen(playlistId: playlistId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryManager = Provider.of<MediaLibraryManager>(context);
    final playbackManager = Provider.of<PlaybackManager>(context);

    // Find playlist
    final playlistIndex = libraryManager.playlists.indexWhere((element) => element.id == playlistId);
    if (playlistIndex == -1) {
      return const Scaffold(body: Center(child: Text("Playlist not found")));
    }
    final playlist = libraryManager.playlists[playlistIndex];

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
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.left_chevron, color: AppStyles.getTextColor(context), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppStyles.getTextColor(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        playlist.name,
                        style: TextStyle(
                          fontSize: 18,
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showAddItemsScreen(context, playlist),
                        child: Text(
                          'Add',
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

            // Playlist Items Reorderable List
            Expanded(
              child: playlist.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.playlist_add, size: 64, color: AppStyles.getSubtextColor(context)),
                          const SizedBox(height: 12),
                          Text(
                            "This playlist is empty.\nTap 'Add' in the top right to add tracks.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppStyles.getSubtextColor(context), fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 100),
                      itemCount: playlist.items.length,
                      onReorder: (oldIndex, newIndex) {
                        libraryManager.reorderPlaylist(playlistId, oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final item = playlist.items[index];
                        return Dismissible(
                          key: Key('${item.id}_dismiss'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_sweep, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            libraryManager.removeMediaFromPlaylist(playlistId, item.id);
                          },
                          child: GlassContainer(
                            key: Key('${item.id}_container'),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(8.0),
                            borderRadius: BorderRadius.circular(16),
                            opacity: 0.08,
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
                                        : const ContainerAudioPlaceholder(),
                                  ),
                                ),
                                
                                // Details
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () {
                                      playbackManager.setPlaylist(playlist.items, index);
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
                                
                                // Playing indicator
                                if (playbackManager.currentItem?.id == item.id)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppStyles.primaryRed,
                                    ),
                                  ),

                                // Drag handle
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: AppStyles.getChevronColor(context),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaylistAddItemsScreen extends StatelessWidget {
  final String playlistId;
  const PlaylistAddItemsScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final libraryManager = Provider.of<MediaLibraryManager>(context);

    // Find playlist to filter items already in it
    final playlist = libraryManager.playlists.firstWhere((element) => element.id == playlistId);
    final availableItems = libraryManager.mediaItems.where((item) {
      return !playlist.items.any((e) => e.id == item.id);
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
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        'Add Items',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
              ),
            ),

            // Available items list
            Expanded(
              child: availableItems.isEmpty
                  ? Center(
                      child: Text(
                        "All items are already in this playlist\nor no media imported yet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppStyles.getSubtextColor(context), fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 40),
                      itemCount: availableItems.length,
                      itemBuilder: (context, index) {
                        final item = availableItems[index];
                        return GlassContainer(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          borderRadius: BorderRadius.circular(16),
                          opacity: 0.08,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Icon(
                              item.isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.music_note_2,
                              color: AppStyles.primaryRed,
                              size: 24,
                            ),
                            title: Text(
                              item.title, 
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              item.isVideo ? "Video" : "Audio (MP3)",
                              style: TextStyle(color: AppStyles.getSubtextColor(context)),
                            ),
                            trailing: const Icon(Icons.add_circle_outline, color: AppStyles.primaryRed, size: 22),
                            onTap: () {
                              libraryManager.addMediaToPlaylist(playlistId, item);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Added: ${item.title}"),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContainerVideoPlaceholder extends StatelessWidget {
  const ContainerVideoPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(CupertinoIcons.video_camera_solid, color: Colors.white70, size: 28),
      ),
    );
  }
}

class ContainerAudioPlaceholder extends StatelessWidget {
  const ContainerAudioPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5252), Color(0xFFFF7E5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(CupertinoIcons.music_note_2, color: Colors.white70, size: 28),
      ),
    );
  }
}
