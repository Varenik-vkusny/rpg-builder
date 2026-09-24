import 'package:flutter/material.dart';

import '../worlds/world.dart';
import 'content_repo.dart';
import 'item.dart';

class NewItemScreen extends StatefulWidget {
  const NewItemScreen({super.key, required this.world, required this.repo});

  final World world;
  final ContentRepo repo;

  @override
  State<NewItemScreen> createState() => _NewItemScreenState();
}

class _NewItemScreenState extends State<NewItemScreen> {
  final _title = TextEditingController();
  final _level = TextEditingController();
  final _stat = TextEditingController();
  final _price = TextEditingController(text: '0');
  ItemKind _kind = ItemKind.weapon;
  Rarity _rarity = Rarity.common;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _level.text = '${widget.world.levelMin}';
  }

  @override
  void dispose() {
    for (final c in [_title, _level, _stat, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasStat => _kind == ItemKind.weapon || _kind == ItemKind.armor;
  String get _statLabel => _kind == ItemKind.weapon ? 'Урон' : 'Защита';

  /// Число ≥ [min] из поля или null.
  int? _int(TextEditingController c, int min) {
    final v = int.tryParse(c.text.trim());
    return v != null && v >= min ? v : null;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final level = _int(_level, 1);
    final price = _int(_price, 0);
    final stat = _hasStat ? _int(_stat, 0) : null;
    final problem = title.isEmpty
        ? 'Нужно название предмета'
        : level == null
        ? 'Уровень — целое число от 1'
        : price == null
        ? 'Цена — целое число от 0'
        : _hasStat && stat == null
        ? '$_statLabel — целое число от 0'
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.createItem(
        widget.world.id,
        NewItem(
          title: title,
          kind: _kind,
          rarity: _rarity,
          level: level!,
          damage: _kind == ItemKind.weapon ? stat : null,
          defense: _kind == ItemKind.armor ? stat : null,
          price: price!,
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

  TextField _number(Key key, TextEditingController c, String label) =>
      TextField(
        key: key,
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый предмет')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('item-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 16),
          const Text('Тип'),
          Wrap(
            spacing: 8,
            children: [
              for (final k in ItemKind.values)
                ChoiceChip(
                  key: Key('item-kind-${k.name}'),
                  label: Text(k.label),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Редкость'),
          Wrap(
            spacing: 8,
            children: [
              for (final r in Rarity.values)
                ChoiceChip(
                  key: Key('item-rarity-${r.name}'),
                  label: Text(r.label),
                  selected: _rarity == r,
                  onSelected: (_) => setState(() => _rarity = r),
                ),
            ],
          ),
          _number(const Key('item-level'), _level, 'Уровень'),
          if (_hasStat) _number(const Key('item-stat'), _stat, _statLabel),
          _number(const Key('item-price'), _price, 'Цена, золото'),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('item-save'),
            onPressed: _busy ? null : _save,
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}
