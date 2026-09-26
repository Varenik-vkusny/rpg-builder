-- Импорт образца из Open5e (4.6): предмет помнит, откуда он (атрибуция CC BY 4.0), и приходит
-- в мир планом через apply_change_set — в историю, с откатом. Набор импорта — область «import»:
-- модель не звали, журнала модели нет (p_attempts = null).
alter table public.items
  add column source text check (source is null or length(btrim(source)) between 1 and 60),
  add column source_ref text check (source_ref is null or length(btrim(source_ref)) between 1 and 200),
  add constraint items_source_pair check ((source is null) = (source_ref is null));

alter table public.change_sets
  drop constraint change_sets_scope_type_check,
  add constraint change_sets_scope_type_check
    check (scope_type in ('location', 'quest', 'character', 'manual', 'import'));

-- Та же операция плана (20260924000011), но создание предмета пишет и источник.
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

  if typ in ('location', 'item', 'character', 'quest') then
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
    if act = 'create' then
      insert into public.locations as t (project_id, slug, title, description, level_min, level_max)
      values (p_project, object_slug, f->>'title', coalesce(f->>'description', ''),
        (f->>'level_min')::int, (f->>'level_max')::int)
      returning to_jsonb(t.*) into after;
    else
      select to_jsonb(t.*) into before from public.locations t where t.id = rid;
      update public.locations t set
        title = coalesce(f->>'title', t.title),
        description = coalesce(f->>'description', t.description),
        level_min = coalesce((f->>'level_min')::int, t.level_min),
        level_max = coalesce((f->>'level_max')::int, t.level_max)
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

  else
    raise exception 'неизвестный вид операции %', typ;
  end case;

  -- Изменение, которое RLS тихо не пропустило, — тоже ошибка.
  if act <> 'delete' and after is null then
    raise exception 'операция % % «%» не записана', act, typ, object_slug;
  end if;
end;
$$;
