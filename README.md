# VideoPlayer-Max 🎬🎵

A premium, custom iOS Multimedia Player built with Flutter. It features a stunning **Light & Dark Liquid Glass (Glassmorphic) UI**, biometric passcode locking, file/web downloading from cloud platforms and social networks, automatic iTunes/Finder sync, and native iOS audio extraction.

---

## ✨ Features

### 1. Liquid Glass Design System
* **Frosted Glass Styling:** Custom `GlassContainer` and `GlassBackground` widgets utilizing real-time blur backdrop filters.
* **Dynamic Themes:** Instant runtime switching between **System**, **Light**, and **Dark** modes.
  * *Dark Mode:* Deep midnight blue gradient canvas with neon glow effects.
  * *Light Mode:* Soft sky pastel gradients with dark high-contrast slate text.
* **Floating Glass Dock:** Frosted navigation bar following strict iOS aesthetics.

### 2. Multi-Source Import & Downloader
* **Camera Roll / Local Files:** Direct import from iOS Photos and the Files app (iCloud / Downloads).
* **Automatic iTunes / Finder File Sharing Sync:** Startup scan that imports directory files synchronized via cable/network and prunes references when deleted outside the app.
* **Direct Web URL Downloader:** Custom download engine supporting cancelable downloads.
* **Dropbox & Google Drive Integration:** Direct shared link downloading with automated Google large-file virus scanner bypass and content header filename resolving.
* **Social Media Downloader:** YouTube high-quality audio/video extraction (`youtube_explode_dart`) and Instagram, Twitter/X, and TikTok direct stream resolving (Cobalt API integration).

### 3. Native iOS Video-to-Audio Extraction
* **AVAssetExportSession Integration:** If a video link (e.g., MP4/MOV) is downloaded with the type set to **Audio**, a native Swift `MethodChannel` launches iOS `AVAssetExportSession` with the `AVAssetExportPresetAppleM4A` preset.
* **Zero Dependencies:** Performs extraction on-device at hardware speeds, prunes the raw video download, and imports a proper `.m4a` audio track.

### 4. Custom Media Player
* **Elite Controller Layout:** Custom elapsed/remaining timing labels, repeat loops, aspect ratio toggling, volume sliders, and mute controllers.
* **Background Playback:** Integrated `audio_session` and `audio_service` to support background audio playback, iOS Control Center now playing widget, and lock screen metadata/commands.
* **Acoustic Visualizer:** Premium rotating vinyl animation for audio tracks.

### 5. Secure Pin & Biometrics Lock
* **Local Authentication:** Gate access to the library using Face ID / Touch ID or a fallback 4-digit PIN.
* **Background State Locking:** Automatically obscures content and shows the passcode screen if the app is backgrounded.

---

## 🛠️ Project Structure

```
lib/
├── constants/
│   └── styles.dart             # AppStyles tokens, themes, HSL colors, and getters
├── models/
│   ├── media_item.dart         # Core data representation for audio/video tracks
│   └── playlist.dart           # User playlist groups schema
├── providers/
│   ├── audio_handler.dart      # iOS Background Audio Service hooks
│   ├── media_library_manager.dart # Persistent library state, syncing, and downloads
│   └── playback_manager.dart   # Playback queues, repeat, shuffle, and volumes
├── screens/
│   ├── main_shell.dart         # Navigation shell with floating glass dock
│   ├── videos_screen.dart      # Library grid, dynamic previews, and actions menu
│   ├── playlists_screen.dart   # Playlist folders and custom queues
│   ├── imports_screen.dart     # Cloud picker, URL downloads, and progress cancel
│   ├── player_screen.dart      # Custom player interface and reorderable drawer
│   ├── settings_screen.dart    # Theme configurations and passcode manager
│   └── pin_lock_screen.dart    # Frosted biometric locking gate
└── widgets/
    ├── glass_background.dart   # Frosted glass background overlay
    ├── glass_container.dart    # Curved frosted layout card
    └── video_preview_widget.dart # Hover/auto-playing grid preview controller
```

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.12.2 or higher)
* Xcode (15.0 or higher for iOS development)
* CocoaPods (`sudo gem install cocoapods`)

### Installation & Run

1. **Clone and open the directory:**
   ```bash
   cd "/Users/7ussain_nabeel/CodingProjects/Github/VideoPlayer-Max"
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Install CocoaPods wrappers:**
   ```bash
   cd ios
   pod install
   cd ..
   ```

4. **Launch the application:**
   - Launch an iOS Simulator or connect a physical developer device.
   - Run:
     ```bash
     flutter run
     ```
