import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_scene_background.dart';
import '../widgets/brand_mascot.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService.instance;

  bool _signup = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_signup) {
        await _auth.signup(
          _usernameController.text,
          _passwordController.text,
        );
      } else {
        await _auth.login(
          _usernameController.text,
          _passwordController.text,
        );
      }
      if (!mounted) return;
      widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return AppSceneBackground(
      playful: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: 10,
                right: 14,
                child: ThemeToggleButton(),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 70, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.center,
                          child: BrandMascot(size: 142),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'JLPTmaster',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.9,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _signup
                              ? '작게 시작해서, 매일 조금씩 쌓아가요.'
                              : '오늘도 부담 없이, 한 단어씩 이어가요.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow.withValues(
                              alpha: dark ? 0.91 : 0.94,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: dark ? 0.16 : 0.045),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _signup ? '처음 만났네요!' : '다시 만나서 반가워요',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _usernameController,
                                  autofocus: true,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: '아이디',
                                    prefixIcon: Icon(Icons.person_outline_rounded),
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.length < 3) {
                                      return '아이디를 3자 이상 입력해 주세요.';
                                    }
                                    if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(text)) {
                                      return '영문, 숫자, _, -, . 만 사용할 수 있어요.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 13),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: '비밀번호',
                                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').length < 4) {
                                      return '비밀번호를 4자 이상 입력해 주세요.';
                                    }
                                    return null;
                                  },
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 13),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: scheme.errorContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _error!,
                                      style: TextStyle(color: scheme.onErrorContainer),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 54,
                                  child: FilledButton(
                                    onPressed: _submitting ? null : _submit,
                                    child: _submitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2.5),
                                          )
                                        : Text(
                                            _signup ? '회원가입' : '로그인',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _submitting
                                      ? null
                                      : () => setState(() {
                                            _signup = !_signup;
                                            _error = null;
                                          }),
                                  child: Text(
                                    _signup
                                        ? '이미 계정이 있어요 · 로그인'
                                        : '처음인가요? · 회원가입',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '한 번 로그인하면 이 기기에서는 자동 로그인됩니다.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
