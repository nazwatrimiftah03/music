import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

enum _AuthMode { login, register, forgot }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _username = TextEditingController();
  final _auth = AuthService();

  _AuthMode _mode = _AuthMode.login;
  bool _loading = false;
  bool _hide = true;
  bool _hideConfirm = true;

  bool get _isLogin => _mode == _AuthMode.login;
  bool get _isRegister => _mode == _AuthMode.register;
  bool get _isForgot => _mode == _AuthMode.forgot;

  @override
  void initState() {
    super.initState();
    // Supaya garis kekuatan password ikut berubah saat mengetik
    _pass.addListener(() {
      if (_isRegister && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    _username.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  void _switchMode(_AuthMode mode) {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    _form.currentState?.reset();
    _pass.clear();
    _confirm.clear();
    setState(() {
      _mode = mode;
      _hide = true;
      _hideConfirm = true;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final email = _email.text.trim();

      if (_isLogin) {
        await _auth.signIn(email, _pass.text);
      } else if (_isRegister) {
        final res = await _auth.signUp(email, _pass.text, _username.text.trim());
        if (res.session == null) {
          _snack('Pendaftaran berhasil, cek email untuk konfirmasi.');
          _switchMode(_AuthMode.login);
        }
      } else {
        await _auth.resetPassword(email);
        _snack('Tautan reset password sudah dikirim ke $email.');
        _switchMode(_AuthMode.login);
      }
    } on AuthException catch (e) {
      _snack(AuthService.friendlyError(e));
    } catch (_) {
      _snack('Terjadi kesalahan, cek koneksi internetmu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== Kekuatan password =====
  int _strength(String p) {
    var score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score; // 0..4
  }

  Widget _strengthBar(ColorScheme cs) {
    final s = _strength(_pass.text);
    const labels = ['Sangat lemah', 'Lemah', 'Cukup', 'Kuat', 'Sangat kuat'];
    final colors = [
      AppColors.danger,
      AppColors.danger,
      AppColors.warning,
      AppColors.success,
      AppColors.success,
    ];
    final empty = _pass.text.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: empty ? 0 : (s + 1) / 5,
              minHeight: 5,
              backgroundColor: cs.outline,
              color: colors[s],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            empty
                ? 'Gunakan 8+ karakter, huruf besar-kecil, angka, dan simbol'
                : 'Kekuatan password: ${labels[s]}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String get _subtitle {
    switch (_mode) {
      case _AuthMode.login:
        return 'Masuk untuk lanjut dengerin musik';
      case _AuthMode.register:
        return 'Buat akun dan mulai dengerin musik';
      case _AuthMode.forgot:
        return 'Masukkan email akunmu, kami kirim tautan untuk mengatur ulang password';
    }
  }

  String get _buttonText {
    switch (_mode) {
      case _AuthMode.login:
        return 'Masuk';
      case _AuthMode.register:
        return 'Daftar';
      case _AuthMode.forgot:
        return 'Kirim Tautan Reset';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [cs.primaryContainer, bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ===== Logo =====
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(Icons.music_note_rounded,
                              size: 46, color: cs.onPrimary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('PinkBeat',
                          textAlign: TextAlign.center,
                          style: tt.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800, color: cs.primary)),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _subtitle,
                          key: ValueKey(_mode),
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ===== Username (daftar saja) =====
                      if (_isRegister) ...[
                        TextFormField(
                          controller: _username,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newUsername],
                          decoration: const InputDecoration(
                            hintText: 'Username',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.length < 3) return 'Minimal 3 karakter';
                            if (!_usernameRegex.hasMatch(t)) {
                              return 'Hanya huruf, angka, titik, dan _ (maks 20)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ===== Email =====
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction:
                        _isForgot ? TextInputAction.done : TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) {
                          if (_isForgot) _submit();
                        },
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Email wajib diisi';
                          if (!_emailRegex.hasMatch(t)) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),

                      // ===== Password =====
                      if (!_isForgot) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _pass,
                          obscureText: _hide,
                          textInputAction: _isRegister
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autofillHints: [
                            _isRegister
                                ? AutofillHints.newPassword
                                : AutofillHints.password
                          ],
                          onFieldSubmitted: (_) {
                            if (_isLogin) _submit();
                          },
                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _hide ? 'Tampilkan' : 'Sembunyikan',
                              icon: Icon(_hide
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                          validator: (v) {
                            final t = v ?? '';
                            if (t.isEmpty) return 'Password wajib diisi';
                            if (t.length < 6) return 'Minimal 6 karakter';
                            return null;
                          },
                        ),
                      ],

                      if (_isRegister) ...[
                        _strengthBar(cs),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirm,
                          obscureText: _hideConfirm,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Ulangi password',
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_hideConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setState(() => _hideConfirm = !_hideConfirm),
                            ),
                          ),
                          validator: (v) =>
                          v != _pass.text ? 'Password tidak sama' : null,
                        ),
                      ],

                      // ===== Lupa password =====
                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : () => _switchMode(_AuthMode.forgot),
                            child: const Text('Lupa password?'),
                          ),
                        )
                      else
                        const SizedBox(height: 12),

                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                            CircularProgressIndicator(strokeWidth: 2.5))
                            : Text(_buttonText),
                      ),
                      const SizedBox(height: 14),

                      // ===== Pindah mode =====
                      if (_isForgot)
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => _switchMode(_AuthMode.login),
                          child: const Text('Kembali ke halaman masuk'),
                        )
                      else
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => _switchMode(
                              _isLogin ? _AuthMode.register : _AuthMode.login),
                          child: Text(_isLogin
                              ? 'Belum punya akun? Daftar'
                              : 'Sudah punya akun? Masuk'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}