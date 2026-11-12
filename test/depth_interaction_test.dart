import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/widgets/tape_3d.dart';

void main() {
  for (final isCase in [true, false]) {
    testWidgets(
        isCase
            ? 'Case atualiza enquanto o dedo continua girando'
            : 'Fita atualiza enquanto o dedo continua girando', (tester) async {
      final image = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.green, BlendMode.src);
        final picture = recorder.endRecording(),
            bitmap = await picture.toImage(8, 8);
        picture.dispose();
        return bitmap;
      });
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: RepaintBoundary(
                      key: key,
                      child: SizedBox(
                          width: 360,
                          height: 360,
                          child: Tape3D(
                              front: image!,
                              cover: image,
                              color: Colors.green,
                              shellColor: Colors.green,
                              caseView: isCase)))))));
      Future<void> frame() async {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }

      Future<List<int>> snapshot() async => (await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final bitmap = await boundary.toImage();
            final bytes =
                await bitmap.toByteData(format: ui.ImageByteFormat.rawRgba);
            bitmap.dispose();
            return bytes!.buffer.asUint8List().toList();
          }))!;
      for (var i = 0; i < 8; i++) {
        await frame();
      }
      final before = await snapshot();
      final paint = find
          .descendant(
              of: find.byType(Tape3D), matching: find.byType(CustomPaint))
          .first;
      final gesture = await tester.startGesture(tester.getCenter(paint));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(8, 0));
        await tester.pump();
        await frame();
      }
      final during = await snapshot();
      var different = 0;
      for (var i = 0; i < before.length; i += 4) {
        if ((before[i + 1] - during[i + 1]).abs() > 30) different++;
      }
      expect(different, greaterThan(200),
          reason: 'o desenho deve avançar durante o gesto');
      await gesture.up();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      image.dispose();
    });
  }
}
