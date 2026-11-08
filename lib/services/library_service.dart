import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class LibraryService {
  final SupabaseClient _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // Simpan lagu dari API ke tabel songs (kalau belum ada),
  // supaya relasi liked_songs & playlist_songs tidak ditolak.
  Future<void> _ensureSong(Song song) async {
    // Lagu unggahan admin (own_) sudah ada di tabel, dan hanya admin yang
    // boleh menulis baris itu, jadi tidak perlu disimpan ulang.
    if (song.id.startsWith('own_')) return;

    await _db.from('songs').upsert(
      song.toJson(),
      onConflict: 'id',
      ignoreDuplicates: true,
    );
  }

  /// Dipakai provider lain (mis. riwayat) supaya lagu pasti ada di tabel songs.
  Future<void> ensureSong(Song song) => _ensureSong(song);

  // ===== LIKED SONGS =====
  Future<Set<String>> likedIds() async {
    final data =
    await _db.from('liked_songs').select('song_id').eq('user_id', _uid);
    return (data as List).map((e) => e['song_id'].toString()).toSet();
  }

  Future<List<Song>> likedSongs() async {
    final data = await _db
        .from('liked_songs')
        .select('liked_at, songs(*)')
        .eq('user_id', _uid)
        .order('liked_at', ascending: false);
    return (data as List)
        .where((e) => e['songs'] != null)
        .map((e) => Song.fromMap(e['songs'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> like(Song song) async {
    await _ensureSong(song);
    await _db
        .from('liked_songs')
        .insert({'user_id': _uid, 'song_id': song.id});
  }

  Future<void> unlike(String songId) => _db
      .from('liked_songs')
      .delete()
      .eq('user_id', _uid)
      .eq('song_id', songId);

  // ===== PLAYLISTS =====
  Future<List<Playlist>> playlists() async {
    final data = await _db
        .from('playlists')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Playlist.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Playlist> createPlaylist(String name) async {
    final row = await _db
        .from('playlists')
        .insert({'user_id': _uid, 'name': name})
        .select()
        .single();
    return Playlist.fromMap(row);
  }

  Future<void> deletePlaylist(String id) =>
      _db.from('playlists').delete().eq('id', id);

  Future<List<Song>> playlistSongs(String playlistId) async {
    final data = await _db
        .from('playlist_songs')
        .select('added_at, songs(*)')
        .eq('playlist_id', playlistId)
        .order('added_at', ascending: true);
    return (data as List)
        .where((e) => e['songs'] != null)
        .map((e) => Song.fromMap(e['songs'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> addToPlaylist(String playlistId, Song song) async {
    await _ensureSong(song);
    await _db.from('playlist_songs').upsert(
      {'playlist_id': playlistId, 'song_id': song.id},
      onConflict: 'playlist_id,song_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> removeFromPlaylist(String playlistId, String songId) => _db
      .from('playlist_songs')
      .delete()
      .eq('playlist_id', playlistId)
      .eq('song_id', songId);
}