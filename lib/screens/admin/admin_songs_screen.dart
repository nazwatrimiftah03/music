import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../services/admin_service.dart';

/// Daftar lagu yang diunggah admin + tombol tambah / hapus.
class AdminSongsScreen extends StatefulWidget {
  const AdminSongsScreen({super.key});

  @override
  State<AdminSongsScreen> createState() => _AdminSongsScreenState();
}

class _AdminSongsScreenState extends State<AdminSongsScreen> {
  final _admin = AdminService();
  late Future<List<Song>> _future;

  @override
  void initState() {
    super.initState();
    _future = _admin.ownSongs();
  }

  void _reload() {
    setState(() {
      _future = _admin.ownSongs();
    });
  }

  Future<void> _add() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddSongScreen()),
    );
    if (added == true && mounted) _reload();
  }

  Future<void> _delete(Song song) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus lagu?'),
        content: Text(
          '"${song.title}" akan dihapus dari aplikasi untuk semua pengguna.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _admin.deleteSong(song);
      if (mounted) _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola lagu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah lagu'),
      ),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal memuat: ${snap.error}'),
              ),
            );
          }

          final songs = snap.data ?? [];
          if (songs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Belum ada lagu yang diunggah.\n'
                      'Tekan "Tambah lagu" untuk mulai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: songs.length,
              itemBuilder: (context, i) {
                final song = songs[i];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      song.coverUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: cs.surfaceContainerHighest,
                        child: const Icon(Icons.music_note_rounded),
                      ),
                    ),
                  ),
                  title: Text(song.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    song.genre == null
                        ? song.artist
                        : '${song.artist} • ${song.genre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                    onPressed: () => _delete(song),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ======================= Form tambah lagu =======================

class AddSongScreen extends StatefulWidget {
  const AddSongScreen({super.key});

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  // (label, tag). Tag disamakan dengan genre di Jamendo supaya lagu ini ikut
  // dihitung di "Rekomendasi untuk kamu".
  static const _genres = [
    ('Tanpa genre', ''),
    ('Pop', 'pop'),
    ('Rock', 'rock'),
    ('Elektronik', 'electronic'),
    ('Hip Hop', 'hiphop'),
    ('Jazz', 'jazz'),
    ('Klasik', 'classical'),
    ('Indie', 'indie'),
    ('Ambient', 'ambient'),
    ('Folk', 'folk'),
    ('Reggae', 'reggae'),
  ];

  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _admin = AdminService();

  String _genre = '';

  String? _audioName;
  Uint8List? _audioBytes;
  String? _coverName;
  Uint8List? _coverBytes;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _audioName = file.name;
        _audioBytes = bytes;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memilih audio: $e');
    }
  }

  Future<void> _pickCover() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _coverName = file.name;
        _coverBytes = bytes;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memilih cover: $e');
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    if (_audioBytes == null || _audioName == null) {
      setState(() => _error = 'Pilih file audio dulu.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _admin.addSong(
        title: _title.text.trim(),
        artist: _artist.text.trim(),
        genre: _genre,
        audioName: _audioName!,
        audioBytes: _audioBytes!,
        coverName: _coverName,
        coverBytes: _coverBytes,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Gagal menyimpan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah lagu')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Judul lagu'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Judul wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _artist,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Artis'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Artis wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _genre,
                    decoration: const InputDecoration(labelText: 'Genre'),
                    items: [
                      for (final g in _genres)
                        DropdownMenuItem(value: g.$2, child: Text(g.$1)),
                    ],
                    onChanged: (v) => setState(() => _genre = v ?? ''),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.audio_file_rounded),
              label: Text(_audioName ?? 'Pilih file audio (mp3, m4a, wav)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickCover,
              icon: const Icon(Icons.image_rounded),
              label: Text(_coverName ?? 'Pilih cover (opsional)'),
            ),
            if (_coverBytes != null) ...[
              const SizedBox(height: 12),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _coverBytes!,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
                  : const Text('Unggah & simpan'),
            ),
            const SizedBox(height: 8),
            Text(
              'Gunakan hanya lagu yang kamu punya haknya (karya sendiri atau '
                  'berlisensi bebas).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}