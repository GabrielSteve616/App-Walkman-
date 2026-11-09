import 'package:flutter/foundation.dart';
import '../models/local_track.dart';
import '../models/tape.dart';
import 'collection_store.dart';
import 'playback.dart';

class AppState extends ChangeNotifier {
  AppState({CollectionStore? store, Playback? playback})
      : store = store ?? CollectionStore(),
        playback = playback ?? Playback();
  final CollectionStore store;
  final Playback playback;
  List<Tape> tapes = [];
  List<StickerAsset> stickers = [];
  Set<String> favorites = {};
  Map<String, LocalTrack> favoriteTracks = {};
  Future<void> _mutation = Future.value();
  bool loaded = false;
  bool _disposed = false;
  String? storageError;
  Future<void> load() async {
    try {
      final data = await store.read();
      tapes = (data['tapes'] as List? ?? [])
          .map((t) => Tape.fromJson(Map<String, dynamic>.from(t)))
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
    } catch (_) {
      storageError =
          'Não foi possível carregar sua coleção. Os arquivos existentes foram preservados.';
    }
    loaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> _save(List<Tape> nextTapes, List<StickerAsset> nextStickers,
      {Set<String>? nextFavorites,
      Map<String, LocalTrack>? nextFavoriteTracks}) async {
    if (!loaded || storageError != null)
      throw StateError(
          'Armazenamento indisponível. Reabra o app antes de salvar.');
    await store.write({
      'tapes': nextTapes.map((t) => t.toJson()).toList(),
      'stickers': nextStickers.map((s) => s.toJson()).toList(),
      'favorites': (nextFavorites ?? favorites).toList(),
      'favoriteTracks': (nextFavoriteTracks ?? favoriteTracks)
          .values
          .map((t) => t.toJson())
          .toList(),
    });
    tapes = nextTapes;
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
    playback.dispose();
    super.dispose();
  }
}
