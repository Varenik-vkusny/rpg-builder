-- Враг из справочника (5д): источник и ключ образца для атрибуции, как у предмета (4.6),
-- и карточка оригинала целиком (числа, атаки, характеристики) — уходит в экспорт.
-- Импорт пишет строку правкой вручную (apply_row_op — любые столбцы), функции плана не
-- меняются; откат убирает строку целиком.
alter table public.characters
  add column source text check (source is null or length(btrim(source)) between 1 and 60),
  add column source_ref text check (source_ref is null or length(btrim(source_ref)) between 1 and 200),
  add column source_card jsonb,
  add constraint characters_source_pair check ((source is null) = (source_ref is null)),
  add constraint characters_source_card check (source_card is null or source is not null);
