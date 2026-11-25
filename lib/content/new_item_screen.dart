import 'package:flutter/material.dart';

import '../help/help.dart';
import '../check/world_check.dart';
import '../worlds/world.dart';
import 'content_repo.dart';
import 'form_kit.dart';
import 'item.dart';
import 'manual_edit.dart';
import 'manual_create.dart';
import 'manual_save.dart';
import 'world_pages.dart' show itemKindIcon;
import '../ui/discard_guard.dart';

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

class _NewItemScreenState extends State<NewItemScreen>
    with DiscardGuard<NewItemScreen> {
  @override
  Map<String, Object?> get formFields => {
    'Название': _title,
    'Уровень': _level,
    _statLabel: _stat,
    'Цена': _price,
    'Тип': _kind,
    'Редкость': _rarity,
  };

  @override
  IconData get formIcon => itemKindIcon(_kind);

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
    final problem =
        titleError(title, 'Нужно название предмета') ??
        (level == null
            ? 'Уровень — целое число от 1'
            : price == null
            ? 'Цена — целое число от 0'
            : _hasStat && stat == null
            ? '$_statLabel — целое число от 0'
            : null);
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
        closeDone(context, 'Сохранено: $title');
      } else {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
      return;
    }
    final error = await createManually(
      widget.repo,
      widget.world.id,
      (w) => createItemEdit(widget.world.id, w, now),
    );
    if (!mounted) return;
    if (error == null) {
      closeDone(context, 'Создано: $title');
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _delete() async {
    final e = widget.editing!;
    if (!await confirmDelete(context, widget.snapshot!, e.id, e.title)) return;
    if (!mounted) return;
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
      closeDone(context, 'Удалено: ${e.title}');
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
  Widget build(BuildContext context) => guardPop(_form(context));

  Widget _form(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Изменить предмет' : 'Новый предмет'),
        actions: [
          if (_editing) DeleteAction(onPressed: _busy ? null : _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('item-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Название'),
          ).help('item.title'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ).help('item.kind', top: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ).help('item.rarity', top: 16),
          _number(
            const Key('item-level'),
            _level,
            'Уровень',
          ).help('item.level'),
          if (_hasStat)
            _number(
              const Key('item-stat'),
              _stat,
              _statLabel,
            ).help(_kind == ItemKind.weapon ? 'item.damage' : 'item.defense'),
          _number(
            const Key('item-price'),
            _price,
            'Цена, золото',
          ).help('item.price'),
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
