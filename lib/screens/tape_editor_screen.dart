import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/tape.dart';
import '../services/app_state.dart';
import '../widgets/tape_artwork.dart';
import '../widgets/color_setting.dart';
import '../widgets/tape_3d.dart';
import 'stickers_screen.dart';

class TapeEditorScreen extends StatefulWidget {
  const TapeEditorScreen({super.key, required this.app, required this.tape});
  final AppState app;
  final Tape tape;
  @override
  State<TapeEditorScreen> createState() => _TapeEditorScreenState();
}

class _TapeEditorScreenState extends State<TapeEditorScreen> {
  late Tape _draft;
  late TextEditingController _name, _description;
  bool _case = false,
      _saving = false,
      _back = false,
      _model = false,
      _placing = false;
  int? _selected;
  @override
  void initState() {
    super.initState();
    _draft = widget.tape.copy();
    _name = TextEditingController(text: _draft.name);
    _description = TextEditingController(text: _draft.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _message('Dê um nome à fita.');
      return;
    }
    setState(() => _saving = true);
    try {
      _draft.name = _name.text.trim();
      _draft.description = _description.text.trim();
      await widget.app.saveTape(_draft);
      if (mounted) Navigator.pop(context, _draft);
    } catch (_) {
      _message('Não foi possível salvar a fita. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addSticker() async {
    final chosen = await showModalBottomSheet<StickerAsset>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: 420,
                child: Column(children: [
                  ListTile(
                      title: const Text('Adicionar figurinha'),
                      trailing: TextButton(
                          onPressed: () async {
                            final asset =
                                await importSticker(context, widget.app);
                            if (context.mounted && asset != null)
                              Navigator.pop(context, asset);
                          },
                          child: const Text('Criar nova'))),
                  Expanded(
                      child: ListenableBuilder(
                          listenable: widget.app,
                          builder: (context, _) => widget.app.stickers.isEmpty
                              ? const Center(
                                  child: Text('Crie sua primeira figurinha.'))
                              : GridView.count(crossAxisCount: 3, children: [
                                  for (final s in widget.app.stickers)
                                    InkWell(
                                        onTap: () => Navigator.pop(context, s),
                                        child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Image.file(File(s.path),
                                                errorBuilder: (_, e, st) =>
                                                    const Icon(
                                                        Icons.broken_image)))),
                                ]))),
                ]))));
    if (chosen != null && mounted)
      setState(() {
        _draft.stickers.add(
            StickerPlacement(assetId: chosen.id, onCase: _case, back: _back));
        _selected = _draft.stickers.length - 1;
        _placing = true;
      });
  }

  Future<void> _cover() async {
    try {
      final image = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600);
      if (image == null) return;
      final path = await widget.app.store.saveImage(await image.readAsBytes(),
          'cover_${DateTime.now().microsecondsSinceEpoch}');
      if (mounted) setState(() => _draft.coverPath = path);
    } catch (_) {
      _message('Não foi possível adicionar a capa.');
    }
  }

  Future<void> _labelPhoto() async {
    final back = _back;
    try {
      final image = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600);
      if (image == null) return;
      final path = await widget.app.store.saveImage(await image.readAsBytes(),
          'label_' + DateTime.now().microsecondsSinceEpoch.toString());
      if (mounted)
        setState(() {
          if (back) {
            _draft.labelBackPath = path;
          } else {
            _draft.labelFrontPath = path;
          }
        });
    } catch (_) {
      _message('Não foi possível adicionar a foto ao rótulo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected != null && _selected! < _draft.stickers.length
        ? _draft.stickers[_selected!]
        : null;
    return Scaffold(
        appBar: AppBar(title: const Text('Personalizar fita'), actions: [
          TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando…' : 'Salvar'))
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Fita')),
                ButtonSegment(value: true, label: Text('Caixa / capa'))
              ],
              selected: {
                _case
              },
              onSelectionChanged: (v) => setState(() {
                    _case = v.first;
                    _selected = null;
                  })),
          const SizedBox(height: 16),
          Row(children: [
            FilterChip(
                label: const Text('Editar em 3D'),
                selected: _model,
                onSelected: (v) => setState(() => _model = v)),
            const SizedBox(width: 8),
            TextButton.icon(
                onPressed: () => setState(() {
                      _back = !_back;
                      _selected = null;
                      _placing = false;
                    }),
                icon: const Icon(Icons.flip),
                label: Text(_back ? 'Verso' : 'Frente')),
          ]),
          if (_model) ...[
            SizedBox(
                height: 360,
                child: TapeModelView(
                    tape: _draft,
                    assets: widget.app.stickers,
                    caseView: _case,
                    backView: _back,
                    placingSticker: _placing && selected != null,
                    onPlace: (hit) {
                      if (selected != null)
                        setState(() {
                          selected.x = hit.uv.dx.clamp(.02, .98);
                          selected.y = hit.uv.dy.clamp(.02, .98);
                          selected.back = hit.back;
                          _back = hit.back;
                        });
                    })),
            SegmentedButton<bool>(segments: const [
              ButtonSegment(value: false, label: Text('Girar modelo')),
              ButtonSegment(value: true, label: Text('Posicionar adesivo'))
            ], selected: {
              _placing
            }, onSelectionChanged: (v) => setState(() => _placing = v.first)),
          ] else
            LayoutBuilder(
                builder: (context, c) => Center(
                    child: SizedBox(
                        width: c.maxWidth,
                        child: LayoutBuilder(
                            builder: (context, preview) => GestureDetector(
                                onPanUpdate: selected == null
                                    ? null
                                    : (d) => setState(() {
                                          selected.x = (selected.x +
                                                  d.delta.dx / preview.maxWidth)
                                              .clamp(.02, .98);
                                          selected.y = (selected.y +
                                                  d.delta.dy /
                                                      (preview.maxWidth /
                                                          (_case
                                                              ? caseAspect
                                                              : tapeAspect)))
                                              .clamp(.02, .98);
                                        }),
                                child: TapeArtwork(
                                    tape: _draft,
                                    assets: widget.app.stickers,
                                    caseView: _case,
                                    backView: _back,
                                    selected: _selected)))))),
          const SizedBox(height: 16),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome da fita'),
              onChanged: (v) => setState(() => _draft.name = v)),
          const SizedBox(height: 12),
          TextField(
              controller: _description,
              decoration:
                  const InputDecoration(labelText: 'Descrição / etiqueta'),
              onChanged: (v) => setState(() => _draft.description = v)),
          const SizedBox(height: 16),
          if (_case) ...[
            ColorSetting(
                title: 'Cor da case (plástico)',
                value: _draft.shellColor,
                onChanged: (v) => setState(() => _draft.shellColor = v)),
            ColorSetting(
                title: 'Cor da capa da case',
                value: _draft.caseColor,
                onChanged: (v) => setState(() => _draft.caseColor = v)),
            ColorSetting(
                title: 'Cor das letras da case',
                value: _draft.caseTextColor ?? 0xFFF1E7D1,
                onChanged: (v) => setState(() => _draft.caseTextColor = v)),
          ] else ...[
            ColorSetting(
                title: 'Cor da fita',
                value: _draft.color,
                onChanged: (v) => setState(() => _draft.color = v)),
            ColorSetting(
                title: 'Cor do rótulo (retângulo branco)',
                value: _draft.labelColor,
                onChanged: (v) => setState(() => _draft.labelColor = v)),
            ColorSetting(
                title: 'Cor das letras da fita',
                value: _draft.textColor,
                onChanged: (v) => setState(() => _draft.textColor = v)),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                  onPressed: _labelPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_back
                      ? 'Foto no rótulo do verso'
                      : 'Foto no rótulo da frente')),
              if ((_back ? _draft.labelBackPath : _draft.labelFrontPath) !=
                  null)
                TextButton(
                    onPressed: () => setState(() {
                          if (_back) {
                            _draft.labelBackPath = null;
                          } else {
                            _draft.labelFrontPath = null;
                          }
                        }),
                    child: const Text('Remover foto do rótulo')),
            ]),
            const Text(
                'A foto fica no retângulo do rótulo, atrás do nome. Escolha Frente ou Verso na prévia.',
                style: TextStyle(fontSize: 12, color: Colors.white60)),
          ],
          if (!_case) ...[
            const SizedBox(height: 10),
            SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      icon: Icon(Icons.album_rounded),
                      label: Text('Sólida')),
                  ButtonSegment(
                      value: true,
                      icon: Icon(Icons.diamond_outlined),
                      label: Text('Cristalina')),
                ],
                selected: {
                  _draft.transparent
                },
                onSelectionChanged: (v) =>
                    setState(() => _draft.transparent = v.first)),
            const SizedBox(height: 10),
          ],
          if (_case)
            Wrap(spacing: 8, children: [
              TextButton.icon(
                  onPressed: _cover,
                  icon: const Icon(Icons.image),
                  label: const Text('Imagem da capa')),
              if (_draft.coverPath != null)
                TextButton(
                    onPressed: () => setState(() => _draft.coverPath = null),
                    child: const Text('Remover capa'))
            ]),
          FilledButton.tonalIcon(
              onPressed: _addSticker,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Adicionar figurinha')),
          Wrap(spacing: 6, children: [
            for (var i = 0; i < _draft.stickers.length; i++)
              if (_draft.stickers[i].onCase == _case &&
                  _draft.stickers[i].back == _back)
                InputChip(
                    label: Text('Figurinha ${i + 1}'),
                    selected: _selected == i,
                    onPressed: () => setState(() {
                          _selected = i;
                          _placing = true;
                        }),
                    onDeleted: () => setState(() {
                          _draft.stickers.removeAt(i);
                          _selected = null;
                        }))
          ]),
          if (selected != null) ...[
            const Text('Arraste a figurinha na prévia para posicionar.'),
            TextButton.icon(
                onPressed: () => setState(() {
                      selected.back = !selected.back;
                      _back = selected.back;
                      _placing = false;
                    }),
                icon: const Icon(Icons.flip),
                label: Text(selected.back
                    ? 'Mover para a frente'
                    : 'Mover para o verso')),
            Row(children: [
              const Text('Tamanho'),
              Expanded(
                  child: Slider(
                      value: selected.width.clamp(.08, .8),
                      min: .08,
                      max: .8,
                      onChanged: (v) => setState(() => selected.width = v)))
            ]),
            Row(children: [
              const Text('Rotação'),
              Expanded(
                  child: Slider(
                      value: selected.angle,
                      min: -math.pi,
                      max: math.pi,
                      onChanged: (v) => setState(() => selected.angle = v)))
            ]),
            TextButton(
                onPressed: () => setState(() {
                      selected.onCase = !selected.onCase;
                      _selected = null;
                    }),
                child: Text(_case ? 'Mover para a fita' : 'Mover para a capa')),
          ],
          const SizedBox(height: 12),
          Text('${_draft.tracks.length} músicas • arraste para ordenar',
              style: Theme.of(context).textTheme.titleMedium),
          ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _draft.tracks.length,
              onReorderItem: (old, next) => setState(() {
                    final track = _draft.tracks.removeAt(old);
                    _draft.tracks.insert(next, track);
                  }),
              itemBuilder: (context, i) => ListTile(
                  key: ValueKey('${_draft.tracks[i].uri}:$i'),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(_draft.tracks[i].title),
                  trailing: IconButton(
                      tooltip: 'Retirar da fita',
                      onPressed: () =>
                          setState(() => _draft.tracks.removeAt(i)),
                      icon: const Icon(Icons.remove_circle_outline)))),
        ]));
  }
}
