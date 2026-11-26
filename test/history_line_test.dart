// Прибор вида А для истории (владелец 25.11): заголовок набора разбирается на «что +
// с чем» — глагол, имя, поле «было → стало», источник значком; день — заголовком.
// Раньше была каша: «Откат: Правка вручную: Лампа», «Применён · 23.11 19:55».
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/history.dart';
import 'package:rpg_builder/assistant/history_line.dart';
import 'package:rpg_builder/assistant/history_tile.dart';
import 'package:rpg_builder/check/world_check.dart';

ChangeSetEntry entry(
  String request, {
  String summary = '',
  List<JournalOp> ops = const [],
  String? reverts,
  SetStatus status = SetStatus.applied,
  String id = 's1',
}) => ChangeSetEntry(
  id: id,
  status: status,
  request: request,
  summary: summary,
  createdAt: DateTime(2026, 11, 25, 19, 52),
  revertsId: reverts,
  ops: ops,
);

JournalOp op(
  String action,
  String type,
  String title, {
  Map<String, dynamic> before = const {},
  Map<String, dynamic> after = const {},
}) => JournalOp(
  action: action,
  type: type,
  label: title.toLowerCase(),
  before: {'title': title, ...before},
  after: action == 'delete' ? null : {'title': title, ...after},
);

const world = WorldSnapshot();
final show = valueShower(world);

HistoryLine line(ChangeSetEntry s, {ChangeSetEntry? original}) =>
    describe(s, world: world, show: show, original: original);

void main() {
  final lamp = entry(
    'Правка вручную: Лампа',
    ops: [
      op(
        'update',
        'item',
        'Лампа',
        before: {'kind': 'misc'},
        after: {'kind': 'consumable'},
      ),
    ],
  );

  test(
    'правка вручную: «Лампа», «Изменено», вид прочее → расходник, вручную',
    () {
      final l = line(lamp);
      expect(
        (l.verb, l.name, l.source, l.field, l.was, l.now),
        (Verb.changed, 'Лампа', Source.hand, 'вид', 'Прочее', 'Расходник'),
      );
      expect(l.offWord, isNull, reason: '«Применён» не пишем — это норма');
    },
  );

  test('откат: имя исходного набора и «Откат: правка», без каши', () {
    final undo = entry(
      'Правка вручную: Лампа',
      id: 's2',
      reverts: 's1',
      ops: [
        op(
          'update',
          'item',
          'Лампа',
          before: {'kind': 'consumable'},
          after: {'kind': 'misc'},
        ),
      ],
    );
    final l = line(undo, original: lamp);
    expect((l.verb, l.name, l.what), (Verb.reverted, 'Лампа', 'правка'));
    final off = line(
      entry('Правка вручную: Лампа', ops: lamp.ops, status: SetStatus.reverted),
    );
    expect((off.off, off.offWord), (true, 'ОТКАЧЕН'));
  });

  test('холст, справочник, удаление: глагол, имя и источник', () {
    final made = line(
      entry(
        'Холст: создано «Враг 1»',
        ops: [op('create', 'character', 'Враг 1')],
      ),
    );
    expect(
      (made.verb, made.name, made.source),
      (Verb.created, 'Враг 1', Source.canvas),
    );
    final moved = line(
      entry(
        'Холст: перенесено «Слизень» → «Рынок»',
        ops: [op('update', 'character', 'Слизень')],
      ),
    );
    expect((moved.verb, moved.name), (Verb.changed, 'Слизень'));
    final imported = line(
      entry(
        'Импорт',
        summary: 'Импорт из Open5e: Боевая кирка',
        ops: [op('create', 'item', 'Боевая кирка')],
      ),
    );
    expect(
      (imported.verb, imported.name, imported.source),
      (Verb.created, 'Боевая кирка', Source.import),
    );
    final gone = line(
      entry('Удаление вручную: Обвал', ops: [op('delete', 'quest', 'Обвал')]),
    );
    expect((gone.verb, gone.name), (Verb.deleted, 'Обвал'));
  });

  test('ассистент: сводка коротко и счётчики +1 ✎2 −1', () {
    final l = line(
      entry(
        'затопи штольню',
        summary: 'Третья штольня затоплена',
        ops: [
          op('update', 'location', 'Штольня №3'),
          op('create', 'character', 'Утопленник'),
          op('delete', 'loot', 'добыча'),
          op('update', 'quest_step', 'шаг'),
        ],
      ),
    );
    expect((l.name, l.source), ('Третья штольня затоплена', Source.assistant));
    // Слово «вручную» в просьбе ассистенту — не форма.
    expect(sourceOf(entry('сделай вручную три шахты')), Source.assistant);
    expect(l.tally, {Verb.created: 1, Verb.changed: 2, Verb.deleted: 1});
  });

  test('день заголовком: «Сегодня», «Вчера», «22 ноября»', () {
    final now = DateTime(2026, 11, 25, 9);
    expect(dayTitle(DateTime(2026, 11, 25, 1), now), 'Сегодня');
    expect(dayTitle(DateTime(2026, 11, 24, 23), now), 'Вчера');
    expect(dayTitle(DateTime(2026, 11, 22, 12), now), '22 ноября');
    expect(dayTitle(DateTime(2025, 3, 1), now), '1 марта 2025');
    expect(clock(DateTime(2026, 11, 25, 9, 5)), '09:05');
  });
}
