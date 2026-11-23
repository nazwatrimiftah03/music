
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/song.dart';

/// Satu baris lirik.
/// [time] bernilai null jika tidak memiliki timestamp.
class LyricLine {
  final Duration? time;
  final String text;

  const LyricLine(this.time, this.text);
}

/// Data lirik lagu.
class Lyrics {
  final List<LyricLine> lines;
  final bool synced;

  const Lyrics(
      this.lines, {
        required this.synced,
      });
}

/// Mengambil lirik dari LRCLIB.
/// Hasil pencarian disimpan dalam cache agar tidak meminta ulang.
class LyricsService {
  static const String _base = 'https://lrclib.net/api/search';

  static const Duration _timeout = Duration(seconds: 10);

  static const int _maxCache = 100;

  static final Map<String, Lyrics?> _cache = {};

  /// Membersihkan judul dan nama artis dari informasi tambahan.
  static String _clean(String value) {
    return value
        .replaceAll(
      RegExp(r'\s*[\(\[].*?[\)\]]'),
      '',
    )
        .replaceAll(
      RegExp(
        r'\s+-\s+(Remaster|Live|Single|Radio).*$',
        caseSensitive: false,
      ),
      '',
    )
        .trim();
  }

  /// Mengambil lirik berdasarkan judul dan artis.
  ///
  /// Mengembalikan null jika lirik tidak ditemukan.
  /// Exception diteruskan jika terjadi masalah jaringan atau respons API.
  Future<Lyrics?> fetch(Song song) async {
    final cacheKey = '${song.id}_${song.title}_${song.artist}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    final title = _clean(song.title);
    final artist = _clean(song.artist);

    if (title.isEmpty) {
      return null;
    }

    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'track_name': title,
        'artist_name': artist,
      },
    );

    final response = await http
        .get(
      uri,
      headers: {
        'User-Agent': 'PinkBeat/1.0',
      },
    )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal memuat lirik (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw const FormatException(
        'Format respons lirik tidak valid',
      );
    }

    Lyrics? result;

    // PRIORITAS 1: Lirik yang memiliki timestamp.
    for (final item in decoded) {
      if (item is! Map || item['instrumental'] == true) {
        continue;
      }

      final synced = item['syncedLyrics'];

      if (synced is! String || synced.trim().isEmpty) {
        continue;
      }

      final parsed = _parseLrc(synced);

      if (parsed.isNotEmpty) {
        result = Lyrics(
          parsed,
          synced: true,
        );
        break;
      }
    }

    // PRIORITAS 2: Lirik biasa tanpa timestamp.
    if (result == null) {
      for (final item in decoded) {
        if (item is! Map || item['instrumental'] == true) {
          continue;
        }

        final plain = item['plainLyrics'];

        if (plain is! String || plain.trim().isEmpty) {
          continue;
        }

        final lines = plain
            .split(RegExp(r'\r?\n'))
            .map((line) => LyricLine(null, line.trim()))
            .where((line) => line.text.isNotEmpty)
            .toList();

        if (lines.isNotEmpty) {
          result = Lyrics(
            lines,
            synced: false,
          );
          break;
        }
      }
    }

    _saveCache(cacheKey, result);

    return result;
  }

  /// Menyimpan hasil pencarian ke cache.
  static void _saveCache(String key, Lyrics? value) {
    if (_cache.length >= _maxCache) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = value;
  }

  /// Mengubah format LRC menjadi daftar LyricLine.
  ///
  /// Mendukung:
  /// [01:23] teks
  /// [01:23.45] teks
  /// [01:23:456] teks
  /// Beberapa timestamp dalam satu baris.
  static List<LyricLine> _parseLrc(String raw) {
    final timestampPattern = RegExp(
      r'\[(\d{1,2}):([0-5]\d)(?:[.:](\d{1,3}))?\]',
    );

    final lines = <LyricLine>[];

    for (final row in raw.split(RegExp(r'\r?\n'))) {
      final matches = timestampPattern.allMatches(row).toList();

      if (matches.isEmpty) continue;

      // Teks berada setelah timestamp terakhir.
      final text = row.substring(matches.last.end).trim();

      for (final match in matches) {
        final minute = int.parse(match.group(1)!);
        final second = int.parse(match.group(2)!);

        final fraction = match.group(3) ?? '0';

        // Mengubah pecahan detik menjadi milidetik.
        final milliseconds = int.parse(
          fraction.padRight(3, '0').substring(0, 3),
        );

        lines.add(
          LyricLine(
            Duration(
              minutes: minute,
              seconds: second,
              milliseconds: milliseconds,
            ),
            text,
          ),
        );
      }
    }

    // Mengurutkan lirik berdasarkan waktu.
    lines.sort(
          (a, b) => a.time!.compareTo(b.time!),
    );

    return lines;
  }
}
