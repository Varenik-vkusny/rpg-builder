-- Общее для всех объектов мира.

-- Автор владеет миром? Проверка владельца явная, не только через RLS на projects.
create function public.owns_project(pid uuid) returns boolean
  language sql stable security invoker set search_path = ''
as $$
  select exists (
    select 1 from public.projects p
    where p.id = pid and p.owner_id = (select auth.uid())
  );
$$;

-- Инвариант VISION.md №8: slug объекта не меняется после создания.
create function public.forbid_slug_change() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if new.slug is distinct from old.slug then
    raise exception 'slug объекта не меняется после создания (было %, стало %)',
      old.slug, new.slug;
  end if;
  return new;
end;
$$;

-- Локация мира.
create table public.locations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  slug text not null check (slug ~ '^[a-z0-9]+(_[a-z0-9]+)*$'),
  title text not null check (length(btrim(title)) between 1 and 120),
  description text not null default '',
  level_min int not null check (level_min >= 1),
  level_max int not null,
  created_at timestamptz not null default now(),
  check (level_min <= level_max),
  unique (project_id, slug),
  -- Для ссылок из других таблиц только внутри того же мира.
  unique (project_id, id)
);

create trigger locations_slug_immutable before update on public.locations
  for each row execute function public.forbid_slug_change();

alter table public.locations enable row level security;

create policy "locations_select_own" on public.locations
  for select to authenticated using (public.owns_project(project_id));
create policy "locations_insert_own" on public.locations
  for insert to authenticated with check (public.owns_project(project_id));
