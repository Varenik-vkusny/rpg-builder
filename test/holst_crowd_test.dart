// Холст, где объектов много (владелец 19.11): новый объект из палитры не теряется —
// виден на холсте сразу, даже если в месте уже больше, чем влезает.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/map/holst_scene.dart';

import 'assistant_fixtures.dart' show addAmbush, floodPlan;
import 'holst_change_test.dart' show ask, everyTry, k, mines;
import 'holst_build_test.dart' show build, drag, placeCenter, settle;
import 'holst_fixture.dart';
import 'holst_look_test.dart' show token;

const _place = Location(
  id: 'p',
  slug: 'p',
  title: 'Бараки',
  description: '',
  levelMin: 1,
  levelMax: 3,
);

List<HolstToken> _tokens(int n) => [
  for (var i = 0; i < n; i++)
    HolstToken(
      id: 't$i',
      slug: 't$i',
      kind: TokenKind.enemy,
      title: 'Гоблин $i',
      placeId: 'p',
    ),
];

List<String> _shown(HolstPlace p) => [for (final t in p.tokens) t.id];

void main() {
  test('место не тесное — новое ничего не двигает', () {
    final ts = _tokens(4);
    expect(
      _shown(layPlace(_place, Offset.zero, ts, const [], first: {'t0'})),
      _shown(layPlace(_place, Offset.zero, ts, const [])),
    );
  });

  test(
    'тесно: новое — в последней видимой клетке, остальные на своих местах',
    () {
      final ts = _tokens(16);
      final plain = _shown(layPlace(_place, Offset.zero, ts, const []));
      final p = layPlace(_place, Offset.zero, ts, const [], first: {'t15'});
      expect(p.overflow, greaterThan(0));
      final shown = _shown(p);
      expect(shown.last, 't15');
      expect(
        shown.sublist(0, shown.length - 1),
        plain.sublist(0, plain.length - 1),
      );
    },
  );

  test('новых больше, чем клеток, — видны самые поздние', () {
    final ts = _tokens(30);
    final cells = layPlace(_place, Offset.zero, ts, const []).tokens.length;
    final p = layPlace(
      _place,
      Offset.zero,
      ts,
      const [],
      first: {for (var i = 0; i < 30; i++) 't$i'},
    );
    expect(_shown(p), [for (var i = 30 - cells; i < 30; i++) 't$i']);
  });

  testWidgets(
    'в Бараках 14 врагов — новый из палитры виден, а не спрятан в «ещё N»',
    (t) async {
      final c = await ashMines();
      final w = await c.snapshotOf(holstWorld.id);
      final barracks = w.locations.firstWhere((l) => l.slug == 'baraki').id;
      for (var i = 1; i <= 14; i++) {
        await c.createCharacter(
          holstWorld.id,
          NewCharacter(
            title: 'Гоблин $i',
            description: '',
            role: Role.enemy,
            locationId: barracks,
            level: 1,
          ),
        );
      }
      await pumpHolst(t, c, size: const Size(412, 900));
      expect(
        find.byKey(const Key('hmore-baraki')),
        findsOneWidget,
        reason: 'тесно',
      );
      await build(t);
      await drag(t, 'enemy', placeCenter(t, 'baraki'));
      await settle(t);
      final made = (await c.snapshotOf(holstWorld.id)).characters
          .firstWhere((x) => x.title == 'Новый враг');
      expect(made.locationId, barracks);
      expect(find.byKey(Key('token-${made.slug}')), findsOneWidget);
    },
  );

  testWidgets(
    'мир на 20 мест и 120 врагов: холст открывается, издалека числа, новое видно',
    (t) async {
      final c = await ashMines();
      for (var p = 1; p <= 20; p++) {
        final place = await c.createLocation(
          holstWorld.id,
          NewLocation(
            title: 'Пещера $p',
            description: '',
            levelMin: 1,
            levelMax: 5,
          ),
        );
        for (var i = 1; i <= 6; i++) {
          await c.createCharacter(
            holstWorld.id,
            NewCharacter(
              title: 'Тварь $p-$i',
              description: '',
              role: Role.enemy,
              locationId: place.id,
              level: 1,
            ),
          );
        }
      }
      // И Бараки тесные — новый враг падает именно туда.
      final barracks = (await c.snapshotOf(holstWorld.id)).locations
          .firstWhere((l) => l.slug == 'baraki')
          .id;
      for (var i = 1; i <= 14; i++) {
        await c.createCharacter(
          holstWorld.id,
          NewCharacter(
            title: 'Гоблин $i',
            description: '',
            role: Role.enemy,
            locationId: barracks,
            level: 1,
          ),
        );
      }
      await pumpHolst(t, c, size: const Size(412, 900));
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('hmore-baraki')), findsOneWidget);
      // Издалека — места с числами, без жетонов.
      await t.tap(find.byKey(const Key('holst-zoom')));
      await settle(t);
      expect(find.textContaining('Пещера 20'), findsWidgets);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('holst-zoom')));
      await settle(t);
      // Новый враг в тесные Бараки — виден сразу.
      await build(t);
      await drag(t, 'enemy', placeCenter(t, 'baraki'));
      await settle(t);
      final made = (await c.snapshotOf(holstWorld.id)).characters
          .firstWhere((x) => x.title == 'Новый враг');
      expect(find.byKey(Key('token-${made.slug}')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  // Владелец: после «Применить» старые жетоны в месте прыгали на другие клетки.
  // Причина: порядок мира — сначала жители и враги, потом события; новый житель
  // вставал перед старым событием и сдвигал его на клетку.
  Map<String, Rect> rects(HolstPlace p) => {
    for (final t in p.tokens) t.id: t.rect,
  };

  HolstToken ev(String id) => HolstToken(
    id: id,
    slug: id,
    kind: TokenKind.event,
    title: id,
    placeId: 'p',
  );

  test(
    'новые объекты, даже встающие по порядку раньше старых, их не двигают',
    () {
      final before = [..._tokens(2), ev('e1')];
      final p0 = layPlace(_place, Offset.zero, before, const []);
      final fresh = _tokens(3).last; // t2: по порядку мира перед событием e1
      for (final after in [
        [before[0], before[1], fresh, before[2]],
        [fresh, ...before],
      ]) {
        final p1 = layPlace(
          _place,
          Offset.zero,
          after,
          const [],
          slots: p0.cellOf,
        );
        final r1 = rects(p1);
        rects(p0).forEach((id, r) => expect(r1[id], r, reason: id));
        // Новый — в клетке, свободной до плана.
        expect(
          rects(p0).values.contains(r1['t2']),
          isFalse,
          reason: 'новый встал на чужую клетку',
        );
        expect(p1.overflow, 0);
      }
      // Без памяти клеток событие прыгает — отсюда и баг.
      final jumped = layPlace(_place, Offset.zero, [
        before[0],
        before[1],
        fresh,
        before[2],
      ], const []);
      expect(rects(jumped)['e1'], isNot(rects(p0)['e1']));
    },
  );

  test('место стало широким — старые остаются в своём столбце и ряду', () {
    final before = _tokens(3);
    final p0 = layPlace(_place, Offset.zero, before, const []);
    final p1 = layPlace(
      _place,
      Offset.zero,
      [...before, ..._tokens(5).skip(3)],
      const [],
      slots: p0.cellOf,
    );
    rects(p0).forEach((id, r) => expect(rects(p1)[id], r, reason: id));
  });

  test('тесно: старые на своих клетках, новое видно в видимой клетке', () {
    final ts = _tokens(16);
    final p0 = layPlace(_place, Offset.zero, ts.take(15).toList(), const []);
    final p1 = layPlace(
      _place,
      Offset.zero,
      ts,
      const [],
      first: {'t15'},
      slots: p0.cellOf,
    );
    expect(_shown(p1), contains('t15'));
    final r1 = rects(p1);
    var kept = 0;
    rects(p0).forEach((id, r) {
      if (r1[id] != null) {
        expect(r1[id], r, reason: id);
        kept++;
      }
    });
    expect(kept, greaterThan(p1.tokens.length - 2));
  });

  testWidgets('«Применить» план: старые жетоны Штольни на тех же клетках', (
    t,
  ) async {
    final c = await mines();
    await addAmbush(c, holstWorld.id);
    await pumpHolst(
      t,
      c,
      size: const Size(380, 900),
      assistant: everyTry(floodPlan()),
    );
    final old = {
      for (final x in ['slizen', 'zasada_u_lebedki'])
        x: t.getRect(token(x)).topLeft - t.getTopLeft(k('holst-canvas')),
    };
    expect(old.length, 2);
    await ask(t);
    await t.pump(const Duration(seconds: 4));
    await t.tap(k('holst-plan-apply'));
    await settle(t);
    expect(token('utoplennik'), findsOneWidget, reason: 'новый на холсте');
    old.forEach((slug, at) {
      expect(
        t.getRect(token(slug)).topLeft - t.getTopLeft(k('holst-canvas')),
        at,
        reason: slug,
      );
    });
  });
}
