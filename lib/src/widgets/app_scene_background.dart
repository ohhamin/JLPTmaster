import 'package:flutter/material.dart';

/// Soft, low-contrast scenery used to give JLPTmaster a playful world feel
/// without making study screens visually busy.
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

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [
                  Color(0xFF111A18),
                  Color(0xFF17221E),
                  Color(0xFF101714),
                ]
              : const [
                  Color(0xFFF8FAEE),
                  Color(0xFFF0F7E9),
                  Color(0xFFE8F2E1),
                ],
          stops: const [0, 0.58, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: dark
                ? _CaveDecorations(playful: playful)
                : _MeadowDecorations(playful: playful),
          ),
          child,
        ],
      ),
    );
  }
}

class _MeadowDecorations extends StatelessWidget {
  const _MeadowDecorations({required this.playful});

  final bool playful;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: -72,
          bottom: -88,
          child: _blob(230, const Color(0xFFBFD8A8).withValues(alpha: 0.34)),
        ),
        Positioned(
          right: -64,
          bottom: -104,
          child: _blob(260, const Color(0xFFA8CC96).withValues(alpha: 0.26)),
        ),
        Positioned(
          right: 28,
          top: 110,
          child: _dot(const Color(0xFFFFD59B), playful ? 18 : 12),
        ),
        Positioned(
          left: 26,
          top: playful ? 130 : 92,
          child: Icon(
            Icons.eco_rounded,
            size: playful ? 38 : 28,
            color: const Color(0xFF79A96F).withValues(alpha: 0.11),
          ),
        ),
        if (playful) ...[
          Positioned(
            right: 42,
            top: 206,
            child: Icon(
              Icons.local_florist_rounded,
              size: 30,
              color: const Color(0xFFF3A7A1).withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            left: 54,
            bottom: 118,
            child: _dot(const Color(0xFFFFFFFF), 10),
          ),
          Positioned(
            left: 82,
            bottom: 150,
            child: _dot(const Color(0xFFFFD89B), 7),
          ),
        ],
      ],
    );
  }
}

class _CaveDecorations extends StatelessWidget {
  const _CaveDecorations({required this.playful});

  final bool playful;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: -84,
          top: -92,
          child: _blob(250, const Color(0xFF24332D).withValues(alpha: 0.78)),
        ),
        Positioned(
          right: -92,
          top: -116,
          child: _blob(280, const Color(0xFF27372F).withValues(alpha: 0.72)),
        ),
        Positioned(
          left: 32,
          bottom: -108,
          child: _blob(250, const Color(0xFF203027).withValues(alpha: 0.66)),
        ),
        Positioned(
          right: 36,
          top: 136,
          child: _dot(const Color(0xFFE5BC72).withValues(alpha: 0.44), playful ? 12 : 8),
        ),
        Positioned(
          left: 58,
          top: playful ? 210 : 154,
          child: _dot(const Color(0xFFB4D7A3).withValues(alpha: 0.28), playful ? 9 : 6),
        ),
        if (playful) ...[
          Positioned(
            right: 74,
            bottom: 146,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 28,
              color: const Color(0xFFE7C27A).withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            left: 30,
            bottom: 122,
            child: Icon(
              Icons.grass_rounded,
              size: 44,
              color: const Color(0xFF89A97E).withValues(alpha: 0.10),
            ),
          ),
        ],
      ],
    );
  }
}

Widget _blob(double size, Color color) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.44),
    ),
  );
}

Widget _dot(Color color, double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
