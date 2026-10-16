-- Переезжает в supabase/migrations в день выкладки (вместе с выкладкой функции ассистента).
-- Ступень 2: ассистент создаёт, правит и удаляет события, врагов события и предметы события.

-- id своего объекта по slug (20260924000010): теперь знает и события.
create or replace function public.plan_object_id(p_project uuid, p_table text, p_slug text)
  returns uuid language plpgsql stable security invoker set search_path = ''
as $$
declare
  found_id uuid;
begin
  if p_table not in ('locations', 'items', 'characters', 'quests', 'events') then
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

-- Таблица цели шага по его виду: шаг «пройти событие» целится в события (раньше — в персонажей).
create or replace function public.step_target_table(p_kind text) returns text
  language sql immutable set search_path = ''
as $$
  select case p_kind when 'collect' then 'items' when 'visit' then 'locations'
    when 'event' then 'events' else 'characters' end;
$$;

-- Подпись операции в журнале (20260924000012): враг и предмет события — «событие/кто».
create or replace function public.plan_op_label(op jsonb) returns text
  language sql immutable set search_path = ''
as $$
  select coalesce(op->>'label', case op->>'type'
    when 'loot' then (op->>'character') || '/' || (op->>'item')
    when 'quest_reward' then (op->>'quest') || '/' || (op->>'item')
    when 'quest_step' then (op->>'quest') || '#' || (op->>'position')
    when 'event_enemy' then (op->>'event') || '/' || (op->>'character')
    when 'event_item' then (op->>'event') || '/' || (op->>'item')
    else op->>'slug' end);
$$;

-- Шаг квеста (20261004000020): цель вида «событие» пишется в event_id.
-- Раньше шаг, чья цель названа явно, для события ничего не писал.
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
      (project_id, quest_id, position, kind, character_id, item_id, location_id, event_id, amount)
    values (p_project, qid, pos, step_kind,
      case when step_kind in ('talk', 'kill') then tgt end,
      case when step_kind = 'collect' then tgt end,
      case when step_kind = 'visit' then tgt end,
      case when step_kind = 'event' then tgt end,
      step_amount)
    returning to_jsonb(s.*) into after;
  else
    before := to_jsonb(prev);
    update public.quest_steps s set
      kind = step_kind,
      character_id = case when step_kind in ('talk', 'kill') then tgt end,
      item_id = case when step_kind = 'collect' then tgt end,
      location_id = case when step_kind = 'visit' then tgt end,
      event_id = case when step_kind = 'event'
        then case when f->>'target' is not null then tgt else s.event_id end end,
      amount = step_amount
    where s.id = prev.id
    returning to_jsonb(s.*) into after;
  end if;
end;
$$;

-- Операция плана (20261001000017): события, враги события, предметы события.
create or replace function public.apply_plan_op(
  p_project uuid, op jsonb, out before jsonb, out after jsonb, out object_slug text
)
  language plpgsql security invoker set search_path = ''
as $$
declare
  f jsonb := coalesce(op->'fields', '{}');
  act text := op->>'action';
  typ text := op->>'type';
  rid uuid;
  cid uuid;
  iid uuid;
