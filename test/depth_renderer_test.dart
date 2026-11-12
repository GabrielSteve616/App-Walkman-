import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/widgets/depth_renderer.dart';

DepthTriangle triangle(int color, double left, double right) => DepthTriangle(
    DepthVertex(0, 0, left, 0, 0),
    DepthVertex(40, 0, right, 1, 0),
    DepthVertex(0, 40, left, 0, 1),
    color);
void main() {
  test('Faces cruzadas se ocultam por pixel sem depender da ordem média', () {
    final red = triangle(0xFFFF0000, .3, .1),
        blue = triangle(0xFF0000FF, .2, .2);
    for (final faces in [
      [red, blue],
      [blue, red]
    ]) {
      final rgba = renderDepth(40, 40, faces);
      int channel(int x, int y, int c) => rgba[(y * 40 + x) * 4 + c];
      expect(channel(3, 3, 0), 255);
      expect(channel(3, 3, 2), 0);
      expect(channel(32, 3, 0), 0);
      expect(channel(32, 3, 2), 255);
    }
  });
  test('Capa opaca esconde a fita e pixels vazios preservam o fundo', () {
    final cover =
        DepthTexture(2, 1, Uint8List.fromList([0, 255, 0, 255, 0, 0, 0, 0]));
    final tape = triangle(0xFFFF0000, .1, .1);
    final lid = DepthTriangle(
        const DepthVertex(0, 0, .2, 0, 0),
        const DepthVertex(40, 0, .2, 1, 0),
        const DepthVertex(0, 40, .2, 0, 1),
        0,
        cover);
    final rgba = renderDepth(40, 40, [lid, tape]);
    expect(rgba[(3 * 40 + 3) * 4 + 1], 255);
    expect(rgba[(3 * 40 + 30) * 4], 255);
  });
  test('Margem transparente da textura preserva a carcaça sólida', () {
    final empty = DepthTexture(1, 1, Uint8List(4));
    final face = DepthTriangle(
        const DepthVertex(0, 0, .2, 0, 0),
        const DepthVertex(40, 0, .2, 1, 0),
        const DepthVertex(0, 40, .2, 0, 1),
        0xFF00FF00,
        empty);
    final rgba = renderDepth(40, 40, [face, triangle(0xFFFF0000, .1, .1)]);
    expect(rgba[(3 * 40 + 3) * 4], 0);
    expect(rgba[(3 * 40 + 3) * 4 + 1], 255);
    expect(rgba[(3 * 40 + 3) * 4 + 3], 255);
  });
  test('UV usa distância da câmera para não deslizar durante a rotação', () {
    final texture = DepthTexture(
        4,
        1,
        Uint8List.fromList([
          255,
          0,
          0,
          255,
          0,
          255,
          0,
          255,
          0,
          0,
          255,
          255,
          255,
          255,
          255,
          255
        ]));
    final face = DepthTriangle(
        const DepthVertex(0, 0, .1, 0, 0),
        const DepthVertex(40, 0, .4, 1, 0),
        const DepthVertex(0, 40, .1, 0, 1),
        0,
        texture);
    final rgba = renderDepth(40, 40, [face]);
    // At x=12, perspective-correct u is about .65, rather than affine .31.
    expect(rgba[(3 * 40 + 12) * 4 + 2], 255);
    expect(rgba[(3 * 40 + 12) * 4 + 1], 0);
  });
}
