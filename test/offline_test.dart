// Прибор «Нет связи» (FEATURES 5ж, задание vision 26.11): обрыв сети и таймаут — не
// пустота и не текст исключения, а «Нет связи» и «Повторить» в списке миров, при
// открытии мира, на холсте после жеста, у ассистента до запроса и при «Применить».
// Введённое и план не теряются: «Повторить» делает то же действие ещё раз.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/ui/offline.dart';
import 'package:supabase/supabase.dart'
    show FunctionException, PostgrestException;

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'fakes.dart';
import 'holst_build_test.dart' show build, drag, placeCenter, settle, snack;
import 'holst_change_test.dart' as change show ask, everyTry, k, mines;
import 'holst_fixture.dart';

/// Так обрыв сети приходит от клиента Supabase на телефоне.
final noNet = Exception(
  'ClientException with SocketException: Failed host lookup: x.supabase.co',
);

/// Связь оборвалась посреди запроса: дошла ли запись — неизвестно.
final midway = Exception('ClientException: Connection reset by peer');

void main() {
  testWidgets(
    'список миров: обрыв — «Нет связи» и «Повторить»; повтор — список',
    (t) async {
      final auth = FakeAuth();
      final worlds = FakeWorlds(auth);
      await pumpApp(t, worlds: worlds);
      await signUp(t, 'a@test.dev');
      await createWorld(t, 'Пепельные копи');
      worlds.offline = noNet;
      await tapButton(t, 'sign-out');
      await signUp(t, 'a@test.dev');
      expect(find.byKey(const Key('load-failed')), findsOneWidget);
      expect(find.text('Нет связи'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      worlds.offline = null;
      await tapButton(t, 'retry');
      expect(find.byKey(const Key('load-failed')), findsNothing);
      expect(find.text('Пепельные копи'), findsOneWidget);
    },
  );

  testWidgets('открыть мир: таймаут — «Нет связи»; повтор — холст', (t) async {
    final content = await minesContent();
    await pumpApp(t, content: content);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    content.offline = TimeoutException('сеть молчит');
    await t.tap(find.text('Пепельные копи'));
    await t.pumpAndSettle();
    expect(find.text('Нет связи'), findsOneWidget);
    content.offline = null;
    await tapButton(t, 'retry');
    expect(find.byKey(const Key('holst-lists')), findsOneWidget);
  });

  testWidgets(
    'холст: жест без сети — «Нет связи» и «Повторить»; повтор записывает',
    (t) async {
      final c = await ashMines();
      await pumpHolst(t, c);
      await build(t);
      c.offline = noNet;
      await drag(t, 'npc', placeCenter(t, 'rynok'));
      expect(snack(t), 'Нет связи');
      c.offline = null;
      await t.tap(find.text('Повторить'));
      await settle(t);
      expect(snack(t), 'Создано: Житель 1 в месте «Рынок»');
    },
  );

  testWidgets(
    'ассистент: обрыв посреди запроса — просьба на месте, повтор даёт план',
    (t) async {
      await openAssistant(
        t,
        FakeAssistant([
          TimeoutException('сеть молчит'),
          proposal(floodPlan()),
          proposal(floodPlan()),
          proposal(floodPlan()),
        ]),
      );
      await ask(t);
      expect(find.byKey(const Key('retry-strip')), findsOneWidget);
      expect(find.text('Нет связи'), findsOneWidget);
      // Просьба не потерялась.
      expect(find.textContaining('затопи её'), findsWidgets);
      await tapButton(t, 'retry');
      expect(find.byKey(const Key('retry-strip')), findsNothing);
      expect(find.byKey(const Key('plan-apply')), findsOneWidget);
    },
  );

  testWidgets(
    'ассистент: «Применить» без сети — план на месте, повтор применяет',
    (t) async {
      final (content, _) = await openAssistant(t);
      await ask(t);
      content.offline = noNet;
      await tapButton(t, 'plan-apply');
      expect(find.byKey(const Key('retry-strip')), findsOneWidget);
      expect(
        find.byKey(const Key('plan-apply')),
        findsOneWidget,
        reason: 'план не потерян',
      );
      expect(content.journal, isEmpty);
      content.offline = null;
      await tapButton(t, 'retry');
      expect(content.journal, hasLength(1));
    },
  );

  // Ревью 26.11: повтор записи после обрыва посреди запроса мог записать дважды.
  testWidgets(
    'холст: связь оборвалась посреди записи — без «Повторить», «проверь историю»',
    (t) async {
      final c = await ashMines();
      await pumpHolst(t, c);
      await build(t);
      c.offline = midway;
      await drag(t, 'npc', placeCenter(t, 'rynok'));
      expect(snack(t), 'Нет связи');
      expect(find.text('Повторить'), findsNothing);
      expect(find.textContaining('проверь историю'), findsOneWidget);
    },
  );

  testWidgets('ассистент: «Применить» оборвалось посреди — без повтора', (
    t,
  ) async {
    final (content, _) = await openAssistant(t);
    await ask(t);
    content.offline = midway;
    await tapButton(t, 'plan-apply');
    expect(find.byKey(const Key('retry')), findsNothing);
    expect(find.textContaining('проверь историю'), findsOneWidget);
    expect(
      find.byKey(const Key('plan-apply')),
      findsOneWidget,
      reason: 'план на месте',
    );
  });

  testWidgets('список миров: сеть молчит дольше 20 с — «Нет связи»', (t) async {
    final auth = FakeAuth();
    final worlds = FakeWorlds(auth)..hang = true;
    await pumpApp(t, worlds: worlds);
    // Вход ждёт, пока экран успокоится: без таймаута крутилка вертелась бы вечно.
    await signUp(t, 'a@test.dev');
    expect(find.text('Нет связи'), findsOneWidget);
  });

  test(
    'отказ сервера по делу — не «нет связи», даже со словами про соединение',
    () {
      expect(
        isOffline(
          const PostgrestException(message: 'Connection reset by policy'),
        ),
        isFalse,
      );
      expect(
        isOffline(FunctionException(status: 500, details: 'ClientException')),
        isFalse,
      );
      expect(isOffline(noNet), isTrue);
      expect(neverSent(noNet), isTrue);
      expect(neverSent(midway), isFalse);
      expect(isOffline(midway), isTrue);
    },
  );

  // Ревью 26.11: строка FEATURES обещает «Нет связи» и на холсте при плане, и при «Отклонить».
  testWidgets(
    'холст: «Применить» плана без сети — «Повторить», план на месте; повтор применяет',
    (t) async {
      final c = await change.mines();
      await pumpHolst(t, c, assistant: change.everyTry(floodPlan()));
      await change.ask(t);
      await settle(t);
      await t.pump(const Duration(seconds: 3));
      c.offline = noNet;
      await t.tap(change.k('holst-plan-apply'));
      await settle(t);
      expect(snack(t), 'Нет связи');
      expect(
        change.k('holst-plan-apply'),
        findsOneWidget,
        reason: 'план не потерян',
      );
      c.offline = null;
      await t.tap(find.text('Повторить'));
      await settle(t);
      expect(c.journal, hasLength(1));
    },
  );

  testWidgets(
    'ассистент: «Отклонить» без сети — «Повторить»; повтор пишет отказ',
    (t) async {
      final (content, _) = await openAssistant(t);
      await ask(t);
      content.offline = noNet;
      await tapButton(t, 'plan-reject');
      expect(find.byKey(const Key('retry-strip')), findsOneWidget);
      content.offline = null;
      await tapButton(t, 'retry');
      expect(content.journal, hasLength(1));
    },
  );
}
