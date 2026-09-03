-- LOCAL DEV ONLY. Never run against a real Supabase project -- it already
-- provides auth.users and auth.uid(); this stub exists so the exact same
-- migrations in supabase/migrations/ can be validated against a plain
-- local Postgres. auth.uid() here reads the same GUC
-- (request.jwt.claim.sub) Supabase's implementation reads, so RLS behaves
-- identically in both places.

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
