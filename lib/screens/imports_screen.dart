import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/styles.dart';
import '../models/media_item.dart';
import '../providers/media_library_manager.dart';
import '../providers/playback_manager.dart';
import 'player_screen.dart';

class ImportsScreen extends StatefulWidget {
  const ImportsScreen({super.key});

  @override
  State<ImportsScreen> createState() => _ImportsScreenState();
}

class _ImportsScreenState extends State<ImportsScreen> {
  final _picker = ImagePicker();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

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

  // Clear all items (Matches "Clear" in top left)
  void _confirmClearLibrary() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Clear Library"),
        content: const Text("Are you sure you want to clear all imported media files? This will delete local persistent copies."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Clear"),
            onPressed: () async {
              final lib = Provider.of<MediaLibraryManager>(context, listen: false);
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              // Delete all items sequentially
              final items = List<MediaItem>.from(lib.mediaItems);
              for (var item in items) {
                await lib.deleteMediaItem(item.id);
              }
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text("Library cleared successfully")),
              );
            },
          ),
        ],
      ),
    );
  }

  // Import from Camera Roll (Gallery)
  Future<void> _importFromCameraRoll() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (!mounted) return;
      if (video != null) {
        final libManager = Provider.of<MediaLibraryManager>(context, listen: false);
        final item = await libManager.addMediaItem(
          sourcePath: video.path,
          originalName: video.name,
          type: MediaType.video,
        );
        if (item != null) {
          _showImportSuccess(item.title);
        }
      }
    } catch (e) {
      _showImportError(e.toString());
    }
  }

  // Import from Safari Downloads / Local Files (Native Document Picker)
  Future<void> _importFromFiles() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mp3', 'm4a', 'wav', 'mov', 'avi'],
      );
      if (!mounted) return;

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final isVideo = name.toLowerCase().endsWith('.mp4') || 
                        name.toLowerCase().endsWith('.mov') || 
                        name.toLowerCase().endsWith('.avi');
        
        final libManager = Provider.of<MediaLibraryManager>(context, listen: false);
        final item = await libManager.addMediaItem(
          sourcePath: path,
          originalName: name,
          type: isVideo ? MediaType.video : MediaType.audio,
        );
        if (item != null) {
          _showImportSuccess(item.title);
        }
      }
    } catch (e) {
      _showImportError(e.toString());
    }
  }

  // Show dialog to download from direct web URL
  void _showUrlDownloadDialog() {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    MediaType selectedType = MediaType.video;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: const Text("Download from URL"),
            content: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Column(
                children: [
                  CupertinoTextField(
                    controller: urlController,
                    placeholder: "https://example.com/movie.mp4",
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: "Save file as (Optional)",
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Text("Type:", style: TextStyle(fontSize: 14)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Row(
                          children: [
                            Icon(
                              selectedType == MediaType.video 
                                  ? CupertinoIcons.check_mark_circled_solid 
                                  : CupertinoIcons.circle,
                              size: 18,
                            ),
                            const Text(" Video", style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedType = MediaType.video;
                          });
                        },
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Row(
                          children: [
                            Icon(
                              selectedType == MediaType.audio 
                                  ? CupertinoIcons.check_mark_circled_solid 
                                  : CupertinoIcons.circle,
                              size: 18,
                            ),
                            const Text(" Audio", style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedType = MediaType.audio;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                child: const Text("Download"),
                onPressed: () {
                  final url = urlController.text.trim();
                  final filename = nameController.text.trim();
                  if (url.isEmpty) return;

                  Navigator.pop(context);
                  _startDownload(
                    url,
                    filename.isEmpty ? null : filename,
                    selectedType,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // Trigger downloader
  Future<void> _startDownload(String url, String? fileName, MediaType type) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final libManager = Provider.of<MediaLibraryManager>(context, listen: false);
    final item = await libManager.downloadMedia(
      url: url,
      fileName: fileName,
      type: type,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
    );

    if (!mounted) return;

    setState(() {
      _isDownloading = false;
    });

    if (item != null) {
      _showImportSuccess("Downloaded ${item.title}");
    } else {
      _showImportError("Failed to download file. Verify the URL is correct and public.");
    }
  }

  void _showImportSuccess(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Successfully imported: $name"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showImportError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error: $error"),
        backgroundColor: AppStyles.primaryRed,
      ),
    );
  }

  // Display Cloud integration details
  void _showCloudIntegrationGuide(String provider) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("$provider Integration"),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "iOS integrates $provider files directly into the native Files app. \n\n"
            "To import from $provider:\n"
            "1. Open the Files option.\n"
            "2. Access your $provider folders in the sidebar browse panel.\n"
            "3. Select the file you want to download and open in this app.",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Open Files"),
            onPressed: () {
              Navigator.pop(context);
              _importFromFiles();
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
                    onTap: _confirmClearLibrary,
                    child: const Text(
                      'Clear',
                      style: AppStyles.headerActionStyle,
                    ),
                  ),
                  const Text(
                    'Imports',
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
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(top: 15),
            children: [
              // Standard iOS List Section
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppStyles.dividerColor, width: 0.5),
                    bottom: BorderSide(color: AppStyles.dividerColor, width: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    _buildImportOption(
                      title: "Camera Roll",
                      icon: CupertinoIcons.photo_on_rectangle,
                      onTap: _importFromCameraRoll,
                    ),
                    const Divider(height: 0.5, indent: 56, color: AppStyles.dividerColor),
                    _buildImportOption(
                      title: "Files (Safari Downloads)",
                      icon: CupertinoIcons.folder_open,
                      onTap: _importFromFiles,
                    ),
                    const Divider(height: 0.5, indent: 56, color: AppStyles.dividerColor),
                    _buildImportOption(
                      title: "DropBox",
                      icon: CupertinoIcons.cloud,
                      onTap: () => _showCloudIntegrationGuide("Dropbox"),
                    ),
                    const Divider(height: 0.5, indent: 56, color: AppStyles.dividerColor),
                    _buildImportOption(
                      title: "Google Drive",
                      icon: CupertinoIcons.cloud_fill,
                      onTap: () => _showCloudIntegrationGuide("Google Drive"),
                    ),
                    const Divider(height: 0.5, indent: 56, color: AppStyles.dividerColor),
                    _buildImportOption(
                      title: "Download from URL Link",
                      icon: CupertinoIcons.link,
                      onTap: _showUrlDownloadDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Download overlay
          if (_isDownloading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppStyles.primaryRed),
                        const SizedBox(height: 16),
                        const Text(
                          "Downloading file...",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: Colors.grey.shade300,
                          color: AppStyles.primaryRed,
                        ),
                        const SizedBox(height: 8),
                        Text("${(_downloadProgress * 100).toStringAsFixed(0)}%"),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImportOption({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppStyles.primaryRed, size: 24),
      title: Text(title, style: AppStyles.importOptionStyle),
      trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.grey, size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
