import 'local_track.dart';

class AudioMoment {
  const AudioMoment(
      {required this.id,
      required this.name,
      required this.track,
      required this.start,
      this.end});
  final String id, name;
  final LocalTrack track;
  final Duration start;
  final Duration? end;
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'track': track.toJson(),
        'start': start.inMilliseconds,
        'end': end?.inMilliseconds
      };
  factory AudioMoment.fromJson(Map<String, dynamic> j) => AudioMoment(
      id: j['id'],
      name: j['name'],
      track: LocalTrack.fromJson(Map<String, dynamic>.from(j['track'])),
      start: Duration(milliseconds: j['start']),
      end: j['end'] is num
          ? Duration(milliseconds: (j['end'] as num).toInt())
          : null);
}
