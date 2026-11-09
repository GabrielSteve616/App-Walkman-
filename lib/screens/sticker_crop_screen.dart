import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Path stickerPath(String shape, Rect rect, List<Offset> freehand) {
  final path = Path();
  if (shape == 'Livre' && freehand.length >= 3)
    return path..addPolygon(freehand, true);
  if (shape == 'Círculo') return path..addOval(rect);
  if (shape == 'Coração') {
    Offset p(double x, double y) =>
        Offset(rect.left + x * rect.width, rect.top + y * rect.height);
    final a = p(.5, 1), b = p(0, .25), c = p(.5, .15), d = p(1, .25);
    path.moveTo(a.dx, a.dy);
    path.cubicTo(p(-.25, .45).dx, p(-.25, .45).dy, b.dx, b.dy, p(.15, .08).dx,
        p(.15, .08).dy);
    path.cubicTo(p(.35, -.05).dx, p(.35, -.05).dy, c.dx, c.dy, c.dx, c.dy);
    path.cubicTo(
        p(.8, -.15).dx, p(.8, -.15).dy, d.dx, d.dy, p(1, .45).dx, p(1, .45).dy);
    path.cubicTo(p(.9, .7).dx, p(.9, .7).dy, a.dx, a.dy, a.dx, a.dy);
    return path..close();
  }
  if (shape == 'Estrela') {
    final points = [
      for (var i = 0; i < 10; i++)
        Offset(
            rect.center.dx +
                math.cos(-math.pi / 2 + i * math.pi / 5) *
                    rect.width *
                    .5 *
                    (i.isEven ? 1 : .46),
            rect.center.dy +
                math.sin(-math.pi / 2 + i * math.pi / 5) *
                    rect.height *
                    .5 *
                    (i.isEven ? 1 : .46))
    ];
    return path..addPolygon(points, true);
  }
  if (shape == 'Triângulo')
    return path
      ..addPolygon([rect.topCenter, rect.bottomRight, rect.bottomLeft], true);
  return path..addRect(rect);
}

