import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/models/tape.dart';
import 'package:walkman/widgets/tape_artwork.dart';

void main() {
  testWidgets('Adesivo continua na borda e no verso da fita e da case',
      (tester) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('walkmen-wrap-');
      try {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xFFFF0000), BlendMode.src);
        final picture = recorder.endRecording();
        final red = await picture.toImage(32, 32);
        final png = await red.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${dir.path}/red.png');
        await file.writeAsBytes(png!.buffer.asUint8List());
        picture.dispose();
        red.dispose();
        final asset = StickerAsset(id: 'red', name: 'red', path: file.path);
        Future<void> isRed(ui.Image image, double x, double y) async {
          final data =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          final index = ((image.height * y).floor() * image.width +
                  (image.width * x).floor()) *
              4;
          expect(data!.getUint8(index), greaterThan(240));
          expect(data.getUint8(index + 1), lessThan(15));
          image.dispose();
        }

        for (final caseView in [false, true]) {
          for (final back in [false, true]) {
            final tape = Tape(id: 't', name: 'Wrap', tracks: [], stickers: [
              StickerPlacement(
                  assetId: 'red',
                  x: .98,
                  y: .5,
                  width: .5,
                  onCase: caseView,
                  back: back)
            ]);
            await isRed(
                await renderTapeTexture(tape, [asset],
                    caseView: caseView, backView: back),
                .93,
                .5);
            // A front right edge is the back left edge.
            await isRed(
                await renderTapeEdge(tape, [asset], back ? 3 : 1,
                    caseView: caseView),
                .5,
                .5);
            await isRed(
                await renderTapeTexture(tape, [asset],
                    caseView: caseView, backView: !back),
                .07,
                .5);
          }
        }
        final clipped = Tape(id: 'clip', name: '', tracks: [], stickers: [
          StickerPlacement(assetId: 'red', x: 0, y: 0, width: .5)
        ]);
        final clippedImage = await renderTapeTexture(clipped, [asset]);
        final rgba =
            await clippedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
        int redAt(double x, double y) => rgba!.getUint8(
            ((clippedImage.height * y).floor() * clippedImage.width +
                    (clippedImage.width * x).floor()) *
                4);
        expect(redAt(.005, .005), lessThan(20));
        expect(redAt(.1, .1), greaterThan(240));
        clippedImage.dispose();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
