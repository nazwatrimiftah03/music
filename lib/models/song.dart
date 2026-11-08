class Song {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final String audioUrl;
  final String? genre;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.audioUrl,
    this.genre,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      coverUrl: json['cover_url'] ?? 'https://picsum.photos/300',
      audioUrl: json['audio_url'] ?? '',
      genre: json['genre'],
    );
  }

  factory Song.fromMap(Map<String, dynamic> json) {
    return Song.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'cover_url': coverUrl,
      'audio_url': audioUrl,
      'genre': genre,
    };
  }
}