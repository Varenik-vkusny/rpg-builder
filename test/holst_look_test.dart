// Прибор 5е.2 «Смотреть»: холст уровня в виде «плашка» — места с жетонами внутри, двери,
// полка; нажал объект — метки на связанных, остальное гаснет; издалека — числа, вблизи — объекты.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/gesture_link.dart';
import 'package:rpg_builder/map/holst_links.dart';
import 'package:rpg_builder/map/holst_scene.dart';
import 'package:rpg_builder/map/holst_tags.dart';
import 'package:rpg_builder/map/holst_threads.dart' show ThreadTone;

import 'holst_fixture.dart';

Finder token(String slug) => find.byKey(Key('token-$slug'));

double opacityOf(WidgetTester t, String slug) => t
    .widget<AnimatedOpacity>(
      find
          .ancestor(of: token(slug), matching: find.byType(AnimatedOpacity))
          .first,
    )
    .opacity;

/// Метки связей (слой меток холста).
HolstTags drawnTags(WidgetTester t) {
  final w = t.widget<CustomPaint>(find.byKey(const Key('holst-tags')));
  return (w.painter! as TagPainter).tags();
}

/// Метки на объектах: id объекта → слова.
Map<String, String> tagTexts(WidgetTester t) => {
  for (final x in drawnTags(t).tags) x.id: x.text,
};

/// Плитки связей нижней строки: имя объекта → как связаны.
Map<String, String> linkTiles(WidgetTester t) {
  final out = <String, String>{};
  final info = find.byKey(const Key('holst-info'));
  for (final e
      in find
          .descendant(
            of: info,
            matching: find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('holst-link-'),
            ),
          )
          .evaluate()) {
    final texts = [
      for (final x
          in find
              .descendant(
                of: find.byWidget(e.widget),
                matching: find.byType(Text),
              )
              .evaluate())
        (x.widget as Text).data!,
    ];
    out[texts.first] = texts.last;
  }
  return out;
}

/// Все тексты нижней строки выбранного.
List<String> infoTexts(WidgetTester t) => [
  for (final x
      in find
          .descendant(
            of: find.byKey(const Key('holst-info')),
            matching: find.byType(Text),
          )
          .evaluate())
    (x.widget as Text).data ?? '',
];

