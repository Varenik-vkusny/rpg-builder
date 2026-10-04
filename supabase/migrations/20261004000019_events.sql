-- Событие (5б.1) — сцена в месте: враги с числом и предметы. Без условий запуска (VISION §7).
-- Создаётся одной транзакцией; правка и удаление идут набором изменений через apply_ops,
-- как у остальных объектов: в историю, с откатом.

create table public.events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  slug text not null check (slug ~ '^[a-z0-9]+(_[a-z0-9]+)*$'),
  title text not null check (length(btrim(title)) between 1 and 120),
  description text not null default '',
  -- События без места не бывает.
  location_id uuid not null,
  created_at timestamptz not null default now(),
  -- Место только из того же мира; место с событиями не удаляется.
  foreign key (project_id, location_id) references public.locations(project_id, id),
  unique (project_id, slug),
  unique (project_id, id)
);

create index events_location_id_idx on public.events (location_id);

create trigger events_slug_immutable before update on public.events
  for each row execute function public.forbid_slug_change();

alter table public.events enable row level security;

create policy "events_select_own" on public.events
  for select to authenticated using (public.owns_project(project_id));
create policy "events_insert_own" on public.events
  for insert to authenticated with check (public.owns_project(project_id));
create policy "events_update_own" on public.events
  for update to authenticated using (public.owns_project(project_id))
  with check (public.owns_project(project_id));
create policy "events_delete_own" on public.events
  for delete to authenticated using (public.owns_project(project_id));

-- Враги события: кто и сколько. Связь, а не объект мира, поэтому без slug.
create table public.event_enemies (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  event_id uuid not null,
  character_id uuid not null,
  amount int not null check (amount >= 1),
  foreign key (project_id, event_id)
    references public.events(project_id, id) on delete cascade,
  -- Враг только из того же мира; враг, стоящий в событии, не удаляется.
  foreign key (project_id, character_id) references public.characters(project_id, id),
  unique (event_id, character_id)
);

create index event_enemies_character_id_idx on public.event_enemies (character_id);

alter table public.event_enemies enable row level security;

create policy "event_enemies_select_own" on public.event_enemies
  for select to authenticated using (public.owns_project(project_id));
-- В событии стоят только враги.
create policy "event_enemies_insert_own_enemy" on public.event_enemies
  for insert to authenticated with check (
    public.owns_project(project_id)
    and exists (
      select 1 from public.characters c
      where c.id = character_id and c.role = 'enemy'
    )
  );
create policy "event_enemies_update_own_enemy" on public.event_enemies
  for update to authenticated using (public.owns_project(project_id))
  with check (
    public.owns_project(project_id)
    and exists (
      select 1 from public.characters c
      where c.id = character_id and c.role = 'enemy'
    )
  );
create policy "event_enemies_delete_own" on public.event_enemies
  for delete to authenticated using (public.owns_project(project_id));

-- Предметы события: что лежит в сцене. Связь, без slug.
create table public.event_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  event_id uuid not null,
  item_id uuid not null,
  foreign key (project_id, event_id)
    references public.events(project_id, id) on delete cascade,
  -- Предмет только из того же мира; предмет, лежащий в событии, не удаляется.
  foreign key (project_id, item_id) references public.items(project_id, id),
  unique (event_id, item_id)
);

create index event_items_item_id_idx on public.event_items (item_id);

alter table public.event_items enable row level security;

create policy "event_items_select_own" on public.event_items
  for select to authenticated using (public.owns_project(project_id));
create policy "event_items_insert_own" on public.event_items
  for insert to authenticated with check (public.owns_project(project_id));
create policy "event_items_delete_own" on public.event_items
  for delete to authenticated using (public.owns_project(project_id));

-- Событие с врагами и предметами — одной транзакцией: либо всё, либо ничего.
-- security invoker: работает с правами автора, RLS действует как обычно.
create function public.create_event(
  p_project_id uuid,
  p_slug text,
  p_title text,
  p_description text,
  p_location_id uuid,
  p_enemies jsonb,  -- [{"character_id": "...", "amount": 3}, ...]
  p_items jsonb     -- ["item_id", ...]
) returns public.events
  language plpgsql security invoker set search_path = ''
as $$
declare
  created public.events;
