// ПОКАЗ ВИДЕО, а не проверка: настоящее приложение под Windows, настоящая база и ассистент.
// Кнопки нажимает тест, окно записывает scripts/record_demo.sh (ffmpeg). В check.sh не входит.
// Сцена: вход → мир «Пепельные копи» → Ассистент → «Штольня №3» → просьба с атакой 14 →
// ассистент спрашивает → ответ → план → «Применить» → История → «Откатить» → мир как был.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test/assistant_fixtures.dart' show fillMines;
import '../test/fakes.dart' show createWorld, openWorld;

const email = String.fromEnvironment('RPGB_TEST_EMAIL_T');
const password = String.fromEnvironment('RPGB_TEST_PASSWORD');
const worldTitle = 'Пепельные копи';
const request =
    'Третья штольня затоплена, слизни там жить не могут. '
    'Теперь там живут утопленники 3 уровня с атакой 14.';

/// Пауза, чтобы зритель успел прочитать экран.
Future<void> pause(WidgetTester t, [int seconds = 2]) async {
  await Future<void>.delayed(Duration(seconds: seconds));
  await t.pump();
}

/// Ждёт, пока появится один из [finders] (сеть и ассистент — до [limit]).
Future<Finder> waitFor(
  WidgetTester t,
  List<Finder> finders, {
  Duration limit = const Duration(seconds: 150),
}) async {
  final end = DateTime.now().add(limit);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    for (final f in finders) {
      if (f.evaluate().isNotEmpty) return f;
    }
  }
  throw StateError('не дождались: $finders');
}

Future<void> tapAndWait(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('показ: вопрос ассистента, применить, откатить', (t) async {
    await app.main();
    await t.pumpAndSettle();
    final db = Supabase.instance.client;
    if (db.auth.currentUser != null) await db.auth.signOut();
    await t.pumpAndSettle();

    // Вход тестовым автором (пароль в поле скрыт).
    await t.enterText(find.byKey(const Key('email')), email);
    await t.enterText(find.byKey(const Key('password')), password);
    await pause(t, 1);
    await tapAndWait(t, find.byKey(const Key('sign-in')));
    await waitFor(t, [find.byKey(const Key('new-world'))]);

    // Мир для показа: создан руками, наполнен «Пепельными копями».
    await createWorld(t, worldTitle);
    await waitFor(t, [find.text(worldTitle)]);
    final world = await db
        .from('projects')
        .select('id')
        .eq('title', worldTitle)
        .order('created_at', ascending: false)
        .limit(1)
        .single();
    final worldId = world['id'] as String;
    addTearDown(() => db.from('projects').delete().eq('id', worldId));
    await fillMines(SupabaseContentRepo(db), worldId);
    await openWorld(t, worldTitle);
    await waitFor(t, [find.byKey(const Key('assistant-open'))]);
    await pause(t, 3);

    // Ассистент: область «Штольня №3», просьба с атакой 14.
    await tapAndWait(t, find.byKey(const Key('assistant-open')));
    await tapAndWait(t, find.byKey(const Key('scope-type-location')));
    await tapAndWait(t, find.byKey(const Key('scope-object-location')));
    await tapAndWait(t, find.text('Штольня №3').last);
    await t.enterText(find.byKey(const Key('assistant-request')), request);
    await pause(t, 2);
    await tapAndWait(t, find.byKey(const Key('assistant-propose')));

    // Ассистент спрашивает (бывает, дважды) — каждый раз выбираем его совет.
    while (true) {
      final next = await waitFor(t, [
        find.byKey(const Key('question-dialog')),
        find.byKey(const Key('plan-apply')),
        find.byKey(const Key('assistant-error')),
      ]);
      if (next.evaluate().first.widget.key != const Key('question-dialog')) {
        break;
      }
      await pause(t, 5);
      await tapAndWait(t, find.byKey(const Key('question-option-0')));
      await pause(t, 1);
      await tapAndWait(t, find.byKey(const Key('question-answer')));
    }

    // План «было → стало» и проверка на копии.
    expect(find.byKey(const Key('assistant-error')), findsNothing);
    await pause(t, 3);
    final list = find.byType(Scrollable).first;
    await t.drag(list, const Offset(0, -500));
    await pause(t, 3);
    await t.drag(list, const Offset(0, 500));
    await pause(t, 1);
    await tapAndWait(t, find.byKey(const Key('plan-apply')));
    await waitFor(t, [find.byKey(const Key('history-open'))]);
    await pause(t, 3);

    // История → «Откатить» → мир как был.
    await tapAndWait(t, find.byKey(const Key('history-open')));
    Finder keyed(String prefix) => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(prefix),
    );
    final set = await waitFor(t, [keyed('history-')]);
    await pause(t, 2);
    await tapAndWait(t, set.first);
    await pause(t, 3);
    await tapAndWait(t, keyed('revert-').first);
    await pause(t, 3);
    await t.pageBack();
    await t.pumpAndSettle();
    await pause(t, 4);
  });
}
