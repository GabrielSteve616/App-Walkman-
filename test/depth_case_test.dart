import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/widgets/tape_3d.dart';

void main() {
  testWidgets('Case fechada esconde a fita durante uma volta completa',
      (tester) async {
    Future<ui.Image> solid(Color color) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(color, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(8, 8);
      picture.dispose();
      return image;
    }

    final images = await tester.runAsync(
        () async => [await solid(Colors.red), await solid(Colors.green)]);
    final red = images![0], green = images[1], key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                        width: 360,
                        height: 360,
                        child: Tape3D(
                            front: red,
                            tapeBack: red,
                            cover: green,
                            caseBack: green,
                            interior: green,
                            tapeEdges: List.filled(4, red),
                            caseEdges: List.filled(4, green),
                            color: Colors.red,
                            shellColor: Colors.green,
                            caseView: true)))))));
    for (var turn = 0; turn < 8; turn++) {
      for (var frame = 0; frame < 6; frame++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        var reds = 0, greens = 0;
        for (var i = 0; i < rgba!.lengthInBytes; i += 4) {
          if (rgba.getUint8(i) > 170 &&
              rgba.getUint8(i + 1) < 80 &&
              rgba.getUint8(i + 3) > 200) reds++;
          if (rgba.getUint8(i + 1) > 80 && rgba.getUint8(i) < 130) greens++;
        }
        expect(greens, greaterThan(500),
            reason: 'Ângulo $turn deve ter modelo pronto');
        expect(reds, lessThan(10),
            reason: 'Fita não deve atravessar a case fechada no ângulo $turn');
        image.dispose();
      });
      final paint = find
          .descendant(
              of: find.byType(Tape3D), matching: find.byType(CustomPaint))
          .first;
      await tester.drag(paint, const Offset(60, 0));
      await tester.pump();
    }
    await tester.pumpWidget(const SizedBox());
    red.dispose();
    green.dispose();
  });
}
