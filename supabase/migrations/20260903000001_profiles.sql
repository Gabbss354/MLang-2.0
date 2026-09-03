-- Profiles, patients and clinicians.
-- On Supabase, auth.users already exists and auth.uid() is provided by the
-- platform. Locally (see db/local-dev/auth_stub.sql), we stub both so this
-- file runs unmodified in both environments.

create extension if not exists pgcrypto;

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('patient', 'clinician')),
  full_name text not null,
  created_at timestamptz not null default now()
);

create table patients (
  id uuid primary key references profiles (id) on delete cascade,
  birth_date date,
  phone text,
  created_at timestamptz not null default now()
);

create table clinicians (
  id uuid primary key references profiles (id) on delete cascade,
  council_type text check (council_type in ('crm', 'crefito')),
  council_number text,
  specialty text,
  created_at timestamptz not null default now()
);

-- Explicit patient <-> clinician care relationship. An episode always
-- belongs to one clinician, but this table lets a clinician see a patient's
-- episode list before the first episode exists (e.g. during onboarding),
-- and is the anchor for future multi-clinician sharing.
create table care_relationships (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients (id) on delete cascade,
  clinician_id uuid not null references clinicians (id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  unique (patient_id, clinician_id)
);
