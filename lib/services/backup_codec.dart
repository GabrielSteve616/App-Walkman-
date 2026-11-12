import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/audio_moment.dart';
import '../models/local_track.dart';
import '../models/tape.dart';

const backupFormat = 'walkmen-backup';
const maxBackupBytes = 128 * 1024 * 1024;
const maxImageBytes = 12 * 1024 * 1024;

class ParsedBackup {
  ParsedBackup(this.collection, this.images, this.settings);
  final Map<String, dynamic> collection;
  final Map<String, Uint8List> images;
  final Map<String, dynamic> settings;
}

class BackupCodec {
  static Future<String> encode(
      Map<String, dynamic> snapshot, Map<String, dynamic> settings) async {
    final data =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(snapshot)) as Map);
    final images = <String, Map<String, String>>{}, paths = <String, String>{};
    // Refuse an oversized collection before retaining all encoded images in memory.
    var estimatedBytes = utf8.encode(jsonEncode(data)).length +
        utf8.encode(jsonEncode(settings)).length +
        4096;
    if (estimatedBytes > maxBackupBytes) {
      throw const FormatException('O backup excede 128 MB.');
    }
    Future<String?> image(dynamic value) async {
      if (value == null) return null;
      if (value is! String || value.isEmpty)
        throw const FormatException('Caminho de imagem inválido.');
      if (paths.containsKey(value)) return paths[value];
      final file = File(value);
      if (!await file.exists())
        throw const FormatException(
            'Uma imagem personalizada não foi encontrada.');
      final length = await file.length();
      if (length > maxImageBytes)
        throw const FormatException('Uma imagem excede 12 MB.');
      estimatedBytes += ((length + 2) ~/ 3) * 4 + 256;
      if (estimatedBytes > maxBackupBytes) {
        throw const FormatException('O backup excede 128 MB.');
      }
      final bytes = await file.readAsBytes();
      final id = 'imagem_${images.length}';
      images[id] = {
        'data': base64Encode(bytes),
        'sha256': sha256.convert(bytes).toString()
      };
      paths[value] = id;
      return id;
    }

    for (final row in (data['tapes'] as List? ?? [])) {
      for (final key in ['coverPath', 'labelFrontPath', 'labelBackPath']) {
        row[key] = await image(row[key]);
      }
    }
    for (final row in (data['stickers'] as List? ?? [])) {
      row['path'] = await image(row['path']);
    }
    final json = jsonEncode({
      'format': backupFormat,
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'collection': data,
      'images': images,
      'settings': settings
    });
    if (utf8.encode(json).length > maxBackupBytes)
      throw const FormatException('O backup excede 128 MB.');
    return json;
  }

  static ParsedBackup decode(String text) {
    if (utf8.encode(text).length > maxBackupBytes)
      throw const FormatException('O backup excede 128 MB.');
    final document = jsonDecode(text);
    if (document is! Map ||
        document['format'] != backupFormat ||
        document['version'] != 1 ||
        document['collection'] is! Map ||
        document['images'] is! Map ||
        document['settings'] is! Map) {
      throw const FormatException(
          'Arquivo de backup do Walkmen inválido ou incompatível.');
    }
    final data = Map<String, dynamic>.from(document['collection'] as Map);
    for (final key in [
      'tapes',
      'moments',
      'stickers',
      'favorites',
      'favoriteTracks'
    ]) {
      if (data[key] is! List) throw FormatException('Dados de $key inválidos.');
    }
    final images = <String, Uint8List>{};
    for (final entry in (document['images'] as Map).entries) {
      if (entry.key is! String ||
          !RegExp(r'^imagem_[0-9]+$').hasMatch(entry.key as String) ||
          entry.value is! Map ||
          (entry.value as Map)['data'] is! String ||
          (entry.value as Map)['sha256'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$')
              .hasMatch((entry.value as Map)['sha256'] as String)) {
        throw const FormatException('Imagem inválida no backup.');
      }
      final encoded = (entry.value as Map)['data'] as String;
      if (encoded.length > ((maxImageBytes + 2) ~/ 3) * 4)
        throw const FormatException('Uma imagem excede 12 MB.');
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty || bytes.length > maxImageBytes)
        throw const FormatException('Imagem vazia ou muito grande.');
      if (sha256.convert(bytes).toString() != (entry.value as Map)['sha256']) {
        throw const FormatException('Uma imagem do backup está danificada.');
      }
      images[entry.key as String] = bytes;
    }
    void checkImage(dynamic id) {
      if (id != null && (id is! String || !images.containsKey(id)))
        throw const FormatException('Imagem da coleção ausente no backup.');
    }

    final tapeIds = <String>{}, stickerIds = <String>{}, momentIds = <String>{};
    for (final row in data['tapes'] as List) {
      final tape = Tape.fromJson(Map<String, dynamic>.from(row as Map));
      if (tape.id.isEmpty || !tapeIds.add(tape.id))
        throw const FormatException('Fita duplicada ou inválida.');
      for (final k in ['coverPath', 'labelFrontPath', 'labelBackPath']) {
        checkImage(row[k]);
      }
    }
    for (final row in data['stickers'] as List) {
      final sticker =
          StickerAsset.fromJson(Map<String, dynamic>.from(row as Map));
      if (sticker.id.isEmpty || !stickerIds.add(sticker.id))
        throw const FormatException('Figurinha duplicada ou inválida.');
      checkImage(row['path']);
    }
    for (final row in data['moments'] as List) {
      final moment =
          AudioMoment.fromJson(Map<String, dynamic>.from(row as Map));
      if (moment.id.isEmpty ||
          !momentIds.add(moment.id) ||
          moment.start < Duration.zero ||
          (moment.end != null && moment.end! <= moment.start))
        throw const FormatException('Marcador inválido.');
    }
    for (final row in data['favoriteTracks'] as List) {
      LocalTrack.fromJson(Map<String, dynamic>.from(row as Map));
    }
    if ((data['favorites'] as List).any((e) => e is! String))
      throw const FormatException('Favoritas inválidas.');
    final settings = Map<String, dynamic>.from(document['settings'] as Map);
    if (settings['musicFolder'] != null && settings['musicFolder'] is! String)
      throw const FormatException('Configuração de pasta inválida.');
    if (settings['volume'] is! num ||
        (settings['volume'] as num) < 0 ||
        (settings['volume'] as num) > 1 ||
        settings['shuffle'] is! bool ||
        settings['loop'] is! int ||
        (settings['loop'] as int) < 0 ||
        (settings['loop'] as int) > 2) {
      throw const FormatException('Configurações de reprodução inválidas.');
    }
    return ParsedBackup(data, images, settings);
  }
}
