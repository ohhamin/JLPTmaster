import 'package:flutter/material.dart';

/// Full-screen illustrated scenery shared by every JLPTmaster route.
///
/// Light mode uses the generated blue-sky meadow artwork, while dark mode
/// switches to the generated charcoal cave and lantern artwork. The artwork is
/// deliberately kept behind translucent Material surfaces so the app stays
/// readable and uncluttered.
class AppSceneBackground extends StatelessWidget {
  const AppSceneBackground({
    super.key,
    required this.child,
    this.playful = false,
  });

  final Widget child;
  final bool playful;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = dark
        ? 'assets/scenes/cave_dark.webp'
        : 'assets/scenes/meadow_light.webp';

    // Keep one fixed illustration behind each route so scrolling cards remain
    // crisp while the meadow/cave world stays visually stable.
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [
                        Color(0x10070B12),
                        Color(0x30070B12),
                        Color(0x50070B12),
                      ]
                    : const [
                        Color(0x08FFFFFF),
                        Color(0x12FFFFFF),
                        Color(0x28F6FBEF),
                      ],
                stops: const [0, 0.56, 1],
              ),
            ),
          ),
        ),
        if (!playful)
          Positioned.fill(
            child: ColoredBox(
              color: dark
                  ? const Color(0x12040A11)
                  : const Color(0x08FFFFFF),
            ),
          ),
        child,
      ],
    );
  }
}
