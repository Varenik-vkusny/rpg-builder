// Скетч (4.4): фото рисунка с камеры или из галереи уходит ассистенту вместе с просьбой.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help.dart';
import 'assistant_service.dart';

/// Кнопка «Фото скетча» и превью приложенного рисунка с «убрать».
class SketchField extends StatelessWidget {
  const SketchField({super.key, required this.image, required this.onChanged});

  final SketchImage? image;
  final ValueChanged<SketchImage?> onChanged;

  Future<void> _attach(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await pickSketch(context);
      if (picked != null) onChanged(picked);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Фото не получено: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = image;
    return Row(
      spacing: 12,
      children: [
        if (i != null)
          Image.memory(
            i.bytes,
            key: const Key('sketch-thumb'),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('sketch-attach'),
              icon: const Icon(Symbols.photo_camera_rounded),
              label: Text(i == null ? 'Фото скетча' : 'Другое фото'),
              onPressed: () => _attach(context),
            ),
          ).help('assistant.sketch'),
        ),
        if (i != null)
          IconButton(
            key: const Key('sketch-remove'),
            tooltip: 'Убрать скетч',
            icon: const Icon(Symbols.close_rounded),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}

/// Автор выбирает камеру или галерею; фото ужимается до 1280 px — модели хватает,
/// а запрос остаётся в пределе картинки (4 МБ base64). Отказался — null.
Future<SketchImage?> pickSketch(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('sketch-camera'),
            leading: const Icon(Symbols.photo_camera_rounded),
            title: const Text('Снять камерой'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            key: const Key('sketch-gallery'),
            leading: const Icon(Symbols.photo_library_rounded),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 80,
  );
  if (file == null) return null;
  return SketchImage(
    await file.readAsBytes(),
    file.mimeType ?? _mimeOf(file.name),
  );
}

/// Тип по расширению: сжатое фото с камеры — JPEG.
String _mimeOf(String name) => switch (name.split('.').last.toLowerCase()) {
  'png' => 'image/png',
  'webp' => 'image/webp',
  _ => 'image/jpeg',
};
