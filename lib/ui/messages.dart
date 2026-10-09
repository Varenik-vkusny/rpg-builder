// Сообщения автору, одинаковые на всех экранах: вопрос перед необратимым действием
// и короткое «сделано» после успешного.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Спрашивает автора перед действием; «да» — true, «Отмена» и нажатие мимо — false.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String text,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('confirm'),
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            key: const Key('confirm-no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            key: const Key('confirm-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

/// Сколько висит «сделано».
const doneDuration = Duration(seconds: 2);

OverlayEntry? _shown;

/// «Сделано»: полоса внизу экрана, исчезает сама. Новое сообщение сменяет прежнее.
/// Полоса не перехватывает нажатия: то, что под ней, остаётся доступным сразу.
void showDone(BuildContext context, String text) {
  final overlay = Overlay.of(context, rootOverlay: true);
  if (_shown?.mounted ?? false) _shown!.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _DoneToast(text, () {
      if (entry.mounted) entry.remove();
    }),
  );
  _shown = entry;
  overlay.insert(entry);
}

/// Закрыть экран с признаком «мир изменился» и сказать автору, что сделано.
void closeDone(BuildContext context, String text) {
  showDone(context, text);
  Navigator.of(context).pop(true);
}

class _DoneToast extends StatefulWidget {
  const _DoneToast(this.text, this.onGone);

  final String text;
  final VoidCallback onGone;

  @override
  State<_DoneToast> createState() => _DoneToastState();
}

class _DoneToastState extends State<_DoneToast> {
  late final _timer = Timer(doneDuration, widget.onGone);

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Positioned(
      left: 16,
      right: 16,
      // Над главной кнопкой внизу экрана.
      bottom: MediaQuery.viewPaddingOf(context).bottom + 96,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          child: Material(
            key: const Key('done-message'),
            color: s.inverseSurface,
            shape: RoundedRectangleBorder(side: BorderSide(color: s.outline)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Symbols.check_rounded, color: s.onInverseSurface),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: TextStyle(color: s.onInverseSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
