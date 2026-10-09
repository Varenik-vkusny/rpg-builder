// Правила полей ввода: длина названия (как в базе — не больше 120 знаков), вид почты,
// пустой поиск образцов. Автор узнаёт причину до отправки; ничего не создаётся.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/open5e/open5e_api.dart';
import 'package:rpg_builder/ui/input_rules.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'fakes.dart';
import 'manual_edit_flow_test.dart' show openMines;
import 'open5e_test.dart' show FakeOpen5e, openLibrary;

final _long = 'я' * 121;
const _tooLong = 'Слишком длинно: 121 знаков, а можно не больше 120';

void main() {
  group('название', () {
    test(
      'пустое — фраза формы; 120 знаков годится; 121 — причина с числом',
      () {
        expect(titleError('', 'Нужно название'), 'Нужно название');
        expect(titleError('я' * 120, 'Нужно название'), isNull);
        expect(titleError(_long, 'Нужно название'), _tooLong);
      },
    );

    test('считаются знаки, а не внутренние единицы строки', () {
      // Значок-эмодзи занимает в строке две единицы, но это один знак.
      expect(titleError('⚒' * 120, 'x'), isNull);
      expect(titleError('🗝' * 120, 'x'), isNull);
      expect(titleError('🗝' * 121, 'x'), isNotNull);
    });
  });

  group('почта', () {
    for (final ok in [
      'a@test.dev',
      'timur.akybaev@mail.example.com',
      'a+tag@b.kz',
    ]) {
      test('годится: $ok', () => expect(looksLikeEmail(ok), isTrue));
    }
    for (final bad in [
      'почта',
      'a@b',
      '@b.kz',
      'a@.kz',
      'a@b.',
      'a@b..kz',
      'a b@c.kz',
      'a@b@c.kz',
    ]) {
      test('не годится: $bad', () => expect(looksLikeEmail(bad), isFalse));
    }
  });

  testWidgets('вход: почта без «@» — причина, в приложение не пускает', (
    t,
  ) async {
    await pumpApp(t);
    await signUp(t, 'timur.mail.kz');
    expect(
      find.text('Почта выглядит неверно — нужен вид name@example.com'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sign-up')), findsOneWidget);
    expect(find.text('Мои миры'), findsNothing);

    await t.tap(find.byKey(const Key('sign-in')));
    await t.pumpAndSettle();
    expect(find.text('Мои миры'), findsNothing);

    await signUp(t, 'timur@mail.kz');
    expect(find.text('Мои миры'), findsOneWidget);
  });

  testWidgets('новый мир: название длиннее 120 знаков не принимается', (
    t,
  ) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await t.tap(find.byKey(const Key('new-world')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('world-title')), _long);
    await tapButton(t, 'world-save');
    expect(find.text(_tooLong), findsOneWidget);
    expect(find.text('Новый мир'), findsWidgets);
  });

  testWidgets('формы объектов: название длиннее 120 знаков не принимается, '
      'ничего не создано', (t) async {
    final content = await openMines(t);
    for (final kind in ['location', 'event', 'item', 'character', 'quest']) {
      await t.scrollUntilVisible(
        find.byKey(Key('new-$kind')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapButton(t, 'new-$kind');
      await t.enterText(find.byKey(Key('$kind-title')), _long);
      await tapButton(t, '$kind-save');
      expect(find.text(_tooLong), findsOneWidget, reason: kind);
      await t.pageBack();
      await t.pumpAndSettle();
    }
    expect(await content.locations(minesId), hasLength(2));
    expect(await content.events(minesId), isEmpty);
    expect(await content.items(minesId), hasLength(2));
    expect(await content.characters(minesId), hasLength(2));
    expect(await content.quests(minesId), hasLength(1));
  });

  testWidgets('место: ровно 120 знаков — принимается', (t) async {
    final content = await openMines(t);
    await tapButton(t, 'new-location');
    await t.enterText(find.byKey(const Key('location-title')), 'я' * 120);
    await tapButton(t, 'location-save');
    expect(await content.locations(minesId), hasLength(3));
  });

  testWidgets('образцы: пустой поиск — причина, запрос не уходит', (t) async {
    final api = FakeOpen5e(const <Open5eItem>[]);
    await openLibrary(t, api);
    api.queries.clear();
    await t.enterText(find.byKey(const Key('open5e-query')), '   ');
    await tapButton(t, 'open5e-search');
    expect(
      find.text('Напиши, что искать, — название по-английски'),
      findsOneWidget,
    );
    expect(api.queries, isEmpty);
  });
}
