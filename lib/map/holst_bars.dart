// Холст мира (5е): шапка с путём, полка у нижнего края холста и нижняя строка выбранного.
// Всё главное — внизу, цели не меньше 48 dp.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'holst_scene.dart';
import 'token_frame.dart';

/// Шапка: назад (уровень вверх или выход), мир и путь, «вблизи / издалека».
class HolstTopBar extends StatelessWidget {
  const HolstTopBar({
    super.key,
    required this.world,
    required this.path,
    required this.far,
    required this.onBack,
    required this.onZoom,
    this.trailing = const [],
  });

  final String world;

  /// «Копи › Штольня №3»; верхний уровень — «Мир».
  final String path;
  final bool far;
  final VoidCallback onBack;
  final VoidCallback? onZoom;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: s.surface,
        border: Border(bottom: BorderSide(color: s.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('holst-back'),
            tooltip: 'Назад',
            icon: const Icon(Symbols.arrow_back_rounded),
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  world,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                ),
                Text(
                  path,
                  key: const Key('holst-path'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onZoom != null)
            TextButton.icon(
              key: const Key('holst-zoom'),
              onPressed: onZoom,
              style: TextButton.styleFrom(
                foregroundColor: s.onSurfaceVariant,
                minimumSize: const Size(48, 48),
              ),
              icon: Icon(
                far ? Symbols.zoom_in_rounded : Symbols.zoom_out_rounded,
              ),
              label: Text(far ? 'издалека' : 'вблизи'),
            ),
          ...trailing,
        ],
      ),
    );
  }
}

/// Полка у нижнего края холста: квесты, предметы и персонажи без места.
class HolstShelf extends StatelessWidget {
  const HolstShelf({
    super.key,
    required this.tokens,
    required this.keys,
    required this.controller,
    required this.chip,
  });

  final List<HolstToken> tokens;

  /// Ключи жетонов — по ним слой меток находит, где стоит жетон полки.
  final Map<String, GlobalKey> keys;
  final ScrollController controller;
  final Widget Function(HolstToken) chip;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      key: const Key('holst-shelf'),
      height: height,
      decoration: BoxDecoration(
        color: s.surfaceContainerLowest.withValues(alpha: .94),
        border: Border(top: BorderSide(color: s.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: s.outlineVariant)),
            ),
            alignment: Alignment.center,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                'ПОЛКА',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: s.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: tokens.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Пусто',
                        style: TextStyle(
                          fontSize: 13,
                          color: s.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: tokens.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => KeyedSubtree(
                      key: keys.putIfAbsent(tokens[i].id, GlobalKey.new),
                      child: chip(tokens[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Связь выбранного: с кем (жетон, если он на холсте или полке; место — без жетона) и как.
typedef LinkTile = ({HolstToken? token, String title, List<String> words});

/// Нижняя строка выбранного: имя крупно и связи плитками — значок и имя объекта,
/// под ним мелко, как связаны. Вид объекта — по значку, место — видно на холсте.
class HolstInfo extends StatelessWidget {
  const HolstInfo({
    super.key,
    required this.token,
    required this.links,
    required this.onPage,
    this.onGlyph,
  });

  final HolstToken token;
  final List<LinkTile> links;
  final VoidCallback onPage;

  /// «Значок» — только у жителя, врага и предмета; null — кнопки нет.
  final VoidCallback? onGlyph;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('holst-info'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            children: [
              framedGlyph(token, s.onSurfaceVariant, s.onSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  token.title,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onGlyph != null) ...[
                OutlinedButton(
                  key: const Key('holst-glyph'),
                  onPressed: onGlyph,
                  child: const Text('Значок'),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton(
                key: const Key('holst-page'),
                onPressed: onPage,
                child: const Text('Страница'),
              ),
            ],
          ),
          if (links.isEmpty)
            Text(
              'Связей нет',
              key: const Key('holst-no-links'),
              style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
            )
          else
            SizedBox(
              height: 52,
              // Связей у объекта немного — строка целиком, листается вбок.
              child: SingleChildScrollView(
                key: const Key('holst-links'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [for (final l in links) _LinkChip(l)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip(this.link);

  final LinkTile link;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = link.token;
    return Container(
      key: Key('holst-link-${t?.slug ?? link.title}'),
      padding: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(color: s.surfaceContainerHigh),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            color: s.surfaceContainerHighest,
            alignment: Alignment.center,
            child: t == null
                ? Icon(
                    Symbols.location_on_rounded,
                    size: 20,
                    color: s.onSurface,
                  )
                : framedGlyph(t, s.onSurfaceVariant, s.onSurface),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                link.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                link.words.join(', '),
                style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
