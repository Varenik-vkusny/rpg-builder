import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../help/help.dart';
import '../worlds/world.dart';
import 'character.dart';
import 'content_repo.dart';
import 'form_kit.dart';
import 'event.dart';
import 'event_edit.dart';
import 'manual_save.dart';

/// Форма события (5б.1): сцена в месте — враги с числом и предметы.
class NewEventScreen extends StatefulWidget {
  const NewEventScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.snapshot,
    this.editing,
    this.locationId,
  });

  final World world;
  final ContentRepo repo;

  /// Мир на момент открытия формы: места, враги, предметы; нужен и для сохранения правки.
  final WorldSnapshot snapshot;

  /// Не null — форма правит существующее событие, а не создаёт новое.
  final Event? editing;

  /// Место, из которого открыли форму, — уже выбрано в новом событии.
  final String? locationId;

  @override
  State<NewEventScreen> createState() => _NewEventScreenState();
}

/// Строка врага в форме: кто и поле числа.
class _EnemyRow {
  String? characterId;
  final amount = TextEditingController(text: '1');
}

class _NewEventScreenState extends State<NewEventScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _locationId;
  final _enemies = <_EnemyRow>[];
  final _items = <String?>[];
  bool _busy = false;
  String? _error;

  bool get _editing => widget.editing != null;
  WorldSnapshot get _w => widget.snapshot;
  late final _foes = [
    for (final c in _w.characters)
      if (c.role == Role.enemy) c,
  ];

  @override
  void initState() {
    super.initState();
    _locationId = widget.locationId;
    final e = widget.editing;
    if (e == null) return;
    _locationId = e.locationId;
    _title.text = e.title;
    _description.text = e.description;
    for (final x in e.enemies) {
      _enemies.add(
        _EnemyRow()
          ..characterId = x.characterId
          ..amount.text = '${x.amount}',
      );
    }
    _items.addAll(e.itemIds);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final r in _enemies) {
      r.amount.dispose();
    }
    super.dispose();
  }

  /// Враги из формы или текст ошибки.
  (List<EventEnemy>, String?) _readEnemies() {
    final out = <EventEnemy>[];
    for (final r in _enemies) {
      final amount = int.tryParse(r.amount.text.trim());
      if (r.characterId == null) return (const [], 'Выбери врага');
      if (amount == null || amount < 1) {
        return (const [], 'Число врагов — целое от 1');
      }
      if (out.any((e) => e.characterId == r.characterId)) {
        return (const [], 'Один враг в событии дважды — поменяй число');
      }
      out.add(EventEnemy(characterId: r.characterId!, amount: amount));
    }
    return (out, null);
  }

  /// Предметы из формы или текст ошибки.
  (List<String>, String?) _readItems() {
    if (_items.contains(null)) return (const [], 'Выбери предмет');
    final ids = [for (final id in _items) id!];
    if (ids.toSet().length != ids.length) {
      return (const [], 'Один предмет в событии дважды');
    }
    return (ids, null);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final (enemies, enemiesError) = _readEnemies();
    final (itemIds, itemsError) = _readItems();
    final problem = title.isEmpty
        ? 'Нужно название события'
        : _locationId == null
        ? 'Выбери место — событие всегда идёт в месте'
        : enemiesError ?? itemsError;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final now = NewEvent(
      title: title,
      description: _description.text.trim(),
      locationId: _locationId!,
      enemies: enemies,
      itemIds: itemIds,
    );
    String? error;
    if (_editing) {
      final slugs = {
        for (final c in _w.characters) c.id: c.slug,
        for (final i in _w.items) i.id: i.slug,
      };
      error = await saveManualEdit(
        widget.repo,
        widget.world.id,
        _w,
        editEvent(widget.world.id, widget.editing!, now, slugs),
      );
    } else {
      try {
        await widget.repo.createEvent(widget.world.id, now);
      } catch (e) {
        error = 'Не удалось сохранить: $e';
      }
    }
    _done(error, _editing ? 'Сохранено: $title' : 'Создано: $title');
  }

  Future<void> _delete() async {
    final e = widget.editing!;
    if (!await confirmDelete(context, _w, e.id, e.title)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    _done(
      await deleteManually(
        widget.repo,
        widget.world.id,
        _w,
        type: 'event',
        id: e.id,
        slug: e.slug,
        title: e.title,
      ),
      'Удалено: ${e.title}',
    );
  }

  /// Нет ошибки — назад с «мир изменился» и словом, что сделано; есть — показать и остаться.
  void _done(String? error, String done) {
    if (!mounted) return;
    if (error == null) {
      closeDone(context, done);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Widget _remove(VoidCallback onPressed) => IconButton(
    tooltip: 'Убрать',
    icon: const Icon(Symbols.close_rounded),
    onPressed: onPressed,
  );

  Widget _enemyRow(int i) {
    final row = _enemies[i];
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            key: Key('event-enemy-$i'),
            initialValue: row.characterId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Враг'),
            items: [
              for (final c in _foes)
                DropdownMenuItem(value: c.id, child: Text(c.title)),
            ],
            onChanged: (v) => setState(() => row.characterId = v),
          ).help('event.enemy'),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            key: Key('event-enemy-amount-$i'),
            controller: row.amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Число'),
          ).help('event.amount'),
        ),
        _remove(() => setState(() => _enemies.removeAt(i).amount.dispose())),
      ],
    );
  }

  Widget _itemRow(int i) => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          key: Key('event-item-$i'),
          initialValue: _items[i],
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Предмет'),
          items: [
            for (final it in _w.items)
              DropdownMenuItem(value: it.id, child: Text(it.title)),
          ],
          onChanged: (v) => setState(() => _items[i] = v),
        ).help('event.item'),
      ),
      _remove(() => setState(() => _items.removeAt(i))),
    ],
  );

  /// Заголовок списка, его строки и кнопка «добавить»; [empty] — если выбирать не из чего.
  List<Widget> _list(
    String title,
    String? empty,
    List<Widget> rows,
    String addKey,
    String addLabel,
    VoidCallback onAdd,
  ) => [
    const SizedBox(height: 16),
    Text(title),
    if (empty != null) Text(empty),
    ...rows,
    if (empty == null)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: Key(addKey),
          onPressed: onAdd,
          icon: const Icon(Symbols.add_rounded),
          label: Text(addLabel),
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Изменить событие' : 'Новое событие'),
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
            key: const Key('event-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Название'),
          ).help('event.title'),
          TextField(
            key: const Key('event-description'),
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Описание'),
          ).help('event.description'),
          DropdownButtonFormField<String>(
            key: const Key('event-location'),
            initialValue: _locationId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Место'),
            items: [
              for (final l in _w.locations)
                DropdownMenuItem(value: l.id, child: Text(l.title)),
            ],
            onChanged: (v) => setState(() => _locationId = v),
          ).help('event.location'),
          if (_w.locations.isEmpty)
            const Text('В мире пока нет мест — сначала создай место'),
          ..._list(
            'Враги',
            _foes.isEmpty ? 'В мире пока нет врагов' : null,
            [for (var i = 0; i < _enemies.length; i++) _enemyRow(i)],
            'event-enemy-add',
            'Добавить врага',
            () => setState(() => _enemies.add(_EnemyRow())),
          ),
          ..._list(
            'Предметы',
            _w.items.isEmpty ? 'В мире пока нет предметов' : null,
            [for (var i = 0; i < _items.length; i++) _itemRow(i)],
            'event-item-add',
            'Добавить предмет',
            () => setState(() => _items.add(null)),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('event-save'),
            onPressed: _busy ? null : _save,
            child: Text(_editing ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }
}
