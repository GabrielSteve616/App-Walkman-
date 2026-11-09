import 'package:flutter/services.dart';

import '../models/local_track.dart';

abstract class MusicLibrary {
  Future<List<LocalTrack>> loadTracks();
}

/// Biblioteca Android por MediaStore ou pasta autorizada pelo seletor do sistema.
class AndroidMusicLibrary implements MusicLibrary {
  const AndroidMusicLibrary();
  static const channel = MethodChannel('walkman/library');

  @override
  Future<List<LocalTrack>> loadTracks() async {
    try {
      final rows = await channel.invokeListMethod<dynamic>('loadTracks') ?? [];
      return rows.map((row) {
        final data = Map<String, dynamic>.from(row as Map);
        return LocalTrack(
          id: data['id'] as String,
          title: data['title'] as String,
          artist: data['artist'] as String,
          album: data['album'] as String,
          folder: data['folder'] as String,
          uri: Uri.parse(data['uri'] as String),
          duration: Duration(milliseconds: (data['duration'] as num).toInt()),
        );
      }).toList();
    } on PlatformException catch (error) {
      throw LibraryUnavailable(
          error.code == 'CHOOSE_FOLDER'
              ? 'Escolha a pasta onde suas músicas estão salvas. O aplicativo guardará esse local para as próximas aberturas.'
              : error.code == 'PERMISSION_DENIED'
                  ? 'Permita o acesso a músicas e áudio para procurar no aparelho, '
                      'ou use “Escolher pasta” para indicar onde suas músicas estão salvas. '
                      'Se o Android não mostrar a pergunta novamente, abra as permissões nos ajustes.'
                  : error.message ??
                      'Não foi possível ler as músicas. Escolha a pasta novamente.',
          code: error.code);
    } on MissingPluginException {
      throw const LibraryUnavailable(
          'A biblioteca de arquivos está disponível no Android.');
    }
  }

  Future<bool> chooseFolder() async =>
      await channel.invokeMethod<bool>('chooseFolder') ?? false;

  Future<void> useAllMusic() => channel.invokeMethod<void>('useAllMusic');
  Future<void> openSettings() => channel.invokeMethod<void>('openSettings');
  Future<List<String>> folders() async =>
      await channel.invokeListMethod<String>('folders') ?? [];
  Future<void> createFolder(String name) =>
      channel.invokeMethod<void>('createFolder', {'name': name});
}

class LibraryUnavailable implements Exception {
  const LibraryUnavailable(this.message, {this.code = ''});
  final String message;
  final String code;
}
