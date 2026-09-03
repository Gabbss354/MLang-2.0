-- Three alert kinds (see plan section 04):
--   red_flag           -- item-level, immediate, safety net
--   clinical_worsening -- score delta vs. best-so-far exceeds MDC95
--   dropout_risk       -- consecutive missed windows, no response involved
-- Every alert carries a plain-language explanation with the number that
-- triggered it -- an alert a clinician can't parse in one line is an alert
-- that gets muted.

create table alerts (
  id uuid primary key default gen_random_uuid(),
  episode_id uuid not null references episodes (id) on delete cascade,
  kind text not null check (kind in ('red_flag', 'clinical_worsening', 'dropout_risk')),
  severity text not null check (severity in ('critical', 'warning', 'info')),
  source_response_id uuid references responses (id),
  source_scheduled_assessment_id uuid references scheduled_assessments (id),
  explanation text not null,
  details jsonb not null default '{}'::jsonb,
  state text not null default 'open' check (state in ('open', 'acknowledged', 'resolved')),
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  acknowledged_by uuid references clinicians (id),
  resolved_at timestamptz,
  check (source_response_id is not null or source_scheduled_assessment_id is not null)
);

create index on alerts (episode_id, state);

-- Append-only. Who saw which patient's data, when -- required by LGPD
-- art. 11 and by CFM 2.314/2022's registro requirement, and cheap to add
-- now versus impossible to backfill after the fact.
create table audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid,
  actor_role text,
  action text not null,
  resource_table text not null,
  resource_id text,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create index on audit_log (actor_id, occurred_at);
create index on audit_log (resource_table, resource_id);

revoke update, delete on audit_log from public;
