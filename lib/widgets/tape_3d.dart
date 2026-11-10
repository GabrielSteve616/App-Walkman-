import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/tape.dart';
import 'tape_artwork.dart';

class SurfaceHit {
  const SurfaceHit(this.uv, this.back);
  final Offset uv;
  final bool back;
}

class Tape3D extends StatefulWidget {
  const Tape3D(
      {super.key,
      required this.front,
      required this.cover,
      required this.color,
      this.shellColor = const Color(0xFF8E9DA5),
      this.caseBack,
      this.tapeBack,
      this.interior,
      this.tapeEdges = const [],
      this.caseEdges = const [],
      this.caseView = false,
      this.backView = false,
      this.placingSticker = false,
      this.previewOnly = false,
      this.onPlace,
      this.onTrackTap,
      this.trackCount = 0});
  final ui.Image front, cover;
  final ui.Image? caseBack, tapeBack, interior;
  final List<ui.Image> tapeEdges, caseEdges;
  final Color color, shellColor;
  final bool caseView, backView, placingSticker, previewOnly;
  final ValueChanged<SurfaceHit>? onPlace;
  final ValueChanged<int>? onTrackTap;
  final int trackCount;
  @override
  State<Tape3D> createState() => _Tape3DState();
}

class _Tape3DState extends State<Tape3D> {
  double _x = -.12, _y = 0, _zoom = 1, _startZoom = 1, _lid = 0;
  Offset _last = Offset.zero;
  bool _openByTouch = false;
  @override
  void initState() {
    super.initState();
    if (widget.backView) _y = math.pi;
  }

  @override
  void didUpdateWidget(covariant Tape3D old) {
    super.didUpdateWidget(old);
    if (old.backView != widget.backView && !widget.placingSticker) {
      _y = widget.backView ? math.pi - .3 : 0;
      _x = -.12;
      _lid = 0;
    }
  }

  @override
  Widget build(BuildContext context) => widget.previewOnly
      ? CustomPaint(
          painter: _ModelPainter(widget, -.12, 0, 1, 0),
          child: const SizedBox.expand())
      : Column(children: [
          Expanded(child: LayoutBuilder(builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            final painter = _ModelPainter(widget, _x, _y, _zoom, _lid);
            void place(Offset position) {
              final hit = painter.surfaceAt(position, size);
              if (hit != null) widget.onPlace?.call(hit);
            }

            return Semantics(
                label: widget.caseView ? 'Case em 3D' : 'Fita em 3D',
                value: widget.caseView
                    ? ((_lid / 2.35 * 100).round().toString() + '%')
                    : null,
                child: GestureDetector(
                    onTapUp: (d) {
                      if (widget.placingSticker) {
                        place(d.localPosition);
                      } else if (widget.caseView) {
                        final hit = painter.surfaceAt(d.localPosition, size);
                        if (hit != null && hit.back) {
                          final index = caseTrackAt(hit.uv, widget.trackCount);
                          if (index != null) widget.onTrackTap?.call(index);
                        }
                      }
                    },
                    onScaleStart: (d) {
                      _last = d.localFocalPoint;
                      _startZoom = _zoom;
                    },
                    onScaleUpdate: (d) {
                      if (d.pointerCount == 1 && widget.placingSticker) {
                        place(d.localFocalPoint);
                        return;
                      }
                      setState(() {
                        if (d.pointerCount == 1 &&
                            _openByTouch &&
                            widget.caseView) {
                          _lid =
                              (_lid - (d.localFocalPoint.dy - _last.dy) * .018)
                                  .clamp(0, 2.35);
                        } else if (d.pointerCount == 1) {
                          final delta = d.localFocalPoint - _last;
                          _y += delta.dx * .013;
                          _x -= delta.dy * .013;
                        } else {
                          _zoom = (_startZoom * d.scale).clamp(.45, 2.8);
                        }
                        _last = d.localFocalPoint;
                      });
                    },
                    child: ClipRect(
                        child: CustomPaint(
                            painter: painter,
                            child: const SizedBox.expand()))));
          })),
          if (widget.caseView && !widget.placingSticker)
            Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
              ChoiceChip(
                  label: const Text('Girar'),
                  selected: !_openByTouch,
                  onSelected: (_) => setState(() => _openByTouch = false)),
              const SizedBox(width: 8),
              ChoiceChip(
                  label: const Text('Abrir'),
                  selected: _openByTouch,
                  onSelected: (_) => setState(() => _openByTouch = true)),
            ]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.placingSticker)
              const Expanded(
                  child: Text('Toque para colar', textAlign: TextAlign.center)),
            IconButton(
                tooltip: 'Centralizar',
                onPressed: () => setState(() {
                      _x = -.12;
                      _y = widget.backView ? math.pi - .3 : -.3;
                      _zoom = 1;
                      _lid = 0;
                    }),
                icon: const Icon(Icons.center_focus_strong))
          ]),
        ]);
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V b) => _V(x + b.x, y + b.y, z + b.z);
  _V operator -(_V b) => _V(x - b.x, y - b.y, z - b.z);
  _V times(double n) => _V(x * n, y * n, z * n);
  double dot(_V b) => x * b.x + y * b.y + z * b.z;
  _V cross(_V b) => _V(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  _V rotate(double rx, double ry) {
    final yy = y * math.cos(rx) - z * math.sin(rx),
        zz = y * math.sin(rx) + z * math.cos(rx);
    return _V(x * math.cos(ry) + zz * math.sin(ry), yy,
        -x * math.sin(ry) + zz * math.cos(ry));
  }
}

