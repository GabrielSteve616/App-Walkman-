import 'dart:io';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/tape.dart';

class ArtTextures {
  ArtTextures(this.images);
  final Map<String, ui.Image> images;
  static final _cache = LinkedHashMap<String, Future<ui.Image?>>();
  static Future<ui.Image?> _image(String path) =>
      _cache.putIfAbsent(path, () async {
        try {
          final codec = await ui.instantiateImageCodec(
              await File(path).readAsBytes(),
              targetWidth: 768,
              allowUpscaling: false);
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          return image;
        } catch (_) {
          return null;
        }
      });
  static Future<ArtTextures> load(Tape tape, List<StickerAsset> assets) async {
    final paths = <String>{
      if (tape.coverPath != null) tape.coverPath!,
      if (tape.labelFrontPath != null) tape.labelFrontPath!,
      if (tape.labelBackPath != null) tape.labelBackPath!,
      for (final s
          in assets.where((a) => tape.stickers.any((p) => p.assetId == a.id)))
        s.path
    };
    while (_cache.length > 48) {
      _cache.remove(_cache.keys.first);
    }
    final images = <String, ui.Image>{};
    for (final path in paths) {
      final image = await _image(path);
      if (image != null) images[path] = image;
    }
    return ArtTextures(images);
  }
}

const tapeAspect = 600 / 370;
const caseAspect = 600 / 390;
Rect caseTrackRect(int index) =>
    Rect.fromLTWH(55 / 600, (108 + index * 23) / 390, 490 / 600, 22 / 390);
int? caseTrackAt(Offset uv, int count) {
  for (var i = 0; i < math.min(10, count); i++) {
    if (caseTrackRect(i).contains(uv)) return i;
  }
  return null;
}

class TapeArtwork extends StatefulWidget {
  const TapeArtwork(
      {super.key,
      required this.tape,
      required this.assets,
      this.caseView = false,
      this.backView = false,
      this.reelAngle = 0,
      this.selected,
      this.onTrackTap});
  final Tape tape;
  final List<StickerAsset> assets;
  final bool caseView, backView;
  final double reelAngle;
  final int? selected;
  final ValueChanged<int>? onTrackTap;
  @override
  State<TapeArtwork> createState() => _TapeArtworkState();
}

class _TapeArtworkState extends State<TapeArtwork> {
  late Future<ArtTextures> _textures;
  String _key = '';
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final key =
        '${widget.tape.labelFrontPath}|${widget.tape.labelBackPath}|${widget.tape.coverPath}|${widget.tape.stickers.map((s) => s.assetId).join(',')}|${widget.assets.map((a) => '${a.id}:${a.path}').join('|')}';
    if (key != _key || _key.isEmpty) {
      _key = key;
      _textures = ArtTextures.load(widget.tape, widget.assets);
    }
  }

  @override
  void didUpdateWidget(covariant TapeArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reload();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
      aspectRatio: widget.caseView ? caseAspect : tapeAspect,
      child: LayoutBuilder(
          builder: (context, c) => GestureDetector(
              onTapUp: widget.onTrackTap == null ||
                      !widget.caseView ||
                      !widget.backView
                  ? null
                  : (d) {
                      final index = caseTrackAt(
                          Offset(d.localPosition.dx / c.maxWidth,
                              d.localPosition.dy / c.maxHeight),
                          widget.tape.tracks.length);
                      if (index != null) widget.onTrackTap!(index);
                    },
              child: FutureBuilder<ArtTextures>(
                  future: _textures,
                  builder: (_, snapshot) => CustomPaint(
                      painter: TapePainter(widget.tape, widget.assets,
                          snapshot.data ?? ArtTextures({}),
                          caseView: widget.caseView,
                          backView: widget.backView,
                          reelAngle: widget.reelAngle,
                          selected: widget.selected))))));
}

