import 'package:flutter/material.dart';

import '../help/help.dart';
import '../ui/input_rules.dart';
import '../ui/messages.dart';
import 'world.dart';
import 'worlds_repo.dart';

const _maxLevel = 20;

class NewWorldScreen extends StatefulWidget {
  const NewWorldScreen({super.key, required this.repo, this.editing});

  final WorldsRepo repo;

  /// Мир, который переименовывают; null — создаётся новый.
  final World? editing;

  @override
  State<NewWorldScreen> createState() => _NewWorldScreenState();
}

class _NewWorldScreenState extends State<NewWorldScreen> {
  late final _title = TextEditingController(text: widget.editing?.title);
  late final _setting = TextEditingController(text: widget.editing?.setting);
  late final _tone = TextEditingController(text: widget.editing?.tone);
  late RangeValues _levels = widget.editing == null
      ? const RangeValues(1, 10)
      : RangeValues(
          widget.editing!.levelMin.toDouble(),
          widget.editing!.levelMax.toDouble(),
        );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _setting.dispose();
    _tone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final problem = titleError(title, 'Нужно название мира');
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = NewWorld(
        title: title,
        setting: _setting.text.trim(),
        tone: _tone.text.trim(),
        levelMin: _levels.start.round(),
        levelMax: _levels.end.round(),
      );
      final old = widget.editing;
      if (old == null) {
        await widget.repo.create(draft);
      } else {
        await widget.repo.update(old.id, draft);
      }
      if (mounted) {
        closeDone(
          context,
          old == null ? 'Мир создан: $title' : 'Мир сохранён: $title',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Не удалось сохранить: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing == null ? 'Новый мир' : 'Мир')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('world-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Название'),
          ).help('world.title'),
          TextField(
            key: const Key('world-setting'),
            controller: _setting,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Сеттинг'),
          ).help('world.setting'),
          TextField(
            key: const Key('world-tone'),
            controller: _tone,
            decoration: const InputDecoration(labelText: 'Тон'),
          ).help('world.tone'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Уровни: ${_levels.start.round()}–${_levels.end.round()}'),
              RangeSlider(
                values: _levels,
                min: 1,
                max: _maxLevel.toDouble(),
                divisions: _maxLevel - 1,
                onChanged: (v) => setState(() => _levels = v),
              ),
            ],
          ).help('world.levels', top: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('world-save'),
            onPressed: _busy ? null : _save,
            child: Text(widget.editing == null ? 'Создать' : 'Сохранить'),
          ),
        ],
      ),
    );
  }
}
