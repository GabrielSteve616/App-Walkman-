import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/widgets/depth_renderer.dart';
import 'package:walkman/widgets/depth_worker.dart';

void main() {
  test(
      'Renderizador em segundo plano preserva profundidade, texturas e atualizações',
      () async {
    final worker = DepthWorker();
    try {
      for (var n = 0; n < 30; n++) {
        final texture =
            DepthTexture(1, 1, Uint8List.fromList([n * 7, 100, 200, 255]));
        final first = DepthTriangle(
            const DepthVertex(0, 0, .2, 0, 0),
            const DepthVertex(20, 0, .2, 1, 0),
            const DepthVertex(0, 20, .2, 0, 1),
            0,
            texture);
        final second = DepthTriangle(
            const DepthVertex(0, 0, .1, 0, 0),
            const DepthVertex(20, 0, .3, 1, 0),
            const DepthVertex(0, 20, .1, 0, 1),
            0xFFFF0000);
        final triangles = [first, second];
        expect(await worker.render(20, 20, triangles),
            orderedEquals(renderDepth(20, 20, triangles)),
            reason: 'alteração de textura $n');
        if (n == 0)
          expect(await worker.render(20, 20, triangles),
              orderedEquals(renderDepth(20, 20, triangles)),
              reason: 'reuso da textura em cache');
      }
      final glass = DepthTriangle(
          const DepthVertex(0, 0, .2, 0, 0),
          const DepthVertex(20, 0, .2, 1, 0),
          const DepthVertex(0, 20, .2, 0, 1),
          0x80804020);
      final pixels = await worker.render(20, 20, [glass]);
      expect(pixels.sublist((3 * 20 + 3) * 4, (3 * 20 + 3) * 4 + 4),
          [64, 32, 16, 128]);
    } finally {
      worker.dispose();
    }
    await expectLater(worker.render(20, 20, []), throwsStateError);
  });
  test('Fechar o visualizador cancela o quadro pendente com segurança',
      () async {
    final worker = DepthWorker();
    final pending = worker.render(20, 20, []);
    worker.dispose();
    await expectLater(pending, throwsStateError);
  });
}