class _Face {
  _Face(this.points, this.color, {this.image, this.quad, this.surface});
  final List<_V> points;
  final Color color;
  final ui.Image? image;
  final List<_V>? quad;
  final bool? surface;
  double get depth => points.fold(0.0, (v, p) => v + p.z) / points.length;
}

class _ModelPainter extends CustomPainter {
  _ModelPainter(this.model, this.rx, this.ry, this.zoom, this.lid);
  final Tape3D model;
  final double rx, ry, zoom, lid;
  List<_Face> _solid(double w, double h, double d, Color base,
      {ui.Image? front,
      ui.Image? back,
      double z = 0,
      List<ui.Image> edges = const [],
      bool hinged = false,
      bool? frontSurface,
      bool? backSurface,
      double radius = .06}) {
    _V point(double x, double y, double zz) {
      var p = _V(x, y, zz + z);
      if (hinged) {
        final py = p.y + h, pz = p.z - z;
        p = _V(p.x, py * math.cos(lid) - pz * math.sin(lid) - h,
            py * math.sin(lid) + pz * math.cos(lid) + z);
      }
      return p.rotate(rx, ry);
    }

    final r = radius;
    final outline = [
      Offset(-w + r, -h),
      Offset(w - r, -h),
      Offset(w, -h + r),
      Offset(w, h - r),
      Offset(w - r, h),
      Offset(-w + r, h),
      Offset(-w, h - r),
      Offset(-w, -h + r)
    ];
    final a = outline.map((p) => point(p.dx, p.dy, d)).toList();
    final b = outline.map((p) => point(p.dx, p.dy, -d)).toList();
    final result = [
      _Face(a, base,
          image: front,
          quad: [
            point(-w, -h, d),
            point(w, -h, d),
            point(w, h, d),
            point(-w, h, d)
          ],
          surface: frontSurface),
      _Face(b.reversed.toList(), base,
          image: back,
          quad: [
            point(w, -h, -d),
            point(-w, -h, -d),
            point(-w, h, -d),
            point(w, h, -d)
          ],
          surface: backSurface),
    ];
    for (var i = 0; i < a.length; i++) {
      final j = (i + 1) % a.length;
      final side = i == 0
          ? 0
          : i == 2
              ? 1
              : i == 4
                  ? 2
                  : i == 6
                      ? 3
                      : null;
      final quad = switch (side) {
        0 => [b[0], b[1], a[1], a[0]],
        1 => [a[2], b[2], b[3], a[3]],
        2 => [a[5], a[4], b[4], b[5]],
        3 => [b[7], a[7], a[6], b[6]],
        _ => null,
      };
      result.add(_Face(
          [a[i], b[i], b[j], a[j]],
          Color.lerp(
              base, i < 3 ? Colors.white : Colors.black, i.isEven ? .15 : .35)!,
          image: side != null && edges.length == 4 ? edges[side] : null,
          quad: quad));
    }
    return result;
  }

