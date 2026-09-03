-- Responses are versioned against the instrument at time of answering --
-- instrument_version is a snapshot, not a live foreign key -- so a later
-- edit to the instrument definition never silently reinterprets a past
-- answer. That snapshot is also what a research export needs to be
-- defensible.

create table responses (
  id uuid primary key default gen_random_uuid(),
  scheduled_assessment_id uuid not null unique references scheduled_assessments (id),
  episode_id uuid not null references episodes (id) on delete cascade,
  instrument_code text not null references instruments (code),
  instrument_version int not null,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  duration_seconds int,
  source text not null default 'app' check (source in ('app', 'web'))
);

create index on responses (episode_id);

create table response_items (
  id uuid primary key default gen_random_uuid(),
  response_id uuid not null references responses (id) on delete cascade,
  item_code text not null,
  -- jsonb, not numeric: a likert choice, a percent slider value, or a
  -- yes/no all fit without a column per response type.
  raw_value jsonb not null,
  answered_at timestamptz not null default now(),
  unique (response_id, item_code)
);

-- One row per subscale per response. value is on the subscale's native
-- scale (see instrument_subscales.min_value/max_value); the scoring
-- function that fills this table is a placeholder (fn_score_response, next
-- migration) pending each instrument's official scoring manual -- see plan
-- section 02 and the license_note on each instrument.
create table scores (
  id uuid primary key default gen_random_uuid(),
  response_id uuid not null references responses (id) on delete cascade,
  subscale_code text not null,
  value numeric not null,
  created_at timestamptz not null default now(),
  unique (response_id, subscale_code)
);

create index on scores (response_id);
