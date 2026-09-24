-- Предмет мира. Урон есть только у оружия, защита — только у брони.
create table public.items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  slug text not null check (slug ~ '^[a-z0-9]+(_[a-z0-9]+)*$'),
  title text not null check (length(btrim(title)) between 1 and 120),
  kind text not null
    check (kind in ('weapon', 'armor', 'consumable', 'quest', 'misc')),
  rarity text not null
    check (rarity in ('common', 'uncommon', 'rare', 'epic', 'legendary')),
  level int not null check (level >= 1),
  damage int check (damage >= 0),
  defense int check (defense >= 0),
  price int not null check (price >= 0),
  created_at timestamptz not null default now(),
  check (case kind
    when 'weapon' then damage is not null and defense is null
    when 'armor' then defense is not null and damage is null
    else damage is null and defense is null
  end),
  unique (project_id, slug),
  -- Для ссылок из других таблиц только внутри того же мира.
  unique (project_id, id)
);

create trigger items_slug_immutable before update on public.items
  for each row execute function public.forbid_slug_change();

alter table public.items enable row level security;

create policy "items_select_own" on public.items
  for select to authenticated using (public.owns_project(project_id));
create policy "items_insert_own" on public.items
  for insert to authenticated with check (public.owns_project(project_id));
