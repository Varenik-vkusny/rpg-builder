-- Откат набора изменений (3.7, VISION.md правило 6): обратный набор через те же apply_ops,
-- одной транзакцией, в историю. Объект меняли после набора — конфликт, откат не идёт.
--
-- Обратная операция — «строковая»: {action, type, row, label[, slug]}. Она ставит строку
-- ровно такой, какой та была до набора (с прежним id, пустыми полями, номером шага),
-- чего операции плана не умеют (null в плане = «не менять»). Модель такие операции
-- прислать не может: схема плана на сервере не пускает лишних полей.

-- Таблица по виду операции.
create function public.op_table(p_type text) returns text
  language sql immutable set search_path = ''
as $$
  select case p_type
    when 'location' then 'locations' when 'item' then 'items'
    when 'character' then 'characters' when 'quest' then 'quests'
    when 'loot' then 'loot' when 'quest_step' then 'quest_steps'
    when 'quest_reward' then 'quest_rewards' end;
$$;

-- Строка таблицы по ключу строки из журнала: у награды ключ — квест и предмет, у прочих — id.
create function public.journal_row(p_type text, p_row jsonb) returns jsonb
  language plpgsql stable security invoker set search_path = ''
as $$
declare
  found jsonb;
begin
  if p_type = 'quest_reward' then
    select to_jsonb(r.*) into found from public.quest_rewards r
      where r.quest_id = (p_row->>'quest_id')::uuid and r.item_id = (p_row->>'item_id')::uuid;
  else
    execute format('select to_jsonb(t.*) from public.%I t where t.id = $1', public.op_table(p_type))
      into found using (p_row->>'id')::uuid;
  end if;
  return found;
end;
$$;

-- Строковая операция: создать строку как была, вернуть поля, удалить. Шаги сдвигаются.
create function public.apply_row_op(p_project uuid, op jsonb, out before jsonb, out after jsonb)
  language plpgsql security invoker set search_path = ''
as $$
declare
  typ text := op->>'type';
  tbl text := public.op_table(typ);
  r jsonb := op->'row';
  cols text;
begin
  if tbl is null or r is null or (r->>'project_id')::uuid is distinct from p_project then
    raise exception 'строковая операция не для этого мира';
  end if;
  if op->>'action' = 'create' then
    if typ = 'quest_step' then
      update public.quest_steps s set position = s.position + 1
        where s.quest_id = (r->>'quest_id')::uuid and s.position >= (r->>'position')::int;
    end if;
    execute format('insert into public.%1$I select * from jsonb_populate_record(null::public.%1$I, $1)'
      || ' returning to_jsonb(%1$I.*)', tbl) into after using r;
  elsif op->>'action' = 'update' then
    before := public.journal_row(typ, r);
    select string_agg(format('%I = x.%I', k, k), ', ') into cols
      from jsonb_object_keys(r) k where k not in ('id', 'project_id');
    execute format('update public.%1$I t set %2$s from jsonb_populate_record(null::public.%1$I, $1) x'
      || ' where t.id = x.id returning to_jsonb(t.*)', tbl, cols) into after using r;
  elsif op->>'action' = 'delete' then
    before := public.journal_row(typ, r);
    if typ = 'quest_reward' then
      delete from public.quest_rewards t
        where t.quest_id = (r->>'quest_id')::uuid and t.item_id = (r->>'item_id')::uuid;
    else
      execute format('delete from public.%I t where t.id = $1', tbl) using (r->>'id')::uuid;
    end if;
    if typ = 'quest_step' then
      update public.quest_steps s set position = s.position - 1
        where s.quest_id = (r->>'quest_id')::uuid and s.position > (r->>'position')::int;
    end if;
  else
    raise exception 'неизвестное действие %', op->>'action';
  end if;
  if (op->>'action' <> 'create' and before is null) or (op->>'action' <> 'delete' and after is null) then
    raise exception 'строка % «%» не найдена', typ, op->>'label';
  end if;
end;
$$;

-- Операции набора: операции плана и строковые операции отката — одним путём, с журналом.
create or replace function public.apply_ops(p_project uuid, p_set uuid, p_ops jsonb)
  returns void
  language plpgsql security invoker set search_path = ''
as $$
declare
  op jsonb;
  n int := 0;
  r record;
  dep record;
