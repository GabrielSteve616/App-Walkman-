import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TrackArtwork extends StatelessWidget {
  const TrackArtwork({super.key, required this.uri, this.size = 52});
  final Uri uri;
  final double size;
  static const _channel = MethodChannel('walkman/library');
  static final _cache = LinkedHashMap<String, Future<Uint8List?>>();
  static Future<Uint8List?> _read(String uri) async {
    try {
      return await _channel.invokeMethod<Uint8List>('artwork', {'uri': uri});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = uri.toString();
    final future = _cache.remove(key) ?? _read(key);
    _cache[key] = future;
    while (_cache.length > 96) {
      _cache.remove(_cache.keys.first);
    }
    final placeholder = ColoredBox(
        color: const Color(0xFF333A43),
        child: Center(
            child: Icon(Icons.album,
                color: Colors.orange.shade200, size: size * .5)));
    return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
            width: size,
            height: size,
            child: FutureBuilder<Uint8List?>(
                future: future,
                builder: (context, snapshot) => snapshot.data == null
                    ? placeholder
                    : Image.memory(snapshot.data!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, error, stack) => placeholder))));
  }
}
