part of 'holst_screen.dart';

/// «Значок» у выбранного жителя, врага или предмета: выбор из набора — жестом через историю.
extension _GlyphPick on _HolstState {
  Future<void> _pickGlyph() async {
    final t = _scene.all[_sel];
    if (t == null) return;
    final choice = await pickGlyph(context, title: t.title, current: t.glyph);
    if (choice == null || !mounted) return;
    final edit = editIcon(widget.world.id, _w, t.id, choice.icon);
    if (edit == null) return;
    final name = choice.icon == null ? 'без значка' : glyphName(choice.icon!);
    await _gesture(
      edit,
      done: 'Значок «${t.title}»: $name',
      marks: {t.id: Mark.changed},
    );
  }
}
