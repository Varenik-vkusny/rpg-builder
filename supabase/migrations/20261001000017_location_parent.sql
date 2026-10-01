-- Вложенность мест (5а.1): место лежит внутри другого — Копи › Штольня №3 › Забой.
-- Не глубже трёх уровней и не само в себе (VISION.md, §7); удалить место с вложенными
-- нельзя — внешний ключ, как у жителей. Проверка вложенности — в конце транзакции:
-- план и откат могут переставлять места по одному, важен итог.
alter table public.locations
  add column parent_id uuid,
  add constraint locations_parent_fk foreign key (project_id, parent_id)
    references public.locations(project_id, id),
  add constraint locations_parent_not_self check (parent_id is distinct from id);

create index locations_parent_id_idx on public.locations (parent_id);

-- Место не в цикле и вместе с вложенными не глубже трёх уровней. Удалённое в той же
-- транзакции место не проверяется. Подъём по родителям помнит путь — цикл не зациклит.
create function public.check_location_nesting() returns trigger
  language plpgsql security invoker set search_path = ''
as $$
declare
  up int;
  down int;
  cyc boolean;
begin
  if not exists (select 1 from public.locations where id = new.id) then
    return null;
  end if;
  with recursive anc(id, parent_id, n, path) as (
    select l.id, l.parent_id, 0, array[l.id] from public.locations l where l.id = new.id
    union all
    select p.id, p.parent_id, a.n + 1, a.path || p.id
    from anc a join public.locations p on p.id = a.parent_id
    where not p.id = any(a.path)
  )
  select max(n), coalesce(bool_or(parent_id = new.id), false) into up, cyc from anc;
  if cyc then
    raise exception 'место «%» лежит само в себе', new.title;
  end if;
  with recursive des(id, n) as (
    select new.id, 0
    union all
    select c.id, d.n + 1 from des d join public.locations c on c.parent_id = d.id
    where d.n < 4
  )
  select max(n) into down from des;
  if up + down + 1 > 3 then
    raise exception 'место «%»: вложенность глубже 3 уровней', new.title;
  end if;
  return null;
end;
$$;

create constraint trigger locations_nesting
  after insert or update of parent_id on public.locations
  deferrable initially deferred
  for each row execute function public.check_location_nesting();

-- Та же операция плана (20260926000016), но место знает родителя: поле parent (slug;
-- «» — на верхний уровень, null — не задаю / не меняю). Комментарии — снаружи функции:
-- тело в базе ровно такое, как здесь.
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

  else
    raise exception 'неизвестный вид операции %', typ;
  end case;

  if act <> 'delete' and after is null then
    raise exception 'операция % % «%» не записана', act, typ, object_slug;
  end if;
end;
$$;
