import 'track_artwork.dart';
import 'package:flutter/material.dart';
import '../models/tape.dart';
import '../services/app_state.dart';

class TapeCatalog extends StatelessWidget {
  const TapeCatalog(
      {super.key,
      required this.app,
      required this.tape,
      this.limit,
      this.expanded = false,
      this.onExpandedChanged});
  final AppState app;
  final Tape tape;
  final int? limit;
  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;
  @override
  Widget build(BuildContext context) {
    final count = limit == null
        ? tape.tracks.length
        : tape.tracks.length.clamp(0, limit!);
    return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
            color: const Color(0xFFE9DFC9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45, blurRadius: 12, offset: Offset(0, 3))
            ]),
        child: Column(children: [
          if (onExpandedChanged != null)
            Tooltip(
                message: expanded ? 'Recolher catálogo' : 'Ampliar catálogo',
                child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onExpandedChanged!(!expanded),
                    onVerticalDragUpdate: (d) {
                      if (d.delta.dy.abs() > 2) onExpandedChanged!(true);
                    },
                    child: SizedBox(
                        height: 30,
                        width: double.infinity,
                        child: Icon(
                            expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            color: const Color(0xFF76513E))))),
          Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFB34C3C), width: 2))),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('CATÁLOGO',
                          style: TextStyle(
                              color: Color(0xFF665847),
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(tape.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF282A2A),
                              fontSize: 18,
                              fontWeight: FontWeight.w800))
                    ])),
                Text('$count',
                    style: const TextStyle(
                        color: Color(0xFF76513E),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ])),
          Expanded(
              child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: count,
                  itemBuilder: (context, i) {
                    final track = tape.tracks[i];
                    return Material(
                        color: Colors.transparent,
                        child: InkWell(
                            onTap: () => app.playback.playTracks(tape.tracks,
                                start: i, name: tape.name),
                            child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 62),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: const BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Color(0xFFBCAF95),
                                            width: .6))),
                                child: Row(children: [
                                  Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: TrackArtwork(
                                          uri: track.uri, size: 52)),
                                  Expanded(
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 9),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                        '${i + 1}'
                                                            .padLeft(2, '0'),
                                                        style: const TextStyle(
                                                            color: Color(
                                                                0xFF9B4538),
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            letterSpacing:
                                                                1.2))),
                                                const SizedBox(height: 4),
                                                Text(track.title,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFF282B2A),
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                                const SizedBox(height: 3),
                                                Text(track.artist,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFF746A5B),
                                                        fontSize: 11))
                                              ]))),
                                  IconButton(
                                      tooltip: 'Favorita',
                                      icon: Icon(
                                          app.favorites.contains(
                                                  track.uri.toString())
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 19,
                                          color: const Color(0xFFA14C3C)),
                                      onPressed: () async {
                                        try {
                                          await app.toggleFavorite(track);
                                        } catch (_) {
                                          if (context.mounted)
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Não foi possível salvar a favorita.')));
                                        }
                                      }),
                                ]))));
                  })),
        ]));
  }
}
