-- Долги журнала перед откатом (3.7):
-- 1) подпись операции считается в одном месте — у применённых и отклонённых наборов одинаково;
-- 2) удаление врага или квеста пишет в журнал и связи, ушедшие вместе с ним каскадом
--    (добыча; шаги и награды) — иначе откат не вернёт их;
-- 3) у врага с добычей роль не меняется и прямой правкой базы.

-- Подпись операции в журнале: slug объекта; добыча и награда — «кто/что», шаг — «квест#номер».
create function public.plan_op_label(op jsonb) returns text
  language sql immutable set search_path = ''
as $$
  select coalesce(op->>'label', case op->>'type'
    when 'loot' then (op->>'character') || '/' || (op->>'item')
    when 'quest_reward' then (op->>'quest') || '/' || (op->>'item')
    when 'quest_step' then (op->>'quest') || '#' || (op->>'position')
    else op->>'slug' end);
$$;

-- Связи, которые удаление объекта унесёт каскадом, — операциями плана с подписью и строкой.
-- Шаги — с последнего: откат идёт с конца журнала и вернёт их по порядку, с первого.
create function public.cascade_rows(p_project uuid, op jsonb)
  returns table (cascade_op jsonb, row_before jsonb)
  language plpgsql stable security invoker set search_path = ''
as $$
begin
  if op->>'action' <> 'delete' then
    return;
  end if;
  if op->>'type' = 'character' then
    return query
      select jsonb_build_object('action', 'delete', 'type', 'loot', 'cascade', true,
          'character', c.slug, 'item', i.slug),
        to_jsonb(l.*)
      from public.loot l
      join public.characters c on c.id = l.character_id
      join public.items i on i.id = l.item_id
      where c.project_id = p_project and c.slug = op->>'slug'
      order by i.slug;
  elsif op->>'type' = 'quest' then
    return query
      select jsonb_build_object('action', 'delete', 'type', 'quest_step', 'cascade', true,
          'quest', q.slug, 'position', s.position),
        to_jsonb(s.*)
      from public.quest_steps s join public.quests q on q.id = s.quest_id
      where q.project_id = p_project and q.slug = op->>'slug'
      order by s.position desc;
    return query
      select jsonb_build_object('action', 'delete', 'type', 'quest_reward', 'cascade', true,
          'quest', q.slug, 'item', i.slug),
        to_jsonb(r.*)
      from public.quest_rewards r
      join public.quests q on q.id = r.quest_id
      join public.items i on i.id = r.item_id
      where q.project_id = p_project and q.slug = op->>'slug'
      order by i.slug;
  end if;
end;
$$;

-- Операции набора — в мир и в журнал, по порядку. Общая часть «Применить» и отката.
create function public.apply_ops(p_project uuid, p_set uuid, p_ops jsonb)
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
    select * into r from public.apply_plan_op(p_project, op);
    insert into public.change_ops
      (project_id, change_set_id, position, action, object_type, object_slug, op, before, after)
    values (p_project, p_set, n, op->>'action', op->>'type', public.plan_op_label(op), op,
      r.before, r.after);
  end loop;
end;
$$;

create or replace function public.apply_change_set(
  p_project_id uuid, p_scope_type text, p_scope_slug text, p_request text, p_summary text,
  p_ops jsonb, p_input_tokens int, p_output_tokens int, p_attempts int
) returns public.change_sets
  language plpgsql security invoker set search_path = ''
as $$
declare
  cs public.change_sets;
begin
  if jsonb_array_length(coalesce(p_ops, '[]')) = 0 then
    raise exception 'в плане нет операций';
  end if;
  cs := public.new_change_set(p_project_id, p_scope_type, p_scope_slug, p_request, p_summary,
    'applied', p_input_tokens, p_output_tokens, p_attempts);
  perform public.apply_ops(p_project_id, cs.id, p_ops);
  return cs;
end;
$$;

create or replace function public.reject_change_set(
  p_project_id uuid, p_scope_type text, p_scope_slug text, p_request text, p_summary text,
  p_ops jsonb, p_input_tokens int, p_output_tokens int, p_attempts int
) returns public.change_sets
  language plpgsql security invoker set search_path = ''
as $$
declare
  cs public.change_sets;
begin
  cs := public.new_change_set(p_project_id, p_scope_type, p_scope_slug, p_request, p_summary,
    'rejected', p_input_tokens, p_output_tokens, p_attempts);
  insert into public.change_ops
    (project_id, change_set_id, position, action, object_type, object_slug, op)
  select p_project_id, cs.id, o.n, o.op->>'action', o.op->>'type', public.plan_op_label(o.op), o.op
  from jsonb_array_elements(coalesce(p_ops, '[]')) with ordinality as o(op, n);
  return cs;
end;
$$;

-- У врага с добычей роль не меняется (добыча бывает только у врага).
create function public.enemy_with_loot_keeps_role() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if old.role = 'enemy' and new.role <> 'enemy'
     and exists (select 1 from public.loot l where l.character_id = old.id) then
    raise exception 'у врага есть добыча — роль не меняется' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger characters_enemy_with_loot_keeps_role before update on public.characters
  for each row execute function public.enemy_with_loot_keeps_role();

revoke execute on function public.plan_op_label(jsonb) from public, anon;
revoke execute on function public.cascade_rows(uuid, jsonb) from public, anon;
revoke execute on function public.apply_ops(uuid, uuid, jsonb) from public, anon;
grant execute on function public.plan_op_label(jsonb) to authenticated;
grant execute on function public.cascade_rows(uuid, jsonb) to authenticated;
grant execute on function public.apply_ops(uuid, uuid, jsonb) to authenticated;
