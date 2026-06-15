import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../constants/styles.dart';
import '../models/media_item.dart';
import '../providers/media_library_manager.dart';
import '../providers/playback_manager.dart';
import 'player_screen.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_container.dart';

class ImportsScreen extends StatefulWidget {
  const ImportsScreen({super.key});

  @override
  State<ImportsScreen> createState() => _ImportsScreenState();
}

class _ImportsScreenState extends State<ImportsScreen> {
  final _picker = ImagePicker();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  CancelToken? _cancelToken;

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
                SnackBar(
                  content: const Text("Library cleared successfully"),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
                    placeholder: "YouTube URL or direct media link",
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: "Save file as (Optional)",
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Text("Type:", style: TextStyle(fontSize: 14, color: Colors.black87)),
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

  Future<void> _startDownload(String url, String? fileName, MediaType type) async {
    _cancelToken = CancelToken();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final libManager = Provider.of<MediaLibraryManager>(context, listen: false);
    final item = await libManager.downloadMedia(
      url: url,
      fileName: fileName,
      type: type,
      cancelToken: _cancelToken,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
    );

    final isCancelled = _cancelToken?.isCancelled ?? false;

    if (!mounted) return;

    setState(() {
      _isDownloading = false;
    });

    if (isCancelled) {
      _showImportError("Download cancelled");
    } else if (item != null) {
      _showImportSuccess("Downloaded ${item.title}");
    } else {
      _showImportError("Failed to download file. Verify the URL is correct and public.");
    }
    _cancelToken = null;
  }

  void _showImportSuccess(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Successfully imported: $name", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showImportError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error: $error", style: const TextStyle(color: Colors.white)),
        backgroundColor: AppStyles.primaryRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 90, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Display Cloud Direct Downloader & File Browser Choice
  void _showCloudDownloadDialog(String provider) {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    MediaType selectedType = MediaType.video;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return CupertinoAlertDialog(
            title: Text("Download from $provider"),
            content: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Paste a shared link from $provider to download the video/audio directly:",
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: urlController,
                    placeholder: "$provider Share Link",
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: "Save file as (Optional)",
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Text("Type:", style: TextStyle(fontSize: 14, color: Colors.black87)),
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
                  const SizedBox(height: 8),
                  const Divider(color: Colors.black12),
                  const SizedBox(height: 4),
                  Text(
                    "Alternatively, browse your $provider directories directly via the iOS Files system:",
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: AppStyles.primaryRed,
                      borderRadius: BorderRadius.circular(8),
                      child: const Text(
                        "Browse Files App",
                        style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _importFromFiles();
                      },
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: Stack(
          children: [
            Column(
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
                            onTap: _confirmClearLibrary,
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppStyles.getTextColor(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            'Imports',
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

                // Glass Import Options List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    children: [
                      _buildImportOption(
                        title: "Camera Roll",
                        icon: CupertinoIcons.photo_on_rectangle,
                        onTap: _importFromCameraRoll,
                      ),
                      _buildImportOption(
                        title: "Files (Safari Downloads)",
                        icon: CupertinoIcons.folder_open,
                        onTap: _importFromFiles,
                      ),
                      _buildImportOption(
                        title: "Dropbox",
                        icon: CupertinoIcons.cloud,
                        onTap: () => _showCloudDownloadDialog("Dropbox"),
                      ),
                      _buildImportOption(
                        title: "Google Drive",
                        icon: CupertinoIcons.cloud_fill,
                        onTap: () => _showCloudDownloadDialog("Google Drive"),
                      ),
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
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: GlassContainer(
                      width: MediaQuery.of(context).size.width * 0.85,
                      padding: const EdgeInsets.all(28.0),
                      opacity: 0.16,
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppStyles.primaryRed),
                          const SizedBox(height: 20),
                          Text(
                            "Downloading file...",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppStyles.getTextColor(context)),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              minHeight: 6,
                              backgroundColor: AppStyles.getDividerColor(context),
                              color: AppStyles.primaryRed,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${(_downloadProgress * 100).toStringAsFixed(0)}%",
                            style: TextStyle(color: AppStyles.getSubtextColor(context), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 120,
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              color: AppStyles.primaryRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  color: AppStyles.primaryRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              onPressed: () {
                                _cancelToken?.cancel();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportOption({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      borderRadius: BorderRadius.circular(16),
      opacity: 0.08,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: AppStyles.primaryRed, size: 24),
        title: Text(
          title, 
          style: TextStyle(color: AppStyles.getTextColor(context), fontSize: 16, fontWeight: FontWeight.bold)
        ),
        trailing: Icon(CupertinoIcons.chevron_right, color: AppStyles.getChevronColor(context), size: 16),
        onTap: onTap,
      ),
    );
  }
}
