import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:walkman/models/audio_moment.dart';
import 'package:walkman/models/local_track.dart';
import 'package:walkman/models/tape.dart';
import 'package:walkman/screens/backup_screen.dart';
import 'package:walkman/services/app_state.dart';
import 'package:walkman/services/backup_codec.dart';
import 'package:walkman/services/backup_service.dart';
import 'package:walkman/services/collection_store.dart';

final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aXcAAAAASUVORK5CYII=');
LocalTrack song() => LocalTrack(
    id: 'a',
    title: 'Música',
    artist: 'Artista',
    album: 'Álbum',
    folder: 'Music',
    uri: Uri.parse('content://music/1'),
    duration: const Duration(minutes: 3));
Map<String, dynamic> get prefs => {
      'volume': .4,
      'shuffle': true,
      'loop': 1,
      'musicFolder': 'content://provider/tree/music'
    };

class FailingStore extends CollectionStore {
  FailingStore(Directory dir) : super(directory: dir);
  bool fail = false;
  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (fail) throw const FileSystemException('Falha simulada');
    await super.write(data);
  }
}

class FakeBackup extends BackupService {
  FakeBackup(this.value);
  final ParsedBackup value;
  bool? chosenLocation;
  @override
  Future<ParsedBackup?> pick() async => value;
  @override
  Future<bool> restoreFolder(ParsedBackup backup) async => false;
  @override
  Future<String?> export(AppState app, {bool chooseLocation = false}) async {
    chosenLocation = chooseLocation;
    return 'Walkmen-backup.json';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Migração usa cópia anterior quando o JSON principal está danificado',
      () async {
    final dir = await Directory.systemTemp.createTemp('walkmen-legacy-');
    try {
      await File('${dir.path}/collection.json').writeAsString('{');
      final recovered = Tape(id: 'r', name: 'recuperada', tracks: []).toJson();
      await File('${dir.path}/collection.json.bak').writeAsString(jsonEncode({
        'tapes': [recovered]
      }));
      expect(
          (await CollectionStore(directory: dir).read())['tapes'], [recovered]);
      expect(await File('${dir.path}/collection.json').readAsString(), '{');
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('Falha dentro da transação SQLite mantém a biblioteca anterior',
      () async {
    final dir = await Directory.systemTemp.createTemp('walkmen-transaction-');
    try {
      final store = CollectionStore(directory: dir);
      await store.write({
        'tapes': ['preservada']
      });
      final db = await openDatabase('${dir.path}/walkmen.sqlite',
          singleInstance: false);
      await db.execute(
          "CREATE TRIGGER reject_save BEFORE INSERT ON collection BEGIN SELECT RAISE(ABORT, 'falha simulada'); END");
      await db.close();
      await expectLater(
          store.write({
            'tapes': ['nova']
          }),
          throwsA(isA<DatabaseException>()));
      expect((await store.read())['tapes'], ['preservada']);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('Falha ao preservar a cópia anterior cancela a gravação inteira',
      () async {
    final dir = await Directory.systemTemp.createTemp('walkmen-previous-');
    try {
      final store = CollectionStore(directory: dir);
      await store.write({
        'tapes': ['preservada']
      });
      final db = await openDatabase('${dir.path}/walkmen.sqlite',
          singleInstance: false);
      await db.execute(
          "CREATE TRIGGER reject_previous BEFORE INSERT ON previous_collection BEGIN SELECT RAISE(ABORT, 'falha simulada'); END");
      await db.close();
      await expectLater(
          store.write({
            'tapes': ['nova']
          }),
          throwsA(isA<DatabaseException>()));
      expect((await store.read())['tapes'], ['preservada']);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('Migração ignora JSON estruturalmente inválido e usa a cópia anterior',
      () async {
    final dir = await Directory.systemTemp.createTemp('walkmen-legacy-schema-');
    try {
      final malformed = jsonEncode({'tapes': 'inválida'});
      await File('${dir.path}/collection.json').writeAsString(malformed);
      final previous = Tape(id: 'r', name: 'Recuperada', tracks: []).toJson();
      await File('${dir.path}/collection.json.bak').writeAsString(jsonEncode({
        'tapes': [previous]
      }));
      expect(
          (await CollectionStore(directory: dir).read())['tapes'], [previous]);
      expect(
          await File('${dir.path}/collection.json').readAsString(), malformed);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('Migra a biblioteca antiga para SQLite sem apagar o JSON anterior',
      () async {
    final dir = await Directory.systemTemp.createTemp('walkmen-migrate-');
    try {
      final old = File('${dir.path}/collection.json');
      final legacy = Tape(id: 'l', name: 'antiga', tracks: []).toJson();
      await old.writeAsString(jsonEncode({
        'tapes': [legacy],
        'favorites': ['a']
      }));
      final store = CollectionStore(directory: dir);
      expect((await store.read())['tapes'], [legacy]);
      final sqlite = File('${dir.path}/walkmen.sqlite');
      expect(ascii.decode((await sqlite.readAsBytes()).take(15).toList()),
          'SQLite format 3');
      expect(await old.exists(), isTrue);
      await store.write({
        'tapes': ['nova']
      });
      expect((await CollectionStore(directory: dir).read())['tapes'], ['nova']);
      expect(jsonDecode(await old.readAsString())['tapes'], [legacy]);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test(
      'Backup restaura fitas, imagens, figurinhas, favoritas, trechos e opções em SQLite',
      () async {
    final sourceDir = await Directory.systemTemp.createTemp('walkmen-source-'),
        targetDir = await Directory.systemTemp.createTemp('walkmen-target-');
    final source = AppState(store: CollectionStore(directory: sourceDir)),
        target = AppState(store: CollectionStore(directory: targetDir));
    try {
      await source.load();
      await target.load();
      await source.playback.applyPreferences(prefs);
      final photo = await source.store.saveImage(png, 'photo');
      final sticker = await source.addSticker('Estrela', png);
      final tape = Tape(
          id: 'tape',
          name: 'Rock',
          tracks: [song()],
          color: 0xff123456,
          transparent: true,
          coverPath: photo,
          labelBackPath: photo,
          stickers: [
            StickerPlacement(
                assetId: sticker.id, x: .9, y: .4, onCase: true, back: true)
          ]);
      await source.saveTape(tape);
      await source.toggleFavorite(song());
      await source.saveMoment(AudioMoment(
          id: 'marker',
          name: 'Refrão',
          track: song(),
          start: const Duration(seconds: 42)));
      await target.saveTape(Tape(id: 'old', name: 'Antiga', tracks: []));
      final text =
          await BackupCodec.encode(await source.backupSnapshot(), prefs);
      expect(text, isNot(contains(sourceDir.path)));
      final backup = BackupCodec.decode(text);
      expect(backup.images.length, 2); // shared cover/label is stored once
      await target.restoreBackup(backup);
      expect(target.tapes.single.id, 'tape');
      expect(target.tapes.single.transparent, isTrue);
      expect(target.tapes.single.stickers.single.x, .9);
      expect(await File(target.tapes.single.coverPath!).readAsBytes(),
          orderedEquals(png));
      expect(target.tapes.single.coverPath, target.tapes.single.labelBackPath);
      expect(await File(target.stickers.single.path).readAsBytes(),
          orderedEquals(png));
      expect(target.favorites, contains(song().uri.toString()));
      expect(target.moments.single.start, const Duration(seconds: 42));
      expect(target.playback.preferences,
          {'volume': .4, 'shuffle': true, 'loop': 1});
      final reopened = AppState(store: CollectionStore(directory: targetDir));
      await reopened.load();
      expect(reopened.tapes.single.toJson(), target.tapes.single.toJson());
      expect(reopened.playback.preferences,
          {'volume': .4, 'shuffle': true, 'loop': 1});
      reopened.dispose();
      final broken = jsonDecode(text) as Map<String, dynamic>;
      (broken['images'] as Map).clear();
      expect(
          () => BackupCodec.decode(jsonEncode(broken)), throwsFormatException);
      final damaged = jsonDecode(text) as Map<String, dynamic>;
      final encodedImage = (damaged['images'] as Map).values.first as Map;
      final encoded = encodedImage['data'] as String;
      encodedImage['data'] =
          (encoded[0] == 'A' ? 'B' : 'A') + encoded.substring(1);
      expect(
          () => BackupCodec.decode(jsonEncode(damaged)), throwsFormatException);
      expect(target.tapes.single.name, 'Rock');
    } finally {
      source.dispose();
      target.dispose();
      await sourceDir.delete(recursive: true);
      await targetDir.delete(recursive: true);
    }
  });
  test('Falha ao restaurar preserva dados e remove somente imagens temporárias',
      () async {
    final dir = await Directory.systemTemp.createTemp('walkmen-fail-');
    final store = FailingStore(dir), app = AppState(store: store);
    try {
      await app.load();
      await app.saveTape(Tape(id: 'old', name: 'Manter', tracks: []));
      final oldImage = await store.saveImage(png, 'original');
      final original =
          Tape(id: 'new', name: 'Nova', tracks: [], coverPath: oldImage);
      final text = await BackupCodec.encode({
        'tapes': [original.toJson()],
        'moments': [],
        'stickers': [],
        'favorites': [],
        'favoriteTracks': []
      }, prefs);
      store.fail = true;
      await expectLater(app.restoreBackup(BackupCodec.decode(text)),
          throwsA(isA<FileSystemException>()));
      expect(app.tapes.single.name, 'Manter');
      expect(((await app.backupSnapshot())['tapes'] as List).single['name'],
          'Manter');
      await app.playback.applyPreferences(prefs);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(app.storageError, isNotNull);
      expect(((await app.backupSnapshot())['tapes'] as List).single['name'],
          'Manter');
      expect(await File(oldImage).exists(), isTrue);
      final files = await Directory('${dir.path}/images').list().toList();
      expect(files.length, 1);
      final reopened = AppState(store: CollectionStore(directory: dir));
      await reopened.load();
      expect(reopened.tapes.single.name, 'Manter');
      reopened.dispose();
    } finally {
      app.dispose();
      await dir.delete(recursive: true);
    }
  });
  testWidgets('Importação pede confirmação antes de substituir a biblioteca',
      (tester) async {
    final tape = Tape(id: 'new', name: 'Restaurada', tracks: []);
    final text = await BackupCodec.encode({
      'tapes': [tape.toJson()],
      'moments': [],
      'stickers': [],
      'favorites': [],
      'favoriteTracks': []
    }, prefs);
    final app = AppState(store: CollectionStore(memory: true));
    await app.load();
    await app.saveTape(Tape(id: 'old', name: 'Atual', tracks: []));
    var refreshed = 0;
    await tester.pumpWidget(MaterialApp(
        home: BackupScreen(
            app: app,
            onRestored: () => refreshed++,
            service: FakeBackup(BackupCodec.decode(text)))));
    expect(find.text('Escolher onde salvar'), findsOneWidget);
    await tester.tap(find.text('Importar backup JSON'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Restaurar backup?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(app.tapes.single.name, 'Atual');
    await tester.tap(find.text('Importar backup JSON'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Restaurar'));
    await tester.pumpAndSettle();
    expect(app.tapes.single.name, 'Restaurada');
    expect(refreshed, 1);
    expect(find.textContaining('Escolha novamente a pasta'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  testWidgets('Botão de escolher destino abre o fluxo de salvamento escolhido',
      (tester) async {
    final tape = Tape(id: 't', name: 'Teste', tracks: []);
    final text = await BackupCodec.encode({
      'tapes': [tape.toJson()],
      'moments': [],
      'stickers': [],
      'favorites': [],
      'favoriteTracks': []
    }, prefs);
    final app = AppState(store: CollectionStore(memory: true));
    await app.load();
    final service = FakeBackup(BackupCodec.decode(text));
    await tester.pumpWidget(MaterialApp(
        home: BackupScreen(app: app, onRestored: () {}, service: service)));
    await tester.tap(find.text('Escolher onde salvar'));
    await tester.pumpAndSettle();
    expect(service.chosenLocation, isTrue);
    expect(find.textContaining('Backup salvo: Walkmen-backup.json'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
  test('Serviço entrega JSON ao Android e apaga somente o arquivo temporário',
      () async {
    final dir = await Directory.systemTemp.createTemp('walkmen-service-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    String? exported;
    var cancelSelection = false;
    var failSelection = false;
    messenger.setMockMethodCallHandler(pathChannel, (call) async => dir.path);
    messenger.setMockMethodCallHandler(BackupService.channel, (call) async {
      if (call.method == 'selectedFolder')
        return 'content://provider/tree/music';
      if (call.method == 'export') {
        exported = await File(call.arguments['path'] as String).readAsString();
        return 'Walkmen-backup.json';
      }
      if (call.method == 'exportToFile') {
        expect(await File(call.arguments['path'] as String).exists(), isTrue);
        if (failSelection) throw PlatformException(code: 'WRITE_FAILED');
        if (cancelSelection) return null;
        exported = await File(call.arguments['path'] as String).readAsString();
        return 'Minha coleção.json';
      }
      if (call.method == 'pick') {
        final f = File('${dir.path}/chosen.json');
        await f.writeAsString(exported!);
        return f.path;
      }
      if (call.method == 'restoreFolder') return true;
      return null;
    });
    final app = AppState(store: CollectionStore(memory: true));
    try {
      await app.load();
      await app.saveTape(Tape(id: 't', name: 'Teste', tracks: []));
      const service = BackupService();
      expect(await service.export(app), 'Walkmen-backup.json');
      expect(await service.export(app, chooseLocation: true),
          'Minha coleção.json');
      cancelSelection = true;
      expect(await service.export(app, chooseLocation: true), isNull);
      failSelection = true;
      await expectLater(service.export(app, chooseLocation: true),
          throwsA(isA<PlatformException>()));
      final restored = await service.pick();
      expect((restored!.collection['tapes'] as List).single['name'], 'Teste');
      expect(await service.restoreFolder(restored), isTrue);
      expect(await dir.list().isEmpty, isTrue);
    } finally {
      app.dispose();
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMethodCallHandler(BackupService.channel, null);
      await dir.delete(recursive: true);
    }
  });
}
