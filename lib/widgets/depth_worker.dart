import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'depth_renderer.dart';

/// Persistent background renderer. Pixel data for each image is sent once,
/// while subsequent frames transfer only geometry and return a bitmap buffer.
class DepthWorker {
  DepthWorker() {
    _receive.listen(_message);
    Isolate.spawn(_entry, _receive.sendPort).then((isolate) {
      if (_closed) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    }, onError: (Object error, StackTrace stack) {
      if (!_ready.isCompleted) _ready.completeError(error, stack);
    });
  }
  final _receive = ReceivePort(), _ready = Completer<SendPort>();
  final _textures = <DepthTexture, int>{};
  final _pending = <int, Completer<Uint8List>>{};
  Isolate? _isolate;
  int _nextTexture = 1, _nextJob = 1;
  bool _closed = false;
  void _message(dynamic message) {
    if (message is SendPort) {
      if (!_ready.isCompleted) _ready.complete(message);
      return;
    }
    final reply = message as List,
        id = reply[0] as int,
        job = _pending.remove(id);
    if (job == null) return;
    if (reply[1] is String) {
      job.completeError(StateError(reply[1] as String));
      return;
    }
    job.complete(
        (reply[1] as TransferableTypedData).materialize().asUint8List());
  }

  Future<Uint8List> render(
      int width, int height, List<DepthTriangle> triangles) async {
    if (_closed) throw StateError('Renderizador encerrado');
    final send = await _ready.future;
    if (_closed) throw StateError('Renderizador encerrado');
    final reset = _textures.length >= 24;
    if (reset) _textures.clear();
    final vertices = Float64List(triangles.length * 15),
        meta = Int32List(triangles.length * 2),
        additions = <List<Object>>[];
    for (var i = 0; i < triangles.length; i++) {
      final tri = triangles[i];
      var offset = i * 15;
      for (final v in [tri.a, tri.b, tri.c]) {
        vertices[offset++] = v.x;
        vertices[offset++] = v.y;
        vertices[offset++] = v.inverseDepth;
        vertices[offset++] = v.u;
        vertices[offset++] = v.v;
      }
      meta[i * 2] = tri.argb;
      final texture = tri.texture;
      if (texture != null) {
        var id = _textures[texture];
        if (id == null) {
          id = _nextTexture++;
          _textures[texture] = id;
          additions.add([
            id,
            texture.width,
            texture.height,
            TransferableTypedData.fromList([texture.rgba])
          ]);
        }
        meta[i * 2 + 1] = id;
      }
    }
    final id = _nextJob++, completer = Completer<Uint8List>();
    _pending[id] = completer;
    send.send([
      id,
      width,
      height,
      TransferableTypedData.fromList(
          [vertices.buffer.asUint8List(), meta.buffer.asUint8List()]),
      triangles.length,
      additions,
      reset
    ]);
    return completer.future;
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    if (!_ready.isCompleted) {
      _ready.future.ignore();
      _ready.completeError(StateError('Renderizador encerrado'));
    }
    for (final job in _pending.values) {
      if (!job.isCompleted)
        job.completeError(StateError('Renderizador encerrado'));
    }
    _pending.clear();
    _receive.close();
    _isolate?.kill(priority: Isolate.immediate);
  }
}

void _entry(SendPort reply) {
  final receive = ReceivePort(), textures = <int, DepthTexture>{};
  reply.send(receive.sendPort);
  receive.listen((dynamic message) {
    final input = message as List, id = input[0] as int;
    try {
      final width = input[1] as int,
          height = input[2] as int,
          count = input[4] as int;
      if (input[6] == true) textures.clear();
      for (final entry in input[5] as List) {
        final row = entry as List;
        textures[row[0] as int] = DepthTexture(row[1] as int, row[2] as int,
            (row[3] as TransferableTypedData).materialize().asUint8List());
      }
      final data = (input[3] as TransferableTypedData).materialize(),
          v = Float64List.view(data, 0, count * 15),
          meta = Int32List.view(data, count * 15 * 8, count * 2);
      final triangles = <DepthTriangle>[];
      for (var i = 0; i < count; i++) {
        final p = i * 15;
        DepthVertex vertex(int x) =>
            DepthVertex(v[x], v[x + 1], v[x + 2], v[x + 3], v[x + 4]);
        triangles.add(DepthTriangle(vertex(p), vertex(p + 5), vertex(p + 10),
            meta[i * 2], textures[meta[i * 2 + 1]]));
      }
      final rgba = renderDepth(width, height, triangles);
      for (var i = 0; i < rgba.length; i += 4) {
        final a = rgba[i + 3];
        if (a < 255) {
          rgba[i] = (rgba[i] * a / 255).round();
          rgba[i + 1] = (rgba[i + 1] * a / 255).round();
          rgba[i + 2] = (rgba[i + 2] * a / 255).round();
        }
      }
      reply.send([
        id,
        TransferableTypedData.fromList([rgba])
      ]);
    } catch (e, stack) {
      reply.send([id, '$e\n$stack']);
    }
  });
}
