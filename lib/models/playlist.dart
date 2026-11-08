class Playlist {
  final String id;
  final String userId;
  final String name;
  final String? createdAt;

  Playlist({
    required this.id,
    required this.userId,
    required this.name,
    this.createdAt,
  });

  factory Playlist.fromMap(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name'] ?? 'Untitled Playlist',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
    };
  }
}