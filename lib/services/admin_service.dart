import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/song.dart';
import 'song_service.dart';

/// Fitur admin: unggah & hapus lagu sendiri (diputar PENUH).
/// File disimpan di Supabase Storage (bucket "music"), datanya di tabel songs
/// dengan id berawalan "own_".
class AdminService {
  static const String bucket = 'music';

  final SupabaseClient _db = Supabase.instance.client;

  /// True kalau akun yang sedang login terdaftar di tabel `admins`.
  Future<bool> isAdmin() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return false;

    try {
      final row = await _db
          .from('admins')
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Lagu yang sudah diunggah (terbaru di atas).
  Future<List<Song>> ownSongs() async {
    final songs = await SongService().ownSongs();
    return songs.reversed.toList();
  }

  Future<Song> addSong({
    required String title,
    required String artist,
    String? genre,
    required String audioName,
    required Uint8List audioBytes,
    String? coverName,
    Uint8List? coverBytes,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final storage = _db.storage.from(bucket);

    final audioPath = 'audio/${stamp}_${_safeName(audioName)}';
    await storage.uploadBinary(
      audioPath,
      audioBytes,
      fileOptions: FileOptions(
        contentType: _audioType(audioName),
        upsert: false,
      ),
    );

    String? coverPath;
    if (coverBytes != null && coverName != null) {
      coverPath = 'covers/${stamp}_${_safeName(coverName)}';
      try {
        await storage.uploadBinary(
          coverPath,
          coverBytes,
          fileOptions: FileOptions(
            contentType: _imageType(coverName),
            upsert: false,
          ),
        );
      } catch (_) {
        await _removeFiles([audioPath]);
        rethrow;
      }
    }

    final row = <String, dynamic>{
      'id': '${SongService.ownPrefix}$stamp',
      'title': title,
      'artist': artist,
      'audio_url': storage.getPublicUrl(audioPath),
      'cover_url': coverPath == null ? null : storage.getPublicUrl(coverPath),
      'genre': (genre == null || genre.isEmpty) ? null : genre,
    };

    try {
      await _db.from('songs').insert(row);
    } catch (_) {
      // Data gagal disimpan -> hapus file supaya tidak jadi sampah.
      await _removeFiles([audioPath, ?coverPath]);
      rethrow;
    }

    return Song.fromMap(row);
  }

  Future<void> deleteSong(Song song) async {
    await _db.from('songs').delete().eq('id', song.id);

    final paths = [
      _pathFromUrl(song.audioUrl),
      _pathFromUrl(song.coverUrl),
    ].whereType<String>().toList();

    await _removeFiles(paths);
  }

  // ---------------- helper ----------------

  Future<void> _removeFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _db.storage.from(bucket).remove(paths);
    } catch (_) {
      // Gagal bersih-bersih file tidak boleh menggagalkan proses utama.
    }
  }

  /// Ambil path file di bucket dari URL publik Supabase.
  String? _pathFromUrl(String url) {
    final marker = '/object/public/$bucket/';
    final i = url.indexOf(marker);
    if (i == -1) return null;
    return Uri.decodeComponent(url.substring(i + marker.length));
  }

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot).toLowerCase();
  }

  String _safeName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot == -1 ? fileName : fileName.substring(0, dot);
    return '${base.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}'
        '${_extension(fileName)}';
  }

  String _audioType(String fileName) {
    switch (_extension(fileName)) {
      case '.m4a':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      case '.mp3':
      default:
        return 'audio/mpeg';
    }
  }

  String _imageType(String fileName) {
    switch (_extension(fileName)) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}