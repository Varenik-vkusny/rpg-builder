import 'package:flutter/material.dart';

import '../worlds/world.dart';
import 'character.dart';
import 'content_repo.dart';
import 'item.dart';
import 'location.dart';

class NewCharacterScreen extends StatefulWidget {
  const NewCharacterScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.locations,
    required this.items,
  });

  final World world;
  final ContentRepo repo;
  final List<Location> locations;
  final List<Item> items;

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
  Role _role = Role.npc;
  String? _locationId;
  final _loot = <_LootRow>[];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
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

  Future<void> _save() async {
    final title = _title.text.trim();
    final (loot, lootError) = _readLoot();
    final problem = title.isEmpty ? 'Нужно имя персонажа' : lootError;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.createCharacter(
        widget.world.id,
        NewCharacter(
          title: title,
          description: _description.text.trim(),
          role: _role,
          locationId: _locationId,
          loot: loot,
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
          child: TextField(
            key: Key('loot-chance-$i'),
            controller: row.chance,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Шанс, %'),
          ),
        ),
        IconButton(
          tooltip: 'Убрать',
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _loot.removeAt(i).chance.dispose()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый персонаж')),
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
                  onSelected: (_) => setState(() => _role = r),
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
                icon: const Icon(Icons.add),
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
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}
