import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/shelf_tape.dart';
import '../models/tape.dart';
import '../services/app_state.dart';
import '../widgets/tape_artwork.dart';
import '../widgets/tape_3d.dart';
import '../widgets/tape_catalog.dart';
import '../animations/tape_unbox_screen.dart';
import 'tape_editor_screen.dart';
import 'player_screen.dart';

class TapesScreen extends StatefulWidget {
  const TapesScreen({super.key, required this.app});
  final AppState app;
  @override
  State<TapesScreen> createState() => _TapesScreenState();
}

class _TapesScreenState extends State<TapesScreen> {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  Timer? _edgeScroll;
  double _velocity = 0;
  AppState get app => widget.app;
  void _dragScroll(Offset position) {
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final y = box.globalToLocal(position).dy;
    _velocity = y < 55
        ? -16
        : y > box.size.height - 55
            ? 16
            : 0;
    if (_velocity == 0) {
      _stopScroll();
      return;
    }
    _edgeScroll ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo((_scroll.offset + _velocity)
          .clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  void _stopScroll() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
  }

  @override
  void dispose() {
    _stopScroll();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (context, _) => Column(children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                      child: Text('Suas fitas',
                          style: Theme.of(context).textTheme.headlineSmall)),
                  Text(app.tapes.length.toString() + ' na estante')
                ])),
            if (app.tapes.isNotEmpty)
              const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                      'Segure para olhar em 3D • arraste para organizar',
                      style: TextStyle(fontSize: 11, color: Colors.white60))),
            Expanded(
                child: app.tapes.isEmpty
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'Abra uma pasta na Biblioteca e toque em Criar fita.',
                                textAlign: TextAlign.center)))
                    : LayoutBuilder(builder: (context, c) {
                        final columns = (c.maxWidth / 66).floor().clamp(2, 12);
                        return ListView.builder(
                            key: _viewport,
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: (app.tapes.length / columns).ceil(),
                            itemBuilder: (context, row) => Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                                decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF13191D),
                                          Color(0xFF34312C)
                                        ]),
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Color(0xFF816044),
                                            width: 10))),
                                child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (var col = 0; col < columns; col++)
                                        if (row * columns + col <
                                            app.tapes.length)
                                          Expanded(child:
                                              Builder(builder: (context) {
                                            final tape =
                                                app.tapes[row * columns + col];
                                            return ShelfTape(
                                                key: ValueKey(tape.id),
                                                app: app,
                                                tape: tape,
                                                onDragUpdate: _dragScroll,
                                                onDragEnd: _stopScroll,
                                                onOpen: () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            TapeUnboxScreen(
                                                                app: app,
                                                                tape: tape))),
                                                child: Container(
                                                    height: 218,
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 3),
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        border: Border.all(
                                                            color: const Color(
                                                                0xFFA5AFB3),
                                                            width: 2),
                                                        gradient:
                                                            LinearGradient(
                                                                colors: [
                                                              const Color(
                                                                  0xFF9AA4A9),
                                                              Color(tape.color),
                                                              const Color(
                                                                  0xFF1A2026)
                                                            ],
                                                                stops: const [
                                                              0,
                                                              .13,
                                                              1
                                                            ]),
                                                        boxShadow: const [
                                                          BoxShadow(
                                                              color: Colors
                                                                  .black54,
                                                              offset:
                                                                  Offset(4, 2),
                                                              blurRadius: 3)
                                                        ]),
                                                    child: Column(children: [
                                                      const Padding(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  vertical: 8),
                                                          child: Text('C90',
                                                              style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .white70))),
                                                      Expanded(
                                                          child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          5),
                                                              child: RotatedBox(
                                                                  quarterTurns:
                                                                      3,
                                                                  child: Container(
                                                                      alignment:
                                                                          Alignment
                                                                              .centerLeft,
                                                                      padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              10),
                                                                      color: Color(tape
                                                                          .caseColor),
                                                                      child: Text(
                                                                          tape.name,
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                          style: TextStyle(color: Color(tape.caseTextColor ?? 0xFF222426), fontWeight: FontWeight.w800, fontSize: 15)))))),
                                                      Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 9),
                                                          child: Text(
                                                              tape.tracks.length
                                                                  .toString(),
                                                              style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .white70)))
                                                    ])));
                                          }))
                                        else
                                          const Expanded(child: SizedBox()),
                                    ])));
                      }))
          ]));
}

