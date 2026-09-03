-- Instrument catalog. An instrument is data, not code: adding a PROM is an
-- insert here, never a store release. Each instrument has 1+ subscales, and
-- direction (higher_is_better) lives on the SUBSCALE, not the instrument --
-- e.g. SPADI carries pain/disability/total subscales that all point the
-- same way, but KOOS-PS and IKDC point opposite ways despite both scoring
-- the knee 0-100.

create table body_regions (
  code text primary key,
  label_pt text not null
);

insert into body_regions (code, label_pt) values
  ('knee', 'Joelho'),
  ('hip', 'Quadril'),
  ('shoulder', 'Ombro'),
  ('lumbar_spine', 'Coluna lombar'),
  ('ankle_foot', 'Tornozelo e pé'),
  ('generic', 'Genérico (qualquer região)');

create table instruments (
  code text primary key,
  name text not null,
  version int not null default 1,
  body_region text not null references body_regions (code),
  median_seconds int not null,
  license_status text not null check (
    license_status in ('public_domain', 'free_clinical_use', 'free_with_registration', 'paid')
  ),
  license_note text,
  created_at timestamptz not null default now()
);

create table instrument_subscales (
  id uuid primary key default gen_random_uuid(),
  instrument_code text not null references instruments (code) on delete cascade,
  subscale_code text not null,
  name text not null,
  min_value numeric not null,
  max_value numeric not null,
  -- true  = a rising score means the patient is doing better (IKDC, FAAM, SANE, PGIC)
  -- false = a rising score means the patient is doing worse (KOOS-PS, HOOS-PS,
  --         QuickDASH, SPADI, ODI, Roland-Morris, NRS pain)
  -- This is read by the alert engine on every comparison -- get it wrong and
  -- "improving" patients trigger worsening alerts.
  higher_is_better boolean not null,
  mdc95 numeric,
  mcid numeric,
  unique (instrument_code, subscale_code)
);

create table instrument_items (
  id uuid primary key default gen_random_uuid(),
  instrument_code text not null references instruments (code) on delete cascade,
  item_code text not null,
  order_index int not null,
  -- Official licensed wording is NOT reproduced here -- see license_status
  -- and license_note on the parent instrument. This placeholder keeps the
  -- engine fully wired and testable; swap the text in once each license is
  -- confirmed with its rights holder (see plan, section 02).
  prompt_pt text not null,
  response_type text not null check (
    response_type in (
      'likert3', 'likert4', 'likert5', 'likert6', 'likert7', 'nrs11', 'percent_slider', 'yes_no'
    )
  ),
  options jsonb,
  subscale_code text not null,
  reverse_scored boolean not null default false,
  -- Null for ordinary items. When set, the daily/response-time alert pass
  -- checks this item's raw_value against the rule and fires a red_flag
  -- alert immediately, without waiting on a computed subscale score --
  -- e.g. {"operator": ">=", "value": 8} for "NRS pain >= 8".
  red_flag_rule jsonb,
  unique (instrument_code, item_code),
  foreign key (instrument_code, subscale_code)
    references instrument_subscales (instrument_code, subscale_code)
);

create index on instrument_items (instrument_code, order_index);

-- A protocol is a named, versioned schedule for one body region --
-- "what to ask, and when" -- kept as data so a new schedule is an insert,
-- never a redeploy.
create table protocols (
  code text primary key,
  body_region text not null references body_regions (code),
  name text not null,
  description text
);

create table protocol_steps (
  id uuid primary key default gen_random_uuid(),
  protocol_code text not null references protocols (code) on delete cascade,
  step_label text not null,
  offset_days int not null,
  window_before_days int not null default 3,
  window_after_days int not null default 7,
  instrument_code text not null references instruments (code),
  order_index int not null,
  unique (protocol_code, step_label)
);

create index on protocol_steps (protocol_code, order_index);
