import 'package:flutter/material.dart';
import '../../services/song_service.dart';
import '../library/song_list_screen.dart';

/// Buka halaman berisi semua lagu dari satu artis.
void openArtist(BuildContext context, String artist) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SongListScreen(
        title: artist,
        icon: Icons.person_rounded,
        loader: () => SongService().byArtist(artist),
        emptyText: 'Belum ada lagu dari "$artist" di aplikasi ini.',
      ),
    ),
  );
}

/// Nama artis yang bisa dipakai untuk membuka halaman artis.
/// False untuk nama kosong atau placeholder "Unknown Artist".
bool hasArtistPage(String artist) {
  final a = artist.trim().toLowerCase();
  return a.isNotEmpty && a != 'unknown artist';
}