class TapeDetailScreen extends StatefulWidget {
  const TapeDetailScreen({super.key, required this.app, required this.id});
  final AppState app;
  final String id;
  @override
  State<TapeDetailScreen> createState() => _TapeDetailScreenState();
}

class _TapeDetailScreenState extends State<TapeDetailScreen> {
  bool _model = false, _case = false, _back = false;
  Future<void> _delete(Tape tape) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Excluir fita?'),
                content: const Text(
                    'Os arquivos de música originais serão preservados.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Excluir'))
                ]));
    if (yes == true) {
      try {
        await widget.app.deleteTape(tape.id);
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Não foi possível excluir a fita.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final app = widget.app,
            tape = app.tapes.where((t) => t.id == widget.id).firstOrNull;
        if (tape == null)
          return const Scaffold(body: Center(child: Text('Fita removida.')));
        return Scaffold(
            appBar: AppBar(title: Text(tape.name), actions: [
              IconButton(
                  tooltip: 'Personalizar',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              TapeEditorScreen(app: app, tape: tape))),
                  icon: const Icon(Icons.edit)),
              IconButton(
                  tooltip: 'Excluir fita',
                  onPressed: () => _delete(tape),
                  icon: const Icon(Icons.delete_outline))
            ]),
            bottomNavigationBar: MiniPlayer(app: app),
            body: Column(children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                        child: SegmentedButton<bool>(
                            segments: const [
                          ButtonSegment(value: false, label: Text('Fita')),
                          ButtonSegment(value: true, label: Text('Caixa'))
                        ],
                            selected: {
                          _case
                        },
                            onSelectionChanged: (v) =>
                                setState(() => _case = v.first))),
                    const SizedBox(width: 8),
                    IconButton(
                        tooltip: _back ? 'Ver frente' : 'Ver verso',
                        onPressed: () => setState(() => _back = !_back),
                        icon: const Icon(Icons.flip)),
                    FilterChip(
                        label: const Text('3D'),
                        selected: _model,
                        onSelected: (v) => setState(() => _model = v)),
                  ])),
              SizedBox(
                  height: (MediaQuery.sizeOf(context).height *
                          (MediaQuery.orientationOf(context) ==
                                  Orientation.landscape
                              ? .20
                              : .35))
                      .clamp(60, 300),
                  child: _model
                      ? TapeModelView(
                          tape: tape,
                          assets: app.stickers,
                          caseView: _case,
                          backView: _back,
                          onTrackTap: (i) => app.playback.playTracks(tape.tracks,
                              start: i, name: tape.name))
                      : Padding(
                          padding: const EdgeInsets.all(20),
                          child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(0)
                                ..rotateZ(0),
                              child: ListenableBuilder(
                                  listenable: app.playback,
                                  builder: (_, child) => AnimatedTapeArtwork(
                                      tape: tape,
                                      assets: app.stickers,
                                      caseView: _case,
                                      backView: _back,
                                      onTrackTap: (i) => app.playback
                                          .playTracks(tape.tracks,
                                              start: i, name: tape.name),
                                      playing: app.playback.playing &&
                                          app.playback.tapeName == tape.name))))),
              FilledButton.icon(
                  onPressed: tape.tracks.isEmpty
                      ? null
                      : () async {
                          await app.playback
                              .playTracks(tape.tracks, name: tape.name);
                          if (context.mounted)
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PlayerScreen(app: app)));
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Tocar fita')),
              Expanded(
                  child: TapeCatalog(
                      app: app, tape: tape, limit: _case && _back ? 10 : null)),
            ]));
      });
}
