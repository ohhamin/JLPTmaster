import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import '../widgets/app_scene_background.dart';
import 'favorites_screen.dart';
import 'level_home_screen.dart';
import 'my_page_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['JLPTmaster', '즐겨찾기', '마이페이지'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          title: Text(_titles[_index]),
          actions: const [
            ThemeToggleButton(),
            SizedBox(width: 10),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: [
            const LevelHomeScreen(),
            const FavoritesScreen(),
            MyPageScreen(onLogout: widget.onLogout),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                height: 72,
                backgroundColor: isDark
                    ? const Color(0xF218222E)
                    : const Color(0xF8FFFEF8),
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
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: '마이페이지',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
