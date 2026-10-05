import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/profile_service.dart';

class NicknameDialog extends StatefulWidget {
  const NicknameDialog({
    super.key,
    required this.initialValue,
    required this.requiredNickname,
    required this.onSave,
  });

  final String initialValue;
  final bool requiredNickname;
  final Future<void> Function(String nickname) onSave;

  static Future<void> show(
    BuildContext context, {
    required bool requiredNickname,
    required String initialValue,
    required Future<void> Function(String nickname) onSave,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !requiredNickname,
      builder: (context) => NicknameDialog(
        initialValue: initialValue,
        requiredNickname: requiredNickname,
        onSave: onSave,
      ),
    );
  }

  @override
  State<NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<NicknameDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  bool get _valid => ProfileService.isValidNickname(_controller.text);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_error != null || mounted) {
      setState(() => _error = null);
    }
  }

  Future<void> _save() async {
    if (_saving || !_valid) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_controller.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ArgumentError
            ? '닉네임은 한글 2~6자로 입력해 주세요.'
            : '닉네임 저장에 실패했어요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !widget.requiredNickname && !_saving,
      child: AlertDialog(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.badge_rounded, color: scheme.primary, size: 21),
            ),
            const SizedBox(width: 11),
            Text(widget.requiredNickname ? '닉네임을 정해주세요' : '닉네임 수정'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.requiredNickname
                  ? 'JLPTmaster에서 사용할 닉네임이에요. 처음 한 번은 꼭 설정해야 해요.'
                  : '카드와 마이페이지에 표시될 닉네임을 바꿀 수 있어요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_saving,
              maxLength: 6,
              inputFormatters: [LengthLimitingTextInputFormatter(6)],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: '닉네임',
                hintText: '한글 2~6자',
                errorText: _error ??
                    (_controller.text.isNotEmpty && !_valid
                        ? '한글 2~6자로 입력해 주세요.'
                        : null),
                border: const OutlineInputBorder(),
                counterText: '${_controller.text.length}/6',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '공백, 영문, 숫자, 특수문자는 사용할 수 없어요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          if (!widget.requiredNickname)
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          FilledButton(
            onPressed: _valid && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}
