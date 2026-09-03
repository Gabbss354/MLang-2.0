-- The central entity is the episode of care (patient + region + side +
-- index date), not the patient -- the same patient can run a knee episode
-- and a lumbar-spine episode at once, each on its own protocol and clock.

create table episodes (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients (id) on delete cascade,
  clinician_id uuid not null references clinicians (id),
  body_region text not null references body_regions (code),
  laterality text not null check (laterality in ('left', 'right', 'bilateral', 'not_applicable')),
  index_date date not null,
  protocol_code text not null references protocols (code),
  status text not null default 'active' check (status in ('active', 'completed', 'discontinued')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index on episodes (patient_id);
create index on episodes (clinician_id);

-- One row per assessment the protocol says should happen. Materialized up
-- front when the episode is created (see fn_materialize_schedule), so a
-- missed assessment is a row with status='missed', not an absence the
-- system has to infer. This is what makes patient dropout detectable server
-- side instead of only patient-reported.
create table scheduled_assessments (
  id uuid primary key default gen_random_uuid(),
  episode_id uuid not null references episodes (id) on delete cascade,
  protocol_step_id uuid not null references protocol_steps (id),
  instrument_code text not null references instruments (code),
  step_label text not null,
  window_open date not null,
  window_close date not null,
  status text not null default 'pending' check (
    status in ('pending', 'notified', 'completed', 'missed', 'skipped')
  ),
  notified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (episode_id, protocol_step_id)
);

create index on scheduled_assessments (episode_id);
create index on scheduled_assessments (status, window_close);

create or replace function fn_touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_episodes_touch
  before update on episodes
  for each row execute function fn_touch_updated_at();
