import 'package:flutter/material.dart';

class ColorSetting extends StatelessWidget {
  const ColorSetting(
      {super.key,
      required this.title,
      required this.value,
      required this.onChanged});
  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: Color(value),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38))),
        trailing: const Icon(Icons.palette_outlined),
        onTap: () async {
          final result = await showDialog<int>(
              context: context,
              builder: (_) => _ColorDialog(title: title, value: value));
          if (result != null) onChanged(result);
        },
      );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.title, required this.value});
  final String title;
  final int value;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late HSVColor _color;
  late TextEditingController _hex;
  bool _valid = true;
  String _code(Color c) =>
      c.toARGB32().toRadixString(16).substring(2).toUpperCase();
  @override
  void initState() {
    super.initState();
    _color = HSVColor.fromColor(Color(widget.value));
    _hex = TextEditingController(text: _code(_color.toColor()));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(HSVColor c) => setState(() {
        _color = c;
        _hex.text = _code(c.toColor());
        _valid = true;
      });
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        scrollable: true,
        content: SizedBox(
            width: 300,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  height: 42,
                  decoration: BoxDecoration(
                      color: _color.toColor(),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white38))),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final value in [
                  0xFF1768AD,
                  0xFFD84B38,
                  0xFF20262C,
                  0xFFE6D8BE,
                  0xFF4F8C72,
                  0xFFA958AC,
                  0xFFEBA83F,
                  0xFFFFFFFF,
                  0xFF000000
                ])
                  InkWell(
                      onTap: () => _set(HSVColor.fromColor(Color(value))),
                      child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white38))))
              ]),
              const SizedBox(height: 10),
              const Align(
                  alignment: Alignment.centerLeft, child: Text('Tonalidade')),
              Slider(
                  value: _color.hue,
                  max: 360,
                  onChanged: (v) => _set(_color.withHue(v))),
              const Align(
                  alignment: Alignment.centerLeft, child: Text('Intensidade')),
              Slider(
                  value: _color.saturation,
                  onChanged: (v) => _set(_color.withSaturation(v))),
              const Align(
                  alignment: Alignment.centerLeft, child: Text('Brilho')),
              Slider(
                  value: _color.value,
                  onChanged: (v) => _set(_color.withValue(v))),
              TextField(
                  controller: _hex,
                  maxLength: 6,
                  decoration: InputDecoration(
                      labelText: 'Código da cor',
                      prefixText: '#',
                      errorText:
                          _valid ? null : 'Use 6 letras ou números de 0 a F.'),
                  onChanged: (v) => setState(() {
                        _valid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v);
                        if (_valid)
                          _color = HSVColor.fromColor(
                              Color(0xFF000000 | int.parse(v, radix: 16)));
                      })),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: _valid
                  ? () => Navigator.pop(context, _color.toColor().toARGB32())
                  : null,
              child: const Text('Aplicar cor'))
        ],
      );
}
