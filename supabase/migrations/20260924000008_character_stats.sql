-- Персонажу — уровень, здоровье, атака. У старых персонажей — ур. 1, здоровье 10, атака 0.
alter table public.characters
  add column level int not null default 1 check (level >= 1),
  add column hp int not null default 10 check (hp >= 1),
  add column attack int not null default 0 check (attack >= 0);

-- create_character знает уровень, здоровье и атаку. Старый вызов без них — по умолчанию.
drop function public.create_character(uuid, text, text, text, text, uuid, jsonb);

create function public.create_character(
  p_project_id uuid,
  p_slug text,
  p_title text,
  p_description text,
  p_role text,
  p_location_id uuid,
  p_loot jsonb,  -- [{"item_id": "...", "chance": 35}, ...]
  p_level int default 1,
  p_hp int default 10,
  p_attack int default 0
) returns public.characters
  language plpgsql security invoker set search_path = ''
as $$
declare
  created public.characters;
begin
  insert into public.characters
    (project_id, slug, title, description, role, location_id, level, hp, attack)
  values
    (p_project_id, p_slug, p_title, p_description, p_role, p_location_id,
     p_level, p_hp, p_attack)
  returning * into created;

  insert into public.loot (project_id, character_id, item_id, chance)
  select p_project_id, created.id, (l->>'item_id')::uuid, (l->>'chance')::numeric
  from jsonb_array_elements(coalesce(p_loot, '[]'::jsonb)) as l;

  return created;
end;
$$;
