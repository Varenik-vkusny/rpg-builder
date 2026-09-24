-- Квест без шагов не сохраняется — и в обход create_quest тоже.
-- Проверка отложена до конца транзакции: create_quest сначала пишет квест,
-- потом шаги, и к моменту записи шаги уже есть.
create function public.quest_must_have_steps() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if exists (select 1 from public.quests where id = new.id)
     and not exists (select 1 from public.quest_steps where quest_id = new.id) then
    raise exception 'у квеста должен быть хотя бы один шаг';
  end if;
  return null;
end;
$$;

create constraint trigger quests_need_steps
  after insert on public.quests
  deferrable initially deferred
  for each row execute function public.quest_must_have_steps();
