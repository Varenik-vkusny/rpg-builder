-- Роль персонажа меняется формой (22.11), но не там, где на ней держатся связи:
-- квест выдаёт только житель, убить можно только врага, в событии стоят только враги.
-- Приложение ловит это проверкой мира до записи; здесь — для всех путей записи, в том
-- числе для отката старого набора (ревью 22.11: откат смены роли мог сломать квест,
-- добавленный позже).
create function public.role_keeps_links() returns trigger
  language plpgsql set search_path = ''
as $$
declare
  q text;
  e text;
begin
  if new.role = old.role then
    return new;
  end if;
  if new.role <> 'npc' then
    select title into q from public.quests where giver_id = old.id limit 1;
    if q is not null then
      raise exception 'роль не меняется: «%» выдаёт квест «%» — квест выдаёт только житель',
        old.title, q using errcode = '23514';
    end if;
  end if;
  if new.role <> 'enemy' then
    select qq.title into q from public.quest_steps s join public.quests qq on qq.id = s.quest_id
      where s.character_id = old.id and s.kind = 'kill' limit 1;
    if q is not null then
      raise exception 'роль не меняется: «%» — цель «убить» в квесте «%»', old.title, q
        using errcode = '23514';
    end if;
    select ev.title into e from public.event_enemies x join public.events ev on ev.id = x.event_id
      where x.character_id = old.id limit 1;
    if e is not null then
      raise exception 'роль не меняется: «%» стоит врагом в событии «%»', old.title, e
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger characters_role_keeps_links before update on public.characters
  for each row execute function public.role_keeps_links();
