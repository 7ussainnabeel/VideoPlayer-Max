import 'package:flutter/material.dart';
import '../constants/styles.dart';
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
      body: _screens[_currentIndex],
      bottomNavigationBar: Theme(
        data: ThemeData(
          canvasColor: AppStyles.bottomNavBg,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: AppStyles.bottomNavSelected,
          unselectedItemColor: AppStyles.bottomNavUnselected,
          backgroundColor: AppStyles.bottomNavBg,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.file_download_outlined, size: 28),
              label: 'Imports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.movie_creation_outlined, size: 28),
              label: 'Videos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.format_list_bulleted, size: 28),
              label: 'Playlists',
            ),
          ],
        ),
      ),
    );
  }
}
