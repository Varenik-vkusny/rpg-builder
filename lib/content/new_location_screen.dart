import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../worlds/world.dart';
import 'content_repo.dart';
import 'location.dart';
import 'manual_edit.dart';
import 'manual_save.dart';
import 'nesting.dart';

class NewLocationScreen extends StatefulWidget {
  const NewLocationScreen({
    super.key,
    required this.world,
    required this.repo,
    this.editing,
    this.snapshot,
    this.locations = const [],
  });

  final World world;
  final ContentRepo repo;

  /// Не null — форма правит существующую локацию, а не создаёт новую.
  final Location? editing;

  /// Мир на момент открытия формы — нужен для сохранения правки.
  final WorldSnapshot? snapshot;

  /// Места мира — из них выбирается, внутри какого лежит это (5а.1).
  final List<Location> locations;

  @override
  State<NewLocationScreen> createState() => _NewLocationScreenState();
}

class _NewLocationScreenState extends State<NewLocationScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  late RangeValues _levels;
  String? _parentId;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _levels = RangeValues(
      (e?.levelMin ?? widget.world.levelMin).toDouble(),
      (e?.levelMax ?? widget.world.levelMax).toDouble(),
    );
    if (e != null) {
      _parentId = e.parentId;
      _title.text = e.title;
      _description.text = e.description;
    }
  }

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
    final now = NewLocation(
      title: title,
      description: _description.text.trim(),
      levelMin: _levels.start.round(),
      levelMax: _levels.end.round(),
      parentId: _parentId,
    );
    if (_editing) {
      final error = await saveManualEdit(
        widget.repo,
        widget.world.id,
        widget.snapshot!,
        editLocation(widget.world.id, widget.editing!, now),
      );
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
      return;
    }
    try {
      await widget.repo.createLocation(widget.world.id, now);
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

  Future<void> _delete() async {
    final e = widget.editing!;
    setState(() => _busy = true);
    final error = await deleteManually(
      widget.repo,
      widget.world.id,
      widget.snapshot!,
      type: 'location',
      id: e.id,
      slug: e.slug,
      title: e.title,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.world;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Изменить локацию' : 'Новая локация'),
        actions: [
          if (_editing)
            IconButton(
              key: const Key('object-delete'),
              tooltip: 'Удалить',
              icon: const Icon(Symbols.delete_rounded),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
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
          _ParentPicker(
            locations: widget.locations,
            self: widget.editing,
            value: _parentId,
            onChanged: (v) => setState(() => _parentId = v),
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
            child: Text(_editing ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }
}

/// «Внутри места»: только места, куда можно положить, не уйдя глубже трёх уровней.
/// Класть некуда — поля нет.
class _ParentPicker extends StatelessWidget {
  const _ParentPicker({
    required this.locations,
    required this.self,
    required this.value,
    required this.onChanged,
  });

  final List<Location> locations;
  final Location? self;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final parents = allowedParents(locations, self);
    if (parents.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String?>(
      key: const Key('location-parent'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Внутри места'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Верхний уровень')),
        for (final l in parents)
          DropdownMenuItem(
            value: l.id,
            child: Text(pathOf(locations, l), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