begin
  if act is null or act not in ('create', 'update', 'delete') then
    raise exception 'неизвестное действие %', act;
  end if;
  object_slug := op->>'slug';

  if typ in ('location', 'item', 'character', 'quest', 'event') then
    if act <> 'create' then
      rid := public.plan_object_id(p_project, typ || 's', object_slug);
    end if;
    if act = 'delete' then
      execute format('delete from public.%I t where t.id = $1 returning to_jsonb(t.*)', typ || 's')
        into before using rid;
      return;
    end if;
  end if;

  case typ
  when 'location' then
    if coalesce(f->>'parent', '') <> '' then
      cid := public.plan_object_id(p_project, 'locations', f->>'parent');
    end if;
    if act = 'create' then
      insert into public.locations as t
        (project_id, slug, title, description, level_min, level_max, parent_id)
      values (p_project, object_slug, f->>'title', coalesce(f->>'description', ''),
        (f->>'level_min')::int, (f->>'level_max')::int, cid)
      returning to_jsonb(t.*) into after;
    else
      select to_jsonb(t.*) into before from public.locations t where t.id = rid;
      update public.locations t set
        title = coalesce(f->>'title', t.title),
        description = coalesce(f->>'description', t.description),
        level_min = coalesce((f->>'level_min')::int, t.level_min),
        level_max = coalesce((f->>'level_max')::int, t.level_max),
        parent_id = case when f->>'parent' is null then t.parent_id else cid end
      where t.id = rid returning to_jsonb(t.*) into after;
    end if;

  when 'item' then
    if act = 'create' then
      insert into public.items as t
        (project_id, slug, title, kind, rarity, level, damage, defense, price, source, source_ref)
      values (p_project, object_slug, f->>'title', f->>'kind', f->>'rarity', (f->>'level')::int,
        (f->>'damage')::int, (f->>'defense')::int, (f->>'price')::int,
        f->>'source', f->>'source_ref')
      returning to_jsonb(t.*) into after;
    else
      select to_jsonb(t.*) into before from public.items t where t.id = rid;
      if f->>'kind' is not null and f->>'kind' <> before->>'kind' then
        raise exception 'вид предмета не меняется';
      end if;
      update public.items t set
        title = coalesce(f->>'title', t.title),
        rarity = coalesce(f->>'rarity', t.rarity),
        level = coalesce((f->>'level')::int, t.level),
        damage = coalesce((f->>'damage')::int, t.damage),
        defense = coalesce((f->>'defense')::int, t.defense),
        price = coalesce((f->>'price')::int, t.price)
      where t.id = rid returning to_jsonb(t.*) into after;
    end if;

  when 'character' then
    if f->>'location' is not null then
      iid := public.plan_object_id(p_project, 'locations', f->>'location');
    end if;
    if act = 'create' then
      insert into public.characters as t
        (project_id, slug, title, description, role, location_id, level, hp, attack)
      values (p_project, object_slug, f->>'title', coalesce(f->>'description', ''), f->>'role', iid,
        coalesce((f->>'level')::int, 1), coalesce((f->>'hp')::int, 10),
        coalesce((f->>'attack')::int, 0))
      returning to_jsonb(t.*) into after;
    else
      select to_jsonb(t.*) into before from public.characters t where t.id = rid;
      if f->>'role' is not null and f->>'role' <> before->>'role' then
        raise exception 'роль персонажа не меняется';
      end if;
      update public.characters t set
        title = coalesce(f->>'title', t.title),
        description = coalesce(f->>'description', t.description),
        location_id = coalesce(iid, t.location_id),
        level = coalesce((f->>'level')::int, t.level),
        hp = coalesce((f->>'hp')::int, t.hp),
        attack = coalesce((f->>'attack')::int, t.attack)
      where t.id = rid returning to_jsonb(t.*) into after;
    end if;

  when 'quest' then
    if f->>'giver' is not null then
      cid := public.plan_object_id(p_project, 'characters', f->>'giver');
    end if;
    if act = 'create' then
      insert into public.quests as t (project_id, slug, title, description, giver_id)
      values (p_project, object_slug, f->>'title', coalesce(f->>'description', ''), cid)
      returning to_jsonb(t.*) into after;
    else
      select to_jsonb(t.*) into before from public.quests t where t.id = rid;
      update public.quests t set
        title = coalesce(f->>'title', t.title),
        description = coalesce(f->>'description', t.description),
        giver_id = coalesce(cid, t.giver_id)
      where t.id = rid returning to_jsonb(t.*) into after;
    end if;

  when 'loot' then
    object_slug := (op->>'character') || '/' || (op->>'item');
    cid := public.plan_object_id(p_project, 'characters', op->>'character');
    iid := public.plan_object_id(p_project, 'items', op->>'item');
    select to_jsonb(t.*) into before from public.loot t
      where t.character_id = cid and t.item_id = iid;
    if act = 'create' then
      insert into public.loot as t (project_id, character_id, item_id, chance)
      values (p_project, cid, iid, (f->>'chance')::numeric) returning to_jsonb(t.*) into after;
    elsif before is null then
      raise exception 'такой добычи нет';
    elsif act = 'update' then
      update public.loot t set chance = (f->>'chance')::numeric
      where t.character_id = cid and t.item_id = iid returning to_jsonb(t.*) into after;
    else
      delete from public.loot t where t.character_id = cid and t.item_id = iid;
    end if;

  when 'quest_step' then
    object_slug := (op->>'quest') || '#' || (op->>'position');
    select s.before, s.after into before, after from public.apply_step_op(p_project, op) s;

  when 'quest_reward' then
    object_slug := (op->>'quest') || '/' || (op->>'item');
    rid := public.plan_object_id(p_project, 'quests', op->>'quest');
    iid := public.plan_object_id(p_project, 'items', op->>'item');
    if act = 'create' then
      insert into public.quest_rewards as t (project_id, quest_id, item_id)
      values (p_project, rid, iid) returning to_jsonb(t.*) into after;
    elsif act = 'delete' then
      delete from public.quest_rewards t where t.quest_id = rid and t.item_id = iid
        returning to_jsonb(t.*) into before;
      if before is null then
        raise exception 'такой награды нет';
      end if;
    else
      raise exception 'награду можно только добавить или убрать';
    end if;

  when 'event' then
    if f->>'location' is not null then
      iid := public.plan_object_id(p_project, 'locations', f->>'location');
    end if;
    if act = 'create' then
      insert into public.events as t (project_id, slug, title, description, location_id)
      values (p_project, object_slug, f->>'title', coalesce(f->>'description', ''), iid)
      returning to_jsonb(t.*) into after;
    else
      select to_jsonb(t.*) into before from public.events t where t.id = rid;
      update public.events t set
        title = coalesce(f->>'title', t.title),
        description = coalesce(f->>'description', t.description),
        location_id = coalesce(iid, t.location_id)
      where t.id = rid returning to_jsonb(t.*) into after;
    end if;

  when 'event_enemy' then
    object_slug := (op->>'event') || '/' || (op->>'character');
    rid := public.plan_object_id(p_project, 'events', op->>'event');
    cid := public.plan_object_id(p_project, 'characters', op->>'character');
    select to_jsonb(t.*) into before from public.event_enemies t
      where t.event_id = rid and t.character_id = cid;
    if act = 'create' then
      insert into public.event_enemies as t (project_id, event_id, character_id, amount)
      values (p_project, rid, cid, (f->>'amount')::int) returning to_jsonb(t.*) into after;
    elsif before is null then
      raise exception 'такого врага в событии нет';
    elsif act = 'update' then
      update public.event_enemies t set amount = (f->>'amount')::int
      where t.event_id = rid and t.character_id = cid returning to_jsonb(t.*) into after;
    else
      delete from public.event_enemies t where t.event_id = rid and t.character_id = cid;
    end if;

  when 'event_item' then
    object_slug := (op->>'event') || '/' || (op->>'item');
    rid := public.plan_object_id(p_project, 'events', op->>'event');
    iid := public.plan_object_id(p_project, 'items', op->>'item');
    if act = 'create' then
      insert into public.event_items as t (project_id, event_id, item_id)
      values (p_project, rid, iid) returning to_jsonb(t.*) into after;
    elsif act = 'delete' then
      delete from public.event_items t where t.event_id = rid and t.item_id = iid
        returning to_jsonb(t.*) into before;
      if before is null then
        raise exception 'такого предмета в событии нет';
      end if;
    else
      raise exception 'предмет в событии можно только добавить или убрать';
    end if;

  else
    raise exception 'неизвестный вид операции %', typ;
  end case;

  if act <> 'delete' and after is null then
    raise exception 'операция % % «%» не записана', act, typ, object_slug;
  end if;
end;
$$;
