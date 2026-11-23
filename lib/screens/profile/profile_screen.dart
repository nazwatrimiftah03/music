
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/data_saver_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/likes_provider.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../services/library_service.dart';
import '../admin/admin_songs_screen.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/listening_stats.dart';

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
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlaylistCount();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    try {
      final admin = await AdminService().isAdmin();

      if (mounted) {
        setState(() => _isAdmin = admin);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAdmin = false);
      }
    }
  }

  Future<void> _loadPlaylistCount() async {
    try {
      final list = await LibraryService().playlists();

      if (mounted) {
        setState(() => _playlistCount = list.length);
      }
    } catch (_) {
      // Tampilkan tanda "-" jika gagal memuat playlist.
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadPlaylistCount(),
      context.read<LikesProvider>().load(),
    ]);
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _joinedText(User? user) {
    final raw = user?.createdAt;

    if (raw == null) return '';

    final date = DateTime.tryParse(raw)?.toLocal();

    if (date == null) return '';

    return 'Bergabung sejak ${_months[date.month - 1]} ${date.year}';
  }

  Future<void> _editUsername(String current) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _EditUsernameDialog(initial: current),
    );

    if (result == true) {
      _snack('Username berhasil diperbarui.');
    }
  }

  Future<void> _changePassword() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );

    if (result == true) {
      _snack('Password berhasil diubah.');
    }
  }

  Future<void> _confirmSignOut() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu harus masuk lagi untuk menggunakan akun PinkBeat.',
        ),
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

    if (yes == true) {
      await _auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final cs = themeData.colorScheme;
    final tt = themeData.textTheme;

    final theme = context.watch<ThemeProvider>();
    final dataSaver = context.watch<DataSaverProvider>();
    final likes = context.watch<LikesProvider>();
    final history = context.watch<HistoryProvider>();

    return StreamBuilder<AuthState>(
      stream: _auth.authChanges,
      builder: (context, snapshot) {
        final user = _auth.user;

        final rawName =
        (user?.userMetadata?['username'] ?? '').toString().trim();

        final name = rawName.isEmpty ? 'User' : rawName;
        final joined = _joinedText(user);

        return SafeArea(
          child: RefreshIndicator(
            color: cs.primary,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              children: [
                // HEADER
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profil Saya',
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kelola akun dan preferensi musikmu.',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.settings_rounded,
                      color: cs.primary,
                      size: 27,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // PROFILE CARD
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary,
                        cs.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 43,
                          backgroundColor: Colors.white,
                          child: Text(
                            name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 35,
                              fontWeight: FontWeight.w900,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        user?.email ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      if (joined.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              joined,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // STATISTIK
                Text(
                  'Aktivitas Musik',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.favorite_rounded,
                        value: '${likes.count}',
                        label: 'Disukai',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.queue_music_rounded,
                        value: _playlistCount?.toString() ?? '-',
                        label: 'Playlist',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.history_rounded,
                        value: '${history.songs.length}',
                        label: 'Riwayat',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // RIWAYAT MUSIK
                _SectionTitle('Sering Kamu Dengarkan'),
                const SizedBox(height: 12),

                ListeningStats(songs: history.songs),

                const SizedBox(height: 28),

                // PENGATURAN AKUN
                _SectionTitle('Pengaturan Akun'),
                const SizedBox(height: 12),

                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.person_outline_rounded,
                          color: cs.primary,
                        ),
                        title: const Text(
                          'Ubah username',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(name),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                        ),
                        onTap: () => _editUsername(rawName),
                      ),
                      Divider(
                        height: 1,
                        color: cs.outlineVariant,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.lock_outline_rounded,
                          color: cs.primary,
                        ),
                        title: const Text(
                          'Ubah password',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                        ),
                        onTap: _changePassword,
                      ),
                      Divider(
                        height: 1,
                        color: cs.outlineVariant,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.email_outlined,
                          color: cs.primary,
                        ),
                        title: const Text(
                          'Email',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          user?.email ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // ADMIN
                if (_isAdmin) ...[
                  const SizedBox(height: 26),
                  _SectionTitle('Administrator'),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.library_music_rounded,
                        color: cs.primary,
                      ),
                      title: const Text(
                        'Kelola lagu',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Unggah dan hapus lagu PinkBeat.',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminSongsScreen(),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // PERSONALISASI
                _SectionTitle('Personalisasi'),
                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tema aplikasi',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_rounded),
                                label: Text('Terang'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_rounded),
                                label: Text('Gelap'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.phone_android_rounded),
                                label: Text('Sistem'),
                              ),
                            ],
                            selected: {theme.mode},
                            onSelectionChanged: (selection) {
                              theme.setMode(selection.first);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.data_saver_on_rounded,
                      color: cs.primary,
                    ),
                    title: const Text(
                      'Hemat data',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Gambar sampul tidak dimuat. '
                          'Lagu tetap diputar seperti biasa.',
                    ),
                    value: dataSaver.enabled,
                    onChanged: dataSaver.setEnabled,
                  ),
                ),

                const SizedBox(height: 28),

                // TENTANG
                _SectionTitle('Tentang PinkBeat'),
                const SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: cs.primary,
                        size: 27,
                      ),
                    ),
                    title: const Text(
                      'PinkBeat',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Musik untuk menemani setiap suasana. '
                          'Lagu populer berupa cuplikan 30 detik. '
                          'Lagu independen diputar penuh.',
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // LOGOUT
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: cs.error,
                    side: BorderSide(
                      color: cs.error.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Keluar dari akun',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: _confirmSignOut,
                ),

                const SizedBox(height: 18),

                Center(
                  child: Text(
                    'Made with love by PinkBeat',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================================================
// WIDGET KECIL
// ======================================================

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 17,
          horizontal: 4,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: cs.primary,
              size: 24,
            ),
            const SizedBox(height: 9),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// DIALOG UBAH USERNAME
// ======================================================

class _EditUsernameDialog extends StatefulWidget {
  final String initial;

  const _EditUsernameDialog({
    required this.initial,
  });

  @override
  State<_EditUsernameDialog> createState() =>
      _EditUsernameDialogState();
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

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = AuthService.friendlyError(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Gagal menyimpan, cek koneksimu.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
              validator: (value) {
                final text = (value ?? '').trim();

                if (text.length < 3) {
                  return 'Minimal 3 karakter';
                }

                if (!_usernameRegex.hasMatch(text)) {
                  return 'Hanya huruf, angka, titik, dan _ (maks 20)';
                }

                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: cs.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

// ======================================================
// DIALOG UBAH PASSWORD
// ======================================================

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState
    extends State<_ChangePasswordDialog> {
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

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = AuthService.friendlyError(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Gagal menyimpan, cek koneksimu.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                  icon: Icon(
                    _hide
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() => _hide = !_hide);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Minimal 6 karakter';
                }

                return null;
              },
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
              validator: (value) {
                if (value != _new.text) {
                  return 'Password tidak sama';
                }

                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: cs.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
