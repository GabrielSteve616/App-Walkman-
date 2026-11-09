import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/tape.dart';
import '../services/app_state.dart';
import 'sticker_crop_screen.dart';

Future<void> recoverLostSticker(BuildContext context, AppState app) async {
  try {
    final lost = await ImagePicker().retrieveLostData();
    if (lost.isEmpty ||
        lost.files == null ||
        lost.files!.isEmpty ||
        !context.mounted) return;
    final bytes = await lost.files!.first.readAsBytes();
    if (!context.mounted) return;
    final cropped = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => StickerCropScreen(bytes: bytes)));
    if (cropped != null) await app.addSticker('Figurinha recuperada', cropped);
  } catch (_) {/* A new selection is available in the Figurinhas tab. */}
}

Future<StickerAsset?> importSticker(BuildContext context, AppState app) async {
  try {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400);
    if (file == null || !context.mounted) return null;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return null;
    final cropped = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => StickerCropScreen(bytes: bytes)));
    if (cropped == null) return null;
    return await app.addSticker(
        'Figurinha ${app.stickers.length + 1}', cropped);
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Não foi possível importar a imagem. Tente novamente.')));
    return null;
  }
}

class StickersScreen extends StatelessWidget {
  const StickersScreen({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (context, _) => Column(children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                      child: Text('Figurinhas',
                          style: Theme.of(context).textTheme.headlineSmall)),
                  FilledButton.icon(
                      onPressed:
                          app.loaded ? () => importSticker(context, app) : null,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Criar')),
                ])),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                    'Importe imagens e recorte em formatos ou desenhe seu próprio contorno. Depois aplique na fita e na capa da caixa.')),
            Expanded(
                child: app.stickers.isEmpty
                    ? const Center(
                        child: Text('Sua coleção de figurinhas começa aqui.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 190,
                                childAspectRatio: .9,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12),
                        itemCount: app.stickers.length,
                        itemBuilder: (context, i) {
                          final sticker = app.stickers[i];
                          return Card(
                              child: Column(children: [
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Image.file(File(sticker.path),
                                        errorBuilder: (_, e, s) =>
                                            const Icon(Icons.broken_image)))),
                            ListTile(
                                dense: true,
                                title: Text(sticker.name),
                                trailing: IconButton(
                                    tooltip: 'Excluir figurinha',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      final yes = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                                  title: const Text(
                                                      'Excluir figurinha?'),
                                                  content: const Text(
                                                      'Ela também será retirada das fitas e das capas.'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: const Text(
                                                            'Cancelar')),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: const Text(
                                                            'Excluir'))
                                                  ]));
                                      if (yes == true) {
                                        try {
                                          await app.deleteSticker(sticker.id);
                                        } catch (_) {
                                          if (context.mounted)
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Não foi possível salvar a alteração.')));
                                        }
                                      }
                                    })),
                          ]));
                        })),
          ]));
}
