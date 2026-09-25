-- «Откачен» и «откат набора» ставит только сам откат (ревью 3.7, СТОП): иначе автор
-- прямой правкой пометил бы набор откаченным, не откатив мир, и история начала бы врать.
-- revert_change_set поднимает флаг транзакции rpgb.reverting = id набора; клиент через
-- PostgREST поднять его не может (одна просьба — одна транзакция, set_config не открыт).

create or replace function public.change_sets_guard() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if not (old.status = 'applied' and new.status = 'reverted')
     or (to_jsonb(new) - 'status') <> (to_jsonb(old) - 'status')
     or current_setting('rpgb.reverting', true) is distinct from old.id::text then
    raise exception 'журнал наборов не переписывается' using errcode = '42501';
  end if;
  return new;
end;
$$;

-- Новый набор: «откачен» сразу не бывает, «откат набора» — только изнутри отката.
create function public.change_sets_insert_guard() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if new.status = 'reverted'
     or (new.reverts_id is not null
         and current_setting('rpgb.reverting', true) is distinct from new.reverts_id::text) then
    raise exception 'откат пишет только функция отката' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger change_sets_insert_guard before insert on public.change_sets
  for each row execute function public.change_sets_insert_guard();

create or replace function public.revert_change_set(p_project_id uuid, p_set uuid)
  returns public.change_sets
  language plpgsql security invoker set search_path = ''
as $$
declare
  orig public.change_sets;
  cs public.change_sets;
  conflicts text;
  ops jsonb;
begin
  select * into orig from public.change_sets s
    where s.id = p_set and s.project_id = p_project_id for update;
  if orig.id is null then
    raise exception 'набора нет';
  end if;
  if orig.status <> 'applied' then
    raise exception 'откатить можно только применённый набор (этот — %)', orig.status;
  end if;
  select string_agg(c.object_slug || ': ' || c.reason, '; ') into conflicts
    from public.change_set_conflicts(p_set) c;
  if conflicts is not null then
    raise exception 'конфликт отката: %', conflicts;
  end if;

  -- Пустые поля строки — тоже значения: откат ставит их как были.
  select jsonb_agg(jsonb_build_object(
      'action', case when o.before is null then 'delete'
        when o.after is null then 'create' else 'update' end,
      'type', o.object_type,
      'row', coalesce(o.before, o.after),
      'label', o.object_slug,
      -- slug нужен каскаду: удаление врага или квеста пишет в журнал и его связи.
      'slug', coalesce(o.before, o.after)->>'slug')
    order by o.position desc) into ops
  from public.change_ops o where o.change_set_id = p_set;

  -- Флаг до конца транзакции: только здесь журнал принимает «откат набора» и «Откачен».
  perform set_config('rpgb.reverting', orig.id::text, true);
  insert into public.change_sets
    (project_id, scope_type, scope_slug, request, summary, status, reverts_id)
  values (p_project_id, orig.scope_type, orig.scope_slug, orig.request,
    'Откат: ' || orig.summary, 'applied', orig.id)
  returning * into cs;
  perform public.apply_ops(p_project_id, cs.id, ops);
  update public.change_sets s set status = 'reverted' where s.id = orig.id;
  perform set_config('rpgb.reverting', '', true);
  return cs;
end;
$$;
