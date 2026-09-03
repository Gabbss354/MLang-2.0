-- The scheduler's clock. fn_materialize_schedule runs once, when an
-- episode is created. fn_daily_tick runs once a day (pg_cron in
-- production) and is the only thing that turns 'pending' into 'notified'
-- and 'notified'/'pending' into 'missed' -- a missed window is a row the
-- system produced on its own, not a gap the app inferred.

create or replace function fn_materialize_schedule(p_episode_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_episode episodes%rowtype;
begin
  select * into v_episode from episodes where id = p_episode_id;
  if not found then
    raise exception 'episode % not found', p_episode_id;
  end if;

  insert into scheduled_assessments
    (episode_id, protocol_step_id, instrument_code, step_label, window_open, window_close)
  select
    v_episode.id,
    ps.id,
    ps.instrument_code,
    ps.step_label,
    v_episode.index_date + ps.offset_days - ps.window_before_days,
    v_episode.index_date + ps.offset_days + ps.window_after_days
  from protocol_steps ps
  where ps.protocol_code = v_episode.protocol_code
  on conflict (episode_id, protocol_step_id) do nothing;
end;
$$;

create or replace function fn_materialize_schedule_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform fn_materialize_schedule(new.id);
  return new;
end;
$$;

create trigger trg_episodes_materialize
  after insert on episodes
  for each row execute function fn_materialize_schedule_trigger();

-- fn_daily_tick: advance every scheduled_assessment's status against
-- today's date. Idempotent -- safe to call more than once on the same day.
create or replace function fn_daily_tick() returns void
language plpgsql security definer set search_path = public as $$
begin
  update scheduled_assessments
    set status = 'notified', notified_at = now()
    where status = 'pending' and window_open <= current_date;

  update scheduled_assessments
    set status = 'missed'
    where status in ('pending', 'notified') and window_close < current_date;

  perform fn_evaluate_dropout(episode_id)
    from (
      select distinct episode_id from scheduled_assessments
      where status = 'missed' and window_close = current_date - 1
    ) recently_missed;
end;
$$;

-- ------------------------------------------------------------- red flags

-- Runs against a single answered item, at answer time -- immediate, no
-- batching. Only NRS-style numeric items and yes/no items are supported by
-- the two operators below; extend as instruments with other response types
-- gain red-flag rules.
create or replace function fn_evaluate_red_flag(p_response_id uuid, p_item_code text, p_raw_value jsonb)
  returns void
language plpgsql security definer set search_path = public as $$
declare
  v_response responses%rowtype;
  v_rule jsonb;
  v_numeric numeric;
  v_fires boolean := false;
begin
  select * into v_response from responses where id = p_response_id;

  select red_flag_rule into v_rule
    from instrument_items
    where instrument_code = v_response.instrument_code and item_code = p_item_code;

  if v_rule is null then
    return;
  end if;

  if v_rule ? 'operator' then
    v_numeric := (p_raw_value #>> '{}')::numeric;
    if v_rule->>'operator' = '>=' and v_numeric >= (v_rule->>'value')::numeric then
      v_fires := true;
    elsif v_rule->>'operator' = '<=' and v_numeric <= (v_rule->>'value')::numeric then
      v_fires := true;
    end if;
  elsif v_rule ? 'equals' then
    v_fires := (p_raw_value #>> '{}') = (v_rule->>'equals');
  end if;

  if v_fires then
    insert into alerts (episode_id, kind, severity, source_response_id, explanation, details)
    values (
      v_response.episode_id,
      'red_flag',
      'critical',
      p_response_id,
      format('Item %s da resposta de %s disparou red flag (regra: %s, valor informado: %s).',
             p_item_code, v_response.instrument_code, v_rule, p_raw_value),
      jsonb_build_object('item_code', p_item_code, 'rule', v_rule, 'raw_value', p_raw_value)
    );
  end if;
end;
$$;

-- ------------------------------------------------------- clinical scoring

-- PLACEHOLDER. Averages item values normalized to 0-1 against each item's
-- own response-type range, then rescales to the subscale's min/max. This
-- is NOT validated against any instrument's official scoring manual (KOOS-PS,
-- HOOS-PS, IKDC, QuickDASH, SPADI, ODI, Roland-Morris and FAAM each publish
-- their own algorithm, and some have special rules for missing items). Do
-- not trust a score this function produces for a clinical decision until
-- each instrument's real algorithm replaces the generic case below -- see
-- plan section 02.
create or replace function fn_score_response(p_response_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_response responses%rowtype;
begin
  select * into v_response from responses where id = p_response_id;

  insert into scores (response_id, subscale_code, value)
  select
    p_response_id,
    ii.subscale_code,
    (
      case when ii.reverse_scored
        then 1 - avg(fn_normalize_item(ii.response_type, ri.raw_value))
        else avg(fn_normalize_item(ii.response_type, ri.raw_value))
      end
    ) * (sub.max_value - sub.min_value) + sub.min_value
  from response_items ri
  join instrument_items ii
    on ii.instrument_code = v_response.instrument_code and ii.item_code = ri.item_code
  join instrument_subscales sub
    on sub.instrument_code = ii.instrument_code and sub.subscale_code = ii.subscale_code
  where ri.response_id = p_response_id
  group by ii.subscale_code, sub.min_value, sub.max_value, ii.reverse_scored
  on conflict (response_id, subscale_code) do update set value = excluded.value;
end;
$$;

create or replace function fn_normalize_item(p_response_type text, p_raw_value jsonb) returns numeric
language plpgsql immutable as $$
declare
  v_max numeric;
begin
  v_max := case p_response_type
    when 'likert7' then 6
    when 'likert6' then 5
    when 'likert5' then 4
    when 'likert4' then 3
    when 'likert3' then 2
    when 'nrs11' then 10
    when 'percent_slider' then 100
    when 'yes_no' then 1
    else 1
  end;
  return greatest(0, least(1, (p_raw_value #>> '{}')::numeric / v_max));
end;
$$;

-- ---------------------------------------------------------- worsening / dropout

-- Compares the new score against the best score this episode has reached
-- on the same subscale so far, in the direction that subscale calls
-- "better" -- never against a population norm. Fires only when the drop
-- exceeds the subscale's MDC95.
create or replace function fn_evaluate_worsening(p_response_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_response responses%rowtype;
  v_score record;
  v_best numeric;
  v_delta numeric;
begin
  select * into v_response from responses where id = p_response_id;

  for v_score in
    select s.subscale_code, s.value, sub.higher_is_better, sub.mdc95, sub.name
    from scores s
    join instrument_subscales sub
      on sub.instrument_code = v_response.instrument_code and sub.subscale_code = s.subscale_code
    where s.response_id = p_response_id
  loop
    if v_score.mdc95 is null then
      continue;
    end if;

    select case when v_score.higher_is_better then max(sc.value) else min(sc.value) end
      into v_best
      from scores sc
      join responses r on r.id = sc.response_id
      where r.episode_id = v_response.episode_id
        and sc.subscale_code = v_score.subscale_code
        and r.completed_at is not null
        and r.id != p_response_id;

    if v_best is null then
      continue;
    end if;

    v_delta := case when v_score.higher_is_better
      then v_best - v_score.value
      else v_score.value - v_best
    end;

    if v_delta > v_score.mdc95 then
      insert into alerts (episode_id, kind, severity, source_response_id, explanation, details)
      values (
        v_response.episode_id,
        'clinical_worsening',
        'warning',
        p_response_id,
        format('%s caiu de %s para %s (variação de %s; MDC95 = %s).',
               v_score.name, v_best, v_score.value, round(v_delta, 1), v_score.mdc95),
        jsonb_build_object(
          'subscale_code', v_score.subscale_code,
          'best_value', v_best,
          'new_value', v_score.value,
          'delta', v_delta,
          'mdc95', v_score.mdc95
        )
      );
    end if;
  end loop;
end;
$$;

-- 2 consecutive missed windows -> warning, 3+ -> critical. Only looks at
-- the tail of the schedule (most recent windows first) so an old missed
-- window followed by two completed ones doesn't count as a current streak.
-- Idempotent: won't open a second dropout_risk alert while one is already
-- open for the episode.
create or replace function fn_evaluate_dropout(p_episode_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_streak int := 0;
  v_row record;
  v_last_id uuid;
  v_severity text;
begin
  for v_row in
    select id, status
    from scheduled_assessments
    where episode_id = p_episode_id and status in ('missed', 'completed')
    order by window_close desc
  loop
    exit when v_row.status <> 'missed';
    v_streak := v_streak + 1;
  end loop;

  if v_streak < 2 then
    return;
  end if;

  v_severity := case when v_streak >= 3 then 'critical' else 'warning' end;

  select id into v_last_id
    from scheduled_assessments
    where episode_id = p_episode_id and status = 'missed'
    order by window_close desc limit 1;

  if exists (
    select 1 from alerts
    where episode_id = p_episode_id and kind = 'dropout_risk' and state = 'open'
  ) then
    return;
  end if;

  insert into alerts (episode_id, kind, severity, source_scheduled_assessment_id, explanation, details)
  values (
    p_episode_id,
    'dropout_risk',
    v_severity,
    v_last_id,
    format('%s janelas de avaliação consecutivas sem resposta.', v_streak),
    jsonb_build_object('consecutive_missed', v_streak)
  );
end;
$$;

-- ------------------------------------------------------------------ audit

-- ---------------------------------------------------------------- triggers

create or replace function fn_response_item_inserted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform fn_evaluate_red_flag(new.response_id, new.item_code, new.raw_value);
  return new;
end;
$$;

create trigger trg_response_items_red_flag
  after insert on response_items
  for each row execute function fn_response_item_inserted();

-- On completion: score the response, mark its scheduled_assessment
-- 'completed' (this is what stops fn_daily_tick from ever calling it
-- missed), then run the worsening check.
create or replace function fn_response_completed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.completed_at is not null and old.completed_at is null then
    perform fn_score_response(new.id);
    update scheduled_assessments set status = 'completed'
      where id = new.scheduled_assessment_id;
    perform fn_evaluate_worsening(new.id);
  end if;
  return new;
end;
$$;

create trigger trg_responses_completed
  after update on responses
  for each row execute function fn_response_completed();

create or replace function fn_write_audit(
  p_action text, p_resource_table text, p_resource_id text, p_metadata jsonb default '{}'::jsonb
) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_log (actor_id, actor_role, action, resource_table, resource_id, metadata)
  select auth.uid(), profiles.role, p_action, p_resource_table, p_resource_id, p_metadata
  from profiles where profiles.id = auth.uid();
end;
$$;
