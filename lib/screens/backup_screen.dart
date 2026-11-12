import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import '../services/backup_codec.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen(
      {super.key,
      required this.app,
      required this.onRestored,
      this.service = const BackupService()});
  final AppState app;
  final VoidCallback onRestored;
  final BackupService service;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool busy = false;
  void message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String explain(Object error) {
    if (error is PlatformException)
      return error.message ?? 'Não foi possível concluir.';
    if (error is FormatException) return error.message;
    return 'Não foi possível concluir. Seus dados atuais foram preservados.';
  }

  Future<void> export({bool chooseLocation = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final name = await widget.service
          .export(widget.app, chooseLocation: chooseLocation);
      if (name != null)
        message(chooseLocation
            ? 'Backup salvo: $name'
            : 'Salvo em Downloads: $name');
    } catch (e) {
      message(explain(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> import() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final backup = await widget.service.pick();
      if (backup == null || !mounted) return;
      final confirmed = await _confirm(backup);
      if (!confirmed || !mounted) return;
      await widget.app.restoreBackup(backup);
      var folderRestored = false;
      try {
        folderRestored = await widget.service.restoreFolder(backup);
      } catch (_) {/* Android may require a new permission. */}
      widget.onRestored();
      message(folderRestored
          ? 'Backup restaurado.'
          : 'Backup restaurado. Escolha novamente a pasta de músicas.');
    } catch (e) {
      message(explain(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> _confirm(ParsedBackup backup) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Restaurar backup?'),
                  content: Text(
                      'A biblioteca atual será substituída por ${(backup.collection['tapes'] as List).length} fitas e ${(backup.collection['stickers'] as List).length} figurinhas do backup. Os arquivos de música não serão apagados.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Restaurar'))
                  ])) ??
      false;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.backup_outlined, size: 64, color: Colors.orangeAccent),
        const SizedBox(height: 18),
        Text('Salve sua coleção',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text(
            'Salve ou restaure suas fitas, favoritas, trechos, capas, figurinhas e configurações.',
            textAlign: TextAlign.center),
        const SizedBox(height: 22),
        FilledButton.icon(
            onPressed: busy ? null : () => export(),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Exportar para Downloads')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: busy ? null : () => export(chooseLocation: true),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Escolher onde salvar')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: busy ? null : import,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Importar backup JSON')),
        const SizedBox(height: 20),
        const Text(
            'As músicas permanecem nas pastas do aparelho. Ao trocar de celular, copie os arquivos de áudio para o mesmo local e autorize a pasta novamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70)),
        if (busy)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()))
      ]));
}
