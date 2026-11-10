import 'package:flutter/material.dart';
import '../services/app_state.dart';

String _time(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
Future<bool?> showAudioMoments(BuildContext context, AppState app) =>
    showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: ListenableBuilder(
                listenable: Listenable.merge([app, app.playback]),
                builder: (context, _) => Column(children: [
                      ListTile(
                          title: const Text('Trechos',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          trailing: FilledButton.icon(
                              onPressed: app.playback.current == null ||
                                      app.playback.duration.inSeconds < 1
                                  ? null
                                  : () => Navigator.pop(context, true),
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text('Marcar'))),
                      Expanded(
                          child: app.moments.isEmpty
                              ? const Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('Sem trechos',
                                          textAlign: TextAlign.center)))
                              : ListView.builder(
                                  itemCount: app.moments.length,
                                  itemBuilder: (context, i) {
                                    final m = app.moments[i];
                                    return ListTile(
                                        leading: const Icon(
                                            Icons.bookmark_rounded,
                                            color: Colors.orangeAccent),
                                        title: Text(m.name),
                                        subtitle: Text(
                                            '${m.track.title}\n${_time(m.start)} – ${_time(m.end)}'),
                                        isThreeLine: true,
                                        onTap: app.playback.busy
                                            ? null
                                            : () => app.playback.playRange(
                                                m.track, m.start, m.end),
                                        trailing: IconButton(
                                            tooltip: 'Excluir trecho',
                                            icon: const Icon(
                                                Icons.delete_outline_rounded),
                                            onPressed: () async {
                                              try {
                                                await app.deleteMoment(m.id);
                                              } catch (_) {
                                                if (context.mounted)
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(const SnackBar(
                                                          content: Text(
                                                              'Não foi possível excluir o trecho.')));
                                              }
                                            }));
                                  })),
                    ]))));
