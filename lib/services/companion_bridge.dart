import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../models/local_track.dart';
import '../widgets/tape_artwork.dart';
import 'app_state.dart';

class CompanionBridge {
  CompanionBridge(this.app, {required this.onAction});
  static const channel = MethodChannel('walkmen/companion');
  final AppState app;
  final Future<void> Function(String action, String id) onAction;
  final Map<String, String> _keys = {}, _images = {};
  bool _closed = false, _syncing = false, _again = false;
  Object? _queue;
  int _index = -1;
  Future<void> attach() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'hostAttached' && !_closed) {
        final data = await channel.invokeMapMethod<String, dynamic>('ready');
        if (data != null && !_closed)
          await onAction(data['action'] ?? '', data['id'] ?? '');
      }
      if (call.method == 'launch' && !_closed) {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        await onAction(data['action'] ?? '', data['id'] ?? '');
      }
    });
    app.addListener(_collectionChanged);
    app.playback.addListener(_playbackChanged);
    unawaited(_sync());
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('ready');
      if (data != null && !_closed)
        await onAction(data['action'] ?? '', data['id'] ?? '');
    } on PlatformException {
    } on MissingPluginException {}
  }

  void _collectionChanged() {
    unawaited(_sync());
  }

  Future<void> _sync() async {
    if (_closed || !app.loaded || app.storageError != null) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      final rows = <Map<String, String>>[];
      for (final tape in List.of(app.tapes)) {
        final key = jsonEncode(tape.toJson());
        if (_keys[tape.id] != key) {
          final image =
              await renderTapeTexture(tape, app.stickers, caseView: true);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          if (bytes != null) {
            _images[tape.id] = await app.store
                .saveImage(bytes.buffer.asUint8List(), 'widget_${tape.id}');
            _keys[tape.id] = key;
          }
        }
        rows.add({
          'id': tape.id,
          'name': tape.name,
          'image': _images[tape.id] ?? ''
        });
      }
      if (!_closed)
        await channel.invokeMethod<void>('syncWidgets',
            {'tapes': jsonEncode(rows)}).timeout(const Duration(seconds: 4));
    } catch (_) {
      /* Widgets can be refreshed next time the app opens. */
    } finally {
      _syncing = false;
      if (_again && !_closed) {
        _again = false;
        unawaited(_sync());
      }
    }
  }

  void _playbackChanged() {
    final p = app.playback;
    if (p.queue.isEmpty || _closed) return;
    final changed = !identical(_queue, p.queue);
    if (!changed && _index == p.index) return;
    _queue = p.queue;
    _index = p.index;
    final data = <String, dynamic>{
      'index': p.index,
      'name': p.tapeName ?? '',
      if (changed) 'queue': jsonEncode(p.queue.map((t) => t.toJson()).toList())
    };
    unawaited(channel
        .invokeMethod<void>('savePlayback', data)
        .timeout(const Duration(seconds: 4))
        .catchError((Object e) {}));
  }

  Future<bool> restoreAndPlay() async {
    final data =
        await channel.invokeMapMethod<String, dynamic>('restorePlayback');
    final list = jsonDecode(data?['queue'] ?? '[]') as List;
    if (list.isEmpty) return false;
    final tracks = list
        .map((row) => LocalTrack.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    await app.playback.playTracks(tracks,
        start: (data?['index'] as int? ?? 0).clamp(0, tracks.length - 1),
        name: (data?['name'] as String?)?.isNotEmpty == true
            ? data!['name'] as String
            : null);
    return true;
  }

  static Future<bool> pin(String kind) async {
    try {
      return await channel.invokeMethod<bool>('pinWidget', {'kind': kind}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  void close() {
    _closed = true;
    app.removeListener(_collectionChanged);
    app.playback.removeListener(_playbackChanged);
    channel.setMethodCallHandler(null);
  }
}
