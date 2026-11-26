// Число в заголовке раздела страницы — плашкой рядом с названием, а не «Кто здесь · 3».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Число в плашке у заголовка раздела [title]; нет плашки — null.
int? sectionCount(WidgetTester t, String title) {
  final head = find.ancestor(of: find.text(title), matching: find.byType(Row));
  final badge = find.descendant(
    of: head.first,
    matching: find.byKey(const Key('section-count')),
  );
  if (badge.evaluate().isEmpty) return null;
  final text = t.widget<Text>(
    find.descendant(of: badge, matching: find.byType(Text)),
  );
  return int.parse(text.data!);
}
