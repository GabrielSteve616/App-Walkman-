import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../models/tape.dart';
import '../services/app_state.dart';
import 'tape_3d.dart';

class ShelfTape extends StatefulWidget {
  const ShelfTape(
      {super.key,
      required this.app,
      required this.tape,
      required this.child,
      required this.onOpen,
      this.onDragUpdate,
      this.onDragEnd});
  final AppState app;
  final Tape tape;
  final Widget child;
  final VoidCallback onOpen;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;
  @override
  State<ShelfTape> createState() => _ShelfTapeState();
}

class _ShelfTapeState extends State<ShelfTape> {
  Offset _down = Offset.zero;
  bool _moved = false;

  void _inspect() {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        enableDrag: false,
        useSafeArea: true,
        builder: (_) => _TapeInspection(app: widget.app, tape: widget.tape));
  }

  Future<void> _move(String id) async {
    try {
      await widget.app.moveTape(id, widget.tape.id);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível salvar a ordem das fitas.')));
    }
  }

  @override
  Widget build(BuildContext context) => DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != widget.tape.id,
        onAcceptWithDetails: (d) => _move(d.data),
        builder: (context, candidates, rejected) => Listener(
            onPointerDown: (e) {
              _down = e.position;
              _moved = false;
            },
            child: LongPressDraggable<String>(
              data: widget.tape.id,
              maxSimultaneousDrags: 1,
              delay: const Duration(milliseconds: 500),
              dragAnchorStrategy: (draggable, context, position) {
                final screen = MediaQuery.sizeOf(context);
                final left = (position.dx - 130).clamp(8.0, screen.width - 268);
                final top =
                    position.dy > 250 ? position.dy - 225 : position.dy + 20;
                return position - Offset(left, top);
              },
              feedback: Material(
                  elevation: 16,
                  color: const Color(0xFF22292E),
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                      width: 260,
                      height: 210,
                      child: Column(children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                            child: Text(widget.tape.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white))),
                        Expanded(
                            child: IgnorePointer(
                                child: TapeModelView(
                                    tape: widget.tape,
                                    assets: widget.app.stickers,
                                    caseView: true,
                                    previewOnly: true))),
                        const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                                'Arraste para organizar • solte para olhar',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white70)))
                      ]))),
              childWhenDragging: Opacity(opacity: .25, child: widget.child),
              onDragUpdate: (d) {
                if ((d.globalPosition - _down).distance > 18) _moved = true;
                if (_moved) widget.onDragUpdate?.call(d.globalPosition);
              },
              onDragEnd: (d) {
                widget.onDragEnd?.call();
                if (mounted && !_moved && !d.wasAccepted) _inspect();
              },
              child: Semantics(
                  button: true,
                  label: 'Segure para olhar ou arraste para organizar',
                  customSemanticsActions: {
                    const CustomSemanticsAction(label: 'Visualizar em 3D'):
                        _inspect,
                  },
                  child: InkWell(
                      onTap: widget.onOpen,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: candidates.isEmpty
                                      ? Colors.transparent
                                      : const Color(0xFFE8BB73),
                                  width: 2)),
                          child: widget.child))),
            )),
      );
}

class _TapeInspection extends StatefulWidget {
  const _TapeInspection({required this.app, required this.tape});
  final AppState app;
  final Tape tape;
  @override
  State<_TapeInspection> createState() => _TapeInspectionState();
}

class _TapeInspectionState extends State<_TapeInspection> {
  bool _case = true, _back = false;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .80,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: Text(widget.tape.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    tooltip: 'Fechar visualização',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ]),
              Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Fita')),
                          ButtonSegment(value: true, label: Text('Caixa'))
                        ],
                        selected: {
                          _case
                        },
                        onSelectionChanged: (v) =>
                            setState(() => _case = v.first)),
                    IconButton(
                        tooltip: _back ? 'Ver frente' : 'Ver verso',
                        icon: const Icon(Icons.flip),
                        onPressed: () => setState(() => _back = !_back)),
                  ]),
              Expanded(
                  child: TapeModelView(
                      tape: widget.tape,
                      assets: widget.app.stickers,
                      caseView: _case,
                      backView: _back)),
            ])),
      );
}
