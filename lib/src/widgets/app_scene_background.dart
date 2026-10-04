import 'package:flutter/material.dart';

/// Full-screen illustrated scenery shared by every JLPTmaster route.
///
/// Both themes use the generated artwork directly:
/// - light: blue sky / clouds / meadow
/// - dark: cave / lantern
///
/// Do not recreate the cave with Flutter shapes. Keeping the real artwork as
/// the single background source makes dark mode match the approved mockup.
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ),

        // Only a very light readability wash is allowed. The artwork itself
        // must stay visible, especially the cave rocks and lantern in dark mode.
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: dark
                  ? const Color(0x08000000)
                  : const Color(0x05FFFFFF),
            ),
          ),
        ),

        child,
      ],
    );
  }
}
