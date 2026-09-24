-- Квест мира: выдающий NPC, шаги по порядку, награды.

create table public.quests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  slug text not null check (slug ~ '^[a-z0-9]+(_[a-z0-9]+)*$'),
  title text not null check (length(btrim(title)) between 1 and 120),
  description text not null default '',
  giver_id uuid not null,
  created_at timestamptz not null default now(),
  -- Выдающий только из того же мира.
  foreign key (project_id, giver_id) references public.characters(project_id, id),
  unique (project_id, slug),
  unique (project_id, id)
);

create index quests_giver_id_idx on public.quests (giver_id);

create trigger quests_slug_immutable before update on public.quests
  for each row execute function public.forbid_slug_change();

alter table public.quests enable row level security;

create policy "quests_select_own" on public.quests
  for select to authenticated using (public.owns_project(project_id));
-- Выдаёт квест только персонаж с ролью «житель» (npc).
create policy "quests_insert_own_npc_giver" on public.quests
  for insert to authenticated with check (
    public.owns_project(project_id)
    and exists (
      select 1 from public.characters c
      where c.id = giver_id and c.role = 'npc'
    )
  );

-- Шаг квеста. Ровно одна цель по виду шага:
--   talk    — поговорить с персонажем
--   kill    — убить N врагов
--   collect — собрать N предметов
--   visit   — прийти в локацию
-- Связь, а не объект мира, поэтому без slug.
create table public.quest_steps (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  quest_id uuid not null,
  position int not null check (position >= 1),
  kind text not null check (kind in ('talk', 'kill', 'collect', 'visit')),
  character_id uuid,
  item_id uuid,
  location_id uuid,
  amount int,
  foreign key (project_id, quest_id)
    references public.quests(project_id, id) on delete cascade,
  -- Цели только из того же мира.
  foreign key (project_id, character_id)
    references public.characters(project_id, id),
  foreign key (project_id, item_id) references public.items(project_id, id),
  foreign key (project_id, location_id)
    references public.locations(project_id, id),
  check (case kind
    when 'talk' then character_id is not null and item_id is null
      and location_id is null and amount is null
    when 'kill' then character_id is not null and item_id is null
      and location_id is null and amount is not null and amount >= 1
    when 'collect' then item_id is not null and character_id is null
      and location_id is null and amount is not null and amount >= 1
    when 'visit' then location_id is not null and character_id is null
      and item_id is null and amount is null
  end),
  unique (quest_id, position)
);

create index quest_steps_character_id_idx on public.quest_steps (character_id);
create index quest_steps_item_id_idx on public.quest_steps (item_id);
create index quest_steps_location_id_idx on public.quest_steps (location_id);

alter table public.quest_steps enable row level security;

create policy "quest_steps_select_own" on public.quest_steps
  for select to authenticated using (public.owns_project(project_id));
-- Убить можно только врага.
create policy "quest_steps_insert_own" on public.quest_steps
  for insert to authenticated with check (
    public.owns_project(project_id)
    and (kind <> 'kill' or exists (
      select 1 from public.characters c
      where c.id = character_id and c.role = 'enemy'
    ))
  );

-- Награда за квест — предмет. Связь, без slug.
create table public.quest_rewards (
  project_id uuid not null references public.projects(id) on delete cascade,
  quest_id uuid not null,
  item_id uuid not null,
  foreign key (project_id, quest_id)
    references public.quests(project_id, id) on delete cascade,
  foreign key (project_id, item_id) references public.items(project_id, id),
  primary key (quest_id, item_id)
);

create index quest_rewards_item_id_idx on public.quest_rewards (item_id);

alter table public.quest_rewards enable row level security;

create policy "quest_rewards_select_own" on public.quest_rewards
  for select to authenticated using (public.owns_project(project_id));
create policy "quest_rewards_insert_own" on public.quest_rewards
  for insert to authenticated with check (public.owns_project(project_id));

-- Квест с шагами и наградами — одной транзакцией: либо всё, либо ничего.
-- Порядок шагов = порядок в массиве. Квест без шагов не создаётся.
-- security invoker: работает с правами автора, RLS действует как обычно.
create function public.create_quest(
  p_project_id uuid,
  p_slug text,
  p_title text,
  p_description text,
  p_giver_id uuid,
  p_steps jsonb,   -- [{"kind": "kill", "character_id": "...", "amount": 4}, ...]
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
    character_id, item_id, location_id, amount)
  select p_project_id, created.id, s.n, s.step->>'kind',
    (s.step->>'character_id')::uuid, (s.step->>'item_id')::uuid,
    (s.step->>'location_id')::uuid, (s.step->>'amount')::int
  from jsonb_array_elements(p_steps) with ordinality as s(step, n);

  insert into public.quest_rewards (project_id, quest_id, item_id)
  select p_project_id, created.id, (r #>> '{}')::uuid
  from jsonb_array_elements(coalesce(p_rewards, '[]'::jsonb)) as r;

  return created;
end;
$$;

-- Проба запрета смены slug знает и квесты (см. 20260924000005_slug_probe.sql).
create or replace function public.slug_change_blocked(p_table text, p_id uuid)
  returns boolean
  language plpgsql security definer set search_path = ''
as $$
declare
  found_own boolean;
begin
  if p_table not in ('locations', 'items', 'characters', 'quests') then
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
