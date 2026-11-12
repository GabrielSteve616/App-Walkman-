import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/widgets/glb_model.dart';

void main() {
  testWidgets('Assets GLB empacotados carregam', (tester) async {
    await tester.runAsync(() async {
      final models = await WalkmenModels.load();
      expect(models.tape.parts, hasLength(2));
    });
  });
  test('GLB da fita tem malhas válidas sem depender de case externa', () async {
    for (final name in ['TEXTE FIT-app.glb']) {
      final b = await File('modelos/$name').readAsBytes();
      final m = GlbModel.decode(ByteData.sublistView(b), 1.25);
      expect(m.parts, hasLength(2));
      expect(
          m.parts
              .every((p) => p.points.isNotEmpty && p.indices.length % 3 == 0),
          isTrue);
    }
  });
}