  List<_Face> _faces() {
    if (!model.caseView) {
      return _solid(1.25, .77, .085, model.color,
          front: model.front,
          back: model.tapeBack ?? model.front,
          frontSurface: false,
          backSurface: true,
          edges: model.tapeEdges,
          radius: .04);
    }
    final shell = model.shellColor;
    return [
      // Back tray, a hollow frame, and a separate cassette seated in the tray.
      ..._solid(1.35, .8775, .025, const Color(0xFF303B42),
          back: model.caseBack ?? model.cover,
          z: -.165,
          backSurface: true,
          radius: .025),
      ..._solid(1.35, .8775, .14, shell, edges: model.caseEdges, radius: .025)
          .skip(2),
      ..._solid(1.29, .8175, .14, const Color(0xFF53636B), radius: .018)
          .skip(2),
      ..._solid(1.22, .752, .08, model.color,
          front: model.front,
          back: model.tapeBack ?? model.front,
          edges: model.tapeEdges,
          radius: .035),
      // The lid pivots around the long top edge, as a cassette jewel case does.
      ..._solid(1.35, .8775, .018, shell,
          front: model.cover,
          z: .158,
          hinged: true,
          frontSurface: false,
          radius: .025),
    ];
  }

  Size? _fittedSize;
  double _fittedScale = 1;
  Offset _fittedCenter = Offset.zero;
  void _fit(Size s) {
    if (_fittedSize == s) return;
    final points = _faces()
        .expand((f) => f.points)
        .map((p) => Offset(p.x, p.y) * (6 / (6 - p.z)))
        .toList();
    var bounds = Rect.fromPoints(points.first, points.first);
    for (final p in points)
      bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
    _fittedScale =
        math.min(s.width * .86 / bounds.width, s.height * .86 / bounds.height) *
            zoom;
    _fittedCenter =
        Offset(s.width / 2, s.height / 2) - bounds.center * _fittedScale;
    _fittedSize = s;
  }

  double _scale(Size s) {
    _fit(s);
    return _fittedScale;
  }

  Offset _center(Size s) {
    _fit(s);
    return _fittedCenter;
  }

  Offset _project(_V p, Size s) {
    final k = 6 / (6 - p.z);
    return _center(s) + Offset(p.x, p.y) * (_scale(s) * k);
  }

