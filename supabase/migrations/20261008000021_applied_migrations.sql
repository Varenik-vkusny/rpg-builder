-- Прибор «папка миграций = база» (0в): имена накатанных миграций по порядку накатки.
-- Только чтение и только имена — ни версий, ни текста запросов. Вызывает вошедший автор;
-- без входа (anon) и для public доступа нет.

create function public.applied_migrations()
returns setof text
language sql
stable
security definer
set search_path = ''
as $$
  select m.name
  from supabase_migrations.schema_migrations m
  order by m.version;
$$;

revoke all on function public.applied_migrations() from public, anon;
grant execute on function public.applied_migrations() to authenticated;
