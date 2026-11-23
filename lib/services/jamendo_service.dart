import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/song.dart';
import 'itunes_service.dart' show interleaveSongs;

class JamendoService {
  // Client ID testing.
  // Nanti sebaiknya daftar sendiri di devportal.jamendo.com.
  static const String _clientId = '8e039e99';

  static const String _base = 'https://api.jamendo.com/v3.0/tracks/';
  static const String _chartBase =
      'https://api.jamendo.com/v3.0/charts/track/';

  /// Mengubah hasil API Jamendo menjadi daftar Song.
  List<Song> _parseSongs(List results) {
    return results
        .map<Song>((item) {
          final genres = item['musicinfo']?['tags']?['genres'];

          return Song(
            id: item['id'].toString(),
            title: item['name'] ?? 'Unknown Title',
            artist: item['artist_name'] ?? 'Unknown Artist',
            coverUrl: item['image'] ??
                item['album_image'] ??
                'https://picsum.photos/300',
            audioUrl: item['audio'] ?? '',
            genre: (genres is List && genres.isNotEmpty)
                ? genres.first.toString()
                : null,
          );
        })
        .where((song) => song.audioUrl.isNotEmpty)
        .toList();
  }

  /// Mengambil lagu berdasarkan parameter dari endpoint tracks.
  Future<List<Song>> _fetch(Map<String, String> params) async {
    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'client_id': _clientId,
        'format': 'json',
        'imagesize': '300',
        'include': 'musicinfo',
        'audioformat': 'mp32',
        ...params,
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Jamendo error ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final headers = data['headers'];

      if (headers is Map && headers['status'] == 'failed') {
        throw Exception(
          'Jamendo: ${headers['error_message'] ?? 'request ditolak'} '
          '(code ${headers['code']})',
        );
      }

      final List results = data['results'] ?? [];
      return _parseSongs(results);
    } on TimeoutException {
      debugPrint('Jamendo: request timeout. Menggunakan daftar lagu kosong.');
      return <Song>[];
    }
  }

  /// Mengambil lagu trending melalui endpoint chart,
  /// lalu mengambil detailnya melalui endpoint tracks.
  Future<List<Song>> _fetchTrendingChart({required int limit}) async {
    try {
      // Tahap 1: Ambil ID lagu dari chart.
      final chartUri = Uri.parse(_chartBase).replace(
        queryParameters: {
          'client_id': _clientId,
          'format': 'json',
          'limit': '$limit',
          'order': 'trending',
        },
      );

      final chartResponse = await http
          .get(chartUri)
          .timeout(const Duration(seconds: 15));

      if (chartResponse.statusCode != 200) {
        throw Exception(
          'Jamendo chart error ${chartResponse.statusCode}',
        );
      }

      final chartData = json.decode(chartResponse.body);
      final chartHeaders = chartData['headers'];

      if (chartHeaders is Map &&
          chartHeaders['status'] == 'failed') {
        throw Exception(
          'Jamendo chart: '
          '${chartHeaders['error_message'] ?? 'request ditolak'}',
        );
      }

      final List chartResults = chartData['results'] ?? [];

      final ids = chartResults
          .map((item) => item['id'].toString())
          .where((id) => id.isNotEmpty)
          .toList();

      if (ids.isEmpty) {
        return <Song>[];
      }

      // Tahap 2: Ambil detail lagu berdasarkan ID.
      // Spasi harus dienkode menjadi %20 agar diterima Jamendo.
      final encodedIds = Uri.encodeComponent(ids.join(' '));

      final detailUri = Uri.parse(
        '$_base?client_id=$_clientId'
        '&format=json'
        '&id=$encodedIds'
        '&imagesize=300'
        '&include=musicinfo'
        '&audioformat=mp32',
      );

      final detailResponse = await http
          .get(detailUri)
          .timeout(const Duration(seconds: 15));

      if (detailResponse.statusCode != 200) {
        throw Exception(
          'Jamendo detail error ${detailResponse.statusCode}',
        );
      }

      final detailData = json.decode(detailResponse.body);
      final detailHeaders = detailData['headers'];

      if (detailHeaders is Map &&
          detailHeaders['status'] == 'failed') {
        throw Exception(
          'Jamendo detail: '
          '${detailHeaders['error_message'] ?? 'request ditolak'}',
        );
      }

      final List detailResults = detailData['results'] ?? [];
      final songs = _parseSongs(detailResults);

      // Susun kembali berdasarkan urutan lagu dari chart.
      final songsById = {
        for (final song in songs) song.id: song,
      };

      return ids
          .map((id) => songsById[id])
          .whereType<Song>()
          .toList();
    } on TimeoutException {
      debugPrint('Jamendo chart: request timeout.');
      return <Song>[];
    } catch (e) {
      debugPrint('Jamendo chart error: $e');
      return <Song>[];
    }
  }

  Future<List<Song>> fetchTrendingSongs({int limit = 30}) {
    return _fetchTrendingChart(limit: limit);
  }

  Future<List<Song>> searchSongs(
    String query, {
    int limit = 30,
  }) {
    return _fetch({
      'limit': '$limit',
      'search': query,
      'order': 'relevance',
    });
  }

  Future<List<Song>> songsByGenre(
    String genreTag, {
    int limit = 30,
  }) {
    return _fetch({
      'limit': '$limit',
      'tags': genreTag,
      'order': 'popularity_week',
    });
  }

  /// Lagu berbahasa Indonesia dari Jamendo (diputar penuh, bukan cuplikan).
  ///
  /// Dicoba tiga cara sekaligus, lalu hasilnya digabung dan dibuang yang kembar:
  /// 1. Filter bahasa lirik "id".
  /// 2. Pencarian kata "indonesia".
  /// 3. Pencarian kata "indonesian".
  ///
  /// Kalau satu cara gagal, cara lain tetap dijalankan.
  Future<List<Song>> indonesianSongs({int limit = 30}) async {
    Future<List<Song>> safe(Future<List<Song>> future) async {
      try {
        return await future;
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
