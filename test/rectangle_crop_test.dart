import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/screens/sticker_crop_screen.dart';

void main() {
  testWidgets('Recorte clássico redimensiona pelos cantos e move a seleção',
      (tester) async {
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
      canvas.drawRect(
          const Rect.fromLTWH(30, 25, 60, 60), Paint()..color = Colors.green);
      final picture = recorder.endRecording(),
          image = await picture.toImage(100, 100);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      return data!.buffer.asUint8List();
    });
    Uint8List? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    child: const Text('Abrir'),
                    onPressed: () async {
                      result = await Navigator.push<Uint8List>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  StickerCropScreen(bytes: bytes!)));
                    })))));
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retângulo'));
    await tester.pumpAndSettle();
    final imageRect = tester.getRect(find.byType(AspectRatio));
    Offset p(double x, double y) =>
        imageRect.topLeft + Offset(imageRect.width * x, imageRect.height * y);
    Future<void> drag(Offset from, Offset to) async {
      final gesture = await tester.startGesture(from);
      await gesture.moveTo(to);
      await gesture.up();
      await tester.pump();
    }

    await drag(p(.1, .1), p(.25, .2));
    await drag(p(.9, .9), p(.85, .8));
    await drag(p(.55, .5), p(.60, .55));
    await tester.tap(find.text('Usar recorte'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(result!);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, inInclusiveRange(59, 61));
      expect(image.height, inInclusiveRange(59, 61));
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      // An interior pixel comes from the selected green square after moving.
      final i = (5 * image.width + 5) * 4;
      expect(rgba!.getUint8(i), lessThan(100));
      expect(rgba.getUint8(i + 1), greaterThan(100));
      image.dispose();
      codec.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
