import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../models/tape.dart';
import '../services/app_state.dart';
import '../widgets/tape_artwork.dart';
import '../widgets/track_artwork.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/audio_moments.dart';

String clockTime(Duration d) =>
    '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

class NowPlayingTape extends StatelessWidget {
  const NowPlayingTape({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final p = app.playback, t = p.current;
    if (t == null) return const SizedBox.shrink();
    final tape =
        app.tapes.where((tape) => tape.name == p.tapeName).firstOrNull ??
            Tape(
                id: 'now-playing',
                name: p.tapeName ?? t.title,
                tracks: p.queue,
                color: 0xFF294954);
    return AspectRatio(
        aspectRatio: tapeAspect,
        child: LayoutBuilder(
            builder: (context, c) => Stack(children: [
                  Positioned.fill(
                      child: AnimatedTapeArtwork(
                          tape: tape,
                          assets: app.stickers,
                          playing: p.playing)),
                  Positioned(
                      left: c.maxWidth * .43,
                      top: c.maxHeight * .445,
                      width: c.maxWidth * .14,
                      height: c.maxHeight * .18,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TrackArtwork(
                              uri: t.uri, size: c.maxWidth * .156))),
                ])));
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app.playback,
      builder: (context, _) {
        final p = app.playback, t = p.current;
        if (t == null) return const SizedBox.shrink();
        return Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: Material(
                color: const Color(0xFF26373E),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                    height: 74,
                    child: Row(children: [
                      const SizedBox(width: 8),
                      SizedBox(width: 66, child: NowPlayingTape(app: app)),
                      Expanded(
                          child: InkWell(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PlayerScreen(app: app))),
                              child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(t.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        Text(
                                            p.error ??
                                                (p.busy
                                                    ? 'Carregando…'
                                                    : t.artist),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: p.error == null
                                                    ? Colors.white60
                                                    : Colors.orange)),
                                      ])))),
                      IconButton(
                          tooltip: p.playing ? 'Pausar' : 'Reproduzir',
                          onPressed: p.busy ? null : p.toggle,
                          icon:
                              Icon(p.playing ? Icons.pause : Icons.play_arrow)),
                      IconButton(
                          tooltip: 'Próxima',
                          onPressed: p.busy ? null : p.next,
                          icon: const Icon(Icons.skip_next)),
                    ]))));
      });
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen(
      {super.key, required this.app, this.initialVertical = true});
  final AppState app;
  final bool initialVertical;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late bool _vertical;
  double? _dragPosition;
  Future<void> _moments() => showAudioMoments(context, widget.app);
  @override
  void initState() {
    super.initState();
    _vertical = widget.initialVertical;
    _orient();
  }

  void _orient() {
    SystemChrome.setPreferredOrientations(_vertical
        ? [DeviceOrientation.portraitUp]
        : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  void _mode(bool vertical) {
    setState(() => _vertical = vertical);
    _orient();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _favorite() async {
    final t = widget.app.playback.current;
    if (t == null) return;
    try {
      await widget.app.toggleFavorite(t);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível salvar a favorita.')));
    }
  }

  Widget _controls(BuildContext context) {
    final app = widget.app, p = app.playback, t = p.current!;
    final total = p.duration.inMilliseconds.toDouble();
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(p.tapeName ?? t.artist,
                      style: const TextStyle(color: Colors.white60))
                ])),
            IconButton(
                tooltip: 'Favoritar',
                onPressed: _favorite,
                icon: Icon(
                    app.favorites.contains(t.uri.toString())
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: Colors.orange))
          ]),
          if (p.error != null)
            Text(p.error!, style: const TextStyle(color: Colors.orange)),
          Slider(
              value: (_dragPosition ?? p.position.inMilliseconds.toDouble())
                  .clamp(0, total > 0 ? total : 1),
              max: total > 0 ? total : 1,
              onChanged:
                  total <= 0 ? null : (v) => setState(() => _dragPosition = v),
              onChangeEnd: total <= 0
                  ? null
                  : (v) {
                      setState(() => _dragPosition = null);
                      p.seek(Duration(milliseconds: v.round()));
                    }),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(clockTime(p.position),
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            Text(clockTime(p.duration),
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            IconButton(
                tooltip: 'Aleatório',
                color: p.shuffle ? Colors.orange : null,
                onPressed: p.toggleShuffle,
                icon: const Icon(Icons.shuffle)),
            IconButton(
                iconSize: 34,
                tooltip: 'Anterior',
                onPressed: p.previous,
                icon: const Icon(Icons.skip_previous)),
            IconButton.filled(
                iconSize: 42,
                tooltip: p.playing ? 'Pausar' : 'Reproduzir',
                onPressed: p.busy ? null : p.toggle,
                icon: Icon(p.playing ? Icons.pause : Icons.play_arrow)),
            IconButton(
                iconSize: 34,
                tooltip: 'Próxima',
                onPressed: p.next,
                icon: const Icon(Icons.skip_next)),
            IconButton(
                tooltip: 'Repetição',
                color: p.loop == LoopMode.off ? null : Colors.orange,
                onPressed: p.toggleLoop,
                icon: Icon(
                    p.loop == LoopMode.one ? Icons.repeat_one : Icons.repeat)),
          ]),
          Row(children: [
            Expanded(
                child: TextButton.icon(
                    onPressed: () => showQueue(context, app),
                    icon: const Icon(Icons.queue_music_rounded),
                    label: const Text('Catálogo'))),
            Expanded(
                child: TextButton.icon(
                    onPressed: _moments,
                    icon: const Icon(Icons.bookmarks_outlined),
                    label: const Text('Trechos'))),
          ]),
          Row(children: [
            IconButton(
                tooltip: 'Parar',
                onPressed: p.stop,
                icon: const Icon(Icons.stop_circle_outlined)),
            const Icon(Icons.volume_up, size: 18),
            Expanded(child: Slider(value: p.volume, onChanged: p.setVolume))
          ]),
        ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(_vertical ? 'Reproduzindo' : 'Modo fita'),
            actions: [
              PopupMenuButton<bool>(
                  tooltip: 'Visualização do player',
                  initialValue: _vertical,
                  onSelected: _mode,
                  itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: false, child: Text('Fita • deitado')),
                        const PopupMenuItem(
                            value: true,
                            child: Text('Player vertical • em pé')),
                      ])
            ]),
        body: SafeArea(
            child: ListenableBuilder(
                listenable: Listenable.merge([widget.app, widget.app.playback]),
                builder: (context, _) {
                  final app = widget.app, t = app.playback.current;
                  if (t == null)
                    return const Center(
                        child: Text('Escolha uma música na biblioteca.'));
                  return LayoutBuilder(builder: (context, c) {
                    if (_vertical) {
                      return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: Column(children: [
                            Text(app.playback.tapeName ?? 'DA SUA BIBLIOTECA',
                                style: const TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 2,
                                    color: Colors.white54)),
                            const SizedBox(height: 22),
                            Center(
                                child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 440),
                                    child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF35434A),
                                                  Color(0xFF171D23)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight),
                                            border: Border.all(
                                                color: Colors.white12),
                                            boxShadow: const [
                                              BoxShadow(
                                                  color: Colors.black45,
                                                  blurRadius: 26,
                                                  offset: Offset(0, 12))
                                            ]),
                                        child: NowPlayingTape(app: app)))),
                            const SizedBox(height: 28),
                            _controls(context),
                          ]));
                    }
                    final artwork = Center(
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: NowPlayingTape(app: app)));
                    return c.maxWidth > 600
                        ? Row(children: [
                            Expanded(flex: 6, child: artwork),
                            Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: _controls(context)))
                          ])
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                children: [artwork, _controls(context)]));
                  });
                })),
      );
}
