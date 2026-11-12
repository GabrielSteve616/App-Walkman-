import 'package:flutter/material.dart';
import '../models/tape.dart';

double colorContrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

class CatalogColors {
  CatalogColors(Tape tape) {
    final base = Color(tape.caseColor);
    paper = base.computeLuminance() < .16
        ? Color.lerp(base, const Color(0xFF151C23), .55)!
        : Color.lerp(base, const Color(0xFFF5EFDF), .64)!;
    const pale = Color(0xFFF4ECD9), dark = Color(0xFF11181D);
    final automatic =
        colorContrast(pale, paper) >= colorContrast(dark, paper) ? pale : dark;
    final custom =
        tape.caseTextColor == null ? automatic : Color(tape.caseTextColor!);
    ink = colorContrast(custom, paper) >= 4.5 ? custom : automatic;
    final mutedCandidate = Color.lerp(ink, paper, .24)!;
    muted = colorContrast(mutedCandidate, paper) >= 4.5 ? mutedCandidate : ink;
    final color = Color(tape.color);
    accent = colorContrast(color, paper) >= 4.5 ? color : ink;
    line = Color.lerp(ink, paper, .82)!;
  }
  late final Color paper, ink, muted, accent, line;
}
