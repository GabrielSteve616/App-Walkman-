import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/animations/tape_unbox_screen.dart';
import 'package:walkman/models/local_track.dart';
import 'package:walkman/services/app_state.dart';
import 'package:walkman/services/collection_store.dart';
import 'package:walkman/services/companion_bridge.dart';
import 'package:walkman/services/music_library.dart';
import 'package:walkman/services/playback.dart';
import 'package:walkman/screens/tapes_screen.dart';
import 'package:walkman/screens/home_screen.dart';
import 'package:walkman/widgets/tape_catalog.dart';
import 'package:walkman/widgets/track_artwork.dart';

class _Player extends Playback {
  @override
  Future<void> playTracks(List<LocalTrack> tracks,
      {int start = 0, String? name}) async {
    queue = tracks;
    index = start;
    tapeName = name;
    notifyListeners();
  }
}

LocalTrack _track(int i) => LocalTrack(
    id: '$i',
    title: 'Música $i',
    artist: 'Artista',
    album: 'Álbum',
    folder: 'Music',
    uri: Uri.parse('content://audio/$i'),
    duration: const Duration(minutes: 3));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => messenger.setMockMethodCallHandler(AndroidMusicLibrary.channel,
      (call) async => call.method == 'artwork' ? null : []));
  tearDown(() {
    messenger.setMockMethodCallHandler(CompanionBridge.channel, null);
    messenger.setMockMethodCallHandler(AndroidMusicLibrary.channel, null);
  });
  test('Widget restaura a fila e o índice sem perder referências de arquivos',
      () async {
    final app =
        AppState(store: CollectionStore(memory: true), playback: _Player());
    await app.load();
    messenger.setMockMethodCallHandler(CompanionBridge.channel, (call) async {
      if (call.method == 'restorePlayback')
        return {
          'queue': jsonEncode([_track(1).toJson(), _track(2).toJson()]),
          'index': 1,
          'name': 'Rock'
        };
      return null;
    });
    final bridge = CompanionBridge(app, onAction: (a, b) async {});
    expect(await bridge.restoreAndPlay(), isTrue);
    expect(app.playback.current!.title, 'Música 2');
    expect(app.playback.tapeName, 'Rock');
    app.dispose();
  });
  test('Ação inicial de um widget é entregue depois de carregar a coleção',
      () async {
    final app = AppState(store: CollectionStore(memory: true));
    await app.load();
    String? action, id;
    messenger.setMockMethodCallHandler(
        CompanionBridge.channel,
        (call) async =>
            call.method == 'ready' ? {'action': 'tape', 'id': '42'} : null);
    final bridge = CompanionBridge(app, onAction: (a, b) async {
      action = a;
      id = b;
    });
    await bridge.attach();
    expect(action, 'tape');
    expect(id, '42');
    bridge.close();
    app.dispose();
  });
  testWidgets('Prateleira abre a caixa, anima e mostra o encarte tocável',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preview = GlobalKey();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            preview.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final app =
        AppState(store: CollectionStore(memory: true), playback: _Player());
    await app.load();
    final tape = app.newTape('Rock de estrada', [_track(1), _track(2)]);
    await app.saveTape(tape);
    await app.saveTape(app.newTape('Lado B', [_track(3)]));
    await tester.pumpWidget(RepaintBoundary(
        key: preview,
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: TapesScreen(app: app)))));
    await tester.pumpAndSettle();
    final first = tester.getRect(find
            .ancestor(
                of: find.text('Rock de estrada'),
                matching: find.byType(InkWell))
            .first),
        second = tester.getRect(find
            .ancestor(of: find.text('Lado B'), matching: find.byType(InkWell))
            .first);
    expect((first.top - second.top).abs(), lessThan(4));
    await capture('prateleira-v05');
    await tester.tap(find.text('Rock de estrada'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TapeUnboxScreen), findsOneWidget);
    expect(find.text('Abrindo a caixa e retirando sua fita…'), findsOneWidget);
    await capture('abertura-061-inicio');
    await tester.pump(const Duration(milliseconds: 900));
    await capture('abertura-061-tampa-aberta');
    await tester.pump(const Duration(milliseconds: 650));
    await capture('abertura-061-retirada');
    await tester.pumpAndSettle();
    expect(find.byType(TapeCatalog), findsOneWidget);
    expect(find.text('ENCARTE / CATÁLOGO'), findsOneWidget);
    final photos = tester
        .widgetList<TrackArtwork>(find.descendant(
            of: find.byType(TapeCatalog), matching: find.byType(TrackArtwork)))
        .toList();
    expect(photos.map((p) => p.uri), tape.tracks.map((t) => t.uri));
    await capture('encarte-v06');
    await tester.tap(find.text('Música 2'));
    await tester.pump();
    expect(app.playback.current!.title, 'Música 2');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets('Ajustes oferece os dois widgets sem criar atalhos falsos',
      (tester) async {
    final app = AppState(store: CollectionStore(memory: true));
    await app.load();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(state: app)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar widget de prateleira'), findsOneWidget);
    expect(find.text('Adicionar widget Walkman'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
