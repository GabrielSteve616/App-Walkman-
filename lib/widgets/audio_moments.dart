import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../models/audio_moment.dart';

String _time(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
Future<void> showAudioMoments(BuildContext context, AppState app) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _Moments(app: app));

class _Moments extends StatefulWidget {
  const _Moments({required this.app});
  final AppState app;
  @override
  State<_Moments> createState() => _MomentsState();
}

class _MomentsState extends State<_Moments> {
  bool _saving = false;
  Future<void> _mark() async {
    final p = widget.app.playback, t = p.current;
    if (t == null || _saving) return;
    final at = p.position;
    if (p.duration > Duration.zero && at >= p.duration) return;
    setState(() => _saving = true);
    try {
      final number =
          widget.app.moments.where((m) => m.track.uri == t.uri).length + 1;
      await widget.app.saveMoment(AudioMoment(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: 'Parte $number',
          track: t,
          start: at));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível salvar.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename(AudioMoment m) async {
    final field = TextEditingController(text: m.name);
    final name = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Renomear'),
                content: TextField(
                    controller: field,
                    autofocus: true,
                    maxLength: 60,
                    decoration: const InputDecoration(hintText: 'Nome'),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) Navigator.pop(dialog, v.trim());
                    }),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, field.text.trim()),
                      child: const Text('Salvar'))
                ]));
    if (name != null && name.isNotEmpty) {
      try {
        await widget.app.renameMoment(m.id, name);
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Não foi possível renomear.')));
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    field.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: ListenableBuilder(
          listenable: Listenable.merge([widget.app, widget.app.playback]),
          builder: (context, _) => Column(children: [
                ListTile(
                    title: const Text('Trechos',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    trailing: FilledButton.icon(
                        onPressed:
                            _saving || widget.app.playback.current == null
                                ? null
                                : _mark,
                        icon: const Icon(Icons.bookmark_add_rounded),
                        label: const Text('Salvar início'))),
                Expanded(
                    child: widget.app.moments.isEmpty
                        ? const Center(
                            child: Icon(Icons.bookmarks_outlined,
                                size: 48, color: Colors.white24))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                            itemCount: widget.app.moments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final m = widget.app.moments[i];
                              return ListTile(
                                  tileColor: const Color(0xFF232A30),
                                  leading: Container(
                                      width: 48,
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF493525),
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      child: const Icon(Icons.bookmark_rounded,
                                          color: Colors.orangeAccent)),
                                  title: Text(m.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      '${_time(m.start)} • ${m.track.title}',
                                      maxLines: 1),
                                  onTap: widget.app.playback.busy
                                      ? null
                                      : () => widget.app.playback
                                          .playFrom(m.track, m.start),
                                  trailing: PopupMenuButton<String>(
                                      tooltip: 'Opções do trecho',
                                      onSelected: (v) async {
                                        if (v == 'rename') {
                                          await _rename(m);
                                        } else {
                                          try {
                                            await widget.app.deleteMoment(m.id);
                                          } catch (_) {
                                            if (mounted)
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'Não foi possível excluir.')));
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                            PopupMenuItem(
                                                value: 'rename',
                                                child: Text('Renomear')),
                                            PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Excluir'))
                                          ]));
                            })),
              ])));
}
