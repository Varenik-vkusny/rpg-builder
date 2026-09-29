// Прибор «текст не ломается»: на каждом экране ищет переполнение и перенос внутри слова.
// Работает только с настоящими шрифтами (real_fonts.dart) — тестовый шрифт всё скрывает.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/ui/parts.dart';

final _letter = RegExp(r'[\p{L}\p{N}]', unicode: true);

class TextFit {
  TextFit(this.variant);

  /// «Тетрадь 360dp ×1.3» — чтобы в отчёте было видно, где сломалось.
  final String variant;
  final problems = <String>{};

  /// Для показа: рамка снимка и съёмка экрана (demo/). В приборе не нужны.
  GlobalKey? frame;
  Future<void> Function(String screen)? shoot;
  final _pendingOverflow = <String>[];
  FlutterExceptionHandler? _old;

  /// Перехватывает сообщения о переполнении; всё остальное — как обычно (тест упадёт).
  void start() {
    _old = FlutterError.onError;
    FlutterError.onError = (d) {
      final msg = d.exceptionAsString();
      if (msg.contains('overflowed')) {
        _pendingOverflow.add(msg.split('\n').first);
      } else {
        _old!(d);
      }
    };
  }

  void stop() => FlutterError.onError = _old;

  /// Проверяет видимый текст текущего экрана.
  void scan(WidgetTester t, String screen) {
    final at = '$variant · $screen';
    for (final o in _pendingOverflow) {
      problems.add('$at: переполнение — $o');
    }
    _pendingOverflow.clear();
    final fabs = [
      for (final f in find.byType(FloatingActionButton).evaluate())
        _rect(f.renderObject! as RenderBox),
      // Полоса действия внизу закрывать текст может, только пока список не докручен.
      if (_atBottom(t))
        for (final b in find.byType(BottomAction).evaluate())
          _rect(b.renderObject! as RenderBox),
    ];
    for (final e in find.byType(RichText).evaluate()) {
      final p = e.renderObject;
      if (p is! RenderParagraph || !p.attached || !p.hasSize) continue;
      final text = p.text.toPlainText(includeSemanticsLabels: false);
      if (text.isEmpty) continue;
      // Подпись поля ввода, обрезанная многоточием, — автор не узнает, что вводит.
      if (p.didExceedMaxLines &&
          e.findAncestorWidgetOfExactType<InputDecorator>() != null) {
        problems.add('$at: подпись поля обрезана — «$text»');
      }
      // Название экрана в шапке, обрезанное многоточием («Пепельные…»).
      if (p.didExceedMaxLines &&
          e.findAncestorWidgetOfExactType<AppBar>() != null) {
        problems.add('$at: название в шапке обрезано — «$text»');
      }
      // Текст под плавающей кнопкой — его не прочесть и не нажать (при любой прокрутке).
      if (e.findAncestorWidgetOfExactType<FloatingActionButton>() == null &&
          e.findAncestorWidgetOfExactType<BottomAction>() == null) {
        final r = _rect(p);
        for (final f in fabs) {
          final x = r.intersect(f);
          if (x.width > 2 && x.height > 2) {
            problems.add('$at: плавающая кнопка закрывает «$text»');
          }
        }
      }
      // Верх каждой строки абзаца — по прямоугольникам выделения всего текста.
      final tops = {
        for (final b in p.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        ))
          b.top.roundToDouble(),
      }.toList()..sort();
      // Заголовок плана — не выше трёх строк, дальше многоточие (решение владельца 28.09).
      if (tops.length > 3 &&
          e.findAncestorWidgetOfExactType<Text>()?.key ==
              const Key('plan-summary')) {
        problems.add('$at: заголовок плана в ${tops.length} строк — «$text»');
      }
      for (final top in tops.skip(1)) {
        final i = p.getPositionForOffset(Offset(-1000, top + 2)).offset;
        if (i <= 0 || i >= text.length) continue;
        if (_letter.hasMatch(text[i - 1]) && _letter.hasMatch(text[i])) {
          final before = text.substring(max(0, i - 14), i);
          final after = text.substring(i, min(text.length, i + 14));
          problems.add('$at: слово разорвано — «$before|$after»');
        }
      }
    }
  }

  static Rect _rect(RenderBox b) => b.localToGlobal(Offset.zero) & b.size;

  /// Главный список докручен до конца (или его нет) — ниже ничего не спрятано.
  static bool _atBottom(WidgetTester t) {
    final list = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    if (list.evaluate().isEmpty) return true;
    final pos = t.state<ScrollableState>(list.first).position;
    return pos.pixels >= pos.maxScrollExtent - 1;
  }

  /// Проверяет экран и, если это показ, снимает его.
  Future<void> see(WidgetTester t, String screen) async {
    scan(t, screen);
    await shoot?.call(screen);
  }

  /// Проверяет экран сверху донизу, прокручивая главный вертикальный список.
  Future<void> scanScrolling(WidgetTester t, String screen) async {
    await see(t, screen);
    final list = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    if (list.evaluate().isEmpty) return;
    for (var k = 0; k < 8; k++) {
      final pos = t.state<ScrollableState>(list.first).position;
      if (pos.pixels >= pos.maxScrollExtent) break;
      pos.jumpTo(min(pos.pixels + 450, pos.maxScrollExtent));
      await t.pumpAndSettle();
      scan(t, '$screen (ниже)');
    }
    t.state<ScrollableState>(list.first).position.jumpTo(0);
    await t.pumpAndSettle();
  }
}
