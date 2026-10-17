// Прибор «мир открывается холстом» (решение владельца 17.10): из списка миров — холст;
// «Списки» — прежний экран мира; назад — снова холст с перечитанным миром; назад с холста —
// список миров.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/location.dart';

import 'assistant_fixtures.dart' show minesId;
import 'fakes.dart';

Finder k(String key) => find.byKey(Key(key));

void main() {
  testWidgets(
    'мир открывается холстом; «Списки» и назад; новое из списков — на холсте',
    (t) async {
      final c = FakeContent();
      await pumpApp(t, content: c);
      await signUp(t, 'author@test.dev');
      await createWorld(t, 'Пепельные копи');
      await t.tap(find.text('Пепельные копи'));
      await t.pumpAndSettle();
      // Холст, а не списки: пустой мир — три старта.
      expect(k('holst-canvas'), findsOneWidget);
      expect(k('holst-empty'), findsOneWidget);
      expect(k('new-location'), findsNothing);

      await t.tap(k('holst-lists'));
      await t.pumpAndSettle();
      expect(k('new-location'), findsOneWidget);
      // Место создали со списков (как формой) — холст после возврата его показывает.
      const worldId = minesId; // id первого мира первого автора в FakeWorlds
      await c.createLocation(
        worldId,
        const NewLocation(
          title: 'Рынок',
          description: '',
          levelMin: 1,
          levelMax: 2,
        ),
      );
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(k('holst-canvas'), findsOneWidget);
      expect(k('hplace-rynok'), findsOneWidget);

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Пепельные копи'), findsOneWidget);
      expect(k('holst-canvas'), findsNothing);
    },
  );

  testWidgets('«Мои миры» — с тем же отступом слева, что карточки, не у края', (
    t,
  ) async {
    await pumpApp(t, content: FakeContent());
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    final title = t.getTopLeft(find.text('Мои миры')).dx;
    // Карточки миров и кнопка «Новый мир» стоят с полем 16 dp — заголовок там же.
    expect(title, inInclusiveRange(16, 18));
  });
}
