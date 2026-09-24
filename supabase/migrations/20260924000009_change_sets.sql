-- Набор изменений ассистента: применяется одной транзакцией или не применяется вовсе
-- (VISION.md, правило 3). Каждая операция пишется с «было» и «стало».

-- ---------- правка и удаление своего содержимого ----------
create policy "locations_update_own" on public.locations
  for update to authenticated using (public.owns_project(project_id))
  with check (public.owns_project(project_id));
create policy "locations_delete_own" on public.locations
  for delete to authenticated using (public.owns_project(project_id));
create policy "items_update_own" on public.items
  for update to authenticated using (public.owns_project(project_id))
  with check (public.owns_project(project_id));
create policy "items_delete_own" on public.items
  for delete to authenticated using (public.owns_project(project_id));
create policy "characters_update_own" on public.characters
  for update to authenticated using (public.owns_project(project_id))
  with check (public.owns_project(project_id));
create policy "characters_delete_own" on public.characters
  for delete to authenticated using (public.owns_project(project_id));
create policy "loot_update_own_enemy" on public.loot
  for update to authenticated using (public.owns_project(project_id))
  with check (
    public.owns_project(project_id)
    and exists (select 1 from public.characters c where c.id = character_id and c.role = 'enemy')
  );
create policy "loot_delete_own" on public.loot
  for delete to authenticated using (public.owns_project(project_id));
create policy "quests_update_own_npc_giver" on public.quests
  for update to authenticated using (public.owns_project(project_id))
  with check (
    public.owns_project(project_id)
    and exists (select 1 from public.characters c where c.id = giver_id and c.role = 'npc')
  );
create policy "quests_delete_own" on public.quests
  for delete to authenticated using (public.owns_project(project_id));
create policy "quest_steps_update_own" on public.quest_steps
  for update to authenticated using (public.owns_project(project_id))
  with check (
    public.owns_project(project_id)
    and (kind <> 'kill' or exists (
      select 1 from public.characters c where c.id = character_id and c.role = 'enemy'
    ))
  );
create policy "quest_steps_delete_own" on public.quest_steps
  for delete to authenticated using (public.owns_project(project_id));
create policy "quest_rewards_delete_own" on public.quest_rewards
  for delete to authenticated using (public.owns_project(project_id));

-- Удаление шага сдвигает следующие одним update: номера проверяются в конце оператора.
alter table public.quest_steps
  drop constraint quest_steps_quest_id_position_key,
  add constraint quest_steps_quest_id_position_key
    unique (quest_id, position) deferrable initially immediate;

-- ---------- журнал ----------
create table public.change_sets (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  scope_type text not null check (scope_type in ('location', 'quest', 'character')),
  scope_slug text not null,
  request text not null,
  summary text not null default '',
  status text not null check (status in ('applied', 'rejected', 'reverted')),
  reverts_id uuid references public.change_sets(id),
  created_at timestamptz not null default now(),
  unique (project_id, id)
);

create table public.change_ops (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  change_set_id uuid not null,
  position int not null check (position >= 1),
  action text not null check (action in ('create', 'update', 'delete')),
  object_type text not null check (object_type in
    ('location', 'item', 'character', 'quest', 'loot', 'quest_step', 'quest_reward')),
  object_slug text not null,
  op jsonb not null,     -- операция плана как есть
  before jsonb,          -- строка до (null — создана)
  after jsonb,           -- строка после (null — удалена или набор отклонён)
  foreign key (project_id, change_set_id)
    references public.change_sets(project_id, id) on delete cascade,
  unique (change_set_id, position)
);

-- Журнал запросов к модели: токены и попытки (1 план + не больше 2 исправлений).
create table public.generations (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  change_set_id uuid not null,
  input_tokens int not null check (input_tokens >= 0),
  output_tokens int not null check (output_tokens >= 0),
  attempts int not null check (attempts between 1 and 3),
  created_at timestamptz not null default now(),
  foreign key (project_id, change_set_id)
    references public.change_sets(project_id, id) on delete cascade
);

create index change_ops_change_set_id_idx on public.change_ops (change_set_id);
create index generations_change_set_id_idx on public.generations (change_set_id);

alter table public.change_sets enable row level security;
alter table public.change_ops enable row level security;
alter table public.generations enable row level security;

create policy "change_sets_select_own" on public.change_sets
  for select to authenticated using (public.owns_project(project_id));
create policy "change_sets_insert_own" on public.change_sets
  for insert to authenticated with check (public.owns_project(project_id));
create policy "change_ops_select_own" on public.change_ops
  for select to authenticated using (public.owns_project(project_id));
create policy "change_ops_insert_own" on public.change_ops
  for insert to authenticated with check (public.owns_project(project_id));
create policy "generations_select_own" on public.generations
  for select to authenticated using (public.owns_project(project_id));
create policy "generations_insert_own" on public.generations
  for insert to authenticated with check (public.owns_project(project_id));
