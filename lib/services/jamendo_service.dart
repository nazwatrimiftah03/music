import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'itunes_service.dart' show interleaveSongs;

class JamendoService {
  // Client ID testing. Nanti sebaiknya daftar sendiri (gratis) di devportal.jamendo.com
  static const String _clientId = '8e039e99';
  static const String _base = 'https://api.jamendo.com/v3.0/tracks/';

  Future<List<Song>> _fetch(Map<String, String> params) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'client_id': _clientId,
      'format': 'json',
      'imagesize': '300',
      'include': 'musicinfo',
      'audioformat': 'mp32',
      ...params,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Jamendo error ${response.statusCode}');
    }

    final data = json.decode(response.body);

    // Jamendo membalas HTTP 200 + results kosong saat client_id ditolak,
    // jadi status di "headers" harus dicek sendiri.
    final headers = data['headers'];
    if (headers is Map && headers['status'] == 'failed') {
      throw Exception(
        'Jamendo: ${headers['error_message'] ?? 'request ditolak'} '
            '(code ${headers['code']})',
      );
    }

    final List results = data['results'] ?? [];

    return results
        .map<Song>((item) {
      final genres = item['musicinfo']?['tags']?['genres'];
      return Song(
        id: item['id'].toString(),
        title: item['name'] ?? 'Unknown Title',
        artist: item['artist_name'] ?? 'Unknown Artist',
        coverUrl: item['image'] ?? item['album_image'] ?? 'https://picsum.photos/300',
        audioUrl: item['audio'] ?? '',
        genre: (genres is List && genres.isNotEmpty)
            ? genres.first.toString()
            : null,
      );
    })
        .where((s) => s.audioUrl.isNotEmpty)
        .toList();
  }

  Future<List<Song>> fetchTrendingSongs({int limit = 30}) =>
      _fetch({'limit': '$limit', 'order': 'popularity_week'});

  Future<List<Song>> searchSongs(String query, {int limit = 30}) =>
      _fetch({'limit': '$limit', 'search': query, 'order': 'relevance'});

  Future<List<Song>> songsByGenre(String genreTag, {int limit = 30}) =>
      _fetch({'limit': '$limit', 'tags': genreTag, 'order': 'popularity_week'});

  /// Lagu berbahasa Indonesia dari Jamendo (diputar PENUH, bukan cuplikan).
  ///
  /// Dicoba tiga cara sekaligus, lalu hasilnya digabung dan dibuang yang kembar:
  ///   1. filter bahasa lirik "id" (Indonesia)
  ///   2. pencarian kata "indonesia"
  ///   3. pencarian kata "indonesian"
  /// Kalau satu cara gagal (misalnya filter bahasa ditolak), cara lain tetap jalan.
  Future<List<Song>> indonesianSongs({int limit = 30}) async {
    Future<List<Song>> safe(Future<List<Song>> f) async {
      try {
        return await f;
      } catch (_) {
        return <Song>[];
      }
    }

    final lists = await Future.wait([
      safe(_fetch({
        'limit': '$limit',
        'lang': 'id',
        'order': 'popularity_month',
      })),
      safe(_fetch({
        'limit': '$limit',
        'search': 'indonesia',
        'order': 'popularity_month',
      })),
      safe(_fetch({
        'limit': '$limit',
        'search': 'indonesian',
        'order': 'popularity_month',
      })),
    ]);

    return interleaveSongs(lists, limit: limit);
  }
}