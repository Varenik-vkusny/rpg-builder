// ПОКАЗ, а не проверка: сквозной путь 2.1–2.6 — рисует экраны мира на подменённой базе в PNG
// с настоящим шрифтом (иконки — квадратики). В check.sh не входит.
// Запуск: flutter test --no-pub demo/snapshots_test.dart  → снимки в build/snapshots/
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';

import '../test/fakes.dart';

final _frame = GlobalKey();

Future<void> _loadFont() async {
  final bytes = File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await t.runAsync(() async {
    final boundary =
        _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/snapshots/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Открывает выпадающий список и выбирает вариант.
Future<void> _pick(WidgetTester t, String key, String option) async {
  await _tap(t, find.byKey(Key(key)));
  await t.tap(find.text(option).last);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('содержимое мира по срезам 2.1–2.4', (t) async {
    await t.runAsync(_loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final content = FakeContent();
    await pumpApp(t, content: content, wrap: _frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await t.tap(find.text('Пепельные копи'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('new-location')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('location-title')), 'Штольня №3');
    await t.enterText(
      find.byKey(const Key('location-description')),
      'Затопленный нижний ярус, пахнет пеплом',
    );
    await _shot(t, '2.1-form');
    await t.tap(find.byKey(const Key('location-save')));
    await _shot(t, '2.1-world');

    await t.tap(find.byKey(const Key('new-item')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('item-title')), 'Ключ от лебёдки');
    await t.tap(find.byKey(const Key('item-kind-quest')));
    await t.enterText(find.byKey(const Key('item-level')), '2');
    await _shot(t, '2.2-form');
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('new-item')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('item-title')), 'Кирка');
    await t.tap(find.byKey(const Key('item-rarity-rare')));
    await t.enterText(find.byKey(const Key('item-level')), '3');
    await t.enterText(find.byKey(const Key('item-stat')), '6');
    await t.enterText(find.byKey(const Key('item-price')), '40');
    await t.tap(find.byKey(const Key('item-save')));
    await _shot(t, '2.2-world');

    await t.tap(find.byKey(const Key('new-character')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('character-title')),
      'Пепельный слизень',
    );
    await t.tap(find.byKey(const Key('character-role-enemy')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('character-location')));
    await t.pumpAndSettle();
    await t.tap(find.text('Штольня №3').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('loot-add')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('loot-item-0')));
    await t.pumpAndSettle();
    await t.tap(find.text('Ключ от лебёдки').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('loot-chance-0')), '35');
    await _shot(t, '2.3-form');
    await t.tap(find.byKey(const Key('character-save')));
    await _shot(t, '2.3-world');

    // 2.4: житель «Бригадир Эрден» выдаёт квест «Обвал в третьей штольне».
    await _tap(t, find.byKey(const Key('new-character')));
    await t.enterText(
      find.byKey(const Key('character-title')),
      'Бригадир Эрден',
    );
    await _tap(t, find.byKey(const Key('character-save')));
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(
      find.byKey(const Key('new-quest')),
      200,
      scrollable: list,
    );
    await _tap(t, find.byKey(const Key('new-quest')));
    await t.enterText(
      find.byKey(const Key('quest-title')),
      'Обвал в третьей штольне',
    );
    await _tap(t, find.byKey(const Key('quest-giver')));
    await _shot(t, '2.4-giver-only-npc'); // врага в списке нет
    await t.tap(find.text('Бригадир Эрден').last);
    await t.pumpAndSettle();
    await _pick(t, 'step-target-0-talk', 'Бригадир Эрден');
    await _tap(t, find.byKey(const Key('step-add')));
    await _pick(t, 'step-kind-1', 'Убить');
    await _pick(t, 'step-target-1-kill', 'Пепельный слизень');
    await t.enterText(find.byKey(const Key('step-amount-1')), '4');
    await _tap(t, find.byKey(const Key('step-add')));
    await _pick(t, 'step-kind-2', 'Собрать');
    await _pick(t, 'step-target-2-collect', 'Ключ от лебёдки');
    await t.enterText(find.byKey(const Key('step-amount-2')), '1');
    await _tap(t, find.byKey(const Key('reward-add')));
    await _pick(t, 'reward-0', 'Кирка');
    await _shot(t, '2.4-form');
    await _tap(t, find.byKey(const Key('quest-save')));
    await t.scrollUntilVisible(
      find.text('Обвал в третьей штольне'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _shot(t, '2.4-world');

    // 2.5: мир из приёмки цел — проверка проблем не находит.
    await _tap(t, find.byKey(const Key('check-world')));
    await _shot(t, '2.5-check-clean');
    await t.pageBack();
    await t.pumpAndSettle();

    // 2.6: «Кайло» ур. 2 с уроном 14 при потолке 8, и его нигде не получить.
    await content.createItem(
      '0-Пепельные копи',
      const NewItem(
        title: 'Кайло',
        kind: ItemKind.weapon,
        rarity: Rarity.common,
        level: 2,
        damage: 14,
        price: 10,
      ),
    );
    await _tap(t, find.byKey(const Key('check-world')));
    expect(find.text('Ошибок: 0 · Предупреждений: 2'), findsOneWidget);
    await _shot(t, '2.6-check-warnings');
    await t.pageBack();
    await t.pumpAndSettle();

    // Второй аккаунт: чужого мира и его содержимого не видит.
    await t.pageBack();
    await t.pumpAndSettle();
    await _tap(t, find.byKey(const Key('sign-out')));
    await signUp(t, 'second@test.dev');
    await _shot(t, '2.4-second-account');

    final saved = (await content.locations('0-Пепельные копи')).single;
    expect(saved, isA<Location>());
    // slug виден только здесь — в интерфейсе его нет.
    debugPrint('slug: ${saved.slug}');
    for (final i in await content.items('0-Пепельные копи')) {
      debugPrint('slug: ${i.slug}');
    }
  });
}
