import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/song.dart';

/// Menggabungkan beberapa daftar lagu secara bergantian (1 dari tiap daftar,
/// lalu putaran berikutnya) dan membuang duplikat berdasarkan id.
List<Song> interleaveSongs(List<List<Song>> lists, {int? limit}) {
  final seen = <String>{};
  final result = <Song>[];
  var round = 0;

  while (true) {
    var addedAny = false;

    for (final list in lists) {
      if (round < list.length) {
        addedAny = true;
        final song = list[round];
        if (seen.add(song.id)) {
          result.add(song);
          if (limit != null && result.length >= limit) return result;
        }
      }
    }

    if (!addedAny) break;
    round++;
  }

  return result;
}

/// Lagu populer (termasuk Indonesia) dari iTunes Search API.
/// Gratis tanpa akun/key, tetapi hanya menyediakan CUPLIKAN 30 detik.
class ItunesService {
  static const String _base = 'https://itunes.apple.com/search';

  /// Prefix id supaya tidak bentrok dengan id Jamendo di tabel songs.
  static const String idPrefix = 'it_';

  /// Daftar artis untuk baris "Hits Indonesia". Silakan diganti sesuai selera.
  static const List<String> _hitArtists = [
    'Tulus',
    'Hindia',
    'Juicy Luicy',
    'Nadin Amizah',
    'Mahalini',
    'Raisa',
    'Tiara Andini',
    'Sheila On 7',
  ];

  Future<List<Song>> search(
      String query, {
        int limit = 25,
        String country = 'ID',
      }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'term': query,
      'country': country,
      'media': 'music',
      'entity': 'song',
      'limit': '$limit',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('iTunes error ${response.statusCode}');
    }

    final data = json.decode(utf8.decode(response.bodyBytes));
    final List results = data['results'] ?? [];
    final seen = <String>{};

    return results
        .where((item) =>
    item['trackId'] != null &&
        (item['previewUrl'] ?? '').toString().isNotEmpty)
        .map<Song>((item) {
      final artwork = (item['artworkUrl100'] ?? '').toString();

      return Song(
        id: '$idPrefix${item['trackId']}',
        title: item['trackName'] ?? 'Unknown Title',
        artist: item['artistName'] ?? 'Unknown Artist',
        coverUrl: artwork.isEmpty
            ? 'https://picsum.photos/300'
            : artwork.replaceAll('100x100bb', '400x400bb'),
        audioUrl: item['previewUrl'].toString(),
        // Sengaja null: nama genre iTunes tidak sama dengan tag Jamendo.
        // Rekomendasi lagu iTunes memakai nama artis (lihat
        // RecommendationService).
        genre: null,
      );
    })
        .where((song) => seen.add(song.id))
        .toList();
  }

  /// Lagu-lagu dari beberapa artis Indonesia, digabung bergantian.
  Future<List<Song>> indonesiaHits({int perArtist = 4}) async {
    final lists = await Future.wait(
      _hitArtists.map((artist) async {
        try {
          return await search(artist, limit: perArtist);
        } catch (_) {
          return <Song>[];
        }
      }),
    );

    final hits = interleaveSongs(lists);

    if (hits.isEmpty) {
      throw Exception('Tidak bisa memuat Hits Indonesia');
    }

    return hits;
  }
}