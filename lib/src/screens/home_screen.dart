import 'package:flutter/material.dart';

import 'favorites_screen.dart';
import 'level_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemePressed,
  });

  final ThemeMode themeMode;
  final VoidCallback onThemePressed;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  IconData get _themeIcon => switch (widget.themeMode) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _index == 0 ? 'JLPTmaster' : '즐겨찾기',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '테마 변경',
            onPressed: widget.onThemePressed,
            icon: Icon(_themeIcon),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _index == 0 ? const LevelHomeScreen() : const FavoritesScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: '학습',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: '즐겨찾기',
          ),
        ],
      ),
    );
  }
}
