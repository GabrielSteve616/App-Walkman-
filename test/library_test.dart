import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/main.dart';
import 'package:walkman/models/local_track.dart';
import 'package:walkman/screens/library_screen.dart';
import 'package:walkman/services/music_library.dart';
import 'package:walkman/services/app_state.dart';
import 'package:walkman/services/collection_store.dart';
import 'package:walkman/services/playback.dart';

class TestLibrary implements MusicLibrary {
  @override
  Future<List<LocalTrack>> loadTracks() async => [
        for (final title in ['Aurora', 'Estrada'])
          LocalTrack(
              id: title,
              title: title,
              artist: 'Artista',
              album: 'Álbum',
              folder: 'Music',
              uri: Uri.parse('content://media/external/audio/media/$title'),
              duration: const Duration(minutes: 3)),
      ];
}

class TestPlayback extends Playback {
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
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidMusicLibrary.channel,
            (call) async => call.method == 'artwork' ? null : []);
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(AndroidMusicLibrary.channel, null));

  testWidgets('Cabeçalho e quatro abas conforme solicitado', (tester) async {
    final app = AppState(store: CollectionStore(memory: true));
    await app.load();
    await tester.pumpWidget(WalkmanApp(state: app));
    await tester.pumpAndSettle();
    expect(find.text('Walkmen'), findsOneWidget);
    expect(find.byTooltip('Pesquisar'), findsOneWidget);
    expect(find.byTooltip('Atualizar músicas'), findsOneWidget);
    expect(find.text('LOCAL • OFFLINE'), findsNothing);
    expect(find.text('Todo o aparelho'), findsNothing);
    await tester.tap(find.text('Fitas'));
    await tester.pumpAndSettle();
    expect(find.text('Suas fitas'), findsOneWidget);
    await tester.tap(find.text('Figurinhas'));
    await tester.pumpAndSettle();
    expect(find.text('Criar'), findsOneWidget);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Alterar pasta de músicas'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets('Pesquisa filtra músicas e mostra estado sem resultados',
      (tester) async {
    final key = GlobalKey<LibraryScreenState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LibraryScreen(key: key, library: TestLibrary()))));
    await tester.pumpAndSettle();
    expect(find.text('Music'), findsOneWidget);
    key.currentState!.toggleSearch();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'aurora');
    await tester.pumpAndSettle();
    expect(find.text('Aurora'), findsOneWidget);
    expect(find.text('Estrada'), findsNothing);
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Sem resultados'), findsOneWidget);
  });
  testWidgets(
      'Tocar música inicia fila; coração salva favorita; toque longo mostra local',
      (tester) async {
    final playback = TestPlayback();
    final app =
        AppState(store: CollectionStore(memory: true), playback: playback);
    await app.load();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LibraryScreen(library: TestLibrary(), app: app))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estrada'));
    await tester.pumpAndSettle();
    expect(playback.calls, 1);
    expect(playback.current!.title, 'Estrada');
    expect(playback.queue.length, 2);
    await tester.tap(find.byTooltip('Favoritar música').last);
    await tester.pumpAndSettle();
    expect(app.favorites, contains(playback.current!.uri.toString()));
    await tester.longPress(find.text('Aurora'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Local da música:'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favoritas'));
    await tester.pumpAndSettle();
    expect(find.text('Estrada'), findsOneWidget);
    expect(find.text('Aurora'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets('Primeira abertura pede pasta sem exibir controles antigos',
      (tester) async {
    // A platform exception reproduces the native first-launch response.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidMusicLibrary.channel, (call) async {
      if (call.method == 'loadTracks')
        throw PlatformException(code: 'CHOOSE_FOLDER');
      return null;
    });
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LibraryScreen(library: AndroidMusicLibrary()))));
    await tester.pumpAndSettle();
    expect(find.text('Onde estão suas músicas?'), findsOneWidget);
    expect(find.text('Escolher pasta de músicas'), findsOneWidget);
    expect(find.text('Todo o aparelho'), findsNothing);
  });
}
