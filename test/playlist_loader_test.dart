import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:walkman/services/playlist_loader.dart';

class QueuePlayer extends AudioPlayer {
  final items = <AudioSource>[];
  final batchLengths = <int>[];
  int? selected;
  Duration? at;
  @override
  Future<Duration?> setAudioSources(List<AudioSource> audioSources,
      {bool preload = true,
      int? initialIndex,
      Duration? initialPosition,
      ShuffleOrder? shuffleOrder}) async {
    batchLengths.add(audioSources.length);
    items
      ..clear()
      ..addAll(audioSources);
    selected = initialIndex;
    at = initialPosition;
    return null;
  }

  @override
  Future<void> insertAudioSources(
      int index, List<AudioSource> audioSources) async {
    batchLengths.add(audioSources.length);
    items.insertAll(index, audioSources);
  }

  @override
  Future<void> addAudioSources(List<AudioSource> audioSources) async {
    batchLengths.add(audioSources.length);
    items.addAll(audioSources);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    selected = index;
    at = position;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Fila com 2501 faixas mantém ordem e seleção sem mensagem gigante',
      () async {
    for (final selected in [0, 1257, 2500]) {
      final player = QueuePlayer();
      final sources = List.generate(
          2501, (i) => AudioSource.uri(Uri.parse('content://music/$i')));
      await loadPlaylist(player, sources,
          initialIndex: selected, initialPosition: const Duration(seconds: 37));
      expect(player.items, orderedEquals(sources));
      expect(player.selected, selected);
      expect(player.at, const Duration(seconds: 37));
      expect(player.batchLengths.every((n) => n <= 50), isTrue);
      expect(player.batchLengths.first, 1);
      await player.dispose();
    }
  });
}