begin
  insert into public.events (project_id, slug, title, description, location_id)
  values (p_project_id, p_slug, p_title, p_description, p_location_id)
  returning * into created;

  insert into public.event_enemies (project_id, event_id, character_id, amount)
  select p_project_id, created.id, (e->>'character_id')::uuid, (e->>'amount')::int
  from jsonb_array_elements(coalesce(p_enemies, '[]'::jsonb)) as e;

  insert into public.event_items (project_id, event_id, item_id)
  select p_project_id, created.id, (i #>> '{}')::uuid
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) as i;

  return created;
end;
$$;

revoke execute on function public.create_event(uuid, text, text, text, uuid, jsonb, jsonb) from public, anon;
grant execute on function public.create_event(uuid, text, text, text, uuid, jsonb, jsonb) to authenticated;

-- Журнал знает событие и его связи: правка вручную и откат идут строковыми операциями.
alter table public.change_ops
  drop constraint change_ops_object_type_check,
  add constraint change_ops_object_type_check
    check (object_type in ('location', 'item', 'character', 'quest', 'loot', 'quest_step',
      'quest_reward', 'event', 'event_enemy', 'event_item'));

create or replace function public.op_table(p_type text) returns text
  language sql immutable set search_path = ''
as $$
  select case p_type
    when 'location' then 'locations' when 'item' then 'items'
    when 'character' then 'characters' when 'quest' then 'quests'
    when 'loot' then 'loot' when 'quest_step' then 'quest_steps'
    when 'quest_reward' then 'quest_rewards'
    when 'event' then 'events' when 'event_enemy' then 'event_enemies'
    when 'event_item' then 'event_items' end;
$$;

-- Удаление события уносит каскадом его врагов и предметы — в журнал до самого события,
-- иначе откат их не вернёт. Остальное — как было (20260924000012_journal_debts.sql).
create or replace function public.cascade_rows(p_project uuid, op jsonb)
  returns table (cascade_op jsonb, row_before jsonb)
  language plpgsql stable security invoker set search_path = ''
as $$
begin
  if op->>'action' <> 'delete' then
    return;
  end if;
  if op->>'type' = 'character' then
    return query
      select jsonb_build_object('action', 'delete', 'type', 'loot', 'cascade', true,
          'character', c.slug, 'item', i.slug),
        to_jsonb(l.*)
      from public.loot l
      join public.characters c on c.id = l.character_id
      join public.items i on i.id = l.item_id
      where c.project_id = p_project and c.slug = op->>'slug'
      order by i.slug;
  elsif op->>'type' = 'quest' then
    return query
      select jsonb_build_object('action', 'delete', 'type', 'quest_step', 'cascade', true,
          'quest', q.slug, 'position', s.position),
        to_jsonb(s.*)
      from public.quest_steps s join public.quests q on q.id = s.quest_id
      where q.project_id = p_project and q.slug = op->>'slug'
      order by s.position desc;
    return query
      select jsonb_build_object('action', 'delete', 'type', 'quest_reward', 'cascade', true,
          'quest', q.slug, 'item', i.slug),
        to_jsonb(r.*)
      from public.quest_rewards r
      join public.quests q on q.id = r.quest_id
      join public.items i on i.id = r.item_id
      where q.project_id = p_project and q.slug = op->>'slug'
      order by i.slug;
  elsif op->>'type' = 'event' then
    return query
      select jsonb_build_object('action', 'delete', 'type', 'event_enemy', 'cascade', true,
          'label', e.slug || '/' || c.slug),
        to_jsonb(ee.*)
      from public.event_enemies ee
      join public.events e on e.id = ee.event_id
      join public.characters c on c.id = ee.character_id
      where e.project_id = p_project and e.slug = op->>'slug'
      order by c.slug;
    return query
      select jsonb_build_object('action', 'delete', 'type', 'event_item', 'cascade', true,
          'label', e.slug || '/' || i.slug),
        to_jsonb(ei.*)
      from public.event_items ei
      join public.events e on e.id = ei.event_id
      join public.items i on i.id = ei.item_id
      where e.project_id = p_project and e.slug = op->>'slug'
      order by i.slug;
  end if;
end;
$$;

-- Проба запрета смены slug знает и события (см. 20260924000005_slug_probe.sql).
create or replace function public.slug_change_blocked(p_table text, p_id uuid)
  returns boolean
  language plpgsql security definer set search_path = ''
as $$
declare
  found_own boolean;
begin
  if p_table not in ('locations', 'items', 'characters', 'quests', 'events') then
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
