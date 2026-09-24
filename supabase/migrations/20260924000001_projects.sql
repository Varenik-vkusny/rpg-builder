-- Мир автора. Автор видит и меняет только свои миры (RLS).
create table public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (length(btrim(title)) between 1 and 120),
  setting text not null default '',
  tone text not null default '',
  level_min int not null check (level_min >= 1),
  level_max int not null,
  created_at timestamptz not null default now(),
  check (level_min <= level_max)
);

create index projects_owner_id_idx on public.projects (owner_id);

alter table public.projects enable row level security;

create policy "projects_select_own" on public.projects
  for select to authenticated using (owner_id = (select auth.uid()));
create policy "projects_insert_own" on public.projects
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "projects_update_own" on public.projects
  for update to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "projects_delete_own" on public.projects
  for delete to authenticated using (owner_id = (select auth.uid()));
