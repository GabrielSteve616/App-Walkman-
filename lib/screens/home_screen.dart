import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/music_library.dart';
import '../services/companion_bridge.dart';
import '../animations/tape_unbox_screen.dart';
import 'library_screen.dart';
import 'tapes_screen.dart';
import 'stickers_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.state});
  final AppState? state;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppState _app;
  final _libraryKey = GlobalKey<LibraryScreenState>();
  int _selected = 0;
  CompanionBridge? _companion;
  @override
  void initState() {
    super.initState();
    _app = widget.state ?? AppState();
    if (!_app.loaded)
      unawaited(_app.load().then((_) {
        if (mounted && widget.state == null && _app.storageError == null) {
          _companion = CompanionBridge(_app, onAction: _widgetAction);
          unawaited(_companion!.attach());
          unawaited(recoverLostSticker(context, _app));
        }
      }));
  }

  @override
  void dispose() {
    _companion?.close();
    if (widget.state == null) _app.dispose();
    super.dispose();
  }

  Future<void> _widgetAction(String action, String id) async {
    if (!mounted) return;
    if (action == 'collection') {
      setState(() => _selected = 1);
      return;
    }
    if (action == 'tape') {
      final tape = _app.tapes.where((t) => t.id == id).firstOrNull;
      if (tape == null) {
        setState(() => _selected = 1);
        return;
      }
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TapeUnboxScreen(app: _app, tape: tape)));
      return;
    }
    if (action == 'resume' || action == 'player') {
      try {
        if (_app.playback.current == null) {
          final restored = await _companion?.restoreAndPlay() ?? false;
          if (!restored) {
            if (_app.tapes.isNotEmpty && _app.tapes.first.tracks.isNotEmpty) {
              await _app.playback.playTracks(_app.tapes.first.tracks,
                  name: _app.tapes.first.name);
            } else {
              final tracks = await const AndroidMusicLibrary().loadTracks();
              if (tracks.isNotEmpty) await _app.playback.playTracks(tracks);
            }
          }
        } else if (action == 'resume' && !_app.playback.playing) {
          await _app.playback.toggle();
        }
        if (mounted && _app.playback.current != null)
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => PlayerScreen(app: _app)));
      } catch (_) {
        if (mounted) {
          setState(() => _selected = 0);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Escolha sua pasta de músicas para começar.')));
        }
      }
    }
  }

  Future<void> _pinWidget(String kind) async {
    final added = await CompanionBridge.pin(kind);
    if (!added && mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Na tela inicial, pressione um espaço vazio e escolha Widgets → Walkmen.')));
  }

  void _libraryAction(VoidCallback action) {
    if (_selected == 0) {
      action();
      return;
    }
    setState(() => _selected = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        appBar: AppBar(
            titleSpacing: 12,
            title: Row(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/app_logo.png',
                      width: 40, height: 40)),
              const SizedBox(width: 10),
              const Text('Walkmen'),
            ]),
            actions: [
              IconButton(
                  tooltip: 'Pesquisar',
                  onPressed: () => _libraryAction(
                      () => _libraryKey.currentState?.toggleSearch()),
                  icon: const Icon(Icons.search)),
              IconButton(
                  tooltip: 'Atualizar músicas',
                  onPressed: () =>
                      _libraryAction(() => _libraryKey.currentState?.refresh()),
                  icon: const Icon(Icons.refresh)),
            ]),
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              ListenableBuilder(
                  listenable: _app,
                  builder: (_, child) => _app.storageError == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_app.storageError!,
                              style: const TextStyle(color: Colors.orange)))),
              Expanded(
                  child: IndexedStack(index: _selected, children: [
                LibraryScreen(
                    key: _libraryKey,
                    library: const AndroidMusicLibrary(),
                    app: _app),
                TapesScreen(app: _app),
                StickersScreen(app: _app),
                ListView(
                    padding: EdgeInsets.fromLTRB(
                        16, 16, 16, MediaQuery.paddingOf(context).bottom + 16),
                    children: [
                      Text('Ajustes',
                          style: Theme.of(context).textTheme.headlineSmall),
                      ListTile(
                          leading: const Icon(Icons.shelves),
                          title: const Text('Adicionar widget de prateleira'),
                          subtitle: const Text(
                              'Duas fitas lado a lado, com nomes e navegação.'),
                          onTap: () => _pinWidget('shelf')),
                      ListTile(
                          leading: const Icon(Icons.radio),
                          title: const Text('Adicionar widget Walkman'),
                          subtitle: const Text(
                              'Toque no aparelho para ouvir e controle a reprodução.'),
                          onTap: () => _pinWidget('walkman')),
                      ListTile(
                          leading: const Icon(Icons.folder_open),
                          title: const Text('Alterar pasta de músicas'),
                          subtitle: const Text(
                              'A pasta escolhida fica guardada no aplicativo.'),
                          onTap: () async {
                            await _libraryKey.currentState?.chooseFolder();
                            if (mounted) setState(() => _selected = 0);
                          }),
                      const ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('Walkmen 0.9.2'),
                          subtitle: Text(
                              'Músicas locais, favoritas, fitas, figurinhas e visualização 2D e 3D.')),
                    ]),
              ])),
            ])),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          MiniPlayer(app: _app),
          ClipRect(
              child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: NavigationBar(
                    backgroundColor: const Color(0x80191D21),
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    selectedIndex: _selected,
                    onDestinationSelected: (v) => setState(() => _selected = v),
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.library_music_outlined),
                          label: 'Biblioteca'),
                      NavigationDestination(
                          icon: Icon(Icons.album_outlined), label: 'Fitas'),
                      NavigationDestination(
                          icon: Icon(Icons.auto_awesome_outlined),
                          label: 'Figurinhas'),
                      NavigationDestination(
                          icon: Icon(Icons.settings_outlined),
                          label: 'Ajustes'),
                    ],
                  )))
        ]),
      );
}
