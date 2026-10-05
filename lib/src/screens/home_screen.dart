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
    final scheme = Theme.of(context).colorScheme;

    return AppSceneBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          title: Text(
            _titles[_index],
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
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
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.72),
              ),
            ),
          ),
          child: NavigationBar(
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
    );
  }
}
