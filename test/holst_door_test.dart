// Прибор С9: подпись двери «внутри: …» — имена только целиком, лишнее — «· ещё N»;
// никогда не обрывается на запятой и не режет имя. Пусто — «пусто».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/map/door_inside.dart';
import 'package:rpg_builder/map/holst_doors.dart';
import 'package:rpg_builder/map/holst_scene.dart';
import 'package:rpg_builder/ui/theme.dart';

import 'real_fonts.dart';

const _zaboy = Location(
  id: 'z',
  slug: 'zaboy',
  title: 'Забой',
  description: '',
  levelMin: 1,
  levelMax: 3,
);

/// Что нарисовано на двери (кроме названия места).
Future<String> label(WidgetTester t, List<String> inside) async {
  await t.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: DoorTile(
            door: HolstDoor(
              _zaboy,
              const Rect.fromLTWH(0, 0, 148, 104),
              inside,
            ),
            onEnter: () {},
          ),
        ),
      ),
    ),
  );
  final texts = [
    for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? '',
  ];
  return texts.firstWhere((s) => s.startsWith('внутри') || s == 'пусто');
}

void main() {
  test('таблица: сколько имён влезает', () {
    // Влезает всё.
    expect(
      insideLabel(['Слизень', 'Засада'], (_) => true),
      'внутри: Слизень, Засада',
    );
    // Влезает одно имя и «ещё».
    expect(
      insideLabel(['Слизень', 'Засада'], (s) => !s.contains(', ')),
      'внутри: Слизень · ещё 1',
    );
    expect(
      insideLabel([
        'Слизень',
        'Засада',
        'Камнеед',
      ], (s) => s.split(', ').length <= 2),
      'внутри: Слизень, Засада · ещё 1',
    );
    // Не влезает даже одно имя — только счёт.
    expect(insideLabel(['Слизень', 'Засада'], (_) => false), 'внутри: ещё 2');
  });

  testWidgets('на двери: целые имена или «ещё N», запятой в конце нет', (
    t,
  ) async {
    await t.runAsync(loadFont);
    for (final names in [
      ['Слизень', 'Засада'],
      ['Слизень', 'Засада', 'Камнеед'],
      ['Слизень', 'Засада', 'Камнеед', 'Гоблин-разведчик', 'Страж'],
      ['Каменный великан-старейшина', 'Засада'],
      ['Камнеед'],
    ]) {
      final s = await label(t, names);
      expect(s.endsWith(','), isFalse, reason: s);
      expect(s.endsWith(' '), isFalse, reason: s);
      final body = s.substring('внутри: '.length);
      final shown = body.split(' · ещё ');
      final listed = shown.first == 'ещё ${names.length}'
          ? <String>[]
          : shown.first.split(', ');
      // Каждое показанное имя — целиком из списка, по порядку.
      expect(listed, names.take(listed.length).toList(), reason: s);
      // Остаток считается верно.
      if (shown.length == 2) {
        expect(int.parse(shown[1]), names.length - listed.length, reason: s);
      } else if (shown.first != 'ещё ${names.length}') {
        expect(listed.length, names.length, reason: s);
      }
    }
  });

  testWidgets('много имён на узкой двери 148 — «· ещё N»', (t) async {
    await t.runAsync(loadFont);
    final s = await label(t, [
      'Слизень',
      'Засада',
      'Камнеед',
      'Гоблин-разведчик',
    ]);
    expect(s, contains('· ещё'));
  });

  testWidgets('случай телефона 22.11: «Слизень, Засада» — оба целиком', (
    t,
  ) async {
    await t.runAsync(loadFont);
    expect(await label(t, ['Слизень', 'Засада']), 'внутри: Слизень, Засада');
  });

  testWidgets('пусто — «пусто»', (t) async {
    await t.runAsync(loadFont);
    expect(await label(t, []), 'пусто');
  });
}
