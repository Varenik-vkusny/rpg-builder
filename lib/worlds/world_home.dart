// Мир открывается холстом (решение владельца 17.10): холст — главный экран, списки
// объектов — кнопкой «Списки» на холсте (формы и страницы — запасной путь, VISION §6).
import 'package:flutter/material.dart';

import '../assistant/assistant_service.dart';
import '../content/content_repo.dart';
import '../content/world_screen.dart';
import '../help/help.dart';
import '../map/holst_screen.dart';
import '../open5e/open5e_api.dart';
import 'world.dart';

class WorldHome extends StatefulWidget {
  const WorldHome({
    super.key,
    required this.world,
    required this.repo,
    required this.assistant,
    this.open5e = const HttpOpen5e(),
  });

  final World world;
  final ContentRepo repo;
  final AssistantService assistant;
  final Open5eApi open5e;

  @override
  State<WorldHome> createState() => _WorldHomeState();
}

class _WorldHomeState extends State<WorldHome> {
  late final _load = widget.repo.snapshot(widget.world.id);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _load,
    builder: (context, snap) {
      if (snap.hasError) {
        return Scaffold(
          appBar: AppBar(actions: const [HelpAction('world')]),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Мир не загрузился. Проверь связь и открой снова'),
            ),
          ),
        );
      }
      // Пока мир грузится — заставка на месте холста, а не отдельный экран.
      final w = snap.data;
      if (w == null) {
        return const Material(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return HolstScreen(
        world: widget.world,
        repo: widget.repo,
        snapshot: w,
        assistant: widget.assistant,
        lists: () => WorldScreen(
          world: widget.world,
          repo: widget.repo,
          assistant: widget.assistant,
          open5e: widget.open5e,
        ),
      );
    },
  );
}