void main() {
  testWidgets('верхний уровень: места с жетонами, вложенное — дверью', (
    t,
  ) async {
    await pumpHolst(t, await ashMines());
    for (final p in ['shtolnya_3', 'baraki', 'rynok', 'lebedka']) {
      expect(find.byKey(Key('hplace-$p')), findsOneWidget, reason: p);
    }
    expect(find.byKey(const Key('hplace-zaboy')), findsNothing);
    expect(find.byKey(const Key('hdoor-zaboy')), findsOneWidget);
    expect(find.text('внутри: Камнеед'), findsOneWidget);
    expect(token('kamneed'), findsNothing);
    // Слизень — в своей штольне, с числом из сцены «Засада».
    final shaft = t.getRect(find.byKey(const Key('hplace-shtolnya_3')));
    expect(shaft.contains(t.getCenter(token('slizen'))), isTrue);
    expect(
      find.descendant(of: token('slizen'), matching: find.text('×3')),
      findsOneWidget,
    );
  });

  testWidgets('полка у нижнего края: квест и предметы', (t) async {
    await pumpHolst(t, await ashMines());
    final shelf = find.byKey(const Key('holst-shelf'));
    Finder onShelf(String slug) =>
        find.descendant(of: shelf, matching: token(slug));
    expect(onShelf('obval'), findsOneWidget);
    expect(onShelf('klyuch_ot_lebedki'), findsOneWidget);
    // В тестах шрифт шире настоящего: полку докручиваем до последнего жетона.
    await t.dragUntilVisible(
      onShelf('kirka'),
      find.descendant(of: shelf, matching: find.byType(ListView)),
      const Offset(-200, 0),
    );
    expect(onShelf('kirka'), findsOneWidget);
    expect(
      t.getRect(shelf).bottom,
      greaterThan(t.getRect(token('storozh')).bottom),
    );
  });

  testWidgets(
    'нажал Слизня — его связи внизу, соседи светятся, остальное гаснет',
    (t) async {
      await pumpHolst(t, await ashMines());
      expect(find.byKey(const Key('holst-info')), findsNothing);
      expect(drawnTags(t).tags, isEmpty, reason: 'в покое меток нет');
      await t.tap(token('slizen'));
      await t.pumpAndSettle();
      // Связи выбранного — белыми метками на самих объектах (выбор владельца 17.10).
      expect(drawnTags(t).tags.map((x) => x.tone).toSet(), {ThreadTone.hot});
      final w = await (await (() async => ashMines())()).snapshotOf(
        holstWorld.id,
      );
      String id(String slug) => [
        ...w.characters.where((x) => x.slug == slug).map((x) => x.id),
        ...w.events.where((x) => x.slug == slug).map((x) => x.id),
        ...w.items.where((x) => x.slug == slug).map((x) => x.id),
        ...w.quests.where((x) => x.slug == slug).map((x) => x.id),
      ].single;
      final tags = tagTexts(t);
      // Слово — про того, на ком метка: Засада — «враги ×3» (решение владельца 19.10).
      expect(tags[id('zasada')], 'враги ×3');
      // Метка — у самого объекта, над ним.
      final canvas = t.getTopLeft(find.byKey(const Key('holst-canvas')));
      final ambush = t.getRect(token('zasada')).shift(-canvas);
      final spec = drawnTags(t).tags.firstWhere((x) => x.id == id('zasada'));
      expect(spec.rect, ambush);
      // Квест и ключ — на полке: видны — метка, за краем — маленькая метка у края.
      final all = {...tags.keys, for (final e in drawnTags(t).edges) e.id};
      expect(
        all,
        containsAll([id('obval'), id('klyuch_ot_lebedki'), id('zasada')]),
      );
      // Связи — плитками: объект и как связан; ни точек, ни косых черт, ни «житель · место».
      expect(linkTiles(t), {
        'Обвал': 'шаг 1: убить ×3',
        'Ключ от лебёдки': 'выпадает 35%',
        // Под плиткой — кем объект плитки приходится выбранному.
        'Засада': 'враги ×3',
      });
      for (final x in infoTexts(t)) {
        expect(x.contains('·') || x.contains(' / '), isFalse, reason: x);
      }
      expect(infoTexts(t), isNot(contains(contains('Штольня'))));
      for (final s in ['slizen', 'obval', 'zasada', 'klyuch_ot_lebedki']) {
        expect(opacityOf(t, s), 1, reason: s);
      }
      for (final s in ['brigadir', 'storozh']) {
        expect(opacityOf(t, s), lessThan(.5), reason: s);
      }
      // Ещё раз — выбор снят, всё светится.
      await t.tap(token('slizen'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('holst-info')), findsNothing);
      expect(opacityOf(t, 'brigadir'), 1);
      expect(drawnTags(t).tags, isEmpty);
    },
  );

  testWidgets('издалека — места с числами без жетонов; вблизи — снова жетоны', (
    t,
  ) async {
    await pumpHolst(t, await ashMines());
    await t.tap(find.byKey(const Key('holst-zoom')));
    await t.pumpAndSettle();
    expect(token('slizen'), findsNothing);
    expect(find.text('издалека'), findsOneWidget);
    final shaft = find.byKey(const Key('hplace-shtolnya_3'));
    expect(
      find.descendant(of: shaft, matching: find.text('3')),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('holst-zoom')));
    await t.pumpAndSettle();
    expect(token('slizen'), findsOneWidget);
  });

  testWidgets('дверь ведёт внутрь: путь сверху, назад — уровень вверх', (
    t,
  ) async {
    await pumpHolst(t, await ashMines());
    // Дверь нажимается целиком, не только стрелкой.
    final door = t.getRect(find.byKey(const Key('hdoor-zaboy')));
    await t.tapAt(door.topLeft + const Offset(30, 30));
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('holst-path'))).data,
      'Штольня №3 › Забой',
    );
    expect(token('kamneed'), findsOneWidget);
    expect(token('slizen'), findsNothing);
    await t.tap(find.byKey(const Key('holst-back')));
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('holst-path'))).data,
      'Штольня №3',
    );
    await t.tap(find.byKey(const Key('holst-back')));
    await t.pumpAndSettle();
    expect(t.widget<Text>(find.byKey(const Key('holst-path'))).data, 'Мир');
  });

  testWidgets('цели не меньше 48 dp, ширина 360 и 400 — без переполнения', (
    t,
  ) async {
    for (final w in [360.0, 400.0]) {
      await pumpHolst(t, await ashMines(), size: Size(w, 760));
      expect(t.getSize(token('slizen')).height, greaterThanOrEqualTo(48));
      expect(t.getSize(find.byKey(const Key('henter-zaboy'))).height, 48);
      expect(t.takeException(), isNull);
    }
  });

  test(
    'связи мира словами автора: слово — про тот конец, на котором стоит',
    () async {
      final w = await (await ashMines()).snapshotOf(holstWorld.id);
      final words = [for (final l in worldLinks(w)) (l.back, l.label, l.step)];
      expect(words, [
        ('его квест', 'выдаёт', null),
        ('убить ×3', 'убить ×3', 1),
        ('пройти', 'пройти', 2),
        ('собрать ×1', 'собрать ×1', 3),
        ('даёт в награду', 'в награду', null),
        ('роняет 35%', 'выпадает 35%', null),
        ('враги ×3', 'в сцене ×3', null),
      ]);
    },
  );

  test('место растёт под жетоны; не влезло — «ещё N», не спрятано', () async {
    final w = await (await ashMines()).snapshotOf(holstWorld.id);
    final shaft = w.locations.firstWhere((l) => l.slug == 'shtolnya_3');
    final many = [
      for (var i = 0; i < 20; i++)
        HolstToken(id: '$i', slug: 's$i', kind: TokenKind.enemy, title: '$i'),
    ];
    final p = layPlace(shaft, Offset.zero, many, const []);
    expect(p.tokens.length + p.overflow, 20);
    expect(p.overflow, greaterThan(0));
    expect(p.overflowRect, isNotNull);
    for (final x in p.tokens) {
      expect(p.rect.contains(x.rect.center), isTrue);
      expect(x.rect.overlaps(p.overflowRect!), isFalse);
    }
  });

  test('связи по объекту: одна плитка, все виды связи в ней', () {
    const links = [
      HolstLink('q', 'npc', 'выдаёт'),
      HolstLink('q', 'npc', 'поговорить'),
      HolstLink('q', 'key', 'собрать ×1'),
    ];
    final g = linkGroups('q', links);
    expect(g.map((x) => x.other), ['npc', 'key']);
    expect(g.first.words, ['выдаёт', 'поговорить']);
  });

  testWidgets('две связи с одним объектом — одна плитка, без точек', (t) async {
    final c = await ashMines();
    final w = await c.snapshotOf(holstWorld.id);
    final quest = w.quests.single.id;
    final brig = w.characters.firstWhere((x) => x.slug == 'brigadir').id;
    // Квест и выдаётся Бригадиром, и просит с ним поговорить.
    await c.applyManualEdit(
      holstWorld.id,
      linkByGesture(holstWorld.id, w, LinkKind.talk, quest, brig, 1),
    );
    await pumpHolst(t, c);
    await t.tap(token('brigadir'));
    await t.pumpAndSettle();
    expect(linkTiles(t), {'Обвал': 'его квест, шаг 4: поговорить'});
    for (final x in infoTexts(t)) {
      expect(x.contains('·') || x.contains(' / '), isFalse, reason: x);
    }
  });

  testWidgets(
    'слово — про объект, на котором стоит: Кирка у Обвала «в награду», Обвал у Кирки «даёт в награду»',
    (t) async {
      await pumpHolst(t, await ashMines(), size: const Size(1100, 800));
      await t.tap(token('obval'));
      await t.pumpAndSettle();
      expect(linkTiles(t)['Кирка'], 'в награду');
      expect(linkTiles(t)['Бригадир'], 'выдаёт');
      await t.tap(token('kirka'));
      await t.pumpAndSettle();
      expect(linkTiles(t), {'Обвал': 'даёт в награду'});
      // Метка на Обвале — теми же словами.
      expect(tagTexts(t).values, ['даёт в награду']);
    },
  );
}
