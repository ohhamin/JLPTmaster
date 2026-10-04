import 'package:flutter/material.dart';

class TtsPressable extends StatefulWidget {
  const TtsPressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.alignment = Alignment.center,
  });

  final VoidCallback onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final AlignmentGeometry alignment;

  @override
  State<TtsPressable> createState() => _TtsPressableState();
}

class _TtsPressableState extends State<TtsPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 85),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 85),
          curve: Curves.easeOut,
          alignment: widget.alignment,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _pressed
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _pressed
                  ? scheme.primary.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
