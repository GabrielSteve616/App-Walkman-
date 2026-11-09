import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/local_track.dart';

class Playback extends ChangeNotifier {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<LocalTrack> queue = [];
  int index = 0;
  bool busy = false;
  String? error;
  String? tapeName;
  bool get playing => _player?.playing ?? false;
  bool get shuffle => _player?.shuffleModeEnabled ?? false;
  LoopMode get loop => _player?.loopMode ?? LoopMode.off;
  double get volume => _player?.volume ?? 1;
  Duration get position => _player?.position ?? Duration.zero;
  Duration get duration =>
      _player?.duration ?? current?.duration ?? Duration.zero;
  LocalTrack? get current =>
      queue.isEmpty ? null : queue[index.clamp(0, queue.length - 1)];
  bool _disposed = false;
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
    _subscriptions.add(player.playerStateStream.listen((_) => _changed()));
    _subscriptions.add(player.positionStream.listen((_) => _changed()));
    _subscriptions.add(player.durationStream.listen((_) => _changed()));
    _subscriptions.add(player.currentIndexStream.listen((i) {
      if (i != null) index = i;
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
    if (tracks.isEmpty || busy) return;
    busy = true;
    error = null;
    queue = List.of(tracks);
    index = start.clamp(0, tracks.length - 1);
    tapeName = name;
    _changed();
    try {
      final player = await _ensure();
      await player.pause();
      await player.setAudioSources([
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
                  duration: t.duration == Duration.zero ? null : t.duration)),
      ], initialIndex: index);
      unawaited(player.play().catchError((Object e) {
        error = 'Não foi possível reproduzir este arquivo.';
        _changed();
      }));
    } catch (e) {
      error =
          'Não foi possível abrir a música. Confira o arquivo e as permissões da pasta.';
    } finally {
      busy = false;
      _changed();
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
    await _action((p) async {
      if (p.hasNext) await p.seekToNext();
    });
  }

  Future<void> previous() async {
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

  Future<void> seek(Duration time) => _action((p) => p.seek(time));
  Future<void> stop() async {
    await _action((p) => p.stop());
  }

  Future<void> setVolume(double value) async {
    await _action((p) => p.setVolume(value));
  }

  Future<void> toggleShuffle() async {
    await _action((p) => p.setShuffleModeEnabled(!shuffle));
  }

  Future<void> toggleLoop() async {
    await _action((p) => p.setLoopMode(switch (loop) {
          LoopMode.off => LoopMode.all,
          LoopMode.all => LoopMode.one,
          LoopMode.one => LoopMode.off
        }));
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
