// Время набора в истории — по часам телефона, а не по Гринвичу, как его отдаёт база.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/history.dart';

ChangeSetEntry _entry(String createdAt) => ChangeSetEntry.fromRow({
  'id': 'set-1',
  'status': 'applied',
  'request': 'Удаление вручную: Причал',
  'summary': '',
  'created_at': createdAt,
});

void main() {
  test('время из базы переводится в местное, момент тот же', () {
    final at = _entry('2026-10-09T06:37:12.345678+00:00').createdAt;
    expect(at.isUtc, isFalse);
    expect(
      at.isAtSameMomentAs(DateTime.utc(2026, 10, 9, 6, 37, 12, 345, 678)),
      isTrue,
    );
    expect(at.hour, DateTime.utc(2026, 10, 9, 6, 37).toLocal().hour);
  });

  test('время с другим смещением — тот же момент, тоже местное', () {
    final at = _entry('2026-10-09T11:37:00+05:00').createdAt;
    expect(at.isUtc, isFalse);
    expect(at.isAtSameMomentAs(DateTime.utc(2026, 10, 9, 6, 37)), isTrue);
  });
}