begin
  for op in select value from jsonb_array_elements(p_ops) loop
    -- Связи, которые уйдут каскадом, — в журнал до самого объекта.
    for dep in select * from public.cascade_rows(p_project, op) loop
      n := n + 1;
      insert into public.change_ops
        (project_id, change_set_id, position, action, object_type, object_slug, op, before)
      values (p_project, p_set, n, 'delete', dep.cascade_op->>'type',
        public.plan_op_label(dep.cascade_op), dep.cascade_op, dep.row_before);
    end loop;
    n := n + 1;
    if op ? 'row' then
      select * into r from public.apply_row_op(p_project, op);
    else
      select * into r from public.apply_plan_op(p_project, op);
    end if;
    insert into public.change_ops
      (project_id, change_set_id, position, action, object_type, object_slug, op, before, after)
    values (p_project, p_set, n, op->>'action', op->>'type', public.plan_op_label(op), op,
      r.before, r.after);
  end loop;
end;
$$;

-- Конфликты отката: объект меняли после набора. Смотрим итог набора по каждой строке
-- (последнюю операцию над ней): строка должна быть ровно такой, какой набор её оставил.
create function public.change_set_conflicts(p_set uuid)
  returns table (object_type text, object_slug text, reason text)
  language sql stable security invoker set search_path = ''
as $$
  with last_op as (
    select distinct on (o.object_type, coalesce(o.after, o.before)->>'id',
        coalesce(o.after, o.before)->>'quest_id', coalesce(o.after, o.before)->>'item_id')
      o.object_type, o.object_slug, o.position, o.before, o.after
    from public.change_ops o
    where o.change_set_id = p_set
    order by o.object_type, coalesce(o.after, o.before)->>'id',
      coalesce(o.after, o.before)->>'quest_id', coalesce(o.after, o.before)->>'item_id',
      o.position desc
  ),
  checked as (
    select l.object_type, l.object_slug, l.position,
      case
        when l.after is not null and public.journal_row(l.object_type, l.after) is null
          then 'удалён после набора'
        when l.after is not null and public.journal_row(l.object_type, l.after) <> l.after
          then 'изменён после набора'
        when l.after is null and public.journal_row(l.object_type, l.before) is not null
          then 'уже есть снова'
      end as reason
    from last_op l
  )
  select c.object_type, c.object_slug, c.reason from checked c
  where c.reason is not null
  order by c.position;
$$;

-- Откат: обратные операции с конца журнала, новый набор в историю, старый — «откачен».
create function public.revert_change_set(p_project_id uuid, p_set uuid)
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

  insert into public.change_sets
    (project_id, scope_type, scope_slug, request, summary, status, reverts_id)
  values (p_project_id, orig.scope_type, orig.scope_slug, orig.request,
    'Откат: ' || orig.summary, 'applied', orig.id)
  returning * into cs;
  perform public.apply_ops(p_project_id, cs.id, ops);
  update public.change_sets s set status = 'reverted' where s.id = orig.id;
  return cs;
end;
$$;

-- Журнал не переписывается: у набора меняется только статус «применён → откачен».
create function public.change_sets_guard() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if not (old.status = 'applied' and new.status = 'reverted')
     or (to_jsonb(new) - 'status') <> (to_jsonb(old) - 'status') then
    raise exception 'журнал наборов не переписывается' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger change_sets_guard before update on public.change_sets
  for each row execute function public.change_sets_guard();

create policy "change_sets_update_own" on public.change_sets
  for update to authenticated using (public.owns_project(project_id))
  with check (public.owns_project(project_id));

revoke execute on function public.op_table(text) from public, anon;
revoke execute on function public.journal_row(text, jsonb) from public, anon;
revoke execute on function public.apply_row_op(uuid, jsonb) from public, anon;
revoke execute on function public.change_set_conflicts(uuid) from public, anon;
revoke execute on function public.revert_change_set(uuid, uuid) from public, anon;
grant execute on function public.op_table(text) to authenticated;
grant execute on function public.journal_row(text, jsonb) to authenticated;
grant execute on function public.apply_row_op(uuid, jsonb) to authenticated;
grant execute on function public.change_set_conflicts(uuid) to authenticated;
grant execute on function public.revert_change_set(uuid, uuid) to authenticated;