  SurfaceHit? surfaceAt(Offset screen, Size size) {
    final p = (screen - _center(size)) / _scale(size),
        origin = const _V(0, 0, 6),
        direction = _V(p.dx, p.dy, -6);
    double nearest = double.infinity;
    _Face? picked;
    Offset? uv;
    for (final face in _faces()) {
      final quad = face.quad ??
          [face.points[0], face.points[1], face.points[2], face.points.last];
      final e = quad[1] - quad[0],
          f = quad[3] - quad[0],
          normal = e.cross(f),
          den = normal.dot(direction);
      if (den.abs() < 1e-8) continue;
      final t = normal.dot(quad[0] - origin) / den;
      if (t <= 0 || t >= nearest) continue;
      final q = origin + direction.times(t) - quad[0];
      final ee = e.dot(e),
          ff = f.dot(f),
          ef = e.dot(f),
          det = ee * ff - ef * ef;
      if (det.abs() < 1e-8) continue;
      final u = (q.dot(e) * ff - q.dot(f) * ef) / det,
          v = (q.dot(f) * ee - q.dot(e) * ef) / det;
      if (u < 0 || u > 1 || v < 0 || v > 1) continue;
      final polygon = Path()
        ..addPolygon(face.points.map((p) => _project(p, size)).toList(), true);
      if (!polygon.contains(screen)) continue;
      nearest = t;
      picked = face;
      uv = Offset(u, v);
    }
    return picked?.surface == null || uv == null
        ? null
        : SurfaceHit(uv, picked!.surface!);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height * .9),
            width: size.width * .5,
            height: 14),
        Paint()
          ..color = Colors.black38
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    final faces = _faces()..sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faces) {
      final path = Path()
        ..addPolygon(face.points.map((p) => _project(p, size)).toList(), true);
      canvas.drawPath(path, Paint()..color = face.color);
      final image = face.image, quad = face.quad;
      if (image != null && quad != null) {
        final vertices = <Offset>[], uv = <Offset>[], indices = <int>[];
        const steps = 12;
        for (var row = 0; row <= steps; row++)
          for (var col = 0; col <= steps; col++) {
            final u = col / steps, v = row / steps;
            final p = quad[0].times((1 - u) * (1 - v)) +
                quad[1].times(u * (1 - v)) +
                quad[2].times(u * v) +
                quad[3].times((1 - u) * v);
            vertices.add(_project(p, size));
            uv.add(Offset(u * image.width, v * image.height));
            if (row < steps && col < steps) {
              final n = row * (steps + 1) + col;
              indices.addAll(
                  [n, n + 1, n + steps + 2, n, n + steps + 2, n + steps + 1]);
            }
          }
        final shader = ui.ImageShader(
            image,
            ui.TileMode.clamp,
            ui.TileMode.clamp,
            Float64List.fromList(
                [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
        final mesh = ui.Vertices(ui.VertexMode.triangles, vertices,
            textureCoordinates: uv, indices: indices);
        canvas.save();
        canvas.clipPath(path);
        canvas.drawVertices(mesh, BlendMode.srcOver, Paint()..shader = shader);
        canvas.restore();
        mesh.dispose();
        shader.dispose();
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white38
            ..style = PaintingStyle.stroke
            ..strokeWidth = .65);
    }
  }

  @override
  bool shouldRepaint(covariant _ModelPainter old) => true;
}

class TapeModelView extends StatefulWidget {
  const TapeModelView(
      {super.key,
      required this.tape,
      required this.assets,
      this.caseView = false,
      this.backView = false,
      this.placingSticker = false,
      this.previewOnly = false,
      this.onPlace,
      this.onTrackTap});
  final Tape tape;
  final List<StickerAsset> assets;
  final bool caseView, backView, placingSticker, previewOnly;
  final ValueChanged<SurfaceHit>? onPlace;
  final ValueChanged<int>? onTrackTap;
  @override
  State<TapeModelView> createState() => _TapeModelViewState();
}

class _TapeModelViewState extends State<TapeModelView> {
  final List<ui.Image?> _images = List.filled(13, null);
  final List<String> _keys = List.filled(13, '');
  bool _loading = false, _dirty = false;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TapeModelView old) {
    super.didUpdateWidget(old);
    _timer ??= Timer(const Duration(milliseconds: 90), () {
      _timer = null;
      _load();
    });
  }

  Future<void> _load() async {
    if (_loading) {
      _dirty = true;
      return;
    }
    _loading = true;
    try {
      final tape = widget.tape.copy(),
          assets = List<StickerAsset>.of(widget.assets);
      for (var i = 0; i < 13; i++) {
        final caseView = i == 1 || i == 3 || i >= 9, back = i == 2 || i == 3;
        final key =
            jsonEncode(tape.toJson()) + assets.map((s) => s.path).join('|');
        if (_keys[i] == key) continue;
        ui.Image image;
        if (i >= 5) {
          image =
              await renderTapeEdge(tape, assets, (i - 5) % 4, caseView: i >= 9);
        } else {
          image = await renderTapeTexture(tape, assets,
              caseView: caseView, backView: back);
        }
        if (!mounted) {
          image.dispose();
          break;
        }
        final previous = _images[i];
        setState(() {
          _images[i] = image;
          _keys[i] = key;
        });
        previous?.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível montar o modelo.');
    } finally {
      _loading = false;
      if (_dirty && mounted) {
        _dirty = false;
        _load();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final i in _images) {
      i?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _error != null
      ? Center(child: Text(_error!))
      : _images.any((i) => i == null)
          ? const Center(child: CircularProgressIndicator())
          : Tape3D(
              front: _images[0]!,
              cover: _images[1]!,
              tapeBack: _images[2],
              caseBack: _images[3],
              interior: _images[4],
              tapeEdges: _images.sublist(5, 9).cast<ui.Image>(),
              caseEdges: _images.sublist(9, 13).cast<ui.Image>(),
              color: Color(widget.tape.color),
              shellColor: Color(widget.tape.shellColor),
              caseView: widget.caseView,
              backView: widget.backView,
              placingSticker: widget.placingSticker,
              previewOnly: widget.previewOnly,
              onPlace: widget.onPlace,
              onTrackTap: widget.onTrackTap,
              trackCount: widget.tape.tracks.length);
}
