import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/tape.dart';
import 'tape_artwork.dart';
import 'glb_model.dart';
import 'depth_renderer.dart';
import 'depth_worker.dart';

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
      this.transparent = false,
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
  final bool transparent;
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
  bool _interacting = false;
  WalkmenModels? _geometry;
  @override
  void initState() {
    super.initState();
    _geometry = WalkmenModels.current;
    if (widget.backView) _y = math.pi;
    WalkmenModels.load().then((m) {
      if (mounted) setState(() => _geometry = m);
    }).catchError((Object e) {
      debugPrint("Walkmen GLB: $e");
    });
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
      ? _DepthCanvas(painter: _ModelPainter(widget, -.12, 0, 1, 0, _geometry))
      : Column(children: [
          Expanded(child: LayoutBuilder(builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            final painter =
                _ModelPainter(widget, _x, _y, _zoom, _lid, _geometry);
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
                      setState(() => _interacting = true);
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
                    onScaleEnd: (_) {
                      if (_interacting) setState(() => _interacting = false);
                    },
                    child: ClipRect(
                        child: _DepthCanvas(
                            painter: painter, interacting: _interacting))));
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
  _Face(this.points, this.color,
      {this.image, this.quad, this.surface, this.uv, this.imported = false});
  final bool imported;
  final List<Offset>? uv;
  final List<_V> points;
  final Color color;
  final ui.Image? image;
  final List<_V>? quad;
  final bool? surface;
  double get depth => points.fold(0.0, (v, p) => v + p.z) / points.length;
}

class _ModelPainter {
  _ModelPainter(
      this.model, this.rx, this.ry, this.zoom, this.lid, this.geometry);
  final WalkmenModels? geometry;
  final Tape3D model;
  final double rx, ry, zoom, lid;
  List<_Face> _solid(double w, double h, double d, Color base,
      {ui.Image? front,
      ui.Image? back,
      double z = 0,
      double dx = 0,
      double dy = 0,
      double? hingeHeight,
      List<ui.Image> edges = const [],
      bool hinged = false,
      bool? frontSurface,
      bool? backSurface,
      double radius = .06}) {
    _V point(double x, double y, double zz) {
      var p = _V(x + dx, y + dy, zz + z);
      if (hinged) {
        final pivot = hingeHeight ?? h;
        final py = p.y + pivot, pz = p.z - z;
        p = _V(p.x, py * math.cos(lid) - pz * math.sin(lid) - pivot,
            py * math.sin(lid) + pz * math.cos(lid) + z);
      }
      return p.rotate(rx, ry);
    }

    // Tiny supports need a smaller bevel than the main shell. An oversized
    // bevel folds the polygon over itself and creates stray triangles.
    final r = radius.clamp(0.0, math.min(w, h) * .49);
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

  List<_Face> _cassette(double w, double h, double depth,
      {double z = 0, bool surfaces = false}) {
    final base = model.transparent
        ? Color.lerp(model.color, const Color(0xFFCFEFF8), .68)!
            .withValues(alpha: .12)
        : model.color;
    return [
      ..._solid(w, h, depth, base,
          front: model.front,
          back: model.tapeBack ?? model.front,
          edges: model.tapeEdges,
          z: z,
          frontSurface: surfaces ? false : null,
          backSurface: surfaces ? true : null,
          radius: .04),
    ];
  }

  List<_Face> _glbFaces(GlbModel source,
      {bool cassette = false, double scale = 1, double z = 0}) {
    final result = <_Face>[];
    final zs = source.parts.expand((p) => p.points).map((p) => p.z);
    final minZ = zs.reduce(math.min), maxZ = zs.reduce(math.max);
    for (final part in source.parts) {
      _V convert(ModelPoint v) {
        var p = _V(v.x * scale, v.y * scale, v.z * scale + z);
        if (part.hinged && model.caseView && !cassette) {
          final pivot = part.pivot, py = p.y - pivot.y, pz = p.z - pivot.z;
          p = _V(p.x, py * math.cos(-lid) - pz * math.sin(-lid) + pivot.y,
              py * math.sin(-lid) + pz * math.cos(-lid) + pivot.z);
        }
        return p.rotate(rx, ry);
      }

      for (var i = 0; i + 2 < part.indices.length; i += 3) {
        final raw = [
          for (var j = 0; j < 3; j++) part.points[part.indices[i + j]]
        ];
        final a = _V(raw[0].x, raw[0].y, raw[0].z),
            b = _V(raw[1].x, raw[1].y, raw[1].z),
            c = _V(raw[2].x, raw[2].y, raw[2].z),
            n = (b - a).cross(c - a);
        final length = math.sqrt(n.dot(n));
        if (length < 1e-9) continue;
        final front = n.z < 0, planar = n.z.abs() / length > .72;
        final points = raw.map(convert).toList();
        final center = points.reduce((a, b) => a + b).times(1 / 3),
            normal = (points[1] - points[0]).cross(points[2] - points[0]);
        if (normal.dot(const _V(0, 0, 6) - center) >= 0) continue;
        final isTape = cassette || !model.caseView;
        final color = isTape ? model.color : model.shellColor;
        final shade = (.75 + .25 * (n.z.abs() / length)).clamp(0.0, 1.0);
        final base = Color.lerp(Colors.black, color, shade)!;
        ui.Image? image;
        bool? surface;
        List<Offset>? uv;
        if (planar) {
          image = isTape
              ? (front ? model.front : model.tapeBack)
              : (front
                  ? (part.hinged ? model.cover : model.interior)
                  : (part.hinged ? model.interior : model.caseBack));
          surface = isTape
              ? (model.caseView ? null : !front)
              : (part.hinged && front
                  ? false
                  : (!part.hinged && !front ? true : null));
          final w = isTape ? 1.25 : 1.35, h = isTape ? .77 : .8775;
          uv = [
            for (final p in raw)
              Offset((front ? p.x / w : -p.x / w) * .5 + .5, p.y / h * .5 + .5)
          ];
        } else {
          final edges = isTape ? model.tapeEdges : model.caseEdges;
          if (edges.length == 4) {
            final w = isTape ? 1.25 : 1.35, h = isTape ? .77 : .8775;
            final side =
                n.x.abs() > n.y.abs() ? (n.x < 0 ? 1 : 3) : (n.y > 0 ? 0 : 2);
            image = edges[side];
            uv = [
              for (final p in raw)
                switch (side) {
                  0 => Offset(p.x / w * .5 + .5, (p.z - minZ) / (maxZ - minZ)),
                  1 => Offset((maxZ - p.z) / (maxZ - minZ), p.y / h * .5 + .5),
                  2 => Offset(p.x / w * .5 + .5, (maxZ - p.z) / (maxZ - minZ)),
                  _ => Offset((p.z - minZ) / (maxZ - minZ), p.y / h * .5 + .5),
                }
            ];
          }
        }
        result.add(_Face(points,
            isTape && model.transparent ? base.withValues(alpha: .2) : base,
            image: image, surface: surface, uv: uv, imported: true));
      }
    }
    return result;
  }

  List<_Face> _trayPanel(Color color, double z, ui.Image? image,
      {bool back = false}) {
    final faces = <_Face>[];
    _V p(double u, double v) =>
        _V((u - .5) * 2.7, (v - .5) * 1.755, z).rotate(rx, ry);
    Offset uv(double u, double v) => Offset(back ? 1 - u : u, v);
    const steps = 1;
    for (var y = 0; y < steps; y++) {
      for (var x = 0; x < steps; x++) {
        final u = x / steps,
            v = y / steps,
            nu = (x + 1) / steps,
            nv = (y + 1) / steps;
        faces.add(_Face([p(u, v), p(nu, v), p(nu, nv)], color,
            image: image,
            uv: [uv(u, v), uv(nu, v), uv(nu, nv)],
            surface: back ? true : null,
            imported: true));
        faces.add(_Face([p(u, v), p(nu, nv), p(u, nv)], color,
            image: image,
            uv: [uv(u, v), uv(nu, nv), uv(u, nv)],
            surface: back ? true : null,
            imported: true));
      }
    }
    return faces;
  }

  List<_Face>? _cachedFaces;
  List<_Face> _faces() => _cachedFaces ??= _buildFaces();
  List<_Face> _buildFaces() {
    if (geometry != null && !model.caseView) return _glbFaces(geometry!.tape);
    if (!model.caseView) return _cassette(1.25, .77, .14, surfaces: true);
    final shell = model.shellColor,
        inner = Color.lerp(shell, const Color(0xFF263139), .6)!;
    const h = .8775;
    return [
      // Tray floor, outer walls and the inset well leave actual volume for the tape.
      ..._trayPanel(inner, -.175, model.interior),
      ..._trayPanel(inner, -.215, model.caseBack ?? model.cover, back: true),
      ..._solid(1.35, h, .185, shell,
              edges: model.caseEdges, z: -.005, radius: .035)
          .skip(2),
      ..._solid(1.29, .8175, .172, inner, z: -.005, radius: .025).skip(2),
      for (final y in [-.83, .83])
        ..._solid(1.30, .032, .014, shell, dy: y, z: -.161, radius: .012),
      for (final x in [-1.30, 1.30])
        ..._solid(.032, .79, .014, shell, dx: x, z: -.161, radius: .012),
      // Hinge barrels remain attached to the tray edge rather than crossing the tape.
      for (final x in [-1.29, 1.29])
        ..._solid(.035, .052, .07, inner,
            dx: x, dy: -.815, z: -.08, radius: .015),
      // Front catches and short side supports are separate moulded parts.
      for (final x in [-.86, .86])
        ..._solid(.09, .022, .035, shell, dx: x, dy: .82, z: .12, radius: .012),
      if (geometry != null && lid > .001)
        ..._glbFaces(geometry!.tape, cassette: true, scale: .94, z: -.015)
      else if (geometry == null && lid > .001)
        ..._cassette(1.22, .752, .125, z: -.015),
      // Hinged lid and its return walls rotate around the same long-edge pivot.
      ..._solid(1.35, h, .018, shell,
          front: model.cover,
          back: model.interior,
          z: .185,
          hinged: true,
          frontSurface: false,
          radius: .035),
      for (final x in [-1.32, 1.32])
        ..._solid(.025, .81, .055, shell,
            dx: x, z: .185, hinged: true, hingeHeight: h, radius: .012),
      ..._solid(1.28, .025, .05, shell,
          dy: .84, z: .185, hinged: true, hingeHeight: h, radius: .012),
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
      if (u < 0 || u > 1 || v < 0 || v > 1 || (face.uv != null && u + v > 1))
        continue;
      final polygon = Path()
        ..addPolygon(face.points.map((p) => _project(p, size)).toList(), true);
      if (!polygon.contains(screen)) continue;
      nearest = t;
      picked = face;
      uv = face.uv == null
          ? Offset(u, v)
          : face.uv![0] * (1 - u - v) + face.uv![1] * u + face.uv![2] * v;
    }
    return picked?.surface == null || uv == null
        ? null
        : SurfaceHit(uv, picked!.surface!);
  }
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
        } else if (i == 4) {
          image = await renderCaseInterior(tape, assets);
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
              transparent: widget.tape.transparent,
              caseView: widget.caseView,
              backView: widget.backView,
              placingSticker: widget.placingSticker,
              previewOnly: widget.previewOnly,
              onPlace: widget.onPlace,
              onTrackTap: widget.onTrackTap,
              trackCount: widget.tape.tracks.length);
}

class _DepthCanvas extends StatefulWidget {
  const _DepthCanvas({required this.painter, this.interacting = false});
  final _ModelPainter painter;
  final bool interacting;
  @override
  State<_DepthCanvas> createState() => _DepthCanvasState();
}

class _DepthCanvasState extends State<_DepthCanvas> {
  static final _textures = Expando<Future<DepthTexture>>();
  DepthWorker? _worker;
  ui.Image? _image;
  bool _busy = false;
  int? _rendered;
  int? _desired;
  @override
  void dispose() {
    _worker?.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<DepthTexture> _texture(ui.Image image) =>
      _textures[image] ??= () async {
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        return DepthTexture(
            image.width,
            image.height,
            bytes!.buffer
                .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      }();
  Future<void> _render(_ModelPainter painter, Size size, int key) async {
    _busy = true;
    try {
      final moving = painter.model.caseView && widget.interacting;
      final scale = moving
          ? math.min(1.0, 400 / math.max(size.width, size.height))
          : math.min(1.5, 640 / math.max(size.width, size.height));
      final width = math.max(1, (size.width * scale).round()),
          height = math.max(1, (size.height * scale).round());
      final triangles = <DepthTriangle>[];
      final faces = painter._faces();
      final requests = <ui.Image, Future<DepthTexture>>{
        for (final face in faces)
          if (face.image != null) face.image!: _texture(face.image!),
      };
      final textures = <ui.Image, DepthTexture>{};
      for (final entry in requests.entries) {
        textures[entry.key] = await entry.value;
      }
      for (final face in faces) {
        final texture = textures[face.image];
        List<Offset>? uv = face.uv;
        if (uv == null && face.quad != null) {
          final q = face.quad!,
              e = q[1] - q[0],
              f = q[3] - q[0],
              ee = e.dot(e),
              ff = f.dot(f),
              ef = e.dot(f),
              det = ee * ff - ef * ef;
          if (det.abs() > 1e-10)
            uv = [
              for (final v in face.points)
                Offset(((v - q[0]).dot(e) * ff - (v - q[0]).dot(f) * ef) / det,
                    ((v - q[0]).dot(f) * ee - (v - q[0]).dot(e) * ef) / det)
            ];
        }
        final vertices = <DepthVertex>[];
        for (var i = 0; i < face.points.length; i++) {
          final point = face.points[i],
              projected = painter._project(point, size),
              at = uv?[i] ?? Offset.zero;
          vertices.add(DepthVertex(projected.dx * scale, projected.dy * scale,
              1 / (6 - point.z), at.dx, at.dy));
        }
        for (var i = 1; i + 1 < vertices.length; i++) {
          triangles.add(DepthTriangle(vertices[0], vertices[i], vertices[i + 1],
              face.color.toARGB32(), texture));
        }
      }
      final rgba =
          await (_worker ??= DepthWorker()).render(width, height, triangles);
      if (!mounted) return;
      final complete = Completer<ui.Image>();
      ui.decodeImageFromPixels(
          rgba, width, height, ui.PixelFormat.rgba8888, complete.complete);
      final next = await complete.future;
      if (!mounted) {
        next.dispose();
        return;
      }
      // Keep showing completed gesture frames while a newer angle is queued;
      // otherwise rapid dragging can discard every frame until the user stops.
      // A changed model or the final high-quality frame must never use stale data.
      final sameModel = widget.painter.model.caseView ==
              painter.model.caseView &&
          widget.painter.model.color == painter.model.color &&
          widget.painter.model.shellColor == painter.model.shellColor &&
          widget.painter.model.transparent == painter.model.transparent &&
          identical(widget.painter.geometry, painter.geometry) &&
          identical(widget.painter.model.front, painter.model.front) &&
          identical(widget.painter.model.tapeBack, painter.model.tapeBack) &&
          identical(widget.painter.model.cover, painter.model.cover) &&
          identical(widget.painter.model.caseBack, painter.model.caseBack) &&
          identical(widget.painter.model.interior, painter.model.interior);
      if (key != _desired && !(widget.interacting && sameModel)) {
        next.dispose();
        return;
      }
      final previous = _image;
      setState(() {
        _image = next;
        _rendered = key;
      });
      if (previous != null)
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    } catch (e) {
      if (mounted) debugPrint('Walkmen: renderização 3D: $e');
      _rendered = key;
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final p = widget.painter,
            m = p.model,
            size = Size(c.maxWidth, c.maxHeight);
        final key = Object.hashAll([
          p.rx,
          p.ry,
          p.zoom,
          p.lid,
          p.geometry,
          size,
          m.caseView,
          m.front,
          m.cover,
          m.caseBack,
          m.tapeBack,
          m.interior,
          m.color,
          m.shellColor,
          m.transparent,
          widget.interacting,
          ...m.tapeEdges,
          ...m.caseEdges
        ]);
        _desired = key;
        if (!_busy && key != _rendered && size.width > 0 && size.height > 0) {
          unawaited(_render(p, size, key));
        }
        return CustomPaint(
            painter: _DepthImagePainter(_image),
            child: const SizedBox.expand());
      });
}

class _DepthImagePainter extends CustomPainter {
  const _DepthImagePainter(this.image);
  final ui.Image? image;
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
    if (image != null)
      canvas.drawImageRect(
          image!,
          Rect.fromLTWH(
              0, 0, image!.width.toDouble(), image!.height.toDouble()),
          Offset.zero & size,
          Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_DepthImagePainter old) => old.image != image;
}
