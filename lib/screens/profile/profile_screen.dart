import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/history_provider.dart';
import '../../providers/likes_provider.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../services/library_service.dart';
import '../admin/admin_songs_screen.dart';
import '../../theme/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  int? _playlistCount;
  bool _isAdmin = false;

  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlaylistCount();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final admin = await AdminService().isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<void> _loadPlaylistCount() async {
    try {
      final list = await LibraryService().playlists();
      if (mounted) setState(() => _playlistCount = list.length);
    } catch (_) {
      // Biarkan tampil "-" kalau gagal
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadPlaylistCount(),
      context.read<LikesProvider>().load(),
    ]);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  String _joinedText(User? user) {
    final raw = user?.createdAt;
    if (raw == null) return '';
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return '';
    return 'Bergabung sejak ${_months[d.month - 1]} ${d.year}';
  }

  Future<void> _editUsername(String current) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _EditUsernameDialog(initial: current),
    );
    if (ok == true) _snack('Username berhasil diperbarui.');
  }

  Future<void> _changePassword() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (ok == true) _snack('Password berhasil diubah.');
  }

  Future<void> _confirmSignOut() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu harus masuk lagi untuk memutar musik.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yes == true) await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final theme = context.watch<ThemeProvider>();
    final likes = context.watch<LikesProvider>();
    final history = context.watch<HistoryProvider>();

    return StreamBuilder<AuthState>(
      stream: _auth.authChanges,
      builder: (context, _) {
        final user = _auth.user;
        final rawName = (user?.userMetadata?['username'] ?? '').toString().trim();
        final name = rawName.isEmpty ? 'User' : rawName;
        final joined = _joinedText(user);

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 8),

                // ===== Header =====
                Center(
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: cs.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(name,
                      style: tt.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 2),
                Center(
                  child: Text(user?.email ?? '',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                if (joined.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(joined,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
                ],
                const SizedBox(height: 24),

                // ===== Statistik =====
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.favorite_rounded,
                        value: '${likes.count}',
                        label: 'Disukai',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.queue_music_rounded,
                        value: _playlistCount?.toString() ?? '-',
                        label: 'Playlist',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.history_rounded,
                        value: '${history.songs.length}',
                        label: 'Riwayat',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ===== Akun =====
                _SectionTitle('Akun'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline_rounded),
                        title: const Text('Ubah username'),
                        subtitle: Text(name),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editUsername(rawName),
                      ),
                      Divider(height: 1, color: cs.outline),
                      ListTile(
                        leading: const Icon(Icons.lock_outline_rounded),
                        title: const Text('Ubah password'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _changePassword,
                      ),
                      Divider(height: 1, color: cs.outline),
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded),
                        title: const Text('Email'),
                        subtitle: Text(user?.email ?? '-'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ===== Admin (hanya tampil untuk admin) =====
                if (_isAdmin) ...[
                  _SectionTitle('Admin'),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.library_music_rounded),
                      title: const Text('Kelola lagu'),
                      subtitle: const Text(
                        'Unggah & hapus lagu sendiri (diputar penuh)',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminSongsScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // ===== Tampilan =====
                _SectionTitle('Tampilan'),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded),
                        label: Text('Terang')),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded),
                        label: Text('Gelap')),
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.phone_android_rounded),
                        label: Text('Sistem')),
                  ],
                  selected: {theme.mode},
                  onSelectionChanged: (s) => theme.setMode(s.first),
                ),
                const SizedBox(height: 28),

                // ===== Tentang =====
                _SectionTitle('Tentang'),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('PinkBeat'),
                    subtitle: const Text(
                      'Lagu populer berupa cuplikan 30 detik. '
                          'Lagu independen diputar penuh.',
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ===== Keluar =====
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar'),
                  onPressed: _confirmSignOut,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================= Widget kecil =======================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: cs.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ======================= Dialog ubah username =======================

class _EditUsernameDialog extends StatefulWidget {
  final String initial;
  const _EditUsernameDialog({required this.initial});

  @override
  State<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<_EditUsernameDialog> {
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  final _form = GlobalKey<FormState>();
  late final TextEditingController _c =
  TextEditingController(text: widget.initial);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().updateUsername(_c.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal menyimpan, cek koneksimu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah username'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _c,
              autofocus: true,
              enabled: !_loading,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                hintText: 'Username baru',
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
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

// ======================= Dialog ubah password =======================

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().updatePassword(_new.text);
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal menyimpan, cek koneksimu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah password'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _new,
              obscureText: _hide,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Password baru',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_hide
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (v) =>
              (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _hide,
              enabled: !_loading,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                hintText: 'Ulangi password baru',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              validator: (v) => v != _new.text ? 'Password tidak sama' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}