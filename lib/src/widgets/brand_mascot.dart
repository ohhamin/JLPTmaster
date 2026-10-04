import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BrandMascot extends StatelessWidget {
  const BrandMascot({
    super.key,
    this.size = 132,
  });

  final double size;

  static Future<Uint8List>? _bytesFuture;

  static Future<Uint8List> _loadBytes() {
    return _bytesFuture ??= () async {
      final parts = await Future.wait([
        rootBundle.loadString('assets/branding/app_icon.part-00'),
        rootBundle.loadString('assets/branding/app_icon.part-01'),
        rootBundle.loadString('assets/branding/app_icon.part-02'),
      ]);
      return base64Decode(parts.join());
    }();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _loadBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(width: size, height: size);
        }
        return Image.memory(
          snapshot.data!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
        );
      },
    );
  }
}
