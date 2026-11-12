import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/local_track.dart';
import '../models/tape.dart';
import '../models/audio_moment.dart';
import 'collection_store.dart';
import 'playback.dart';
import 'backup_codec.dart';

class AppState extends ChangeNotifier {
  AppState({CollectionStore? store, Playback? playback})
      : store = store ?? CollectionStore(),
        playback = playback ?? Playback() {
    this.playback.addListener(_playbackChanged);
  }
  final CollectionStore store;
  final Playback playback;
  List<Tape> tapes = [];
  List<AudioMoment> moments = [];
  List<StickerAsset> stickers = [];
  Set<String> favorites = {};
  Map<String, LocalTrack> favoriteTracks = {};
  Future<void> _mutation = Future.value();
  bool loaded = false;
  bool _collectionReadable = false;
  bool _disposed = false;
  bool _restoring = false;
  String _lastPreferences = '';
  Timer? _settingsTimer;
  String? storageError;
  Future<void> load() async {
    try {
      final data = await store.read();
      tapes = (data['tapes'] as List? ?? [])
          .map((t) => Tape.fromJson(Map<String, dynamic>.from(t)))
          .toList();
      moments = (data['moments'] as List? ?? [])
          .map((m) => AudioMoment.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      stickers = (data['stickers'] as List? ?? [])
          .map((s) => StickerAsset.fromJson(Map<String, dynamic>.from(s)))
          .toList();
      favorites = Set<String>.from(data['favorites'] as List? ?? []);
      favoriteTracks = {
        for (final row in data['favoriteTracks'] as List? ?? [])
          (row as Map)['uri'] as String:
              LocalTrack.fromJson(Map<String, dynamic>.from(row))
      };
      if (data['settings'] is Map) {
        await playback.applyPreferences(
            Map<String, dynamic>.from(data['settings'] as Map));
      }
      _collectionReadable = true;
    } catch (_) {
      storageError =
          'Não foi possível carregar sua coleção. Os arquivos existentes foram preservados.';
    }
    loaded = true;
    _lastPreferences = jsonEncode(playback.preferences);
    if (!_disposed) notifyListeners();
  }

  Future<void> _save(List<Tape> nextTapes, List<StickerAsset> nextStickers,
      {List<AudioMoment>? nextMoments,
      Set<String>? nextFavorites,
      Map<String, LocalTrack>? nextFavoriteTracks}) async {
    if (!loaded || storageError != null)
      throw StateError(
          'Armazenamento indisponível. Reabra o app antes de salvar.');
    await store.write({
      'tapes': nextTapes.map((t) => t.toJson()).toList(),
      'moments': (nextMoments ?? moments).map((m) => m.toJson()).toList(),
      'stickers': nextStickers.map((s) => s.toJson()).toList(),
      'favorites': (nextFavorites ?? favorites).toList(),
      'favoriteTracks': (nextFavoriteTracks ?? favoriteTracks)
          .values
          .map((t) => t.toJson())
          .toList(),
      'settings': playback.preferences,
    });
    tapes = nextTapes;
    moments = nextMoments ?? moments;
    stickers = nextStickers;
    favorites = nextFavorites ?? favorites;
    favoriteTracks = nextFavoriteTracks ?? favoriteTracks;
    if (!_disposed) notifyListeners();
  }

  Future<void> _change(Future<void> Function() action) {
    final next = _mutation.catchError((_) {}).then((_) => action());
    _mutation = next;
    return next;
  }

  void _playbackChanged() {
    if (!loaded || _disposed || _restoring || storageError != null) return;
    final current = jsonEncode(playback.preferences);
    if (current == _lastPreferences) return;
    _lastPreferences = current;
    _settingsTimer?.cancel();
    _settingsTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_change(() => _save(List.of(tapes), List.of(stickers)))
          .catchError((Object _) {
        storageError = 'Não foi possível salvar as configurações.';
        if (!_disposed) notifyListeners();
      }));
    });
  }

  Future<Map<String, dynamic>> backupSnapshot() async {
    // A failed earlier edit did not replace the current collection; allow a
    // backup of the last successfully committed state.
    await _mutation.catchError((_) {});
    if (!loaded || !_collectionReadable)
      throw StateError('Coleção indisponível.');
    return jsonDecode(jsonEncode({
      'tapes': tapes.map((t) => t.toJson()).toList(),
      'moments': moments.map((m) => m.toJson()).toList(),
      'stickers': stickers.map((s) => s.toJson()).toList(),
      'favorites': favorites.toList(),
      'favoriteTracks': favoriteTracks.values.map((t) => t.toJson()).toList(),
      'settings': playback.preferences,
    })) as Map<String, dynamic>;
  }

  Future<void> restoreBackup(ParsedBackup backup) => _change(() async {
        if (!loaded) throw StateError('A coleção ainda está carregando.');
        _settingsTimer?.cancel();
        final staged = <String>[];
        var committed = false;
        try {
          final paths = <String, String>{};
          final prefix = 'restore_${DateTime.now().microsecondsSinceEpoch}';
          for (final entry in backup.images.entries) {
            final path =
                await store.saveImage(entry.value, '${prefix}_${paths.length}');
            staged.add(path);
            paths[entry.key] = path;
          }
          final data = Map<String, dynamic>.from(
              jsonDecode(jsonEncode(backup.collection)) as Map);
          for (final row in data['tapes'] as List) {
            for (final key in [
              'coverPath',
              'labelFrontPath',
              'labelBackPath'
            ]) {
              if (row[key] != null) row[key] = paths[row[key]]!;
            }
          }
          for (final row in data['stickers'] as List) {
            if (row['path'] != null) row['path'] = paths[row['path']]!;
          }
          final nextTapes = (data['tapes'] as List)
              .map((t) => Tape.fromJson(Map<String, dynamic>.from(t)))
              .toList();
          final nextMoments = (data['moments'] as List)
              .map((m) => AudioMoment.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          final nextStickers = (data['stickers'] as List)
              .map((s) => StickerAsset.fromJson(Map<String, dynamic>.from(s)))
              .toList();
          final nextFavorites = Set<String>.from(data['favorites'] as List);
          final nextTracks = <String, LocalTrack>{
            for (final row in data['favoriteTracks'] as List)
              (row as Map)['uri'] as String:
                  LocalTrack.fromJson(Map<String, dynamic>.from(row))
          };
          final settings = <String, dynamic>{
            for (final key in ['volume', 'shuffle', 'loop'])
              key: backup.settings[key]
          };
          data['settings'] = settings;
          await store.write(data);
          committed = true;
          _collectionReadable = true;
          tapes = nextTapes;
          moments = nextMoments;
          stickers = nextStickers;
          favorites = nextFavorites;
          favoriteTracks = nextTracks;
          storageError = null;
          _restoring = true;
          try {
            await playback.applyPreferences(settings);
          } catch (_) {
            // The collection is already committed; saved preferences can be
            // applied when a new player is created.
          } finally {
            _restoring = false;
          }
          _lastPreferences = jsonEncode(playback.preferences);
          if (!_disposed) notifyListeners();
        } finally {
          if (!committed) {
            for (final path in staged) {
              try {
                await File(path).delete();
              } catch (_) {/* original collection remains intact */}
            }
          }
        }
      });

  Future<void> saveTape(Tape tape) => _change(() {
        final next = List<Tape>.of(tapes);
        final index = next.indexWhere((t) => t.id == tape.id);
        if (index < 0) {
          next.add(tape.copy());
        } else {
          next[index] = tape.copy();
        }
        return _save(next, List.of(stickers));
      });
  Future<void> moveTape(String id, String targetId) => _change(() async {
        if (id == targetId) return;
        final next = List<Tape>.of(tapes);
        final from = next.indexWhere((t) => t.id == id),
            to = next.indexWhere((t) => t.id == targetId);
        if (from < 0 || to < 0) return;
        final tape = next.removeAt(from);
        next.insert(to, tape);
        await _save(next, List.of(stickers));
      });

  Future<void> saveMoment(AudioMoment m) => _change(() {
        if (m.start < Duration.zero || (m.end != null && m.end! <= m.start))
          throw ArgumentError('Trecho inválido');
        return _save(List.of(tapes), List.of(stickers),
            nextMoments: [...moments.where((x) => x.id != m.id), m]);
      });
  Future<void> renameMoment(String id, String name) => _change(() {
        final title = name.trim();
        if (title.isEmpty) throw ArgumentError('Nome vazio');
        return _save(List.of(tapes), List.of(stickers),
            nextMoments: moments
                .map((m) => m.id == id
                    ? AudioMoment(
                        id: m.id,
                        name: title,
                        track: m.track,
                        start: m.start,
                        end: m.end)
                    : m)
                .toList());
      });
  Future<void> deleteMoment(String id) =>
      _change(() => _save(List.of(tapes), List.of(stickers),
          nextMoments: moments.where((m) => m.id != id).toList()));
  Future<void> deleteTape(String id) => _change(
      () => _save(tapes.where((t) => t.id != id).toList(), List.of(stickers)));
  Future<void> toggleFavorite(LocalTrack track) => _change(() {
        final next = Set<String>.of(favorites);
        if (!next.add(track.uri.toString())) next.remove(track.uri.toString());
        final metadata = Map<String, LocalTrack>.of(favoriteTracks);
        if (next.contains(track.uri.toString())) {
          metadata[track.uri.toString()] = track;
        } else {
          metadata.remove(track.uri.toString());
        }
        return _save(List.of(tapes), List.of(stickers),
            nextFavorites: next, nextFavoriteTracks: metadata);
      });
  Future<StickerAsset> addSticker(String name, Uint8List bytes) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final path = await store.saveImage(bytes, id);
    final sticker = StickerAsset(id: id, name: name, path: path);
    await _change(() => _save(List.of(tapes), [...stickers, sticker]));
    return sticker;
  }

  Future<void> deleteSticker(String id) => _change(() async {
        final next = tapes.map((t) {
          final copy = t.copy();
          copy.stickers.removeWhere((s) => s.assetId == id);
          return copy;
        }).toList();
        await _save(next, stickers.where((s) => s.id != id).toList());
      });
  Tape newTape(String name, List<LocalTrack> tracks) => Tape(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      tracks: List.of(tracks));
  @override
  void dispose() {
    _disposed = true;
    _settingsTimer?.cancel();
    playback.removeListener(_playbackChanged);
    playback.dispose();
    super.dispose();
  }
}
