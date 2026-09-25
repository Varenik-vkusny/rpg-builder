// ПОКАЗ, а не проверка: история и откат (3.7) на подменённой базе. В check.sh не входит.
// Запуск: flutter test --no-pub demo/history_snapshots_test.dart → build/snapshots/3.7-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/autofix_test.dart' show floodWithAttack;
import '../test/fakes.dart';
import 'shots.dart';

const flood = 'Штольня №3 затоплена: слизни ушли, появились утопленники';

void main() {
  testWidgets('история: затопление → откат; конфликт', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final content = await minesContent();
    final assistant = FakeAssistant([
      proposal(floodWithAttack(8)),
      proposal(floodWithAttack(8)),
    ]);
    await pumpApp(t, content: content, assistant: assistant, wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    Future<void> applyFlood() async {
      await tapShown(t, find.byKey(const Key('assistant-open')));
      await pick(t, 'scope-object-location', 'Штольня №3');
      await t.enterText(
        find.byKey(const Key('assistant-request')),
        'Затопи её, слизни там жить не могут',
      );
      await tapShown(t, find.byKey(const Key('assistant-propose')));
      await tapShown(t, find.byKey(const Key('plan-apply')));
    }

    // Применили затопление → история с «было → стало».
    await applyFlood();
    await shot(t, '3.7-world-flooded');
    await tapShown(t, find.byKey(const Key('history-open')));
    await tapShown(t, find.text(flood));
    await shot(t, '3.7-history');

    // Откатили → набор «Откачен», рядом обратный набор; мир как был.
    await tapShown(t, find.byKey(const Key('revert-set-0')));
    await shot(t, '3.7-reverted');
    await t.pageBack();
    await t.pumpAndSettle();
    await shot(t, '3.7-world-restored');

    // Снова затопили, потом мир поправили — откат показывает конфликт.
    await applyFlood();
    content.version++;
    await tapShown(t, find.byKey(const Key('history-open')));
    await tapShown(t, find.text(flood).first);
    await tapShown(t, find.byKey(const Key('revert-set-2')));
    await shot(t, '3.7-conflict');
  });
}
