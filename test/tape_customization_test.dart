import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/models/tape.dart';
import 'package:walkman/services/app_state.dart';
import 'package:walkman/services/collection_store.dart';
import 'package:walkman/screens/tape_editor_screen.dart';
import 'package:walkman/widgets/tape_artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Cores e fotos sobrevivem à reabertura sem quebrar fitas antigas',
      () async {
    final old = Tape.fromJson(
        {'id': 'old', 'name': 'Antiga', 'tracks': [], 'color': 0xFF1768AD});
    expect(old.labelColor, 0xFFEDE3CE);
    expect(old.labelBackPath, isNull);
    expect(old.caseTextColor, isNull);
    final store = CollectionStore(memory: true);
    final saved = AppState(store: store);
    await saved.load();
    final tape = Tape(
        id: 't',
        name: 'Nova',
        tracks: [],
        shellColor: 0xFF882299,
        labelColor: 0xFF224466,
        textColor: 0xFFFEDCBA,
        caseTextColor: 0xFFABCDEF,
        labelFrontPath: 'front.png',
        labelBackPath: 'back.png');
    await saved.saveTape(tape);
    final reopened = AppState(store: store);
    await reopened.load();
    expect(reopened.tapes.single.toJson(), tape.toJson());
    saved.dispose();
    reopened.dispose();
  });
  testWidgets('Foto fica no rótulo da face correta e preserva a janela',
      (tester) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('walkmen-label-');
      try {
        Future<String> photo(String name, Color color) async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(color, BlendMode.src);
          final picture = recorder.endRecording(),
              image = await picture.toImage(64, 64);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('${dir.path}/$name.png');
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
          image.dispose();
          return file.path;
        }

        final tape = Tape(
            id: 't',
            name: '',
            tracks: [],
            labelFrontPath: await photo('front', const Color(0xFF00FF00)),
            labelBackPath: await photo('back', const Color(0xFFFF0000)));
        for (final back in [false, true]) {
          final image = await renderTapeTexture(tape, [], backView: back);
          final rgba =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          int channel(double x, double y, int c) =>
              rgba!.getUint8(((image.height * y).floor() * image.width +
                          (image.width * x).floor()) *
                      4 +
                  c);
          expect(channel(.24, .21, back ? 0 : 1), greaterThan(240));
          expect(channel(.24, .21, back ? 1 : 0), lessThan(15));
          // Center window is drawn over the label photo.
          expect(channel(.5, .52, back ? 0 : 1), lessThan(150));
          image.dispose();
        }
        tape.labelFrontPath = null;
        tape.labelColor = 0xFF1122EE;
        final image = await renderTapeTexture(tape, []);
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final offset = ((image.height * .21).floor() * image.width +
                (image.width * .24).floor()) *
            4;
        expect(rgba!.getUint8(offset + 2), greaterThan(220));
        image.dispose();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
  testWidgets('Editor aplica cor personalizada às letras e salva',
      (tester) async {
    final app = AppState(store: CollectionStore(memory: true));
    await app.load();
    final tape = Tape(id: 't', name: 'Minha fita', tracks: []);
    await app.saveTape(tape);
    await tester
        .pumpWidget(MaterialApp(home: TapeEditorScreen(app: app, tape: tape)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cor das letras da fita'), 200,
        scrollable: find.byType(Scrollable).first);
    final palette = find.bySemanticsLabel('Cor das letras da fita: Azul');
    await tester.ensureVisible(palette);
    await tester.pumpAndSettle();
    await tester.tap(palette);
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(app.tapes.single.textColor, 0xFF1768AD);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
