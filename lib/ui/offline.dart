// «Нет связи» (FEATURES 5ж, задание vision 26.11): обрыв сети не прячется за пустым
// экраном или текстом исключения — автор видит «Нет связи» и «Повторить». Введённое и
// план не теряются: экран остаётся, повтор делает то же действие ещё раз.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase/supabase.dart'
    show
        AuthApiException,
        FunctionException,
        PostgrestException,
        StorageException;

import 'action_sheet_buttons.dart';

/// Сколько ждать сеть, прежде чем сказать «Нет связи» (загрузка списка и мира).
const loadTimeout = Duration(seconds: 20);

/// Ошибка — обрыв сети или таймаут, а не отказ сервера по делу. Ответ сервера с
/// ошибкой (база, функция, вход) — не «нет связи», даже если в тексте есть похожие
/// слова: повторять его бесполезно (ревью 26.11).
bool isOffline(Object? e) {
  if (e is PostgrestException ||
      e is FunctionException ||
      e is AuthApiException ||
      e is StorageException) {
    return false;
  }
  if (e is TimeoutException) return true;
  return neverSent(e) || _brokenMidway.any('$e'.contains);
}

/// Запрос точно не ушёл на сервер: нет сети, сервер не найден, соединение не
/// открылось. Только тогда «Повторить» запись безопасно — двойной записи не будет.
bool neverSent(Object? e) {
  if (e is PostgrestException || e is FunctionException) return false;
  final s = '$e';
  return const [
    'Failed host lookup',
    'Network is unreachable',
    'Connection refused',
    'No address associated',
    'OS Error: Software caused connection abort',
  ].any(s.contains);
}

/// Связь оборвалась, когда запрос, возможно, уже дошёл: записалось ли — неизвестно.
const _brokenMidway = [
  'SocketException',
  'Connection reset',
  'Connection closed',
  'ClientException',
  'TimeoutException',
  'AuthRetryableFetchException',
];

/// Заголовок и причина одной строкой — для полос и окон.
(String, String) failureWords(
  Object? e, {
  String what = 'Не удалось загрузить',
}) => isOffline(e)
    ? ('Нет связи', 'Проверь интернет и повтори')
    : (what, _short('$e'));

String _short(String s) {
  final line = s.split('\n').first.trim();
  return line.length > 80 ? '${line.substring(0, 79)}…' : line;
}

/// Блок вида А на месте экрана, который не загрузился: ячейка-значок, «Нет связи»,
/// причина одной строкой, «Повторить» во всю ширину.
class LoadFailed extends StatelessWidget {
  const LoadFailed(
    this.error, {
    super.key,
    required this.onRetry,
    this.what = 'Не удалось загрузить',
  });

  final Object? error;
  final VoidCallback onRetry;
  final String what;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final offline = isOffline(error);
    final (title, sub) = failureWords(error, what: what);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          key: const Key('load-failed'),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: s.surfaceContainerLow,
            border: Border.all(color: s.error),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                spacing: 12,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    color: s.error,
                    alignment: Alignment.center,
                    child: Icon(
                      offline
                          ? Symbols.cloud_off_rounded
                          : Symbols.error_rounded,
                      color: s.onError,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: s.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              sheetMain(
                context,
                label: 'Повторить',
                icon: Symbols.refresh_rounded,
                style: SheetMain.primary,
                key: const Key('retry'),
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Полоса «Нет связи» внутри экрана (ассистент): ячейка, слова, «Повторить» справа.
class RetryStrip extends StatelessWidget {
  const RetryStrip(this.message, {super.key, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      key: const Key('retry-strip'),
      decoration: BoxDecoration(
        color: s.errorContainer,
        border: Border.all(color: s.error),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 48,
              color: s.error,
              alignment: Alignment.center,
              child: Icon(Symbols.cloud_off_rounded, color: s.onError),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Нет связи',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: s.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: s.error)),
              ),
              child: TextButton(
                key: const Key('retry'),
                onPressed: onRetry,
                child: const Text('Повторить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
