import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'app_state.dart';
import 'backup_codec.dart';

Future<int> _writeBackup(Map<String, dynamic> args) async {
  final json = await BackupCodec.encode(
      Map<String, dynamic>.from(args['collection'] as Map),
      Map<String, dynamic>.from(args['settings'] as Map));
  final file = File(args['path'] as String);
  await file.writeAsString(json, flush: true);
  return await file.length();
}

Future<ParsedBackup> _readBackup(String path) async {
  final file = File(path);
  if (await file.length() > maxBackupBytes)
    throw const FormatException('O backup excede 128 MB.');
  return BackupCodec.decode(await file.readAsString());
}

class BackupService {
  const BackupService();
  static const channel = MethodChannel('walkmen/backup');
  Future<String?> export(AppState app, {bool chooseLocation = false}) async {
    final folder = await channel.invokeMethod<String>('selectedFolder');
    final snapshot = await app.backupSnapshot();
    final settings = <String, dynamic>{
      ...Map<String, dynamic>.from(snapshot['settings'] as Map),
      'musicFolder': folder
    };
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/walkmen-export-${DateTime.now().microsecondsSinceEpoch}.json');
    try {
      await compute(_writeBackup,
          {'collection': snapshot, 'settings': settings, 'path': file.path});
      final filename = await channel.invokeMethod<String>(
          chooseLocation ? 'exportToFile' : 'export', {'path': file.path});
      if (filename == null && !chooseLocation)
        throw StateError('Não foi possível salvar o backup.');
      return filename;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<ParsedBackup?> pick() async {
    final path = await channel.invokeMethod<String>('pick');
    if (path == null) return null;
    final file = File(path);
    try {
      return await compute(_readBackup, path);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<bool> restoreFolder(ParsedBackup backup) async =>
      await channel.invokeMethod<bool>(
          'restoreFolder', {'folder': backup.settings['musicFolder']}) ??
      false;
}
