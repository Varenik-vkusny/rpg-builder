import 'package:flutter/material.dart';

import '../worlds/world.dart';
import 'content_repo.dart';
import 'location.dart';

class NewLocationScreen extends StatefulWidget {
  const NewLocationScreen({super.key, required this.world, required this.repo});

  final World world;
  final ContentRepo repo;

  @override
  State<NewLocationScreen> createState() => _NewLocationScreenState();
}

class _NewLocationScreenState extends State<NewLocationScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late RangeValues _levels = RangeValues(
    widget.world.levelMin.toDouble(),
    widget.world.levelMax.toDouble(),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Нужно название локации');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.createLocation(
        widget.world.id,
        NewLocation(
          title: title,
          description: _description.text.trim(),
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
    final w = widget.world;
    return Scaffold(
      appBar: AppBar(title: const Text('Новая локация')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('location-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          TextField(
            key: const Key('location-description'),
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Описание'),
          ),
          const SizedBox(height: 16),
          Text('Уровни: ${_levels.start.round()}–${_levels.end.round()}'),
          if (w.levelMin < w.levelMax)
            RangeSlider(
              key: const Key('location-levels'),
              values: _levels,
              min: w.levelMin.toDouble(),
              max: w.levelMax.toDouble(),
              divisions: w.levelMax - w.levelMin,
              onChanged: (v) => setState(() => _levels = v),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('location-save'),
            onPressed: _busy ? null : _save,
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}
