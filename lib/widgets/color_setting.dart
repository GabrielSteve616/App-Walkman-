import 'package:flutter/material.dart';

const walkmenColors = <String, int>{
  'Azul': 0xFF1768AD,
  'Vermelho': 0xFFD84B38,
  'Preto': 0xFF171B20,
  'Creme': 0xFFE6D8BE,
  'Verde': 0xFF4F8C72,
  'Roxo': 0xFF9359B2,
  'Laranja': 0xFFFF8A32,
  'Branco': 0xFFFFFFFF,
  'Rosa': 0xFFE17BA3,
  'Amarelo': 0xFFE8BD49
};

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
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final e in walkmenColors.entries)
            Tooltip(
                message: e.key,
                child: Semantics(
                    button: true,
                    selected: value == e.value,
                    label: title + ': ' + e.key,
                    child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => onChanged(e.value),
                        child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: Color(e.value),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: value == e.value
                                        ? Colors.orangeAccent
                                        : Colors.white24,
                                    width: value == e.value ? 3 : 1)),
                            child: value == e.value
                                ? Icon(Icons.check_rounded,
                                    size: 21,
                                    color: ThemeData.estimateBrightnessForColor(
                                                Color(e.value)) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black87)
                                : null))))
        ])
      ]));
}
