import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/slug.dart';

void main() {
  test('название превращается в латинский slug', () {
    expect(slugify('Штольня №3'), 'shtolnya_3');
    expect(slugify('Ключ от лебёдки'), 'klyuch_ot_lebedki');
    expect(slugify('Пепельный слизень'), 'pepelnyy_slizen');
    expect(slugify('  Old Mine!! '), 'old_mine');
    expect(slugify('№!?'), 'object');
  });

  test('занятый slug получает номер', () {
    expect(uniqueSlug('Штольня', []), 'shtolnya');
    expect(uniqueSlug('Штольня', ['shtolnya']), 'shtolnya_2');
    expect(uniqueSlug('Штольня', ['shtolnya', 'shtolnya_2']), 'shtolnya_3');
  });
}
