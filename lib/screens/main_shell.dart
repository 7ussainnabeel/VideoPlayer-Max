import 'package:flutter/material.dart';
import '../constants/styles.dart';
import '../widgets/glass_container.dart';
import 'imports_screen.dart';
import 'videos_screen.dart';
import 'playlists_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 1; // Default to Videos tab (middle)

  final List<Widget> _screens = const [
    ImportsScreen(),
    VideosScreen(),
    PlaylistsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Content Area
          Positioned.fill(
            child: Padding(
              // Allow content to scroll slightly under the floating bottom dock
              padding: const EdgeInsets.only(bottom: 0),
              child: _screens[_currentIndex],
            ),
          ),
          
          // Floating Glassmorphic Navigation Dock
          Positioned(
            left: 24,
            right: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: GlassContainer(
              height: 66,
              borderRadius: BorderRadius.circular(33),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              blur: 24.0,
              opacity: 0.10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.cloud_download_outlined, 'Imports'),
                  _buildNavItem(1, Icons.play_circle_outline, 'Videos'),
                  _buildNavItem(2, Icons.playlist_play, 'Playlists'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final activeColor = AppStyles.primaryRed;
    final inactiveColor = Colors.white60;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: isSelected ? 28 : 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
