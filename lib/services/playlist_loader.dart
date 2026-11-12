import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';

/// Open the requested track first, then extend the active playlist in bounded
/// platform messages. Inserting the prefix preserves the original folder order.
Future<void> loadPlaylist(AudioPlayer player, List<AudioSource> sources,
    {required int initialIndex, required Duration initialPosition}) async {
  const batchSize = 50;
  if (sources.length <= batchSize) {
    await player.setAudioSources(sources,
        initialIndex: initialIndex, initialPosition: initialPosition);
    return;
  }
  await player.setAudioSources([sources[initialIndex]],
      initialIndex: 0, initialPosition: initialPosition);
  for (var offset = 0; offset < initialIndex; offset += batchSize) {
    await player.insertAudioSources(offset,
        sources.sublist(offset, math.min(offset + batchSize, initialIndex)));
  }
  for (var offset = initialIndex + 1;
      offset < sources.length;
      offset += batchSize) {
    await player.addAudioSources(
        sources.sublist(offset, math.min(offset + batchSize, sources.length)));
  }
  await player.seek(initialPosition, index: initialIndex);
}
