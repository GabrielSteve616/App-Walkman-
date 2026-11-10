import 'package:flutter/material.dart';
import '../services/app_state.dart';
import 'track_artwork.dart';

Future<void> showQueue(BuildContext context, AppState app) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: ListenableBuilder(
                listenable: app.playback,
                builder: (context, _) {
                  final p = app.playback;
                  return Column(children: [
                    ListTile(
                        title: const Text('Catálogo da reprodução',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(p.tapeName ?? 'Músicas da biblioteca')),
                    Expanded(
                        child: ListView.builder(
                            itemCount: p.queue.length,
                            itemBuilder: (context, i) {
                              final track = p.queue[i], selected = i == p.index;
                              return ListTile(
                                  selected: selected,
                                  selectedTileColor: const Color(0xFF3A2C21),
                                  leading:
                                      TrackArtwork(uri: track.uri, size: 48),
                                  title: Text(track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text('${i + 1} • ${track.artist}',
                                      maxLines: 1),
                                  trailing: selected
                                      ? const Icon(Icons.equalizer_rounded,
                                          color: Colors.orangeAccent)
                                      : const Icon(Icons.play_arrow_rounded),
                                  onTap: () => p.playTracks(List.of(p.queue),
                                      start: i, name: p.tapeName));
                            })),
                  ]);
                })));
