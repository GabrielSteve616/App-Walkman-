import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:walkman/models/local_track.dart';
import 'package:walkman/models/tape.dart';
import 'package:walkman/services/app_state.dart';
import 'package:walkman/services/collection_store.dart';
import 'package:walkman/widgets/tape_artwork.dart';
import 'package:walkman/widgets/tape_3d.dart';
import 'package:walkman/screens/sticker_crop_screen.dart';
import 'package:walkman/screens/tape_editor_screen.dart';

LocalTrack track(String id) => LocalTrack(
    id: id,
    title: 'Música $id',
    artist: 'Artista',
    album: 'Álbum',
    folder: 'Music/Minha pasta',
    uri: Uri.parse('content://music/$id'),
    duration: const Duration(minutes: 3));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Fitas, referências, figurinhas e favoritas sobrevivem à reabertura',
      () async {
    final directory = await Directory.systemTemp.createTemp('walkmen-test-');
    final app = AppState(store: CollectionStore(directory: directory));
    await app.load();
    final tape = app.newTape('Estradas', [track('1'), track('2')]);
    tape.stickers.add(
        StickerPlacement(assetId: 'sticker', onCase: true, x: .2, angle: .4));
    await app.saveTape(tape);
    await Future.wait(
        [app.toggleFavorite(track('1')), app.toggleFavorite(track('2'))]);
    final reopened = AppState(store: CollectionStore(directory: directory));
    await reopened.load();
    expect(reopened.tapes.single.name, 'Estradas');
    expect(
        reopened.tapes.single.tracks.first.uri.toString(), 'content://music/1');
    expect(reopened.tapes.single.stickers.single.onCase, isTrue);
    expect(reopened.favorites.length, 2);
    expect(reopened.favoriteTracks.values.map((t) => t.title),
        contains('Música 1'));
    await reopened.deleteTape(tape.id);
    expect(reopened.tapes, isEmpty);
    expect(reopened.favorites.length, 2);
    app.dispose();
    reopened.dispose();
    await directory.delete(recursive: true);
  });
  test('Backup recupera a coleção após JSON incompleto', () async {
    final directory = await Directory.systemTemp.createTemp('walkmen-backup-');
    final store = CollectionStore(directory: directory);
    await store.write({
      'tapes': ['primeiro']
    });
    await store.write({
      'tapes': ['segundo']
    });
    final db = await openDatabase('${directory.path}/walkmen.sqlite',
        singleInstance: false);
    await db.update('collection', {'document': '{'},
        where: 'id = ?', whereArgs: [1]);
    await db.close();
    expect((await store.read())['tapes'], ['primeiro']);
    await directory.delete(recursive: true);
  });
  test('Recortes têm máscara e contorno livre real', () {
    const rect = Rect.fromLTWH(0, 0, 100, 100);
    expect(
        stickerPath('Círculo', rect, []).contains(const Offset(0, 0)), isFalse);
    expect(stickerPath('Círculo', rect, []).contains(rect.center), isTrue);
    final free = stickerPath('Livre', rect,
        [Offset.zero, const Offset(100, 0), const Offset(0, 100)]);
    expect(free.contains(const Offset(10, 10)), isTrue);
    expect(free.contains(const Offset(90, 90)), isFalse);
    for (final shape in ['Estrela', 'Coração', 'Triângulo']) {
      expect(stickerPath(shape, rect, []).getBounds().isEmpty, isFalse);
    }
  });
  testWidgets('Editor não altera a fita original ao editar o rascunho',
      (tester) async {
    final app = AppState(store: CollectionStore(memory: true));
    await app.load();
    final tape = app.newTape('Original', [track('1')]);
    await tester
        .pumpWidget(MaterialApp(home: TapeEditorScreen(app: app, tape: tape)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Outro nome');
    await tester.pumpAndSettle();
    expect(tape.name, 'Original');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets('Malha 3D gira, amplia e abre a caixa sem erro de desenho',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final tape =
        Tape(id: 'test', name: 'ESTRADAS • VOL. 1', tracks: [track('1')]);
    final images = await tester.runAsync(() async => [
          await renderTapeTexture(tape, []),
          await renderTapeTexture(tape, [], caseView: true),
          await renderTapeTexture(tape, [], caseView: true, backView: true),
          await renderCaseInterior(tape, []),
        ]);
    final key = GlobalKey();
    Future<void> capture(String name) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump();
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: Center(
                child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                        width: 360,
                        height: 320,
                        child: Tape3D(
                            front: images![0],
                            cover: images[1],
                            color: Colors.blue)))))));
    await tester.pumpAndSettle();
    await capture('fita-3d');
    await tester.drag(find.byType(Tape3D), const Offset(100, 30));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: Center(
                child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                        width: 360,
                        height: 360,
                        child: Tape3D(
                            front: images[0],
                            cover: images[1],
                            color: Colors.blue,
                            caseView: true,
                            caseBack: images[2],
                            interior: images[3])))))));
    await tester.pumpAndSettle();
    await capture('case-glb-fechada');
    await tester.tap(find.text('Abrir'));
    final paint = find
        .descendant(of: find.byType(Tape3D), matching: find.byType(CustomPaint))
        .first;
    await tester.drag(paint, const Offset(0, -80));
    await tester.pumpAndSettle();
    final opened =
        tester.getSemantics(find.bySemanticsLabel('Case em 3D')).value;
    expect(opened, isNot('0%'));
    expect(find.byType(Slider), findsNothing);
    await capture('caixa-3d-aberta');
    await tester.drag(paint, const Offset(0, 55));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.bySemanticsLabel('Case em 3D')).value,
        isNot(opened));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    for (final image in images) {
      image.dispose();
    }
    semantics.dispose();
  });
}
