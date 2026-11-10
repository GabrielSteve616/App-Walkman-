import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tape.dart';
import '../services/app_state.dart';
import '../widgets/tape_artwork.dart';
import '../screens/tapes_screen.dart';

class TapeUnboxScreen extends StatefulWidget {
  const TapeUnboxScreen({super.key, required this.app, required this.tape});
  final AppState app;
  final Tape tape;
  @override
  State<TapeUnboxScreen> createState() => _TapeUnboxScreenState();
}

class _TapeUnboxScreenState extends State<TapeUnboxScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _opened = false;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _open();
      })
      ..forward();
  }

  void _open() {
    if (!mounted || _opened) return;
    _opened = true;
    Navigator.pushReplacement(
        context,
        PageRouteBuilder(
            pageBuilder: (_, a, b) =>
                TapeDetailScreen(app: widget.app, id: widget.tape.id),
            transitionsBuilder: (_, a, b, child) =>
                FadeTransition(opacity: a, child: child)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.tape.name), actions: [
          TextButton(onPressed: _open, child: const Text('Ver faixas'))
        ]),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: LayoutBuilder(
                  builder: (context, c) => AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        double phase(double a, double b) =>
                            Curves.easeInOutCubic.transform(
                                ((_controller.value - a) / (b - a))
                                    .clamp(0, 1));
                        final open = phase(.06, .43);
                        final lift = phase(.48, .62);
                        final pull = phase(.62, .84);
                        final finish = phase(.86, 1);
                        final width = math.min(
                            math.min(c.maxWidth * .78, 440.0),
                            c.maxHeight * .43 * caseAspect);
                        final height = width / caseAspect;
                        final angle = open * 2.32;
                        final trayY = height * .35;
                        final tapeY = trayY - height * 1.05 * pull;
                        // The tray and hinge stay fixed until the cassette clears the rim.
                        final tray = Opacity(
                            opacity: 1 - finish,
                            child: Transform.translate(
                                offset:
                                    Offset(0, trayY + height * .35 * finish),
                                child: Container(
                                    width: width,
                                    height: height,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF20292E),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                            color:
                                                Color(widget.tape.shellColor),
                                            width: 5),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Colors.black54,
                                              blurRadius: 20,
                                              offset: Offset(0, 12))
                                        ]),
                                    child: Stack(children: [
                                      Positioned.fill(
                                          child: Padding(
                                              padding: const EdgeInsets.all(9),
                                              child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF303A40),
                                                      border: Border.all(
                                                          color: Colors.black54,
                                                          width: 2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5))))),
                                      for (final x in [.30, .70])
                                        Positioned(
                                            left: width * x - 5,
                                            top: height * .54,
                                            child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: const BoxDecoration(
                                                    color: Color(0xFF83949C),
                                                    shape: BoxShape.circle))),
                                    ]))));
                        final lid = Opacity(
                            opacity: 1 - finish,
                            child: Transform.translate(
                                offset:
                                    Offset(0, trayY + height * .35 * finish),
                                child: Transform(
                                    alignment: Alignment.topCenter,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, .0007)
                                      ..rotateX(-angle),
                                    child: SizedBox(
                                        width: width,
                                        height: height,
                                        child: angle < math.pi / 2
                                            ? TapeArtwork(
                                                tape: widget.tape,
                                                assets: widget.app.stickers,
                                                caseView: true)
                                            : Container(
                                                decoration: BoxDecoration(
                                                    color: Color.lerp(
                                                        Color(widget
                                                            .tape.shellColor),
                                                        Colors.white,
                                                        .3)!,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFF72858F),
                                                        width: 5)),
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(11),
                                                    child: DecoratedBox(decoration: BoxDecoration(color: Color(widget.tape.caseColor), border: Border.all(color: Color(widget.tape.shellColor), width: 2)))))))));
                        final cassette = Transform.translate(
                            offset: Offset(0, tapeY * (1 - finish)),
                            child: Transform.scale(
                                scale: 1 + .04 * lift + .035 * finish,
                                child: Container(
                                    width: width * .90,
                                    decoration: BoxDecoration(boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withValues(
                                              alpha: .2 + .35 * lift),
                                          blurRadius: 8 + 22 * lift,
                                          offset: Offset(0, 3 + 14 * lift))
                                    ]),
                                    child: TapeArtwork(
                                        tape: widget.tape,
                                        assets: widget.app.stickers))));
                        // Center the visible assembly, including the open lid and lifted tape.
                        final trayCenter = trayY + height * .35 * finish;
                        final hingeY = trayCenter - height / 2;
                        final lidEdge = hingeY +
                            math.cos(angle) *
                                height /
                                (1 - .0007 * math.sin(angle) * height);
                        final cassetteCenter = tapeY * (1 - finish);
                        final cassetteHalf = width *
                            .90 /
                            tapeAspect /
                            2 *
                            (1 + .04 * lift + .035 * finish);
                        final top = math.min(math.min(hingeY, lidEdge),
                            cassetteCenter - cassetteHalf);
                        final bottom = math.max(
                            math.max(trayCenter + height / 2, lidEdge),
                            cassetteCenter + cassetteHalf);
                        final visibleTop = top * (1 - finish) +
                            (cassetteCenter - cassetteHalf) * finish;
                        final visibleBottom = bottom * (1 - finish) +
                            (cassetteCenter + cassetteHalf) * finish;
                        final centerOffset = -(visibleTop + visibleBottom) / 2;
                        return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) => _controller.stop(),
                            onVerticalDragUpdate: (d) => _controller.value =
                                (_controller.value -
                                        d.delta.dy / (c.maxHeight * .55))
                                    .clamp(0, 1),
                            child: SizedBox.expand(
                                child: Transform.translate(
                                    offset: Offset(0, centerOffset),
                                    child: Stack(
                                        alignment: Alignment.center,
                                        clipBehavior: Clip.none,
                                        children: [
                                          tray,
                                          // Once opened, the lid sits behind the cassette being lifted out.
                                          if (open > .95) lid,
                                          cassette,
                                          if (open <= .95) lid,
                                          if (pull < .15)
                                            Opacity(
                                                opacity: (1 - open).clamp(0, 1),
                                                child: Transform.translate(
                                                    offset: Offset(0,
                                                        trayY + height * .47),
                                                    child: Container(
                                                        width: width * .97,
                                                        height: 4,
                                                        color: const Color(
                                                            0xFF9BAEB6)))),
                                        ]))));
                      }))),
        ])),
      );
}
