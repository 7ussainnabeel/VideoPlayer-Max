# App Store Upload & Review Guidelines Checklist 🚀

This document lists step-by-step procedures, configurations, and critical review precautions to safely upload and pass Apple App Store review for **VideoPlayer-Max**.

---

## ⚠️ Critical Review Precaution: Guideline 5.2.3 (Media Downloader)
Apple strictly enforces **Guideline 5.2.3 (Intellectual Property - Audio/Video Downloader)**. Apps that facilitate direct downloading/saving of copyrighted content from third-party social networks (YouTube, Instagram, TikTok, Twitter/X) without explicit API keys or oauth agreements from those companies **will be summarily rejected**.

### How to Bypass Rejection during App Store Review:
1. **De-brand All Screen Copy & Assets:**
   - Ensure **no** text labels, hints, placeholders, screenshots, or app descriptions refer to "YouTube", "Instagram", "Twitter / X", or "TikTok".
   - Advertise the app purely as a *"Local Network File Downloader"* or *"Cloud Document Manager"* (focusing on Dropbox, Google Drive, and standard direct HTTP links).
2. **Implement Review-Period Feature Flags (Recommended):**
   - Connect **Firebase Remote Config** to the app.
   - Define a boolean flag `enable_social_downloads`.
   - Set `enable_social_downloads` to `false` in Firebase during the review window.
   - When the reviewer tests the URL input or downloads, the app will reject YouTube or social links with a generic error (e.g. *"Supported only for direct public file links"*).
   - Once the app is approved and status becomes *Ready for Distribution*, flip `enable_social_downloads` to `true` to activate full download abilities for standard users.
3. **Reviewer Demo Files:**
   - When submitting the review details inside App Store Connect, provide a sample URL that points to a **non-copyrighted, public domain MP4/MP3 file** on a generic file server (do not send them a YouTube or Instagram link).

---

## 📝 Required plist Configurations (`Info.plist`)
Ensure your `/ios/Runner/Info.plist` has the following keys configured with clear, reviewer-compliant descriptions. Lack of descriptions or vague descriptions will result in immediate rejection under **Guideline 5.1.1 (Privacy)**.

```xml
<!-- Background Audio Capability -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<!-- Face ID / Passcode Permission -->
<key>NSFaceIDUsageDescription</key>
<string>VideoPlayer-Max needs permission to use Face ID to verify your identity and unlock your private media vault.</string>

<!-- Gallery Export Permissions -->
<key>NSPhotoLibraryUsageDescription</key>
<string>VideoPlayer-Max needs access to your Photos library to pick videos for import and export tracks.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>VideoPlayer-Max needs permission to save exported files directly to your Camera Roll gallery.</string>

<!-- iTunes & Finder File Sharing Sync Capabilities -->
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

---

## 📦 Packaging & Archiving using Xcode

To create a build for App Store Connect distribution:

### Step 1: Prepare Flutter iOS build
Inside the project root:
```bash
flutter build ios --release
```

### Step 2: Configure signing in Xcode
1. Open the project in Xcode:
   - Double-click `/Users/7ussain_nabeel/CodingProjects/Github/VideoPlayer-Max/ios/Runner.xcworkspace`.
2. Under **Runner Target** > **Signing & Capabilities**:
   - Enable **Automatically manage signing**.
   - Select your Apple Developer account under **Team**.
   - Ensure the **Bundle Identifier** is registered on your developer account console.

### Step 3: Archive the App
1. In Xcode's top bar, select **Any iOS Device (arm64)** as the target device (do not select a simulator).
2. Click **Product** in the Xcode menu bar, then choose **Archive**.
3. Once archiving is complete, the Xcode Organizer window will appear.
4. Click **Distribute App** and follow the prompts to upload the package to **App Store Connect / TestFlight**.

---

## 📋 App Store Connect Submission Checklist

When finalizing the submission form on App Store Connect:

- [ ] **Privacy Policy URL:** A hosted link outlining data usage, particularly detailing that biometric data (Face ID) remains entirely on-device and that file downloads are local-only.
- [ ] **Review Demo Details:** Provide username/password (if login is ever enabled) or clear instructions on how the local biometrics mock PIN lock works (e.g., standard code `1234`).
- [ ] **Intellectual Property confirmation:** Ensure there are no trademark infringements in the keywords field or app store description page.
