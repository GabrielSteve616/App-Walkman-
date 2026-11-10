import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/models/audio_moment.dart';
import 'package:walkman/models/local_track.dart';
import 'package:walkman/services/app_state.dart';
import 'package:walkman/services/collection_store.dart';
import 'package:walkman/services/playback.dart';
import 'package:walkman/screens/player_screen.dart';
import 'package:walkman/widgets/color_setting.dart';

LocalTrack song(int i) => LocalTrack(
    id: '$i',
    title: 'Faixa $i',
    artist: 'Artista',
    album: 'Álbum',
    folder: 'Music',
    uri: Uri.parse('content://test/$i'),
    duration: const Duration(minutes: 3));

class Player extends Playback {
  int seeks = 0, calls = 0;
  Duration testPosition = const Duration(seconds: 30);
  Duration? rangeStart, rangeEnd;
  @override
  Duration get duration => const Duration(minutes: 3);
  @override
  Duration get position => testPosition;
  @override
  Future<void> seek(Duration time) async {
    seeks++;
  }

  @override
  Future<void> playTracks(List<LocalTrack> tracks,
      {int start = 0, String? name}) async {
    queue = tracks;
    index = start;
    tapeName = name;
    calls++;
    notifyListeners();
  }

  @override
  Future<void> playRange(LocalTrack t, Duration start, Duration end) async {
    rangeStart = start;
    rangeEnd = end;
  }
}

void main() {
  test('Trechos sobrevivem à reabertura e não somem ao salvar favoritas',
      () async {
    final store = CollectionStore(memory: true);
    final state = AppState(store: store);
    await state.load();
    final m = AudioMoment(
        id: 'm',
        name: 'Refrão',
        track: song(1),
        start: const Duration(seconds: 22),
        end: const Duration(seconds: 38));
    await state.saveMoment(m);
    await state.toggleFavorite(song(2));
    final reopened = AppState(store: store);
    await reopened.load();
    expect(reopened.moments.single.toJson(), m.toJson());
    await reopened.deleteMoment('m');
    expect(reopened.moments, isEmpty);
    await expectLater(
        reopened.saveMoment(AudioMoment(
            id: 'bad',
            name: 'x',
            track: song(1),
            start: const Duration(seconds: 10),
            end: Duration.zero)),
        throwsArgumentError);
    state.dispose();
    reopened.dispose();
  });
  test('Paleta principal tem exatamente dez cores diferentes', () {
    expect(walkmenColors.length, 10);
    expect(walkmenColors.values.toSet().length, 10);
  });
  testWidgets(
      'Player abre vertical com fita, escolhe qualquer faixa e salva trecho',
      (tester) async {
    tester.view.physicalSize = const Size(420, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = Player();
    await p.playTracks([song(1), song(2), song(3)]);
    final app = AppState(store: CollectionStore(memory: true), playback: p);
    await app.load();
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(app: app)));
    await tester.pumpAndSettle();
    expect(find.text('Reproduzindo'), findsOneWidget);
    expect(find.byType(NowPlayingTape), findsOneWidget);
    final slider = find.byType(Slider).first;
    final g = await tester.startGesture(tester.getCenter(slider));
    await g.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(p.seeks, 0);
    await g.up();
    await tester.pump();
    expect(p.seeks, 1);
    await tester.ensureVisible(find.text('Catálogo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faixa 3').last);
    await tester.pump();
    expect(p.index, 2);
    Navigator.of(tester.element(find.text('Catálogo da reprodução'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Trechos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trechos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('Trechos'), findsNothing);
    expect(
        tester
            .widgetList<IconButton>(find.byType(IconButton))
            .firstWhere((b) => b.tooltip == 'Salvar trecho')
            .onPressed,
        isNull);
    await tester.ensureVisible(find.byTooltip('Marcar início'));
    await tester.pumpAndSettle();
    p.testPosition = const Duration(seconds: 37);
    await tester.tap(find.byTooltip('Marcar início'));
    await tester.pump();
    p.testPosition = const Duration(seconds: 52);
    await tester.tap(find.byTooltip('Marcar fim'));
    await tester.pump();
    await tester.tap(find.byTooltip('Salvar trecho'));
    await tester.pumpAndSettle();
    expect(app.moments.single.start, const Duration(seconds: 37));
    expect(app.moments.single.end, const Duration(seconds: 52));
    await tester.tap(find.byTooltip('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.byType(RangeSlider), findsNothing);
    await tester.tap(find.text('Trechos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(app.moments.single.name));
    await tester.pump();
    expect(p.rangeStart, const Duration(seconds: 37));
    expect(p.rangeEnd, const Duration(seconds: 52));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
