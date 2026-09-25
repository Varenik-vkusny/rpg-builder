-- Ручная правка и удаление (4.1) — набором изменений через те же apply_ops, что
-- «Применить» и откат: правка в истории, её можно откатить, откат старого набора
-- видит, что объект меняли руками. Операции строковые (как у отката).

-- Набор «вручную»: область — сам объект, без модели (токенов и попыток нет).
alter table public.change_sets
  drop constraint change_sets_scope_type_check,
  add constraint change_sets_scope_type_check
    check (scope_type in ('location', 'quest', 'character', 'manual'));

create or replace function public.new_change_set(
  p_project_id uuid, p_scope_type text, p_scope_slug text, p_request text,
  p_summary text, p_status text, p_input_tokens int, p_output_tokens int, p_attempts int
) returns public.change_sets
  language plpgsql security invoker set search_path = ''
as $$
declare
  cs public.change_sets;
begin
  insert into public.change_sets (project_id, scope_type, scope_slug, request, summary, status)
  values (p_project_id, p_scope_type, p_scope_slug, p_request, coalesce(p_summary, ''), p_status)
  returning * into cs;
  -- Модель не звали (правка вручную) — и журнала модели нет.
  if p_attempts is not null then
    insert into public.generations (project_id, change_set_id, input_tokens, output_tokens, attempts)
    values (p_project_id, cs.id, p_input_tokens, p_output_tokens, p_attempts);
  end if;
  return cs;
end;
$$;

-- Строковая операция: новая строка пишет только переданные столбцы — остальное по
-- умолчанию (id новой добычи или шага даёт база). Откат передаёт строку целиком.
create or replace function public.apply_row_op(p_project uuid, op jsonb, out before jsonb, out after jsonb)
  language plpgsql security invoker set search_path = ''
as $$
declare
  typ text := op->>'type';
  tbl text := public.op_table(typ);
  r jsonb := op->'row';
  cols text;
begin
  if tbl is null or r is null or (r->>'project_id')::uuid is distinct from p_project then
    raise exception 'строковая операция не для этого мира';
  end if;
  if op->>'action' = 'create' then
    if typ = 'quest_step' then
      update public.quest_steps s set position = s.position + 1
        where s.quest_id = (r->>'quest_id')::uuid and s.position >= (r->>'position')::int;
    end if;
    select string_agg(format('%I', k), ', ') into cols from jsonb_object_keys(r) k;
    execute format('insert into public.%1$I (%2$s) select %2$s'
      || ' from jsonb_populate_record(null::public.%1$I, $1) returning to_jsonb(%1$I.*)', tbl, cols)
      into after using r;
  elsif op->>'action' = 'update' then
    before := public.journal_row(typ, r);
    select string_agg(format('%I = x.%I', k, k), ', ') into cols
      from jsonb_object_keys(r) k where k not in ('id', 'project_id');
    if typ = 'loot' and r->>'id' is null then
      -- Добыча из правки вручную — по врагу и предмету (id у экрана нет).
      select to_jsonb(l.*) into before from public.loot l
        where l.character_id = (r->>'character_id')::uuid and l.item_id = (r->>'item_id')::uuid;
      r := r || jsonb_build_object('id', before->>'id');
    end if;
    execute format('update public.%1$I t set %2$s from jsonb_populate_record(null::public.%1$I, $1) x'
      || ' where t.id = x.id returning to_jsonb(t.*)', tbl, cols) into after using r;
  elsif op->>'action' = 'delete' then
    if typ = 'loot' and r->>'id' is null then
      select to_jsonb(l.*) into before from public.loot l
        where l.character_id = (r->>'character_id')::uuid and l.item_id = (r->>'item_id')::uuid;
    elsif typ = 'quest_step' and r->>'id' is null then
      select to_jsonb(s.*) into before from public.quest_steps s
        where s.quest_id = (r->>'quest_id')::uuid and s.position = (r->>'position')::int;
    else
      before := public.journal_row(typ, r);
    end if;
    if typ = 'quest_reward' then
      delete from public.quest_rewards t
        where t.quest_id = (r->>'quest_id')::uuid and t.item_id = (r->>'item_id')::uuid;
    else
      execute format('delete from public.%I t where t.id = $1', tbl) using (before->>'id')::uuid;
    end if;
    if typ = 'quest_step' then
      update public.quest_steps s set position = s.position - 1
        where s.quest_id = (before->>'quest_id')::uuid and s.position > (before->>'position')::int;
    end if;
  else
    raise exception 'неизвестное действие %', op->>'action';
  end if;
  if (op->>'action' <> 'create' and before is null) or (op->>'action' <> 'delete' and after is null) then
    raise exception 'строка % «%» не найдена', typ, op->>'label';
  end if;
end;
$$;

-- «Сохранить» в форме правки и «Удалить»: одной транзакцией, в историю.
create function public.apply_manual_edit(
  p_project_id uuid, p_slug text, p_title text, p_ops jsonb
) returns public.change_sets
  language plpgsql security invoker set search_path = ''
as $$
declare
  cs public.change_sets;
begin
  if jsonb_array_length(coalesce(p_ops, '[]')) = 0 then
    raise exception 'в правке нет изменений';
  end if;
  if exists (select 1 from jsonb_array_elements(p_ops) o where not (o.value ? 'row')) then
    raise exception 'правка вручную — только строковые операции';
  end if;
  cs := public.new_change_set(p_project_id, 'manual', p_slug, p_title, p_title,
    'applied', null, null, null);
  perform public.apply_ops(p_project_id, cs.id, p_ops);
  return cs;
end;
$$;

revoke execute on function public.apply_manual_edit(uuid, text, text, jsonb) from public, anon;
grant execute on function public.apply_manual_edit(uuid, text, text, jsonb) to authenticated;
