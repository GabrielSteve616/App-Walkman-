import 'dart:typed_data';
import '../lib/widgets/depth_renderer.dart';

void main() {
  final pixels = Uint8List(256 * 256 * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = 110;
    pixels[i + 1] = 150;
    pixels[i + 2] = 220;
    pixels[i + 3] = 255;
  }
  final texture = DepthTexture(256, 256, pixels), triangles = <DepthTriangle>[];
  for (var layer = 0; layer < 8; layer++) {
    final z = .1 + layer * .01;
    final a = DepthVertex(0, 0, z, 0, 0),
        b = DepthVertex(512, 0, z, 1, 0),
        c = DepthVertex(512, 512, z, 1, 1),
        d = DepthVertex(0, 512, z, 0, 1);
    triangles.addAll([
      DepthTriangle(a, b, c, 0xFFFFFFFF, texture),
      DepthTriangle(a, c, d, 0xFFFFFFFF, texture)
    ]);
  }
  for (var i = 0; i < 3; i++) {
    renderDepth(512, 512, triangles);
  }
  final watch = Stopwatch()..start();
  for (var i = 0; i < 8; i++) {
    renderDepth(512, 512, triangles);
  }
  watch.stop();
  print('8 camadas opacas, 512x512: ' +
      (watch.elapsedMicroseconds / 8000).toStringAsFixed(2) +
      ' ms/quadro (Dart local)');
}
