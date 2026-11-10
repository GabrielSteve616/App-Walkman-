import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkman/models/tape.dart';
import 'package:walkman/widgets/catalog_colors.dart';
import 'package:walkman/widgets/color_setting.dart';
import 'package:walkman/widgets/tape_artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Catálogo combina com as dez capas e mantém contraste legível', () {
    final papers = <Color>{};
    for (final color in walkmenColors.values) {
      for (final lettering in [null, color, 0xFFFFFFFF, 0xFF000000]) {
        final palette = CatalogColors(Tape(
            id: 't',
            name: '',
            tracks: [],
            caseColor: color,
            caseTextColor: lettering));
        papers.add(palette.paper);
        expect(colorContrast(palette.paper, palette.ink),
            greaterThanOrEqualTo(4.5));
        expect(colorContrast(palette.paper, palette.muted),
            greaterThanOrEqualTo(4.5));
        expect(colorContrast(palette.paper, palette.accent),
            greaterThanOrEqualTo(4.5));
      }
    }
    expect(papers.length, 10);
  });
  testWidgets(
      'Material cristalino tem corpo translúcido e laterais transparentes',
      (tester) async {
    await tester.runAsync(() async {
      Future<int> opacity(bool transparent, {bool edge = false}) async {
        final tape =
            Tape(id: 't', name: '', tracks: [], transparent: transparent);
        expect(Tape.fromJson(tape.toJson()).transparent, transparent);
        final image = edge
            ? await renderTapeEdge(tape, [], 0)
            : await renderTapeTexture(tape, []);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final x = (image.width * .90).floor(), y = (image.height * .80).floor();
        final alpha = data!.getUint8((y * image.width + x) * 4 + 3);
        image.dispose();
        return alpha;
      }

      expect(await opacity(false), 255);
      expect(await opacity(true), lessThan(220));
      expect(await opacity(false, edge: true), 255);
      expect(await opacity(true, edge: true), lessThan(150));
    });
  });
}
