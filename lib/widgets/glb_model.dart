import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';

class ModelPoint {
  const ModelPoint(this.x, this.y, this.z);
  final double x, y, z;
}

class ModelPart {
  ModelPart(this.name, this.points, this.indices, this.pivot, this.hinged);
  final String name;
  final List<ModelPoint> points;
  final List<int> indices;
  final ModelPoint pivot;
  final bool hinged;
}

class GlbModel {
  GlbModel(this.parts) : outline = _outline(parts);
  final List<ModelPart> parts;
  final List<ModelPoint> outline;
  static List<ModelPoint> _outline(List<ModelPart> parts) {
    final points = parts.expand((p) => p.points);
    final low = points.map((p) => p.y).reduce(math.min),
        high = points.map((p) => p.y).reduce(math.max);
    final left = <ModelPoint>[], right = <ModelPoint>[];
    for (var row = 0; row <= 128; row++) {
      final y = low + (high - low) * (row + .001) / 128.002;
      double minX = double.infinity, maxX = double.negativeInfinity;
      for (final part in parts) {
        for (var i = 0; i < part.indices.length; i += 3) {
          for (var edge = 0; edge < 3; edge++) {
            final a = part.points[part.indices[i + edge]],
                b = part.points[part.indices[i + (edge + 1) % 3]];
            if ((a.y <= y && b.y >= y) || (b.y <= y && a.y >= y)) {
              if ((b.y - a.y).abs() < 1e-9) continue;
              final x = a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y);
              minX = math.min(minX, x);
              maxX = math.max(maxX, x);
            }
          }
        }
      }
      if (minX.isFinite) {
        left.add(ModelPoint(minX, y, 0));
        right.add(ModelPoint(maxX, y, 0));
      }
    }
    return [...left, ...right.reversed];
  }

  static GlbModel decode(ByteData source, double halfWidth,
      {bool flipDepth = false}) {
    if (source.lengthInBytes < 20 ||
        source.getUint32(0, Endian.little) != 0x46546c67 ||
        source.getUint32(4, Endian.little) != 2) {
      throw const FormatException('GLB 2.0 inválido');
    }
    Map<String, dynamic>? json;
    ByteData? binary;
    for (var offset = 12; offset + 8 <= source.lengthInBytes;) {
      final length = source.getUint32(offset, Endian.little),
          type = source.getUint32(offset + 4, Endian.little);
      if (offset + 8 + length > source.lengthInBytes)
        throw const FormatException('GLB truncado');
      final bytes =
          source.buffer.asUint8List(source.offsetInBytes + offset + 8, length);
      if (type == 0x4e4f534a)
        json = jsonDecode(utf8.decode(bytes).trim()) as Map<String, dynamic>;
      if (type == 0x004e4942) binary = ByteData.sublistView(bytes);
      offset += length + 8;
    }
    if (json == null || binary == null)
      throw const FormatException('GLB sem geometria');
    final doc = json, data = binary;
    List<List<double>> accessor(int index) {
      final a = doc['accessors'][index],
          view = doc['bufferViews'][a['bufferView']];
      final count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]!;
      final type = a['componentType'] as int,
          size = type == 5126 || type == 5125
              ? 4
              : type == 5123
                  ? 2
                  : 1;
      final offset = (view['byteOffset'] as int? ?? 0) +
              (a['byteOffset'] as int? ?? 0),
          stride = view['byteStride'] as int? ?? count * size;
      double read(int at) => switch (type) {
            5126 => data.getFloat32(at, Endian.little),
            5125 => data.getUint32(at, Endian.little).toDouble(),
            5123 => data.getUint16(at, Endian.little).toDouble(),
            5121 => data.getUint8(at).toDouble(),
            _ => throw const FormatException('Accessor não suportado')
          };
      return List.generate(
          a['count'] as int,
          (i) => List.generate(
              count, (c) => read(offset + i * stride + c * size)));
    }

    final animated = <int>{
      for (final a in doc['animations'] ?? [])
        for (final c in a['channels'])
          if (c['target']['path'] == 'rotation') c['target']['node'] as int
    };
    final raw = <ModelPart>[];
    final nodes = doc['nodes'] as List;
    // These supplied Blender exports use independent root objects with TRS.
    for (var ni = 0; ni < nodes.length; ni++) {
      final n = nodes[ni];
      if (n['mesh'] == null) continue;
      final t = (n['translation'] as List? ?? [0, 0, 0]).cast<num>(),
          s = (n['scale'] as List? ?? [1, 1, 1]).cast<num>(),
          q = (n['rotation'] as List? ?? [0, 0, 0, 1]).cast<num>();
      ModelPoint transform(List<double> p) {
        final x = p[0] * s[0], y = p[1] * s[1], z = p[2] * s[2];
        final tx = 2 * (q[1] * z - q[2] * y),
            ty = 2 * (q[2] * x - q[0] * z),
            tz = 2 * (q[0] * y - q[1] * x);
        return ModelPoint(
            x + q[3] * tx + q[1] * tz - q[2] * ty + t[0],
            y + q[3] * ty + q[2] * tx - q[0] * tz + t[1],
            z + q[3] * tz + q[0] * ty - q[1] * tx + t[2]);
      }

      for (final primitive in doc['meshes'][n['mesh']]['primitives']) {
        if ((primitive['mode'] ?? 4) != 4)
          throw const FormatException('Esperadas faces triangulares');
        final points = accessor(primitive['attributes']['POSITION'] as int)
            .map(transform)
            .toList();
        final indices = primitive['indices'] == null
            ? List.generate(points.length, (i) => i)
            : accessor(primitive['indices'] as int)
                .map((v) => v.first.toInt())
                .toList();
        raw.add(ModelPart(
            n['name'] ?? 'Peça',
            points,
            indices,
            ModelPoint(t[0].toDouble(), t[1].toDouble(), t[2].toDouble()),
            animated.contains(ni)));
      }
    }
    if (raw.isEmpty) throw const FormatException('GLB vazio');
    final all = raw.expand((p) => p.points),
        xs = all.map((p) => p.x),
        ys = all.map((p) => p.y),
        zs = all.map((p) => p.z);
    final minX = xs.reduce(math.min),
        maxX = xs.reduce(math.max),
        minY = ys.reduce(math.min),
        maxY = ys.reduce(math.max),
        minZ = zs.reduce(math.min),
        maxZ = zs.reduce(math.max);
    final scale = halfWidth * 2 / (maxX - minX),
        cx = (minX + maxX) / 2,
        cy = (minY + maxY) / 2,
        cz = (minZ + maxZ) / 2;
    ModelPoint normalize(ModelPoint p) => ModelPoint((p.x - cx) * scale,
        -(p.y - cy) * scale, (p.z - cz) * scale * (flipDepth ? -1 : 1));
    return GlbModel([
      for (final p in raw)
        ModelPart(
            p.name,
            p.points.map(normalize).toList(),
            flipDepth
                ? [
                    for (var i = 0; i < p.indices.length; i += 3) ...[
                      p.indices[i],
                      p.indices[i + 2],
                      p.indices[i + 1]
                    ]
                  ]
                : p.indices,
            normalize(p.pivot),
            p.hinged)
    ]);
  }
}

class WalkmenModels {
  WalkmenModels(this.tape);
  final GlbModel tape;
  static WalkmenModels? current;
  static Future<WalkmenModels>? _pending;
  static Future<WalkmenModels> load() => _pending ??= _load();
  static Future<WalkmenModels> _load() async {
    final tape = await rootBundle.load('modelos/TEXTE FIT-app.glb');
    return current = WalkmenModels(GlbModel.decode(tape, 1.25));
  }
}
