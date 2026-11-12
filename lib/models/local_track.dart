class LocalTrack {
  const LocalTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.folder,
    required this.uri,
    required this.duration,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String folder;
  final Uri uri;
  final Duration duration;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'folder': folder,
        'uri': uri.toString(),
        'duration': duration.inMilliseconds,
      };

  factory LocalTrack.fromJson(Map<String, dynamic> data) => LocalTrack(
        id: data['id'],
        title: data['title'],
        artist: data['artist'],
        album: data['album'],
        folder: data['folder'],
        uri: Uri.parse(data['uri']),
        duration: Duration(milliseconds: data['duration'] ?? 0),
      );
}