class StickerCropScreen extends StatefulWidget {
  const StickerCropScreen({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<StickerCropScreen> createState() => _StickerCropScreenState();
}

class _StickerCropScreenState extends State<StickerCropScreen> {
  ui.Image? _image;
  String _shape = 'Livre';
  Offset? _handle;
  Offset _dragStart = Offset.zero;
  Rect _dragRect = Rect.zero;
  double _x = .5, _y = .5, _w = .8, _h = .8;
  final List<Offset> _points = [];
  final List<int> _strokes = [];
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes,
          targetWidth: 1536, allowUpscaling: false);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      if (mounted)
        setState(() => _image = image);
      else
        image.dispose();
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'Não foi possível abrir esta imagem. Escolha outra.');
    }
  }

  Rect _rect(Size size) => Rect.fromCenter(
          center: Offset(_x * size.width, _y * size.height),
          width: _w * size.width,
          height: _h * size.height)
      .intersect(Offset.zero & size);
  void _startSelection(Offset position, Size size) {
    _dragStart = Offset(position.dx / size.width, position.dy / size.height);
    _dragRect = _rect(const Size(1, 1));
    _handle = null;
    if (_shape != 'Retângulo') return;
    final rect = _rect(size);
    final handles = <Offset, Offset>{
      rect.topLeft: const Offset(-1, -1),
      rect.topRight: const Offset(1, -1),
      rect.bottomLeft: const Offset(-1, 1),
      rect.bottomRight: const Offset(1, 1),
      rect.topCenter: const Offset(0, -1),
      rect.bottomCenter: const Offset(0, 1),
      rect.centerLeft: const Offset(-1, 0),
      rect.centerRight: const Offset(1, 0),
    };
    var distance = 26.0;
    for (final entry in handles.entries) {
      final d = (entry.key - position).distance;
      if (d < distance) {
        distance = d;
        _handle = entry.value;
      }
    }
  }

  void _adjustSelection(Offset position, Size size) {
    final delta = Offset(position.dx / size.width, position.dy / size.height) -
        _dragStart;
    final h = _handle;
    if (h == null) {
      _x = (_dragRect.center.dx + delta.dx).clamp(_w / 2, 1 - _w / 2);
      _y = (_dragRect.center.dy + delta.dy).clamp(_h / 2, 1 - _h / 2);
      return;
    }
    var l = _dragRect.left,
        r = _dragRect.right,
        t = _dragRect.top,
        b = _dragRect.bottom;
    if (h.dx < 0) l = (l + delta.dx).clamp(0, r - .1);
    if (h.dx > 0) r = (r + delta.dx).clamp(l + .1, 1);
    if (h.dy < 0) t = (t + delta.dy).clamp(0, b - .1);
    if (h.dy > 0) b = (b + delta.dy).clamp(t + .1, 1);
    _w = (r - l).clamp(.1, 1);
    _h = (b - t).clamp(.1, 1);
    _x = (l + r) / 2;
    _y = (t + b) / 2;
  }

  Future<void> _save() async {
    final image = _image;
    if (image == null || _saving) return;
    if (_shape == 'Livre' && _points.length < 3) {
      setState(() => _error = 'Desenhe um contorno fechado com o dedo.');
      return;
    }
    setState(() => _saving = true);
    try {
      final size = Size(image.width.toDouble(), image.height.toDouble());
      final points = _points
          .map((p) => Offset(p.dx * size.width, p.dy * size.height))
          .toList();
      final path = stickerPath(_shape, _rect(size), points);
      final bounds = path.getBounds().intersect(Offset.zero & size);
      if (bounds.width < 2 || bounds.height < 2)
        throw StateError('Seleção muito pequena');
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.translate(-bounds.left, -bounds.top);
      canvas.clipPath(path);
      canvas.drawImage(image, Offset.zero, Paint());
      final picture = recorder.endRecording();
      final output =
          await picture.toImage(bounds.width.ceil(), bounds.height.ceil());
      final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      output.dispose();
      picture.dispose();
      if (mounted) Navigator.pop(context, bytes!.buffer.asUint8List());
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível recortar. Ajuste a seleção.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Recortar figurinha'), actions: [
        TextButton(
            onPressed: _saving ||
                    _image == null ||
                    (_shape == 'Livre' && _points.length < 3)
                ? null
                : _save,
            child: Text(_saving ? 'Salvando…' : 'Usar recorte'))
      ]),
      body: _image == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!))
          : Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: true,
                            icon: Icon(Icons.gesture),
                            label: Text('Com o dedo')),
                        ButtonSegment(
                            value: false,
                            icon: Icon(Icons.crop),
                            label: Text('Retângulo')),
                      ],
                      selected: {
                        _shape == 'Livre'
                      },
                      onSelectionChanged: _saving
                          ? null
                          : (v) => setState(() {
                                if (v.first) {
                                  _shape = 'Livre';
                                } else {
                                  _shape = 'Retângulo';
                                }
                                _error = null;
                              }))),
              if (_shape != 'Livre')
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(spacing: 6, children: [
                      for (final shape in [
                        'Retângulo',
                        'Círculo',
                        'Estrela',
                        'Coração',
                        'Triângulo'
                      ])
                        ChoiceChip(
                            label: Text(
                                shape == 'Retângulo' ? 'Retangular' : shape),
                            selected: _shape == shape,
                            onSelected: _saving
                                ? null
                                : (_) => setState(() {
                                      _shape = shape;
                                      _error = null;
                                    })),
                    ])),
              Expanded(
                  child: Center(
                      child: AspectRatio(
                          aspectRatio: _image!.width / _image!.height,
                          child: LayoutBuilder(builder: (context, constraints) {
                            final size = Size(
                                constraints.maxWidth, constraints.maxHeight);
                            Offset normalized(Offset p) => Offset(
                                (p.dx / size.width).clamp(0, 1),
                                (p.dy / size.height).clamp(0, 1));
                            return GestureDetector(
                                onPanDown: (d) {
                                  if (_shape != 'Livre')
                                    _startSelection(d.localPosition, size);
                                  if (_shape == 'Livre')
                                    setState(() {
                                      _strokes.add(_points.length);
                                      _points.add(normalized(d.localPosition));
                                    });
                                },
                                onPanUpdate: (d) => setState(() {
                                      if (_shape == 'Livre') {
                                        _points
                                            .add(normalized(d.localPosition));
                                      } else {
                                        _adjustSelection(d.localPosition, size);
                                      }
                                    }),
                                child: CustomPaint(
                                    painter: _CropPainter(
                                        _image!,
                                        _shape,
                                        _rect(size),
                                        _points
                                            .map((p) => Offset(
                                                p.dx * size.width,
                                                p.dy * size.height))
                                            .toList()),
                                    child: const SizedBox.expand()));
                          })))),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.orange)),
              if (_shape == 'Livre')
                Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                  TextButton.icon(
                      onPressed: _strokes.isEmpty
                          ? null
                          : () => setState(() {
                                final start = _strokes.removeLast();
                                _points.removeRange(start, _points.length);
                              }),
                      icon: const Icon(Icons.undo),
                      label: const Text('Desfazer trecho')),
                  TextButton.icon(
                      onPressed: _points.isEmpty
                          ? null
                          : () => setState(() {
                                _points.clear();
                                _strokes.clear();
                              }),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Recomeçar')),
                ]),
              if (_shape != 'Livre' && _shape != 'Retângulo') ...[
                Row(children: [
                  const SizedBox(width: 12),
                  const Text('Largura'),
                  Expanded(
                      child: Slider(
                          value: _w,
                          min: .1,
                          max: 1,
                          onChanged: (v) => setState(() {
                                _w = v;
                                _x = _x.clamp(v / 2, 1 - v / 2);
                              })))
                ]),
                Row(children: [
                  const SizedBox(width: 12),
                  const Text('Altura'),
                  Expanded(
                      child: Slider(
                          value: _h,
                          min: .1,
                          max: 1,
                          onChanged: (v) => setState(() {
                                _h = v;
                                _y = _y.clamp(v / 2, 1 - v / 2);
                              })))
                ]),
              ],
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                      _shape == 'Livre'
                          ? 'Contorne a imagem com o dedo. Pode levantar e continuar. O ponto verde marca o início; finalize em Usar recorte.'
                          : _shape == 'Retângulo'
                              ? 'Puxe os cantos ou as bordas para ajustar. Arraste dentro do retângulo para mover o corte.'
                              : 'Arraste a seleção e ajuste largura e altura. O exterior ficará transparente.',
                      textAlign: TextAlign.center)),
            ]));
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.shape, this.rect, this.points);
  final ui.Image image;
  final String shape;
  final Rect rect;
  final List<Offset> points;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF454545), BlendMode.srcOver);
    paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: image,
        fit: BoxFit.fill);
    final path = stickerPath(shape, rect, points);
    if (shape == 'Livre' && points.length < 3) {
      if (points.isNotEmpty)
        canvas.drawCircle(points.first, 4, Paint()..color = Colors.greenAccent);
      return;
    }
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(path, Offset.zero);
    canvas.drawPath(mask, Paint()..color = Colors.black54);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    if (shape == 'Retângulo') {
      final grid = Paint()
        ..color = Colors.white54
        ..strokeWidth = 1;
      for (var i = 1; i < 3; i++) {
        canvas.drawLine(Offset(rect.left + rect.width * i / 3, rect.top),
            Offset(rect.left + rect.width * i / 3, rect.bottom), grid);
        canvas.drawLine(Offset(rect.left, rect.top + rect.height * i / 3),
            Offset(rect.right, rect.top + rect.height * i / 3), grid);
      }
      final stroke = Paint()
        ..color = Colors.white
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (final corner in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight
      ]) {
        final sx = corner.dx == rect.left ? 1 : -1,
            sy = corner.dy == rect.top ? 1 : -1;
        canvas.drawLine(corner, corner + Offset(18.0 * sx, 0), stroke);
        canvas.drawLine(corner, corner + Offset(0, 18.0 * sy), stroke);
      }
      for (final edge in [rect.topCenter, rect.bottomCenter]) {
        canvas.drawLine(
            edge - const Offset(9, 0), edge + const Offset(9, 0), stroke);
      }
      for (final edge in [rect.centerLeft, rect.centerRight]) {
        canvas.drawLine(
            edge - const Offset(0, 9), edge + const Offset(0, 9), stroke);
      }
    }
    if (shape == 'Livre' && points.isNotEmpty)
      canvas.drawCircle(points.first, 4, Paint()..color = Colors.greenAccent);
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) => true;
}
