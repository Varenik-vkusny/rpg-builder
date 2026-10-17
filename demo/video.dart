// Видео для показа владельцу: кадры прямо из прогона экрана (30 в секунду) и «палец» —
// кружок там, где касается автор. Кадры — в build/video/<имя>/, склейка в mp4 — ffmpeg
// (bash demo/video.sh <имя>). Время в прогоне подменное: видео идёт с настоящей скоростью
// анимаций, сколько бы ни считались кадры.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shots.dart' show frame;

const _step = Duration(microseconds: 33333);

class Video {
  Video(this.t, this.name) {
    final dir = Directory('build/video/$name');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  final WidgetTester t;
  final String name;

  /// Где палец и нажат ли он; null — пальца нет.
  final finger = ValueNotifier<(Offset, bool)?>(null);
  int _n = 0;

  /// Экран с кружком пальца поверх — его и снимает рамка [frame].
  Widget wrap(Widget app) => RepaintBoundary(
    key: frame,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          app,
          ValueListenableBuilder(
            valueListenable: finger,
            builder: (_, f, _) => f == null
                ? const SizedBox.shrink()
                : Positioned(
                    left: f.$1.dx - 22,
                    top: f.$1.dy - 22,
                    child: IgnorePointer(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: f.$2 ? .45 : .2),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );

  Future<void> _shot() => t.runAsync(() async {
    final b = frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      'build/video/$name/f${(_n++).toString().padLeft(5, '0')}.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
  });

  /// Идёт время [d]: кадр каждые 33 мс.
  Future<void> wait(Duration d) async {
    for (var e = Duration.zero; e < d; e += _step) {
      await t.pump(_step);
      await _shot();
    }
  }

  Future<void> _glide(Offset from, Offset to, int frames, [TestGesture? g]) async {
    for (var i = 1; i <= frames; i++) {
      final p = Offset.lerp(from, to, Curves.easeInOut.transform(i / frames))!;
      finger.value = (p, g != null);
      if (g != null) await g.moveTo(p);
      await t.pump(_step);
      await _shot();
    }
  }

  Offset _at = const Offset(190, 500);

  /// Палец подъезжает к [f] и нажимает.
  Future<void> tap(Finder f) => tapAt(t.getCenter(f));

  Future<void> tapAt(Offset p) async {
    await _glide(_at, p, 12);
    final g = await t.startGesture(p);
    finger.value = (p, true);
    await wait(const Duration(milliseconds: 120));
    await g.up();
    finger.value = (p, false);
    _at = p;
    await wait(const Duration(milliseconds: 300));
  }

  /// Провести пальцем от [a] к [b]; [hold] — сколько держать перед движением (подъём).
  Future<void> drag(
    Offset a,
    Offset b, {
    Duration hold = const Duration(milliseconds: 100),
    int frames = 30,
  }) async {
    await _glide(_at, a, 12);
    final g = await t.startGesture(a);
    finger.value = (a, true);
    await wait(hold);
    await _glide(a, b, frames, g);
    await g.up();
    finger.value = (b, false);
    _at = b;
    await wait(const Duration(milliseconds: 200));
  }

  void hide() => finger.value = null;

  int get frames => _n;
}
