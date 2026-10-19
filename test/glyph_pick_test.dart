// Прибор «автор выбирает значок вида» (5д): выбранный житель, враг или предмет → «Значок» →
// значок из набора; правка — жестом через историю, «Отменить» возвращает; у события и квеста
// кнопки нет; неизвестное имя значка — значок по роли; в нижней строке связи — та же рамка.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/glyphs.dart';

import 'fakes.dart';
import 'holst_build_test.dart' show settle, snack, snackSub;
import 'holst_fixture.dart';
import 'holst_look_test.dart' show token;

Finder k(String key) => find.byKey(Key(key));

Future<String?> iconOf(FakeContent c, String slug) async {
  final w = await c.snapshotOf(holstWorld.id);
  return [
    ...w.characters.where((x) => x.slug == slug).map((x) => x.icon),
    ...w.items.where((x) => x.slug == slug).map((x) => x.icon),
  ].single;
}

Future<void> choose(WidgetTester t, String slug, String? icon) async {
  await t.tap(token(slug));
  await t.pumpAndSettle();
  await t.tap(k('holst-glyph'));
  await t.pumpAndSettle();
  await t.scrollUntilVisible(
    k('glyph-pick-${icon ?? 'none'}'),
    200,
    scrollable: find.descendant(
      of: k('glyph-sheet'),
      matching: find.byType(Scrollable),
    ),
  );
  await t.tap(k('glyph-pick-${icon ?? 'none'}'));
  await settle(t);
}

void main() {
  testWidgets(
    'Слизню — значок слизня: в истории, на жетоне, «Отменить» снимает',
    (t) async {
      final c = await ashMines();
      await pumpHolst(t, c, size: const Size(1100, 800));
      final sets = c.journal.length;
      expect(k('glyph-slizen'), findsNothing);
      await choose(t, 'slizen', 'slime');
      expect(snack(t), 'Значок «Слизень»: слизень');
      expect(snackSub(t), 'проверено · в истории');
      expect(await iconOf(c, 'slizen'), 'slime');
      expect(c.journal.length, sets + 1);
      expect(
        find.descendant(of: token('slizen'), matching: k('glyph-slizen')),
        findsOneWidget,
      );
      await t.tap(k('holst-snack-action'));
      await settle(t);
      expect(await iconOf(c, 'slizen'), isNull);
      expect(k('glyph-slizen'), findsNothing);
    },
  );

  testWidgets('предмет на полке — кирке значок кирки; «Без значка» убирает', (
    t,
  ) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: const Size(1100, 800));
    await choose(t, 'kirka', 'war-pick');
    expect(await iconOf(c, 'kirka'), 'war-pick');
    // Выбор того же жетона снимает выделение — выбираем заново.
    await t.tap(token('kirka'));
    await t.pumpAndSettle();
    await choose(t, 'kirka', null);
    expect(await iconOf(c, 'kirka'), isNull);
  });

  testWidgets('у события и квеста кнопки «Значок» нет', (t) async {
    await pumpHolst(t, await ashMines(), size: const Size(1100, 800));
    for (final slug in ['zasada', 'obval']) {
      await t.tap(token(slug));
      await t.pumpAndSettle();
      expect(k('holst-info'), findsOneWidget, reason: slug);
      expect(k('holst-glyph'), findsNothing, reason: slug);
      await t.tap(token(slug));
      await t.pumpAndSettle();
    }
  });

  testWidgets('нижняя строка связи — рамка и значок, как на жетоне', (t) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: const Size(1100, 800));
    await choose(t, 'slizen', 'slime');
    await t.tap(token('slizen'));
    await t.pumpAndSettle();
    await t.tap(token('obval'));
    await t.pumpAndSettle();
    expect(
      find.descendant(of: k('holst-link-slizen'), matching: k('glyph-slizen')),
      findsOneWidget,
    );
  });

  test(
    'каждое имя значка — файл картинки и наоборот; имена не повторяются',
    () {
      final ids = [for (final (_, g) in glyphGroups) ...g.keys];
      expect(ids.toSet().length, ids.length);
      final files = {
        for (final f in Directory('assets/glyphs').listSync())
          f.uri.pathSegments.last.replaceAll('.svg', ''),
      };
      // Опечатка в имени — пустая клетка у автора; лишний файл — значок, которого не выбрать.
      expect(files, ids.toSet());
      expect(glyphName('нет-такого'), isNull);
    },
  );
}
