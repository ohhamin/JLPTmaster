import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copy a Japanese word, kanji or example without triggering the TTS target.
class CopyTextButton extends StatelessWidget {
  const CopyTextButton({super.key, required this.text, this.label = '텍스트'});

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '$label 복사',
      onPressed: text.trim().isEmpty ? null : () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('$label 복사했어요'),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      },
      icon: const Icon(Icons.content_copy_rounded, size: 17),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: const EdgeInsets.all(5),
    );
  }
}
