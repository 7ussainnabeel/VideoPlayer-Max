import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/styles.dart';
import '../providers/media_library_manager.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_container.dart';
import 'pin_lock_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final libraryManager = Provider.of<MediaLibraryManager>(context);
    final themeMode = libraryManager.themeMode;
    final isPinSet = libraryManager.appLockPin != null && libraryManager.appLockPin!.isNotEmpty;

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
                            Icon(
                              CupertinoIcons.left_chevron,
                              color: AppStyles.getTextColor(context),
                              size: 18,
                            ),
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
                        'Settings',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 60), // Balancing width
                    ],
                  ),
                ),
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 40, left: 16, right: 16),
                children: [
                  // --- APPEARANCE SECTION ---
                  _buildSectionHeader(context, "Appearance"),
                  const SizedBox(height: 8),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(16),
                    opacity: 0.08,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Choose App Theme",
                          style: TextStyle(
                            fontSize: 15,
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildThemeButton(context, ThemeMode.system, "System", themeMode)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildThemeButton(context, ThemeMode.light, "Light", themeMode)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildThemeButton(context, ThemeMode.dark, "Dark", themeMode)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- SECURITY SECTION ---
                  _buildSectionHeader(context, "Security & Privacy"),
                  const SizedBox(height: 8),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(8),
                    opacity: 0.08,
                    child: Column(
                      children: [
                        // Toggle Switch for Passcode Lock
                        ListTile(
                          leading: Icon(
                            isPinSet ? Icons.lock : Icons.lock_open,
                            color: AppStyles.getIconColor(context),
                          ),
                          title: Text(
                            "Passcode Lock",
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Switch.adaptive(
                            value: isPinSet,
                            activeTrackColor: AppStyles.primaryRed,
                            onChanged: (val) {
                              if (val) {
                                // Transition to setup PIN mode
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => PinLockScreen(
                                      forceSetupMode: true,
                                      onUnlocked: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Passcode Lock Enabled'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              } else {
                                // Verify current PIN to disable
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => PinLockScreen(
                                      onUnlocked: () async {
                                        await libraryManager.disableAppLock();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Passcode Lock Disabled'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),

                        // If PIN is enabled, display extra controls
                        if (isPinSet) ...[
                          const Divider(height: 1, color: Colors.white10),
                          ListTile(
                            leading: Icon(
                              Icons.pin,
                              color: AppStyles.getIconColor(context),
                            ),
                            title: Text(
                              "Change Passcode",
                              style: TextStyle(
                                color: AppStyles.getTextColor(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Icon(
                              CupertinoIcons.chevron_right,
                              color: AppStyles.getChevronColor(context),
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) => PinLockScreen(
                                    forceSetupMode: true,
                                    onUnlocked: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Passcode Changed Successfully'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          ListTile(
                            leading: const Icon(
                              Icons.security,
                              color: AppStyles.primaryRed,
                            ),
                            title: const Text(
                              "Lock App Now",
                              style: TextStyle(
                                color: AppStyles.primaryRed,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Icon(
                              CupertinoIcons.chevron_right,
                              color: AppStyles.getChevronColor(context),
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.pop(context); // Pop settings
                              libraryManager.lockApp(); // Secure app
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppStyles.getSubtextColor(context).withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeButton(
    BuildContext context,
    ThemeMode mode,
    String label,
    ThemeMode currentMode,
  ) {
    final isSelected = mode == currentMode;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: () {
        Provider.of<MediaLibraryManager>(context, listen: false).setThemeMode(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppStyles.primaryRed
              : (isLight
                  ? Colors.black.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.05)),
          border: Border.all(
            color: isSelected
                ? AppStyles.primaryRed
                : (isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.08)),
            width: 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : AppStyles.getTextColor(context),
          ),
        ),
      ),
    );
  }
}
