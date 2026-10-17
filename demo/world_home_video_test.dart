// ПОКАЗ ВИДЕО: мир открывается холстом; «Списки» — прежний экран мира; назад — холст.
// Запуск: flutter test --no-pub demo/world_home_video_test.dart && bash demo/video.sh world-home
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/app.dart';
import 'package:rpg_builder/open5e/open5e_api.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';
import 'video.dart';

void main() {
  testWidgets('видео: мир открывается холстом', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(380, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = FakeContent();
    final auth = FakeAuth();
    final v = Video(t, 'world-home');
    await t.pumpWidget(
      v.wrap(
        RpgBuilderApp(
          auth: auth,
          worlds: FakeWorlds(auth),
          content: c,
          assistant: FakeAssistant(),
          open5e: const HttpOpen5e(),
        ),
      ),
    );
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await fillMines(c, minesId);
    const s = Duration(milliseconds: 1000);
    await v.wait(s * .6);
    await v.tap(find.text('Пепельные копи'));
    v.hide();
    await v.wait(s * 1.5);
    await v.tap(find.byKey(const Key('holst-lists')));
    v.hide();
    await v.wait(s * 1.5);
    await v.tap(find.byType(BackButton).first);
    v.hide();
    await v.wait(s * 1.5);
  });
}
