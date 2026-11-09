import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CollectionStore {
  CollectionStore({this.directory, this.memory = false});
  Directory? directory;
  final bool memory;
  Map<String, dynamic> _data = {};
  Future<void> _writing = Future.value();

  Future<Directory> get root async =>
      directory ??= await getApplicationDocumentsDirectory();

  Future<Map<String, dynamic>> read() async {
    if (memory) return _data;
    final dir = await root;
    for (final name in ['collection.json', 'collection.json.bak']) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) {
        try {
          return Map<String, dynamic>.from(
              jsonDecode(await file.readAsString()));
        } on FormatException {
          if (name.endsWith('.bak')) rethrow;
        }
      }
    }
    return {};
  }

  Future<void> write(Map<String, dynamic> data) {
    final snapshot = jsonEncode(data);
    final task = _writing.catchError((_) {}).then((_) async {
      if (memory) {
        _data = Map<String, dynamic>.from(jsonDecode(snapshot));
        return;
      }
      final dir = await root;
      await dir.create(recursive: true);
      final file = File('${dir.path}/collection.json');
      final temp = File('${file.path}.tmp');
      final backup = File('${file.path}.bak');
      await temp.writeAsString(snapshot, flush: true);
      if (await file.exists()) {
        if (await backup.exists()) await backup.delete();
        await file.rename(backup.path);
      }
      await temp.rename(file.path);
    });
    _writing = task;
    return task;
  }

  Future<String> saveImage(List<int> bytes, String id) async {
    final dir = Directory('${(await root).path}/images');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$id.png');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
