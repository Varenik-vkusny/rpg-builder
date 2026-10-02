-- Раскладка карты (5а.4): где автор положил блок места на холсте. Это раскладка автора, а не
-- содержимое мира: не входит в план ИИ, историю, откат и экспорт (VISION.md §10). Поэтому —
-- отдельная таблица, а не поля места: строка места целиком уходит в «было/стало» истории.
-- Нет строки — место встаёт само в свободную клетку (приложение, lib/map/map_model.dart).
create table public.location_layout (
  location_id uuid primary key,
  project_id uuid not null references public.projects(id) on delete cascade,
  x double precision not null check (x >= 0),
  y double precision not null check (y >= 0),
  -- Место только из того же мира; удалили место — его положение уходит с ним.
  foreign key (project_id, location_id)
    references public.locations(project_id, id) on delete cascade
);

alter table public.location_layout enable row level security;

create policy "location_layout_own" on public.location_layout
  for all to authenticated
  using (public.owns_project(project_id))
  with check (public.owns_project(project_id));
