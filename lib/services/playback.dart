import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/local_track.dart';
import 'playlist_loader.dart';

class Playback extends ChangeNotifier {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<LocalTrack> queue = [];
  int index = 0;
  bool busy = false;
  String? error;
  String? tapeName;
  bool get playing => _player?.playing ?? false;
  bool _savedShuffle = false;
  LoopMode _savedLoop = LoopMode.off;
  double _savedVolume = 1;
  bool get shuffle => _player?.shuffleModeEnabled ?? _savedShuffle;
  LoopMode get loop => _player?.loopMode ?? _savedLoop;
  double get volume => _player?.volume ?? _savedVolume;
  Map<String, dynamic> get preferences =>
      {'volume': volume, 'shuffle': shuffle, 'loop': loop.index};
  Future<void> applyPreferences(Map<String, dynamic> settings) async {
    _savedVolume = (settings['volume'] as num? ?? 1).toDouble().clamp(0, 1);
    _savedShuffle = settings['shuffle'] as bool? ?? false;
    final index =
        (settings['loop'] as int? ?? 0).clamp(0, LoopMode.values.length - 1);
    _savedLoop = LoopMode.values[index];
    final p = _player;
    if (p != null) {
      await p.setVolume(_savedVolume);
      await p.setShuffleModeEnabled(_savedShuffle);
      await p.setLoopMode(_savedLoop);
    }
    _changed();
  }

  Duration get position => _player?.position ?? Duration.zero;
  Duration get duration =>
      _player?.duration ?? current?.duration ?? Duration.zero;
  LocalTrack? get current =>
      queue.isEmpty ? null : queue[index.clamp(0, queue.length - 1)];
  bool _disposed = false;
  bool _queueReady = false;
  ({List<LocalTrack> tracks, int start, String? name})? _pendingPlay;
  ({Duration start, Duration? end})? _nextRange;
  Duration? _rangeEnd;
  Future<void> playFrom(LocalTrack track, Duration start) async {
    if (busy || start < Duration.zero) return;
    _rangeEnd = null;
    final target = queue.indexWhere((t) => t.uri == track.uri);
    if (_player != null && _queueReady && target >= 0) {
      await _action((p) async {
        await p.seek(start, index: target);
        unawaited(p.play().catchError((Object e) {
          error = 'Falha na reprodução.';
          _changed();
        }));
      });
    } else {
      _nextRange = (start: start, end: null);
      await playTracks([track], name: track.album);
    }
  }

