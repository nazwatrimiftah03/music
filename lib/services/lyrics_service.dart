import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/song.dart';

/// Satu baris lirik. [time] null kalau lirik tidak punya penanda waktu.
class LyricLine {
  final Duration? time;
  final String text;
  const LyricLine(this.time, this.text);
}

class Lyrics {
  final List<LyricLine> lines;

  /// True kalau setiap baris punya waktu (bisa di-highlight mengikuti lagu).
  final bool synced;
  const Lyrics(this.lines, {required this.synced});
}

/// Lirik dari LRCLIB (https://lrclib.net) - gratis, tanpa akun/key.
/// Hasil disimpan di memori supaya lagu yang sama tidak diminta ulang.
class LyricsService {
  static const String _base = 'https://lrclib.net/api/search';
  static const Duration _timeout = Duration(seconds: 10);

  static final Map<String, Lyrics?> _cache = {};

  /// Buang bagian seperti "(feat. X)", "[Remastered]" supaya pencarian cocok.
  static String _clean(String s) => s
      .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
      .replaceAll(RegExp(r'\s+-\s+(Remaster|Live|Single|Radio).*$',
      caseSensitive: false), '')
      .trim();

  /// Return null kalau lirik tidak ditemukan atau lagunya instrumental.
  /// Melempar exception kalau jaringan bermasalah (supaya bisa "Coba lagi").
  Future<Lyrics?> fetch(Song song) async {
    if (_cache.containsKey(song.id)) return _cache[song.id];

    final uri = Uri.parse(_base).replace(queryParameters: {
      'track_name': _clean(song.title),
      'artist_name': _clean(song.artist),
    });

    final res = await http
        .get(uri, headers: {'User-Agent': 'PinkBeat/1.0'}).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Gagal memuat lirik (${res.statusCode})');
    }

    final list = jsonDecode(res.body);
    Lyrics? result;

    if (list is List) {
      // Utamakan yang bertanda waktu, lalu yang teks biasa.
      for (final item in list) {
        if (item is! Map || item['instrumental'] == true) continue;
        final synced = item['syncedLyrics'];
        if (synced is String && synced.trim().isNotEmpty) {
          final parsed = _parseLrc(synced);
          if (parsed.isNotEmpty) {
            result = Lyrics(parsed, synced: true);
            break;
          }
        }
      }
      if (result == null) {
        for (final item in list) {
          if (item is! Map || item['instrumental'] == true) continue;
          final plain = item['plainLyrics'];
          if (plain is String && plain.trim().isNotEmpty) {
            result = Lyrics(
              plain
                  .split('\n')
                  .map((l) => LyricLine(null, l.trim()))
                  .toList(),
              synced: false,
            );
            break;
          }
        }
      }
    }

    _cache[song.id] = result;
    return result;
  }

  /// Format LRC: "[01:23.45] teks" (boleh beberapa penanda waktu per baris).
  static List<LyricLine> _parseLrc(String raw) {
    final stamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final lines = <LyricLine>[];

    for (final row in raw.split('\n')) {
      final matches = stamp.allMatches(row).toList();
      if (matches.isEmpty) continue;
      final text = row.substring(matches.last.end).trim();

      for (final m in matches) {
        final min = int.parse(m.group(1)!);
        final sec = int.parse(m.group(2)!);
        final fracRaw = m.group(3) ?? '0';
        final ms = int.parse(fracRaw.padRight(3, '0').substring(0, 3));
        lines.add(LyricLine(
          Duration(minutes: min, seconds: sec, milliseconds: ms),
          text,
        ));
      }
    }

    lines.sort((a, b) => a.time!.compareTo(b.time!));
    return lines;
  }
}