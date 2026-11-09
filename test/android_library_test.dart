import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/services/music_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const library = AndroidMusicLibrary();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() =>
      messenger.setMockMethodCallHandler(AndroidMusicLibrary.channel, null));

  test('Converte referências e caminhos retornados pelo Android', () async {
    messenger.setMockMethodCallHandler(AndroidMusicLibrary.channel,
        (call) async {
      expect(call.method, 'loadTracks');
      return [
        {
          'id': '42',
          'title': 'Aurora',
          'artist': 'Artista',
          'album': 'Álbum',
          'folder': 'Music/Minha coleção/',
          'uri': 'content://media/external/audio/media/42',
          'duration': 123000
        }
      ];
    });
    final tracks = await library.loadTracks();
    expect(tracks.single.folder, 'Music/Minha coleção/');
    expect(tracks.single.uri.scheme, 'content');
    expect(tracks.single.duration, const Duration(seconds: 123));
  });

  test('Permissão negada oferece pasta e ajustes sem inventar músicas',
      () async {
    messenger.setMockMethodCallHandler(AndroidMusicLibrary.channel, (_) async {
      throw PlatformException(code: 'PERMISSION_DENIED');
    });
    await expectLater(
        library.loadTracks(),
        throwsA(isA<LibraryUnavailable>().having((error) => error.message,
            'orientação', contains('Escolher pasta'))));
  });

  test('Cancelar seletor não solicita recarregamento da biblioteca', () async {
    messenger.setMockMethodCallHandler(AndroidMusicLibrary.channel,
        (call) async {
      expect(call.method, 'chooseFolder');
      return false;
    });
    expect(await library.chooseFolder(), isFalse);
  });
}
