-- Применение плана ассистента. Всё — security invoker: права автора, RLS как обычно.
-- Формат операции — как у серверной функции (supabase/functions/assistant/plan.ts).

-- id своего объекта по slug; нет — ошибка (и весь набор откатывается).
create function public.plan_object_id(p_project uuid, p_table text, p_slug text)
  returns uuid language plpgsql stable security invoker set search_path = ''
as $$
declare
  found_id uuid;
begin
  if p_table not in ('locations', 'items', 'characters', 'quests') then
    raise exception 'неизвестная таблица %', p_table;
  end if;
  execute format('select id from public.%I where project_id = $1 and slug = $2', p_table)
    into found_id using p_project, p_slug;
  if found_id is null then
    raise exception '% «%» нет в мире', p_table, p_slug;
  end if;
  return found_id;
end;
$$;

-- Таблица цели шага по его виду.
create function public.step_target_table(p_kind text) returns text
  language sql immutable set search_path = ''
as $$
  select case p_kind when 'collect' then 'items' when 'visit' then 'locations'
    else 'characters' end;
$$;

-- Шаг квеста: создать (только в конец), изменить, удалить со сдвигом следующих.
create function public.apply_step_op(p_project uuid, op jsonb, out before jsonb, out after jsonb)
  language plpgsql security invoker set search_path = ''
as $$
declare
  f jsonb := coalesce(op->'fields', '{}');
  qid uuid := public.plan_object_id(p_project, 'quests', op->>'quest');
  pos int := (op->>'position')::int;
  prev public.quest_steps;
  step_kind text;
  tgt uuid;
  step_amount int;
begin
  select * into prev from public.quest_steps s where s.quest_id = qid and s.position = pos;
  if op->>'action' = 'delete' then
    if prev.id is null then
      raise exception 'шага % нет', pos;
    end if;
    before := to_jsonb(prev);
    delete from public.quest_steps s where s.id = prev.id;
    update public.quest_steps s set position = s.position - 1
      where s.quest_id = qid and s.position > pos;
    return;
  end if;
  if op->>'action' = 'create' then
    if prev.id is not null
       or pos <> 1 + (select count(*) from public.quest_steps s where s.quest_id = qid) then
      raise exception 'новый шаг — только в конец';
    end if;
  elsif prev.id is null then
    raise exception 'шага % нет', pos;
  end if;

  step_kind := coalesce(f->>'step_kind', prev.kind);
  tgt := case when f->>'target' is not null
    then public.plan_object_id(p_project, public.step_target_table(step_kind), f->>'target')
    else coalesce(prev.character_id, prev.item_id, prev.location_id) end;
  step_amount := case when step_kind in ('kill', 'collect')
    then coalesce((f->>'amount')::int, prev.amount) end;

  if prev.id is null then
    insert into public.quest_steps as s
      (project_id, quest_id, position, kind, character_id, item_id, location_id, amount)
    values (p_project, qid, pos, step_kind,
      case when step_kind in ('talk', 'kill') then tgt end,
      case when step_kind = 'collect' then tgt end,
      case when step_kind = 'visit' then tgt end,
      step_amount)
    returning to_jsonb(s.*) into after;
  else
    before := to_jsonb(prev);
    update public.quest_steps s set
      kind = step_kind,
      character_id = case when step_kind in ('talk', 'kill') then tgt end,
      item_id = case when step_kind = 'collect' then tgt end,
      location_id = case when step_kind = 'visit' then tgt end,
      amount = step_amount
    where s.id = prev.id
    returning to_jsonb(s.*) into after;
  end if;
end;
$$;