  Future<void> playRange(LocalTrack track, Duration start, Duration end) async {
    if (busy || start < Duration.zero || end <= start) return;
    _nextRange = (start: start, end: end);
    await playTracks([track], name: track.title);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<AudioPlayer> _ensure() async {
    if (_player != null) return _player!;
    try {
      await const MethodChannel('walkmen/companion')
          .invokeMethod<bool>('ensureNotifications')
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      /* Media playback remains available if notifications are denied. */
    }
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final player = _player = AudioPlayer(maxSkipsOnError: 5);
    await player.setVolume(_savedVolume);
    await player.setShuffleModeEnabled(_savedShuffle);
    await player.setLoopMode(_savedLoop);
    _subscriptions.add(player.playerStateStream.listen((_) => _changed()));
    _subscriptions.add(player.positionStream.listen((position) {
      if (_rangeEnd != null && position >= _rangeEnd!) {
        _rangeEnd = null;
        unawaited(player.pause());
      }
      _changed();
    }));
    _subscriptions.add(player.durationStream.listen((_) => _changed()));
    _subscriptions.add(player.currentIndexStream.listen((i) {
      if (i != null && !busy) index = i;
      _changed();
    }));
    _subscriptions.add(player.errorStream.listen((e) {
      error =
          'Arquivo indisponível ou formato não suportado. Verifique a permissão da pasta.';
      _changed();
    }));
    return player;
  }

  Future<void> playTracks(List<LocalTrack> tracks,
      {int start = 0, String? name}) async {
    if (tracks.isEmpty) return;
    if (busy) {
      _pendingPlay = (tracks: List.of(tracks), start: start, name: name);
      return;
    }
    final range = _nextRange;
    _nextRange = null;
    _rangeEnd = null;
    if (_player != null &&
        _queueReady &&
        name == tapeName &&
        listEquals(tracks.map((t) => t.uri).toList(),
            queue.map((t) => t.uri).toList()) &&
        range == null) {
      index = start.clamp(0, queue.length - 1);
      error = null;
      await _action((p) async {
        await p.seek(Duration.zero, index: index);
        unawaited(p.play().catchError((Object e) {
          error = 'Falha na reprodução.';
          _changed();
        }));
      });
      return;
    }
    busy = true;
    _queueReady = false;
    error = null;
    queue = List.of(tracks);
    index = start.clamp(0, tracks.length - 1);
    tapeName = name;
    _changed();
    try {
      final player = await _ensure();
      await player.pause();
      final selectedIndex = index;
      await loadPlaylist(
          player,
          [
            for (final t in queue)
              AudioSource.uri(t.uri,
                  tag: MediaItem(
                      id: t.uri.toString(),
                      title: t.title,
                      artist: t.artist,
                      artUri: Uri(
                          scheme: 'content',
                          host: 'br.com.walkman.walkman.art',
                          path: '/cover',
                          queryParameters: {'source': t.uri.toString()}),
                      album: name ?? t.album,
                      duration:
                          t.duration == Duration.zero ? null : t.duration)),
          ],
          initialIndex: selectedIndex,
          initialPosition: range?.start ?? Duration.zero);
      index = selectedIndex;
      _queueReady = true;
      error = null;
      _rangeEnd = range?.end;
      unawaited(player.play().catchError((Object e) {
        error = 'Não foi possível reproduzir este arquivo.';
        _changed();
      }));
    } catch (e, stack) {
      debugPrint('Walkmen: erro ao preparar fila: $e\n$stack');
      error =
          'Não foi possível abrir a música. Confira o arquivo e as permissões da pasta.';
    } finally {
      busy = false;
      _changed();
      final next = _pendingPlay;
      _pendingPlay = null;
      if (next != null && !_disposed)
        unawaited(playTracks(next.tracks, start: next.start, name: next.name));
    }
  }

  Future<void> toggle() async {
    final p = _player;
    if (p == null || busy) return;
    try {
      if (p.playing) {
        await p.pause();
      } else {
        if (p.processingState == ProcessingState.completed)
          await p.seek(Duration.zero, index: 0);
        unawaited(p.play().catchError((Object e) {
          error = 'Falha na reprodução.';
          _changed();
        }));
      }
    } catch (_) {
      error = 'Falha na reprodução.';
      _changed();
    }
  }

  Future<void> next() async {
    _rangeEnd = null;
    await _action((p) async {
      if (p.hasNext) await p.seekToNext();
    });
  }

  Future<void> previous() async {
    _rangeEnd = null;
    await _action((p) async {
      if (p.hasPrevious) {
        await p.seekToPrevious();
      } else {
        await p.seek(Duration.zero);
      }
    });
  }

  Future<void> _action(Future<void> Function(AudioPlayer) action) async {
    final player = _player;
    if (player == null) return;
    try {
      await action(player);
    } catch (_) {
      error = 'Não foi possível executar o comando nesta música.';
    }
    _changed();
  }

  Future<void> seek(Duration time) {
    _rangeEnd = null;
    return _action((p) => p.seek(time));
  }

  Future<void> stop() async {
    _rangeEnd = null;
    await _action((p) => p.stop());
  }

  Future<void> setVolume(double value) async {
    _savedVolume = value.clamp(0, 1);
    await _action((p) => p.setVolume(value));
    _changed();
  }

  Future<void> toggleShuffle() async {
    _savedShuffle = !shuffle;
    await _action((p) => p.setShuffleModeEnabled(_savedShuffle));
    _changed();
  }

  Future<void> toggleLoop() async {
    _savedLoop = switch (loop) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off
    };
    await _action((p) => p.setLoopMode(_savedLoop));
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_player?.dispose() ?? Future.value());
    super.dispose();
  }
}
