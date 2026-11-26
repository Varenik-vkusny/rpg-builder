// Сообщения автору, одинаковые на всех экранах: вопрос перед действием (шторка вида А,
// action_sheet.dart) и короткое «сделано» после успешного.
import 'dart:async';

import 'package:flutter/material.dart';

import 'done_strip.dart';

export 'action_sheet.dart';
export 'done_strip.dart' show DoneKind;

/// Сколько висит «сделано».
const doneDuration = Duration(seconds: 2);

/// Убрать полосу, которая сейчас на экране.
VoidCallback? _hideShown;

/// «Сделано»: полоса внизу экрана, исчезает сама. Новое сообщение сменяет прежнее.
/// Полоса не перехватывает нажатия: то, что под ней, остаётся доступным сразу.
void showDone(BuildContext context, String text, DoneKind kind, {String? sub}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _hideShown?.call();
  late final OverlayEntry entry;
  // Убирается один раз: после remove() полоса ещё «mounted» до следующего кадра,
  // и срок прежней полосы мог убрать её второй раз (найдено 25.11).
  var hidden = false;
  void hide() {
    if (hidden) return;
    hidden = true;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(builder: (_) => _DoneToast(text, kind, sub, hide));
  _hideShown = hide;
  overlay.insert(entry);
}

/// Закрыть экран с признаком «мир изменился» и сказать автору, что сделано.
void closeDone(BuildContext context, String text, DoneKind kind) {
  showDone(context, text, kind);
  Navigator.of(context).pop(true);
}

class _DoneToast extends StatefulWidget {
  const _DoneToast(this.text, this.kind, this.sub, this.onGone);

  final String text;
  final DoneKind kind;
  final String? sub;
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
    return Positioned(
      left: 16,
      right: 16,
      // Над главной кнопкой внизу экрана.
      bottom: MediaQuery.viewPaddingOf(context).bottom + 96,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          child: DoneStrip(
            key: const Key('done-message'),
            kind: widget.kind,
            title: widget.text,
            sub: widget.sub,
          ),
        ),
      ),
    );
  }
}
