import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/styles.dart';
import '../models/playlist.dart';
import '../providers/media_library_manager.dart';
import '../providers/playback_manager.dart';
import 'player_screen.dart';

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
        const SnackBar(
          content: Text("No media currently playing"),
          backgroundColor: AppStyles.primaryRed,
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
                    onTap: _showCreatePlaylistDialog,
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const Text(
                    'Playlists',
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
      body: libraryManager.playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_add, size: 64, color: AppStyles.textGray),
                  const SizedBox(height: 12),
                  const Text(
                    "No playlists created yet.\nTap '+' in the top left to create one.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppStyles.textGray, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 10),
              itemCount: libraryManager.playlists.length,
              separatorBuilder: (context, index) => const Divider(
                height: 0.5,
                color: AppStyles.dividerColor,
              ),
              itemBuilder: (context, index) {
                final playlist = libraryManager.playlists[index];
                return Dismissible(
                  key: Key(playlist.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    libraryManager.deletePlaylist(playlist.id);
                  },
                  child: Container(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(playlist.name, style: AppStyles.importOptionStyle),
                      subtitle: Text("${playlist.items.length} items", style: const TextStyle(color: AppStyles.textGray)),
                      trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.grey, size: 16),
                      onTap: () {
                        // Open detail screen
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
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.left_chevron, color: Colors.white, size: 20),
                        Text('Back', style: AppStyles.headerActionStyle),
                      ],
                    ),
                  ),
                  Text(
                    playlist.name,
                    style: AppStyles.headerTitleStyle,
                  ),
                  GestureDetector(
                    onTap: () => _showAddItemsScreen(context, playlist),
                    child: const Text(
                      'Add',
                      style: AppStyles.headerActionStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: playlist.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_add, size: 64, color: AppStyles.textGray),
                  const SizedBox(height: 12),
                  const Text(
                    "This playlist is empty.\nTap 'Add' in the top right to add tracks.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppStyles.textGray, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: playlist.items.length,
              separatorBuilder: (context, index) => const Divider(
                height: 0.5,
                indent: 90,
                color: AppStyles.dividerColor,
              ),
              itemBuilder: (context, index) {
                final item = playlist.items[index];
                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_sweep, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    libraryManager.removeMediaFromPlaylist(playlistId, item.id);
                  },
                  child: Container(
                    color: Colors.white,
                    height: 80,
                    child: Row(
                      children: [
                        // Custom Thumbnail
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
                                ? const ContainerVideoPlaceholder()
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
                        
                        // Playing indicator
                        if (playbackManager.currentItem?.id == item.id)
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Icon(
                              Icons.play_arrow,
                              color: AppStyles.primaryRed,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
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
                    onTap: () => Navigator.pop(context),
                    child: const Text('Cancel', style: AppStyles.headerActionStyle),
                  ),
                  const Text(
                    'Add Items',
                    style: AppStyles.headerTitleStyle,
                  ),
                  const SizedBox(width: 50), // Spacer to center
                ],
              ),
            ),
          ),
        ),
      ),
      body: availableItems.isEmpty
          ? const Center(
              child: Text(
                "All items are already in this playlist\nor no media imported yet.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppStyles.textGray, fontSize: 16),
              ),
            )
          : ListView.separated(
              itemCount: availableItems.length,
              separatorBuilder: (context, index) => const Divider(height: 0.5, color: AppStyles.dividerColor),
              itemBuilder: (context, index) {
                final item = availableItems[index];
                return Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: Icon(
                      item.isVideo ? CupertinoIcons.video_camera_solid : CupertinoIcons.music_note_2,
                      color: AppStyles.primaryRed,
                    ),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.isVideo ? "Video" : "Audio (MP3)"),
                    trailing: const Icon(Icons.add_circle_outline, color: AppStyles.primaryRed),
                    onTap: () {
                      libraryManager.addMediaToPlaylist(playlistId, item);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Added: ${item.title}")),
                      );
                    },
                  ),
                );
              },
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
          colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
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
          colors: [Color(0xFFE53935), Color(0xFFF39C12)],
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
