import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/models/local_track.dart';
import 'package:walkman/models/tape.dart';
import 'package:walkman/services/app_state.dart';
import 'package:walkman/services/collection_store.dart';
import 'package:walkman/services/music_library.dart';
import 'package:walkman/services/playback.dart';
import 'package:walkman/screens/player_screen.dart';
import 'package:walkman/screens/sticker_crop_screen.dart';
import 'package:walkman/widgets/tape_artwork.dart';
import 'package:walkman/widgets/tape_3d.dart';

LocalTrack song(int i) => LocalTrack(
    id: '$i',
    title: 'Faixa $i',
    artist: 'Artista',
    album: 'Álbum',
    folder: 'Music',
    uri: Uri.parse('content://audio/$i'),
    duration: const Duration(minutes: 3));

class _Playback extends Playback {
  int calls = 0;
  @override
  Future<void> playTracks(List<LocalTrack> tracks,
      {int start = 0, String? name}) async {
    calls++;
    queue = tracks;
    index = start;
    tapeName = name;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          AndroidMusicLibrary.channel, (_) async => null));
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(AndroidMusicLibrary.channel, null));
  test(
      'Verso mantém coordenadas dos adesivos e compatibilidade com fitas antigas',
      () {
    final placement = StickerPlacement(
        assetId: 'a', back: true, onCase: true, x: .31, y: .66);
    final copy = StickerPlacement.fromJson(placement.toJson());
    expect(copy.back, isTrue);
    expect(copy.x, .31);
    final old = placement.toJson()..remove('back');
    expect(StickerPlacement.fromJson(old).back, isFalse);
  });
  testWidgets('Verso da caixa limita a dez faixas e toca a faixa selecionada',
      (tester) async {
    final tape = Tape(
        id: 't', name: 'Rock', tracks: [for (var i = 0; i < 14; i++) song(i)]);
    int? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 300,
                    child: TapeArtwork(
                        tape: tape,
                        assets: const [],
                        caseView: true,
                        backView: true,
                        onTrackTap: (i) => selected = i))))));
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byType(TapeArtwork));
    final target = caseTrackRect(4).center;
    await tester.tapAt(
        box.topLeft + Offset(target.dx * box.width, target.dy * box.height));
    await tester.pump();
    expect(selected, 4);
    expect(caseTrackAt(caseTrackRect(10).center, 14), isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Alternar player vertical preserva a fila e não reinicia o áudio',
      (tester) async {
    final playback = _Playback();
    final state =
        AppState(store: CollectionStore(memory: true), playback: playback);
    await state.load();
    await playback.playTracks([song(1), song(2)]);
    await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: PlayerScreen(app: state)));
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingTape), findsOneWidget);
    await tester.tap(find.byTooltip('Visualização do player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player vertical • em pé'));
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingTape), findsNothing);
    expect(find.text('Reproduzindo'), findsOneWidget);
    expect(playback.calls, 1);
    expect(playback.queue.length, 2);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('Posicionamento 3D encontra frente e verso sem mudar a rotação',
      (tester) async {
    final tape = Tape(id: 't', name: 'ROCK / LIVE', tracks: [song(1)]);
    final images = await tester.runAsync(() async => [
          await renderTapeTexture(tape, []),
          await renderTapeTexture(tape, [], caseView: true),
          await renderTapeTexture(tape, [], caseView: true, backView: true)
        ]);
    SurfaceHit? hit;
    Widget model(bool back) => MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 360,
                    height: 420,
                    child: Tape3D(
                        key: ValueKey(back),
                        front: images![0],
                        cover: images[1],
                        caseBack: images[2],
                        color: Colors.blue,
                        caseView: true,
                        backView: back,
                        placingSticker: true,
                        onPlace: (h) => hit = h)))));
    await tester.pumpWidget(model(false));
    await tester.pumpAndSettle();
    Finder paint() => find
        .descendant(of: find.byType(Tape3D), matching: find.byType(CustomPaint))
        .first;
    await tester.tapAt(tester.getCenter(paint()));
    await tester.pump();
    expect(hit, isNotNull);
    expect(hit!.back, isFalse);
    expect(hit!.uv.dx, inInclusiveRange(.3, .7));
    await tester.pumpWidget(model(true));
    await tester.pumpAndSettle();
    hit = null;
    await tester.tapAt(tester.getCenter(paint()));
    await tester.pump();
    expect(hit, isNotNull);
    expect(hit!.back, isTrue);
    await tester.pumpWidget(const SizedBox());
    for (final image in images!) {
      image.dispose();
    }
  });
  testWidgets('Prévias de capa rock e verso são renderizadas sem distorção',
      (tester) async {
    final tape = Tape(
        id: 'preview',
        name: 'MIDNIGHT\nHIGHWAY',
        description: 'LIVE SESSIONS / VOL. 01',
        tracks: [for (var i = 1; i <= 12; i++) song(i)],
        color: 0xFFAA3D31);
    final key = GlobalKey();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final back in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
              body: Center(
                  child: RepaintBoundary(
                      key: key,
                      child: SizedBox(
                          width: 260,
                          child: TapeArtwork(
                              tape: tape,
                              assets: const [],
                              caseView: true,
                              backView: back)))))));
      await tester.pumpAndSettle();
      await capture(back ? 'case-verso-v04' : 'case-rock-v04');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Contorno com o dedo exporta recorte PNG transparente',
      (tester) async {
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = Colors.red);
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      return data!.buffer.asUint8List();
    });
    dynamic result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  StickerCropScreen(bytes: bytes!)));
                    },
                    child: const Text('Abrir recorte'))))));
    await tester.tap(find.text('Abrir recorte'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.text('Com o dedo'), findsOneWidget);
    await tester.tap(find.text('Retângulo'));
    await tester.pumpAndSettle();
    expect(find.text('Retângulo'), findsOneWidget);
    expect(find.text('Largura'), findsNothing);
    expect(find.text('Altura'), findsNothing);
    await tester.tap(find.text('Com o dedo'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(AspectRatio).last);
    Offset point(double x, double y) =>
        rect.topLeft + Offset(rect.width * x, rect.height * y);
    final gesture = await tester.startGesture(point(.15, .15));
    await gesture.moveTo(point(.8, .15));
    await gesture.up();
    await tester.pump();
    final second = await tester.startGesture(point(.8, .15));
    await second.moveTo(point(.5, .8));
    await second.moveTo(point(.15, .15));
    await second.up();
    await tester.pump();
    await tester.tap(find.text('Retângulo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Círculo'));
    await tester.pump();
    await tester.tap(find.text('Com o dedo'));
    await tester.pump();
    // Switching modes preserves the finger contour instead of discarding it.
    await tester.tap(find.text('Usar recorte'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    final alpha = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(result);
      final image = (await codec.getNextFrame()).image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final values = <int>{
        for (var i = 3; i < rgba!.lengthInBytes; i += 4) rgba.getUint8(i)
      };
      image.dispose();
      codec.dispose();
      return values;
    });
    expect(alpha, contains(0));
    expect(alpha, contains(255));
    expect(tester.takeException(), isNull);
  });
}
