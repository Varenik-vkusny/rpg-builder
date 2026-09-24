-- Персонаж мира и добыча врага.

create table public.characters (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  slug text not null check (slug ~ '^[a-z0-9]+(_[a-z0-9]+)*$'),
  title text not null check (length(btrim(title)) between 1 and 120),
  description text not null default '',
  role text not null check (role in ('npc', 'merchant', 'enemy')),
  location_id uuid,
  created_at timestamptz not null default now(),
  -- Локация только из того же мира.
  foreign key (project_id, location_id) references public.locations(project_id, id),
  unique (project_id, slug),
  unique (project_id, id)
);

create index characters_location_id_idx on public.characters (location_id);

create trigger characters_slug_immutable before update on public.characters
  for each row execute function public.forbid_slug_change();

alter table public.characters enable row level security;

create policy "characters_select_own" on public.characters
  for select to authenticated using (public.owns_project(project_id));
create policy "characters_insert_own" on public.characters
  for insert to authenticated with check (public.owns_project(project_id));

-- Добыча: враг роняет предмет с шансом 0 < шанс ≤ 100 (проценты).
-- Связь, а не объект мира, поэтому без slug.
create table public.loot (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  character_id uuid not null,
  item_id uuid not null,
  chance numeric(5, 2) not null check (chance > 0 and chance <= 100),
  -- Враг и предмет только из того же мира.
  foreign key (project_id, character_id)
    references public.characters(project_id, id) on delete cascade,
  foreign key (project_id, item_id) references public.items(project_id, id),
  unique (character_id, item_id)
);

create index loot_item_id_idx on public.loot (item_id);

alter table public.loot enable row level security;

create policy "loot_select_own" on public.loot
  for select to authenticated using (public.owns_project(project_id));
-- Добычу задают только врагу.
create policy "loot_insert_own_enemy" on public.loot
  for insert to authenticated with check (
    public.owns_project(project_id)
    and exists (
      select 1 from public.characters c
      where c.id = character_id and c.role = 'enemy'
    )
  );

-- Персонаж с добычей — одной транзакцией: либо всё, либо ничего.
-- security invoker: работает с правами автора, RLS действует как обычно.
create function public.create_character(
  p_project_id uuid,
  p_slug text,
  p_title text,
  p_description text,
  p_role text,
  p_location_id uuid,
  p_loot jsonb  -- [{"item_id": "...", "chance": 35}, ...]
) returns public.characters
  language plpgsql security invoker set search_path = ''
as $$
declare
  created public.characters;
begin
  insert into public.characters
    (project_id, slug, title, description, role, location_id)
  values
    (p_project_id, p_slug, p_title, p_description, p_role, p_location_id)
  returning * into created;

  insert into public.loot (project_id, character_id, item_id, chance)
  select p_project_id, created.id, (l->>'item_id')::uuid, (l->>'chance')::numeric
  from jsonb_array_elements(coalesce(p_loot, '[]'::jsonb)) as l;

  return created;
end;
$$;
