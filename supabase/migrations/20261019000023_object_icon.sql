-- Значок вида (5д, выбор владельца 19.10): имя значка из встроенного набора приложения
-- (game-icons, assets/glyphs) у жителя, врага и предмета. null — значок по роли или виду.
-- Пишется правкой вручную (apply_row_op — любые столбцы строки), поэтому функции плана
-- не меняются; откат возвращает строку целиком. Неизвестное приложению имя — как null.
alter table public.characters
  add column icon text check (icon is null or icon ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(icon) <= 60);

alter table public.items
  add column icon text check (icon is null or icon ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(icon) <= 60);
