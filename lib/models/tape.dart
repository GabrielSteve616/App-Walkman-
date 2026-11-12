import 'local_track.dart';

class StickerAsset {
  const StickerAsset(
      {required this.id, required this.name, required this.path});
  final String id, name, path;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'path': path};
  factory StickerAsset.fromJson(Map<String, dynamic> data) =>
      StickerAsset(id: data['id'], name: data['name'], path: data['path']);
}

class StickerPlacement {
  StickerPlacement(
      {required this.assetId,
      this.x = .5,
      this.y = .5,
      this.width = .25,
      this.angle = 0,
      this.onCase = false,
      this.back = false});
  final String assetId;
  double x, y, width, angle;
  bool onCase;
  bool back;
  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        'x': x,
        'y': y,
        'width': width,
        'angle': angle,
        'onCase': onCase,
        'back': back,
      };
  factory StickerPlacement.fromJson(Map<String, dynamic> data) =>
      StickerPlacement(
          assetId: data['assetId'],
          x: (data['x'] as num).toDouble(),
          y: (data['y'] as num).toDouble(),
          width: (data['width'] as num).toDouble(),
          angle: (data['angle'] as num).toDouble(),
          onCase: data['onCase'] ?? false,
          back: data['back'] ?? false);
}

class Tape {
  Tape(
      {required this.id,
      required this.name,
      required this.tracks,
      this.description = '',
      this.color = 0xFF1768AD,
      this.caseColor = 0xFFE6D8BE,
      this.shellColor = 0xFF8E9DA5,
      this.labelColor = 0xFFEDE3CE,
      this.textColor = 0xFF292B2C,
      this.caseTextColor,
      this.labelFrontPath,
      this.labelBackPath,
      this.transparent = false,
      this.coverPath,
      List<StickerPlacement>? stickers})
      : stickers = stickers ?? [];
  final String id;
  String name, description;
  List<LocalTrack> tracks;
  int color, caseColor, shellColor, labelColor, textColor;
  int? caseTextColor;
  bool transparent;
  String? coverPath, labelFrontPath, labelBackPath;
  List<StickerPlacement> stickers;
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'color': color,
        'caseColor': caseColor,
        'shellColor': shellColor,
        'labelColor': labelColor,
        'textColor': textColor,
        'caseTextColor': caseTextColor,
        'labelFrontPath': labelFrontPath,
        'labelBackPath': labelBackPath,
        'transparent': transparent,
        'coverPath': coverPath,
        'stickers': stickers.map((s) => s.toJson()).toList()
      };
  factory Tape.fromJson(Map<String, dynamic> data) => Tape(
      id: data['id'],
      name: data['name'],
      description: data['description'] ?? '',
      tracks: (data['tracks'] as List)
          .map((t) => LocalTrack.fromJson(Map<String, dynamic>.from(t)))
          .toList(),
      color: data['color'],
      caseColor: data['caseColor'] ?? 0xFFE6D8BE,
      shellColor: data['shellColor'] ?? 0xFF8E9DA5,
      labelColor: data['labelColor'] ?? 0xFFEDE3CE,
      textColor: data['textColor'] ?? 0xFF292B2C,
      caseTextColor: data['caseTextColor'],
      labelFrontPath: data['labelFrontPath'],
      labelBackPath: data['labelBackPath'],
      transparent: data['transparent'] ?? false,
      coverPath: data['coverPath'],
      stickers: (data['stickers'] as List? ?? [])
          .map((s) => StickerPlacement.fromJson(Map<String, dynamic>.from(s)))
          .toList());
  Tape copy() => Tape.fromJson(toJson());
}
