-- Шаг квеста «пройти событие» (5б.3): пятая цель шага — событие.
-- Условий запуска у события нет (VISION §7): шаг только называет сцену, которую надо пройти.

alter table public.quest_steps
  add column event_id uuid,
  -- Событие только из того же мира; событие, на котором стоит шаг квеста, не удаляется.
  add constraint quest_steps_project_id_event_id_fkey
    foreign key (project_id, event_id) references public.events(project_id, id),
  drop constraint quest_steps_kind_check,
  add constraint quest_steps_kind_check
    check (kind in ('talk', 'kill', 'collect', 'visit', 'event')),
  drop constraint quest_steps_check,
  -- Ровно одна цель по виду шага.
  add constraint quest_steps_check check (case kind
    when 'talk' then character_id is not null and item_id is null
      and location_id is null and event_id is null and amount is null
    when 'kill' then character_id is not null and item_id is null
      and location_id is null and event_id is null and amount is not null and amount >= 1
    when 'collect' then item_id is not null and character_id is null
      and location_id is null and event_id is null and amount is not null and amount >= 1
    when 'visit' then location_id is not null and character_id is null
      and item_id is null and event_id is null and amount is null
    when 'event' then event_id is not null and character_id is null
      and item_id is null and location_id is null and amount is null
  end);

create index quest_steps_event_id_idx on public.quest_steps (event_id);

-- Квест с шагами и наградами — как было (20260924000006_quests.sql), шаг знает событие.
create or replace function public.create_quest(
  p_project_id uuid,
  p_slug text,
  p_title text,
  p_description text,
  p_giver_id uuid,
  p_steps jsonb,   -- [{"kind": "kill", "character_id": "...", "amount": 4}, {"kind": "event", "event_id": "..."}]
  p_rewards jsonb  -- ["item_id", ...]
) returns public.quests
  language plpgsql security invoker set search_path = ''
as $$
declare
  created public.quests;
begin
  if jsonb_array_length(coalesce(p_steps, '[]'::jsonb)) = 0 then
    raise exception 'у квеста должен быть хотя бы один шаг';
  end if;

  insert into public.quests (project_id, slug, title, description, giver_id)
  values (p_project_id, p_slug, p_title, p_description, p_giver_id)
  returning * into created;

  insert into public.quest_steps (project_id, quest_id, position, kind,
    character_id, item_id, location_id, event_id, amount)
  select p_project_id, created.id, s.n, s.step->>'kind',
    (s.step->>'character_id')::uuid, (s.step->>'item_id')::uuid,
    (s.step->>'location_id')::uuid, (s.step->>'event_id')::uuid, (s.step->>'amount')::int
  from jsonb_array_elements(p_steps) with ordinality as s(step, n);

  insert into public.quest_rewards (project_id, quest_id, item_id)
  select p_project_id, created.id, (r #>> '{}')::uuid
  from jsonb_array_elements(coalesce(p_rewards, '[]'::jsonb)) as r;

  return created;
end;
$$;

-- Шаг из плана ассистента — как было (20260924000010_apply_change_set.sql). Ассистент шагов
-- «пройти событие» не создаёт, но может править квест, где такой шаг есть: шаг, которому план
-- сменил вид, перестаёт ссылаться на событие; шаг, вид которого не тронут, событие сохраняет.
create or replace function public.apply_step_op(p_project uuid, op jsonb, out before jsonb, out after jsonb)
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
      event_id = case when step_kind = 'event' then s.event_id end,
      amount = step_amount
    where s.id = prev.id
    returning to_jsonb(s.*) into after;
  end if;
end;
$$;
