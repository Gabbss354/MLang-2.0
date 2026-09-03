-- Row Level Security: patient A must never be able to see patient B, and
-- this has to be enforced by the database, not by an `if` in application
-- code that someone forgets. Every table hanging off an episode reaches
-- episodes to find out who patient_id/clinician_id are; catalog tables
-- (instruments, protocols, ...) are non-sensitive reference data, readable
-- by any authenticated user.

create or replace function fn_is_patient_of(p_episode_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from episodes
    where id = p_episode_id and patient_id = auth.uid()
  );
$$;

create or replace function fn_is_clinician_of(p_episode_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from episodes
    where id = p_episode_id and clinician_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------- profiles

alter table profiles enable row level security;
alter table patients enable row level security;
alter table clinicians enable row level security;
alter table care_relationships enable row level security;

create policy profiles_self on profiles
  for select using (id = auth.uid());

create policy patients_self on patients
  for select using (id = auth.uid());

create policy patients_own_clinician on patients
  for select using (
    exists (
      select 1 from care_relationships cr
      where cr.patient_id = patients.id and cr.clinician_id = auth.uid()
    )
  );

create policy clinicians_self on clinicians
  for select using (id = auth.uid());

create policy clinicians_visible_to_own_patients on clinicians
  for select using (
    exists (
      select 1 from care_relationships cr
      where cr.clinician_id = clinicians.id and cr.patient_id = auth.uid()
    )
  );

create policy care_relationships_participant on care_relationships
  for select using (patient_id = auth.uid() or clinician_id = auth.uid());

-- ----------------------------------------------------------------- catalog

alter table body_regions enable row level security;
alter table instruments enable row level security;
alter table instrument_subscales enable row level security;
alter table instrument_items enable row level security;
alter table protocols enable row level security;
alter table protocol_steps enable row level security;

create policy catalog_read_body_regions on body_regions for select using (true);
create policy catalog_read_instruments on instruments for select using (true);
create policy catalog_read_subscales on instrument_subscales for select using (true);
create policy catalog_read_items on instrument_items for select using (true);
create policy catalog_read_protocols on protocols for select using (true);
create policy catalog_read_protocol_steps on protocol_steps for select using (true);

-- ---------------------------------------------------------------- episodes

alter table episodes enable row level security;
alter table scheduled_assessments enable row level security;
alter table responses enable row level security;
alter table response_items enable row level security;
alter table scores enable row level security;
alter table alerts enable row level security;

create policy episodes_owner on episodes
  for select using (patient_id = auth.uid() or clinician_id = auth.uid());

create policy episodes_patient_insert on episodes
  for insert with check (patient_id = auth.uid());

create policy episodes_clinician_insert on episodes
  for insert with check (clinician_id = auth.uid());

create policy scheduled_assessments_owner on scheduled_assessments
  for select using (fn_is_patient_of(episode_id) or fn_is_clinician_of(episode_id));

create policy responses_owner on responses
  for select using (fn_is_patient_of(episode_id) or fn_is_clinician_of(episode_id));

create policy responses_patient_insert on responses
  for insert with check (fn_is_patient_of(episode_id));

create policy responses_patient_update on responses
  for update using (fn_is_patient_of(episode_id));

create policy response_items_owner on response_items
  for select using (
    exists (
      select 1 from responses r
      where r.id = response_items.response_id
        and (fn_is_patient_of(r.episode_id) or fn_is_clinician_of(r.episode_id))
    )
  );

create policy response_items_patient_insert on response_items
  for insert with check (
    exists (
      select 1 from responses r
      where r.id = response_items.response_id and fn_is_patient_of(r.episode_id)
    )
  );

create policy scores_owner on scores
  for select using (
    exists (
      select 1 from responses r
      where r.id = scores.response_id
        and (fn_is_patient_of(r.episode_id) or fn_is_clinician_of(r.episode_id))
    )
  );

create policy alerts_owner on alerts
  for select using (fn_is_patient_of(episode_id) or fn_is_clinician_of(episode_id));

create policy alerts_clinician_update on alerts
  for update using (fn_is_clinician_of(episode_id));

-- ---------------------------------------------------------------- audit_log

alter table audit_log enable row level security;
-- Deliberately no select/insert policy for regular users: writes only
-- happen through fn_write_audit (security definer, next migration), reads
-- are an operator/service-role concern, not an app-user one.
