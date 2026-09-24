-- Проба запрета смены slug (VISION.md, правило 8) — прибор для тестов.
--
-- Правки объектов у автора пока нет (нет политики update), поэтому обычный
-- update из приложения не доходит до триггера: его отсекает RLS. Проба делает
-- настоящий update своего объекта и смотрит, остановил ли его триггер.
-- Ничего не меняет: удавшаяся смена slug тут же откатывается.
-- true — триггер запретил смену; false — slug сменился бы (триггера нет).
create function public.slug_change_blocked(p_table text, p_id uuid)
  returns boolean
  language plpgsql security definer set search_path = ''
as $$
declare
  found_own boolean;
begin
  if p_table not in ('locations', 'items', 'characters') then
    raise exception 'проба slug не знает таблицу %', p_table;
  end if;
  execute format(
    'select exists (select 1 from public.%I
       where id = $1 and public.owns_project(project_id))', p_table)
    into found_own using p_id;
  if not found_own then
    raise exception 'объект % не найден среди своих', p_id;
  end if;

  begin
    begin
      execute format(
        'update public.%I set slug = slug || ''_proba'' where id = $1', p_table)
        using p_id;
    exception when raise_exception then
      return true;  -- триггер остановил смену
    end;
    -- Смена прошла — откатываем её и докладываем.
    raise exception using errcode = 'P0099';
  exception when sqlstate 'P0099' then
    return false;
  end;
end;
$$;

revoke execute on function public.slug_change_blocked(text, uuid) from public, anon;
grant execute on function public.slug_change_blocked(text, uuid) to authenticated;
