import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/audio_moment.dart';
import '../models/local_track.dart';
import '../models/tape.dart';

/// The existing document format is kept as the SQLite payload so upgrades
/// preserve older tapes, favorite metadata and sticker placements verbatim.
class CollectionStore {
  CollectionStore({this.directory, this.memory = false});
  Directory? directory;
  final bool memory;
  Map<String, dynamic> _data = {};
  Future<void> _writing = Future.value();
  Future<Directory> get root async =>
      directory ??= await getApplicationDocumentsDirectory();

  Future<Database> _open() async {
    final dir = await root;
    await dir.create(recursive: true);
    return openDatabase('${dir.path}/walkmen.sqlite',
        singleInstance: false, version: 1, onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE collection (id INTEGER PRIMARY KEY CHECK (id = 1), document TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE previous_collection (id INTEGER PRIMARY KEY CHECK (id = 1), document TEXT NOT NULL)');
    });
  }

  Map<String, dynamic> _decode(String text) =>
      Map<String, dynamic>.from(jsonDecode(text) as Map);
  void _validateLegacy(Map<String, dynamic> data) {
    for (final row in data['tapes'] as List? ?? []) {
      Tape.fromJson(Map<String, dynamic>.from(row as Map));
    }
    for (final row in data['moments'] as List? ?? []) {
      AudioMoment.fromJson(Map<String, dynamic>.from(row as Map));
    }
    for (final row in data['stickers'] as List? ?? []) {
      StickerAsset.fromJson(Map<String, dynamic>.from(row as Map));
    }
    Set<String>.from(data['favorites'] as List? ?? []);
    for (final row in data['favoriteTracks'] as List? ?? []) {
      LocalTrack.fromJson(Map<String, dynamic>.from(row as Map));
    }
    if (data['settings'] != null && data['settings'] is! Map) {
      throw const FormatException('Configurações antigas inválidas');
    }
  }

  Future<Map<String, dynamic>?> _legacy() async {
    final dir = await root;
    Object? failure;
    for (final name in ['collection.json', 'collection.json.bak']) {
      final file = File('${dir.path}/$name');
      if (!await file.exists()) continue;
      try {
        final data = _decode(await file.readAsString());
        _validateLegacy(data);
        return data;
      } catch (e) {
        failure = e;
      }
    }
    if (failure != null)
      throw FormatException('Biblioteca anterior inválida: $failure');
    return null;
  }

  Future<Map<String, dynamic>> read() async {
    if (memory) return _data;
    await _writing.catchError((_) {});
    final db = await _open();
    try {
      var rows = await db.query('collection',
          columns: ['document'], where: 'id = ?', whereArgs: [1]);
      if (rows.isEmpty) {
        final legacy = await _legacy();
        if (legacy == null) return {};
        await db.insert('collection', {'id': 1, 'document': jsonEncode(legacy)},
            conflictAlgorithm: ConflictAlgorithm.ignore);
        rows = await db.query('collection',
            columns: ['document'], where: 'id = ?', whereArgs: [1]);
      }
      try {
        return _decode(rows.single['document'] as String);
      } catch (_) {
        final previous = await db.query('previous_collection',
            columns: ['document'], where: 'id = ?', whereArgs: [1]);
        if (previous.isEmpty) rethrow;
        return _decode(previous.single['document'] as String);
      }
    } finally {
      await db.close();
    }
  }

  Future<void> write(Map<String, dynamic> data) {
    final snapshot = jsonEncode(data);
    final task = _writing.catchError((_) {}).then((_) async {
      if (memory) {
        _data = _decode(snapshot);
        return;
      }
      final db = await _open();
      try {
        await db.transaction((txn) async {
          final old = await txn.query('collection',
              columns: ['document'], where: 'id = ?', whereArgs: [1]);
          if (old.isNotEmpty) {
            // Keep only a decodable prior snapshot; never overwrite it with corruption.
            var valid = true;
            try {
              _decode(old.single['document'] as String);
            } catch (_) {
              valid = false;
            }
            if (valid) {
              await txn.insert('previous_collection',
                  {'id': 1, 'document': old.single['document']},
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
          await txn.insert('collection', {'id': 1, 'document': snapshot},
              conflictAlgorithm: ConflictAlgorithm.replace);
        });
      } finally {
        // A close error after a committed transaction must not be reported as
        // a failed restore: the new database already references staged images.
        try {
          await db.close();
        } catch (_) {/* transaction result is authoritative */}
      }
    });
    _writing = task;
    return task;
  }

  Future<String> saveImage(List<int> bytes, String id) async {
    final dir = Directory('${(await root).path}/images');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$id.png');
    await file.create(exclusive: true);
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      try {
        await file.delete();
      } catch (_) {/* no existing file was replaced */}
      rethrow;
    }
    return file.path;
  }
}