class TapePainter extends CustomPainter {
  TapePainter(this.tape, this.assets, this.textures,
      {this.caseView = false,
      this.backView = false,
      this.reelAngle = 0,
      this.selected});
  final Tape tape;
  final List<StickerAsset> assets;
  final ArtTextures textures;
  final bool caseView, backView;
  final double reelAngle;
  final int? selected;
  void _text(Canvas c, String text, Offset offset, double size, Color color,
      double width,
      {int lines = 1}) {
    if (caseView && tape.caseTextColor != null)
      color = Color(tape.caseTextColor!);
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                fontSize: size,
                height: 1.1,
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: .7)),
        textDirection: TextDirection.ltr,
        maxLines: lines,
        ellipsis: '…')
      ..layout(maxWidth: width);
    painter.paint(c, offset);
  }

  void _case(Canvas c) {
    const shell = Rect.fromLTWH(8, 8, 584, 374);
    final border = RRect.fromRectAndRadius(shell, const Radius.circular(12));
    c.drawShadow(Path()..addRRect(border), Colors.black, 10, false);
    c.drawRRect(
        border,
        Paint()
          ..shader = LinearGradient(colors: [
            Color.lerp(Color(tape.shellColor), Colors.white, .4)!,
            Color.lerp(Color(tape.shellColor), Colors.black, .35)!,
            Color(tape.shellColor)
          ], begin: Alignment.topLeft, end: Alignment.bottomRight)
              .createShader(shell));
    const insert = Rect.fromLTWH(34, 24, 540, 340);
    c.save();
    c.clipRect(insert);
    c.drawRect(insert,
        Paint()..color = Color.lerp(Color(tape.caseColor), Colors.black, .65)!);
    final cover = textures.images[tape.coverPath];
    if (!backView && cover != null) {
      paintImage(canvas: c, rect: insert, image: cover, fit: BoxFit.cover);
      c.drawRect(
          insert,
          Paint()
            ..shader = const LinearGradient(colors: [
              Colors.black54,
              Colors.transparent,
              Colors.black87
            ], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                .createShader(insert));
    } else if (!backView) {
      c.drawRect(
          insert,
          Paint()
            ..shader = LinearGradient(colors: [
              Color.lerp(Color(tape.caseColor), Colors.black, .30)!,
              const Color(0xFF080B10)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight)
                .createShader(insert));
      final bolt = Path()
        ..moveTo(410, 62)
        ..lineTo(280, 206)
        ..lineTo(365, 191)
        ..lineTo(300, 306)
        ..lineTo(495, 140)
        ..lineTo(406, 157)
        ..close();
      c.drawPath(bolt, Paint()..color = Color(tape.caseColor));
      for (var i = 0; i < 8; i++) {
        c.drawLine(
            Offset(230, 250 + i * 9),
            Offset(550, 190 + i * 9),
            Paint()
              ..color = Colors.white10
              ..strokeWidth = 1);
      }
    }
    _text(c, backView ? 'TRACK LIST / LADO B' : 'ROCK • COMPACT CASSETTE',
        const Offset(55, 38), 14, Color(tape.caseTextColor ?? 0xFFE4CDA5), 490);
    c.drawLine(
        const Offset(55, 62),
        const Offset(548, 62),
        Paint()
          ..color = Color(tape.color)
          ..strokeWidth = 3);
    _text(c, tape.name.toUpperCase(), const Offset(55, 75), backView ? 22 : 36,
        Color(tape.caseTextColor ?? 0xFFF1E7D1), backView ? 490 : 330,
        lines: backView ? 1 : 3);
    if (backView) {
      for (var i = 0; i < math.min(10, tape.tracks.length); i++) {
        final y = caseTrackRect(i).top * 390;
        if (i.isEven)
          c.drawRect(
              Rect.fromLTWH(51, y, 498, 22), Paint()..color = Colors.white10);
        _text(c, (i + 1).toString().padLeft(2, '0'), Offset(58, y + 4), 12,
            Colors.white54, 30);
        _text(c, tape.tracks[i].title, Offset(96, y + 3), 14,
            Color(tape.caseTextColor ?? 0xFFF0E5D2), 425);
        c.drawPath(
            Path()
              ..moveTo(532, y + 6)
              ..lineTo(532, y + 16)
              ..lineTo(540, y + 11)
              ..close(),
            Paint()..color = Color(tape.color));
      }
      _text(
          c,
          tape.tracks.length > 10
              ? '+ ' +
                  (tape.tracks.length - 10).toString() +
                  ' na lista completa'
              : tape.tracks.length.toString() + ' FAIXAS / WALKMEN',
          const Offset(55, 346),
          11,
          Colors.white54,
          490);
    } else {
      c.drawRect(const Rect.fromLTWH(34, 284, 540, 80),
          Paint()..color = Color(tape.caseColor));
      _text(
          c,
          tape.description.isEmpty
              ? 'ANALOG SOUND • LOUD & CLEAR'
              : tape.description,
          const Offset(55, 299),
          18,
          Color(tape.caseTextColor ?? 0xFF292825),
          490,
          lines: 2);
      _text(
          c,
          tape.tracks.length.toString() + ' TRACKS / C-90',
          const Offset(55, 344),
          11,
          Color(tape.caseTextColor ?? 0xFF554C42),
          490);
    }
    c.restore();
    c.drawRect(const Rect.fromLTWH(16, 23, 12, 342),
        Paint()..color = Color(tape.color));
    for (final x in [55.0, 520.0]) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 9, 35, 10), const Radius.circular(3)),
          Paint()
            ..color = Color.lerp(Color(tape.shellColor), Colors.black, .2)!);
    }
    c.drawRRect(
        border,
        Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    c.drawLine(
        const Offset(36, 27),
        const Offset(563, 27),
        Paint()
          ..color = Colors.white38
          ..strokeWidth = 2);
  }

  void _cassette(Canvas c) {
    final base = Color(tape.color);
    const shell = Rect.fromLTWH(14, 18, 572, 334);
    final body = RRect.fromRectAndRadius(shell, const Radius.circular(17));
    c.drawShadow(Path()..addRRect(body), Colors.black, 9, false);
    c.drawRRect(
        body,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(base, Colors.white, .27)!,
                base,
                Color.lerp(base, Colors.black, .45)!
              ]).createShader(shell));
    c.drawRRect(
        body,
        Paint()
          ..color = const Color(0xFF111A20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(19, 23, 562, 324), const Radius.circular(13)),
        Paint()
          ..color = Colors.white38
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(29, 33, 542, 300), const Radius.circular(10)),
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    // Paper label follows the recessed upper panel, leaving the head bridge exposed.
    final label = RRect.fromRectAndRadius(
        const Rect.fromLTWH(49, 43, 502, 218), const Radius.circular(12));
    c.drawRRect(
        label.shift(const Offset(0, 2)), Paint()..color = Colors.black26);
    c.drawRRect(label, Paint()..color = Color(tape.labelColor));
    final labelImage =
        textures.images[backView ? tape.labelBackPath : tape.labelFrontPath];
    if (labelImage != null) {
      c.save();
      c.clipRRect(label);
      paintImage(
          canvas: c,
          rect: label.outerRect,
          image: labelImage,
          fit: BoxFit.cover);
      c.restore();
    }
    c.drawRRect(
        label,
        Paint()
          ..color = const Color(0xFFB8AD97)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(65, 56, 38, 43), const Radius.circular(3)),
        Paint()..color = const Color(0xFF292D2E));
    _text(c, backView ? 'B' : 'A', const Offset(73, 61), 28,
        const Color(0xFFF1E5CB), 28);
    _text(c, tape.name, const Offset(119, 57), 24, Color(tape.textColor), 410);
    for (final y in [91.0, 108.0]) {
      c.drawLine(
          Offset(119, y),
          Offset(533, y),
          Paint()
            ..color = Color(tape.textColor).withValues(alpha: .4)
            ..strokeWidth = 1);
    }
    c.drawRect(const Rect.fromLTWH(50, 120, 500, 11),
        Paint()..color = const Color(0xFFAB382D));
    c.drawRect(const Rect.fromLTWH(50, 133, 500, 3),
        Paint()..color = const Color(0xFFBDA279));
    final window = RRect.fromRectAndRadius(
        const Rect.fromLTWH(86, 151, 428, 94), const Radius.circular(40));
    c.drawRRect(window.inflate(3), Paint()..color = const Color(0xFFACA48F));
    c.drawRRect(window, Paint()..color = const Color(0xFF151C20));
    c.save();
    c.clipRRect(window);
    for (final x in [176.0, 424.0]) {
      c.drawCircle(Offset(x, 198), tape.transparent ? 67 : 45,
          Paint()..color = const Color(0xFF584034));
      for (final radius in [41.0, 44.0]) {
        c.drawCircle(
            Offset(x, 198),
            radius,
            Paint()
              ..color = const Color(0xFF795B45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
      }
    }
    for (final y in [158.0, 238.0]) {
      c.drawLine(
          Offset(176, y),
          Offset(424, y),
          Paint()
            ..color = const Color(0xFF8D6850)
            ..strokeWidth = 2);
    }
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(258, 164, 84, 68), const Radius.circular(4)),
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFF47413A), Color(0xFF272C2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)
              .createShader(const Rect.fromLTWH(258, 164, 84, 68)));
    for (final x in [176.0, 424.0]) {
      c.drawCircle(
          Offset(x, 198), 32, Paint()..color = const Color(0xFFE3D8BF));
      c.drawCircle(
          Offset(x, 198), 22, Paint()..color = const Color(0xFF10181C));
      c.save();
      c.translate(x, 198);
      c.rotate(reelAngle);
      for (var i = 0; i < 6; i++) {
        c.rotate(math.pi / 3);
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(-3, -27, 6, 13), const Radius.circular(1)),
            Paint()..color = const Color(0xFFE3D8BF));
      }
      c.restore();
    }
    c.restore();
    _text(c, 'NORMAL BIAS   •   C90   •   120µs EQ', const Offset(166, 267), 11,
        Colors.white70, 330);
    final bridge = Path()
      ..moveTo(117, 346)
      ..lineTo(143, 289)
      ..lineTo(457, 289)
      ..lineTo(483, 346)
      ..close();
    c.drawPath(
        bridge,
        Paint()
          ..shader = LinearGradient(colors: [
            Color.lerp(base, Colors.black, .20)!,
            Color.lerp(base, Colors.black, .5)!
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              .createShader(const Rect.fromLTWH(117, 289, 366, 57)));
    c.drawPath(
        bridge,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    for (final x in [153.0, 218.0, 382.0, 447.0]) {
      c.drawCircle(Offset(x, 326), 8, Paint()..color = const Color(0xFF101619));
      c.drawCircle(
          Offset(x, 326),
          8,
          Paint()
            ..color = Colors.white24
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(274, 318, 52, 17), const Radius.circular(3)),
        Paint()..color = Colors.black54);
    for (final x in [32.0, 568.0]) {
      for (final y in [36.0, 332.0]) {
        c.drawCircle(Offset(x, y), 6, Paint()..color = const Color(0xFF161F23));
        c.drawCircle(
            Offset(x, y), 4.5, Paint()..color = const Color(0xFFB2B9B8));
        c.drawLine(
            Offset(x - 2.5, y),
            Offset(x + 2.5, y),
            Paint()
              ..color = Colors.black87
              ..strokeWidth = 1.3);
      }
      for (var i = 0; i < 5; i++) {
        c.drawLine(
            Offset(x - 6, 150 + i * 22),
            Offset(x + 6, 150 + i * 22),
            Paint()
              ..color = Colors.black26
              ..strokeWidth = 2);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final height = caseView ? 390.0 : 370.0;
    canvas.save();
    canvas.scale(size.width / 600, size.height / height);
    if (caseView)
      _case(canvas);
    else
      _cassette(canvas);
    canvas.save();
    final stickerClip = caseView
        ? Rect.fromLTWH(0, 0, 600, 390)
        : Rect.fromLTWH(0, 0, 600, 370);
    canvas.clipRect(stickerClip);
    for (var i = 0; i < tape.stickers.length; i++) {
      final p = tape.stickers[i];
      if (p.onCase != caseView) continue;
      final asset = assets.where((a) => a.id == p.assetId).firstOrNull;
      final image = textures.images[asset?.path];
      if (image == null) continue;
      void draw({bool selection = false}) {
        final w = p.width * 600;
        canvas.save();
        canvas.translate(p.x * 600, p.y * height);
        canvas.rotate(p.angle);
        final rect = Rect.fromCenter(
            center: Offset.zero,
            width: w,
            height: w * image.height / image.width);
        paintImage(
            canvas: canvas, rect: rect, image: image, fit: BoxFit.contain);
        if (selection)
          canvas.drawRect(
              rect.inflate(4),
              Paint()
                ..color = Colors.orange
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3);
        canvas.restore();
      }

      if (p.back == backView) {
        draw(selection: selected == i);
      } else {
        // Material which extends past a wall continues onto the opposite face.
        final depth = caseView ? 70.0 : 41.0;
        for (final edge in [0, 1, 2, 3]) {
          canvas.save();
          switch (edge) {
            case 0:
              canvas.translate(600, -depth);
              canvas.scale(-1, -1);
            case 1:
              canvas.translate(-600 - depth, 0);
            case 2:
              canvas.translate(600, 2 * height + depth);
              canvas.scale(-1, -1);
            case 3:
              canvas.translate(600 + depth, 0);
          }
          draw();
          canvas.restore();
        }
      }
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TapePainter oldDelegate) => true;
}

Future<ui.Image> renderTapeTexture(Tape tape, List<StickerAsset> assets,
    {bool caseView = false, bool backView = false}) async {
  final textures = await ArtTextures.load(tape, assets);
  final recorder = ui.PictureRecorder();
  final size = caseView ? const Size(600, 390) : const Size(900, 555);
  TapePainter(tape, assets, textures, caseView: caseView, backView: backView)
      .paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  return image;
}

class AnimatedTapeArtwork extends StatefulWidget {
  const AnimatedTapeArtwork(
      {super.key,
      required this.tape,
      required this.assets,
      required this.playing,
      this.caseView = false,
      this.backView = false,
      this.onTrackTap});
  final Tape tape;
  final List<StickerAsset> assets;
  final bool playing, caseView, backView;
  final ValueChanged<int>? onTrackTap;
  @override
  State<AnimatedTapeArtwork> createState() => _AnimatedTapeArtworkState();
}

class _AnimatedTapeArtworkState extends State<AnimatedTapeArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reels;
  @override
  void initState() {
    super.initState();
    _reels =
        AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _sync();
  }

  void _sync() {
    if (widget.playing && !widget.caseView) {
      _reels.repeat();
    } else {
      _reels.stop();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedTapeArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing ||
        oldWidget.caseView != widget.caseView) _sync();
  }

  @override
  void dispose() {
    _reels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _reels,
      builder: (_, child) => TapeArtwork(
          tape: widget.tape,
          assets: widget.assets,
          caseView: widget.caseView,
          backView: widget.backView,
          onTrackTap: widget.onTrackTap,
          reelAngle: _reels.value * math.pi * 2));
}

/// Continuation of the same sticker across the four physical side walls.
/// Edges are top, right, bottom, left; coordinates match the 3D side quads.
Future<ui.Image> renderTapeEdge(Tape tape, List<StickerAsset> assets, int edge,
    {bool caseView = false}) async {
  final textures = await ArtTextures.load(tape, assets);
  final h = caseView ? 390.0 : 370.0, d = caseView ? 70.0 : 41.0;
  final size = edge.isEven ? Size(600, d) : Size(d, h);
  final recorder = ui.PictureRecorder();
  // Each edge has its own canvas so no face texture is stretched onto a wall.
  final canvas = Canvas(recorder);
  canvas.drawColor(
      caseView ? Color(tape.shellColor) : Color(tape.color), BlendMode.srcOver);
  for (final back in [false, true]) {
    canvas.save();
    if (edge == 0) {
      canvas.translate(back ? 600 : 0, back ? 0 : d);
      if (back) canvas.scale(-1, -1);
    } else if (edge == 2) {
      canvas.translate(back ? 600 : 0, back ? d + h : -h);
      if (back) canvas.scale(-1, -1);
    } else if (edge == 3) {
      canvas.translate(back ? -600 : d, 0);
    } else {
      canvas.translate(back ? d : -600, 0);
    }
    for (final p
        in tape.stickers.where((p) => p.onCase == caseView && p.back == back)) {
      final asset = assets.where((a) => a.id == p.assetId).firstOrNull;
      final image = textures.images[asset?.path];
      if (image == null) continue;
      canvas.save();
      canvas.translate(p.x * 600, p.y * h);
      canvas.rotate(p.angle);
      final w = p.width * 600;
      paintImage(
          canvas: canvas,
          rect: Rect.fromCenter(
              center: Offset.zero,
              width: w,
              height: w * image.height / image.width),
          image: image,
          fit: BoxFit.contain);
      canvas.restore();
    }
    canvas.restore();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  return image;
}
