import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../worlds/world.dart';
import 'character.dart';
import 'content_repo.dart';
import 'item.dart';
import 'location.dart';
import 'manual_edit.dart';
import 'manual_save.dart';

class NewCharacterScreen extends StatefulWidget {
  const NewCharacterScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.locations,
    required this.items,
    this.editing,
    this.snapshot,
  });

  final World world;
  final ContentRepo repo;
  final List<Location> locations;
  final List<Item> items;

  /// Не null — форма правит существующего персонажа, а не создаёт нового.
  final Character? editing;

  /// Мир на момент открытия формы — нужен для сохранения правки.
  final WorldSnapshot? snapshot;

  @override
  State<NewCharacterScreen> createState() => _NewCharacterScreenState();
}

/// Строка добычи в форме: предмет и поле шанса.
class _LootRow {
  String? itemId;
  final chance = TextEditingController();
}

class _NewCharacterScreenState extends State<NewCharacterScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _level = TextEditingController(text: '1');
  final _hp = TextEditingController(text: '10');
  final _attack = TextEditingController(text: '0');
  Role _role = Role.npc;
  String? _locationId;
  final _loot = <_LootRow>[];
  bool _busy = false;
  String? _error;

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) return;
    _role = e.role;
    _locationId = e.locationId;
    _title.text = e.title;
    _description.text = e.description;
    _level.text = '${e.level}';
    _hp.text = '${e.hp}';
    _attack.text = '${e.attack}';
    for (final l in e.loot) {
      final row = _LootRow()..itemId = l.itemId;
      row.chance.text = l.chance == l.chance.roundToDouble()
          ? '${l.chance.round()}'
          : '${l.chance}';
      _loot.add(row);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _level.dispose();
    _hp.dispose();
    _attack.dispose();
    for (final r in _loot) {
      r.chance.dispose();
    }
    super.dispose();
  }

  /// Добыча из формы или текст ошибки.
  (List<LootDrop>, String?) _readLoot() {
    if (_role != Role.enemy) return (const [], null);
    final drops = <LootDrop>[];
    for (final r in _loot) {
      final chance = double.tryParse(r.chance.text.trim().replaceAll(',', '.'));
      if (r.itemId == null) return (const [], 'Выбери предмет добычи');
      if (chance == null || !LootDrop.validChance(chance)) {
        return (const [], 'Шанс добычи — больше 0 и не больше 100');
      }
      if (drops.any((d) => d.itemId == r.itemId)) {
        return (const [], 'Один предмет в добыче дважды');
      }
      drops.add(LootDrop(itemId: r.itemId!, chance: chance));
    }
    return (drops, null);
  }

  /// Уровень, здоровье, атака из формы или текст ошибки.
  ((int, int, int)?, String?) _readStats() {
    int? n(TextEditingController c) => int.tryParse(c.text.trim());
    final (level, hp, attack) = (n(_level), n(_hp), n(_attack));
    if (level == null || level < 1) return (null, 'Уровень — целое от 1');
    if (hp == null || hp < 1) return (null, 'Здоровье — целое от 1');
    if (attack == null || attack < 0) return (null, 'Атака — целое от 0');
    return ((level, hp, attack), null);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final (loot, lootError) = _readLoot();
    final (stats, statsError) = _readStats();
    final problem = title.isEmpty
        ? 'Нужно имя персонажа'
        : statsError ?? lootError;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final now = NewCharacter(
      title: title,
      description: _description.text.trim(),
      role: _role,
      locationId: _locationId,
      loot: loot,
      level: stats!.$1,
      hp: stats.$2,
      attack: stats.$3,
    );
    if (_editing) {
      final itemSlugs = {for (final i in widget.snapshot!.items) i.id: i.slug};
      final error = await saveManualEdit(
        widget.repo,
        widget.world.id,
        widget.snapshot!,
        editCharacter(widget.world.id, widget.editing!, now, itemSlugs),
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
      await widget.repo.createCharacter(widget.world.id, now);
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
      type: 'character',
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

  Widget _lootRow(int i) {
    final row = _loot[i];
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            key: Key('loot-item-$i'),
            initialValue: row.itemId,
            decoration: const InputDecoration(labelText: 'Предмет'),
            items: [
              for (final it in widget.items)
                DropdownMenuItem(value: it.id, child: Text(it.title)),
            ],
            onChanged: (v) => setState(() => row.itemId = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            key: Key('loot-chance-$i'),
            controller: row.chance,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Шанс, %'),
          ),
        ),
        IconButton(
          tooltip: 'Убрать',
          icon: const Icon(Symbols.close_rounded),
          onPressed: () => setState(() => _loot.removeAt(i).chance.dispose()),
        ),
      ],
    );
  }

  Widget _statField(String key, TextEditingController c, String label) =>
      Expanded(
        child: TextField(
          key: Key(key),
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Изменить персонажа' : 'Новый персонаж'),
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
            key: const Key('character-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          TextField(
            key: const Key('character-description'),
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Описание'),
          ),
          const SizedBox(height: 16),
          const Text('Роль'),
          Wrap(
            spacing: 8,
            children: [
              for (final r in Role.values)
                ChoiceChip(
                  key: Key('character-role-${r.name}'),
                  label: Text(r.label),
                  selected: _role == r,
                  onSelected: _editing
                      ? null
                      : (_) => setState(() => _role = r),
                ),
            ],
          ),
          DropdownButtonFormField<String?>(
            key: const Key('character-location'),
            initialValue: _locationId,
            decoration: const InputDecoration(labelText: 'Локация'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Без локации')),
              for (final l in widget.locations)
                DropdownMenuItem(value: l.id, child: Text(l.title)),
            ],
            onChanged: (v) => setState(() => _locationId = v),
          ),
          Row(
            spacing: 8,
            children: [
              _statField('character-level', _level, 'Уровень'),
              _statField('character-hp', _hp, 'Здоровье'),
              _statField('character-attack', _attack, 'Атака'),
            ],
          ),
          if (_role == Role.enemy) ...[
            const SizedBox(height: 16),
            const Text('Добыча'),
            if (widget.items.isEmpty)
              const Text('В мире пока нет предметов для добычи'),
            for (var i = 0; i < _loot.length; i++) _lootRow(i),
            if (widget.items.isNotEmpty)
              TextButton.icon(
                key: const Key('loot-add'),
                onPressed: () => setState(() => _loot.add(_LootRow())),
                icon: const Icon(Symbols.add_rounded),
                label: const Text('Добавить добычу'),
              ),
          ],
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('character-save'),
            onPressed: _busy ? null : _save,
            child: Text(_editing ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }
}
