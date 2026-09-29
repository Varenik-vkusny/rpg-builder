import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../worlds/world.dart';
import 'content_repo.dart';
import 'item.dart';
import 'manual_edit.dart';
import 'manual_save.dart';

class NewItemScreen extends StatefulWidget {
  const NewItemScreen({
    super.key,
    required this.world,
    required this.repo,
    this.editing,
    this.snapshot,
  });

  final World world;
  final ContentRepo repo;

  /// Не null — форма правит существующий предмет, а не создаёт новый.
  final Item? editing;

  /// Мир на момент открытия формы — нужен для сохранения правки.
  final WorldSnapshot? snapshot;

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

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) {
      _level.text = '${widget.world.levelMin}';
      return;
    }
    _kind = e.kind;
    _rarity = e.rarity;
    _title.text = e.title;
    _level.text = '${e.level}';
    _price.text = '${e.price}';
    final stat = e.kind == ItemKind.weapon
        ? e.damage
        : e.kind == ItemKind.armor
        ? e.defense
        : null;
    if (stat != null) _stat.text = '$stat';
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
    final now = NewItem(
      title: title,
      kind: _kind,
      rarity: _rarity,
      level: level!,
      damage: _kind == ItemKind.weapon ? stat : null,
      defense: _kind == ItemKind.armor ? stat : null,
      price: price!,
    );
    if (_editing) {
      final error = await saveManualEdit(
        widget.repo,
        widget.world.id,
        widget.snapshot!,
        editItem(widget.world.id, widget.editing!, now),
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
      await widget.repo.createItem(widget.world.id, now);
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
      type: 'item',
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
      appBar: AppBar(
        title: Text(_editing ? 'Изменить предмет' : 'Новый предмет'),
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
                  onSelected: _editing
                      ? null
                      : (_) => setState(() => _kind = k),
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
            child: Text(_editing ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }
}
