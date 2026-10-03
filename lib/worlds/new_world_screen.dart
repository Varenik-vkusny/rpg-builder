import 'package:flutter/material.dart';

import '../help/help.dart';
import 'world.dart';
import 'worlds_repo.dart';

const _maxLevel = 20;

class NewWorldScreen extends StatefulWidget {
  const NewWorldScreen({super.key, required this.repo});

  final WorldsRepo repo;

  @override
  State<NewWorldScreen> createState() => _NewWorldScreenState();
}

class _NewWorldScreenState extends State<NewWorldScreen> {
  final _title = TextEditingController();
  final _setting = TextEditingController();
  final _tone = TextEditingController();
  RangeValues _levels = const RangeValues(1, 10);
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
    if (title.isEmpty) {
      setState(() => _error = 'Нужно название мира');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.create(
        NewWorld(
          title: title,
          setting: _setting.text.trim(),
          tone: _tone.text.trim(),
          levelMin: _levels.start.round(),
          levelMax: _levels.end.round(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('Новый мир')),
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
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Уровни: ${_levels.start.round()}–${_levels.end.round()}'),
              RangeSlider(
                values: _levels,
                min: 1,
                max: _maxLevel.toDouble(),
                divisions: _maxLevel - 1,
                onChanged: (v) => setState(() => _levels = v),
              ),
            ],
          ).help('world.levels'),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('world-save'),
            onPressed: _busy ? null : _save,
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}
