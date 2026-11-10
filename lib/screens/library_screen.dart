import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/local_track.dart';
import '../services/music_library.dart';
import '../services/app_state.dart';
import '../widgets/status_panel.dart';
import '../widgets/track_artwork.dart';
import 'tape_editor_screen.dart';

enum LibraryView { folders, songs, favorites }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.library, this.app});
  final MusicLibrary library;
  final AppState? app;
  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  late Future<List<LocalTrack>> _tracks;
  String _query = '';
  bool _searchVisible = false, _choosing = false;
  LibraryView _view = LibraryView.folders;
  String? _folder;
  List<String> _folders = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.app?.addListener(_appChanged);
    _tracks = _load();
  }

  void _appChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.app?.removeListener(_appChanged);
    _search.dispose();
    super.dispose();
  }

  Future<List<LocalTrack>> _load() async {
    final tracks = await widget.library.loadTracks();
    if (widget.library is AndroidMusicLibrary) {
      _folders = await (widget.library as AndroidMusicLibrary).folders();
    }
    return tracks;
  }

  void refresh() => setState(() {
        _tracks = _load();
      });
  void toggleSearch() => setState(() {
        _searchVisible = !_searchVisible;
        if (!_searchVisible) {
          _query = '';
          _search.clear();
        }
      });
  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> chooseFolder() async {
    final library = widget.library;
    if (library is! AndroidMusicLibrary || _choosing) return;
    setState(() => _choosing = true);
    try {
      if (await library.chooseFolder() && mounted) {
        _folder = null;
        _view = LibraryView.folders;
        refresh();
      }
    } on PlatformException catch (e) {
      _message(e.message ?? 'Não foi possível abrir a pasta.');
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  Future<String?> _askName(String title, String initial) async {
    final input = TextEditingController(text: initial);
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: input,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
                  }),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () {
                      if (input.text.trim().isNotEmpty)
                        Navigator.pop(context, input.text.trim());
                    },
                    child: const Text('Continuar'))
              ],
            ));
    // The dialog owns a closing animation, so release its controller after it.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
    return result;
  }

  Future<void> _newFolder() async {
    final library = widget.library;
    if (library is! AndroidMusicLibrary) return;
    final name = await _askName('Criar subpasta', '');
    if (name == null || !mounted) return;
    try {
      await library.createFolder(name);
      if (mounted) {
        refresh();
        _message('Pasta criada dentro da pasta de músicas.');
      }
    } on PlatformException catch (e) {
      _message(e.message ?? 'Não foi possível criar a pasta.');
    }
  }

  List<LocalTrack> _inFolder(List<LocalTrack> all, String folder) => all
      .where((t) =>
          t.folder.replaceAll(RegExp(r'/+$'), '') ==
              folder.replaceAll(RegExp(r'/+$'), '') ||
          t.folder.startsWith('${folder.replaceAll(RegExp(r'/+$'), '')}/'))
      .toList();
  Future<void> _createTape(List<LocalTrack> tracks, String folder) async {
    final app = widget.app;
    if (app == null || !app.loaded || tracks.isEmpty) return;
    final name = await _askName(
        'Criar fita desta pasta',
        folder.split('/').where((s) => s.isNotEmpty).lastOrNull ??
            'Minha fita');
    if (name == null || !mounted) return;
    final saved = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                TapeEditorScreen(app: app, tape: app.newTape(name, tracks))));
    if (saved != null) _message('Fita salva na aba Fitas.');
  }

  void _showLocation(LocalTrack track) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: Text(track.title),
              content: SelectableText(
                  'Local da música:\n${track.folder}\n\nReferência do arquivo:\n${track.uri}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'))
              ]));
  Future<void> _favorite(LocalTrack track) async {
    try {
      await widget.app?.toggleFavorite(track);
    } catch (_) {
      _message('Não foi possível salvar a favorita.');
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(children: [
              if (_folder != null)
                IconButton(
                    tooltip: 'Voltar às pastas',
                    onPressed: () => setState(() {
                          _folder = null;
                          _view = LibraryView.folders;
                        }),
                    icon: const Icon(Icons.arrow_back)),
              Expanded(
                  child: Text(
                      _folder == null
                          ? (_view == LibraryView.favorites
                              ? 'Favoritas'
                              : 'Biblioteca')
                          : _folder!
                                  .split('/')
                                  .where((s) => s.isNotEmpty)
                                  .lastOrNull ??
                              'Pasta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'Pastas',
                  onPressed: () => setState(() {
                        _view = LibraryView.folders;
                        _folder = null;
                      }),
                  icon: const Icon(Icons.folder_outlined)),
              IconButton(
                  tooltip: 'Favoritas',
                  onPressed: () => setState(() {
                        _view = LibraryView.favorites;
                        _folder = null;
                      }),
                  color: _view == LibraryView.favorites ? Colors.orange : null,
                  icon: const Icon(Icons.favorite_border)),
              if (widget.library is AndroidMusicLibrary)
                IconButton(
                    tooltip: 'Criar pasta',
                    onPressed: _newFolder,
                    icon: const Icon(Icons.create_new_folder_outlined)),
            ])),
        if (_searchVisible)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                  controller: _search,
                  autofocus: true,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                      labelText: 'Pesquisar músicas e pastas',
                      prefixIcon: Icon(Icons.search)))),
        Expanded(
            child: FutureBuilder<List<LocalTrack>>(
                future: _tracks,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    return SingleChildScrollView(
                        child: Column(children: [
                      StatusPanel(
                          icon: Icons.folder_open,
                          title: error is LibraryUnavailable &&
                                  error.code == 'CHOOSE_FOLDER'
                              ? 'Onde estão suas músicas?'
                              : 'Acesso à pasta de músicas',
                          message: error is LibraryUnavailable
                              ? error.message
                              : 'Não foi possível abrir os arquivos.'),
                      if (widget.library is AndroidMusicLibrary)
                        FilledButton.icon(
                            onPressed: _choosing ? null : chooseFolder,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Escolher pasta de músicas')),
                    ]));
                  }
                  final all = snapshot.data ?? [];
                  var tracks = _folder == null ? all : _inFolder(all, _folder!);
                  if (_view == LibraryView.favorites) {
                    final saved = <String, LocalTrack>{
                      ...?widget.app?.favoriteTracks
                    };
                    for (final track in all) {
                      if (widget.app?.favorites
                              .contains(track.uri.toString()) ??
                          false) saved[track.uri.toString()] = track;
                    }
                    tracks = saved.values.toList();
                  }
                  tracks = tracks
                      .where((t) =>
                          '${t.title} ${t.artist} ${t.album} ${t.folder}'
                              .toLowerCase()
                              .contains(_query))
                      .toList();
                  if (_view == LibraryView.folders && _query.isEmpty) {
                    final folders = <String>{
                      ..._folders,
                      ...all.map((t) => t.folder)
                    }.toList()
                      ..sort();
                    if (folders.isEmpty)
                      return const StatusPanel(
                          icon: Icons.folder_open,
                          title: 'Pasta vazia',
                          message:
                              'Adicione músicas pelo gerenciador e toque no ícone de atualizar.');
                    return ListView.builder(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.paddingOf(context).bottom),
                        itemCount: folders.length,
                        itemBuilder: (context, i) {
                          final folder = folders[i],
                              list = _inFolder(all, folder);
                          return ListTile(
                              leading: list.isEmpty
                                  ? const Icon(Icons.folder_outlined, size: 42)
                                  : TrackArtwork(uri: list.first.uri),
                              title: Text(folder
                                      .split('/')
                                      .where((s) => s.isNotEmpty)
                                      .lastOrNull ??
                                  folder),
                              subtitle:
                                  Text('${list.length} músicas', maxLines: 2),
                              tileColor: const Color(0xFF223038),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              onTap: () => setState(() {
                                    _folder = folder;
                                    _view = LibraryView.songs;
                                  }),
                              trailing: PopupMenuButton<String>(
                                  tooltip: 'Opções da pasta',
                                  onSelected: (value) {
                                    if (value == 'tape')
                                      _createTape(list, folder);
                                    else
                                      setState(() {
                                        _folder = folder;
                                        _view = LibraryView.songs;
                                      });
                                  },
                                  itemBuilder: (_) => [
                                        const PopupMenuItem(
                                            value: 'open',
                                            child: Text('Abrir pasta')),
                                        PopupMenuItem(
                                            value: 'tape',
                                            enabled: list.isNotEmpty &&
                                                (widget.app?.loaded ?? false),
                                            child: const Text('Criar fita'))
                                      ]));
                        });
                  }
                  if (tracks.isEmpty)
                    return StatusPanel(
                        icon: _view == LibraryView.favorites
                            ? Icons.favorite_border
                            : Icons.music_off,
                        title: _view == LibraryView.favorites
                            ? 'Nenhuma favorita ainda'
                            : (_query.isEmpty
                                ? 'Pasta sem músicas'
                                : 'Sem resultados'),
                        message: _view == LibraryView.favorites
                            ? 'Toque no coração de uma música para guardá-la aqui.'
                            : 'Adicione arquivos de áudio ou tente outra pesquisa.');
                  return Column(children: [
                    if (_folder != null && widget.app != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            Expanded(
                                child: Text('${tracks.length} músicas',
                                    style: const TextStyle(
                                        color: Colors.white60))),
                            FilledButton.tonalIcon(
                                onPressed: () => _createTape(tracks, _folder!),
                                icon: const Icon(Icons.album),
                                label: const Text('Criar fita')),
                          ])),
                    Expanded(
                        child: ListView.builder(
                            padding: EdgeInsets.only(
                                bottom: MediaQuery.paddingOf(context).bottom),
                            itemCount: tracks.length,
                            itemBuilder: (context, index) {
                              final track = tracks[index];
                              return ListTile(
                                  leading: TrackArtwork(uri: track.uri),
                                  title: Text(track.title),
                                  subtitle: Text(
                                      '${track.artist} • ${track.album}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  onTap: widget.app == null
                                      ? () => _showLocation(track)
                                      : () => widget.app!.playback
                                          .playTracks(tracks, start: index),
                                  onLongPress: () => _showLocation(track),
                                  trailing: widget.app == null
                                      ? null
                                      : IconButton(
                                          tooltip: 'Favoritar música',
                                          onPressed: () => _favorite(track),
                                          icon: Icon(
                                              widget.app!.favorites.contains(
                                                      track.uri.toString())
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: Colors.orange)));
                            })),
                  ]);
                })),
      ]);
}
