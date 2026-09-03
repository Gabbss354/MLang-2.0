-- Proves, end to end, against the real migrations + seed (not a mock):
--   1. patient A cannot see patient B's episodes/data, and vice versa
--   2. a clinician only sees their own patients' episodes
--   3. creating an episode materializes its full schedule automatically
--   4. red-flag, clinical-worsening and dropout-risk alerts all fire
--      correctly, including the higher_is_better direction handling
-- Run as: sudo -u postgres psql -d elo -v ON_ERROR_STOP=1 -f db/local-dev/rls_test.sql

\set ON_ERROR_STOP on
\pset tuples_only off

-- ---------------------------------------------------------------- fixtures
-- (account provisioning is out of RLS's scope in production too -- a
-- signup trigger or service-role call, not a patient inserting their own
-- profile row.)

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'paciente.a@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'paciente.b@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'dra.a@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'dr.b@example.com');

insert into profiles (id, role, full_name) values
  ('11111111-1111-1111-1111-111111111111', 'patient', 'Paciente A'),
  ('22222222-2222-2222-2222-222222222222', 'patient', 'Paciente B'),
  ('33333333-3333-3333-3333-333333333333', 'clinician', 'Dra. A'),
  ('44444444-4444-4444-4444-444444444444', 'clinician', 'Dr. B');

insert into patients (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222');

insert into clinicians (id, council_type, council_number, specialty) values
  ('33333333-3333-3333-3333-333333333333', 'crm', '111111-SP', 'Ortopedia'),
  ('44444444-4444-4444-4444-444444444444', 'crm', '222222-SP', 'Fisiatria');

-- Patient A is cared for by clinician A ONLY; patient B by clinician B
-- ONLY. This is the isolation the tests below try to break.
insert into care_relationships (patient_id, clinician_id) values
  ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333'),
  ('22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444');

set role authenticated;

-- ---------------------------------------------------- episode creation

-- Patient A: index date 50 days ago, so several windows have already
-- opened/closed by "today" -- exercises fn_daily_tick and lets a real
-- worsening comparison happen between two already-open windows.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into episodes (patient_id, clinician_id, body_region, laterality, index_date, protocol_code)
values ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
        'knee', 'right', current_date - 50, 'knee_acl_post_op')
returning id as episode_a \gset ep_
select 'episode_a=' || :'ep_episode_a' as info;

set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
\echo '--- check 1: episode creation materialized the full schedule ---'
select 'episode_a scheduled_assessments (expect 15)' as check, count(*) from scheduled_assessments where episode_id = :'ep_episode_a';

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
insert into episodes (patient_id, clinician_id, body_region, laterality, index_date, protocol_code)
values ('22222222-2222-2222-2222-222222222222', '44444444-4444-4444-4444-444444444444',
        'knee', 'left', current_date, 'knee_acl_post_op')
returning id as episode_b \gset ep_
select 'episode_b=' || :'ep_episode_b' as info;
select 'episode_b scheduled_assessments (expect 15)' as check, count(*) from scheduled_assessments where episode_id = :'ep_episode_b';

-- ------------------------------------------------------------ RLS checks

\echo '--- check 2: patient A sees only their own episode ---'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select 'patient A episodes visible (expect 1)' as check, count(*) from episodes;
select 'patient A can see episode B directly by id (expect 0)' as check, count(*) from episodes where id = :'ep_episode_b';
select 'patient A can see episode B scheduled_assessments (expect 0)' as check, count(*) from scheduled_assessments where episode_id = :'ep_episode_b';

\echo '--- check 3: patient B sees only their own episode ---'
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select 'patient B episodes visible (expect 1)' as check, count(*) from episodes;

\echo '--- check 4: clinician A sees only patient A ---'
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select 'clinician A episodes visible (expect 1)' as check, count(*) from episodes;
select 'clinician A can see patient B profile (expect 0)' as check, count(*) from patients where id = '22222222-2222-2222-2222-222222222222';

\echo '--- check 5: clinician B sees only patient B ---'
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select 'clinician B episodes visible (expect 1)' as check, count(*) from episodes;

-- ------------------------------------------------ scoring & alert engine

\echo '--- functional: patient A answers basal KOOS-PS, all items = 0 (best) ---'
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select id as sched_id from scheduled_assessments
  where episode_id = :'ep_episode_a' and step_label = 'basal' \gset basal_

insert into responses (scheduled_assessment_id, episode_id, instrument_code, instrument_version)
values (:'basal_sched_id', :'ep_episode_a', 'koos_ps', 1)
returning id as response_id \gset r1_

insert into response_items (response_id, item_code, raw_value)
select :'r1_response_id', 'q' || n, '0'::jsonb from generate_series(1, 7) n;

update responses set completed_at = now(), duration_seconds = 42 where id = :'r1_response_id';

select 'basal KOOS-PS score (expect 0, best possible)' as check, value from scores where response_id = :'r1_response_id';
select 'alerts after basal only (expect 0 -- nothing to compare against yet)' as check, count(*) from alerts where episode_id = :'ep_episode_a';

\echo '--- functional: 6-week KOOS-PS comes back much worse (raw=2 of 0-4) ---'
select id as sched_id from scheduled_assessments
  where episode_id = :'ep_episode_a' and step_label = '6sem' \gset w6_

insert into responses (scheduled_assessment_id, episode_id, instrument_code, instrument_version)
values (:'w6_sched_id', :'ep_episode_a', 'koos_ps', 1)
returning id as response_id \gset r2_

insert into response_items (response_id, item_code, raw_value)
select :'r2_response_id', 'q' || n, '2'::jsonb from generate_series(1, 7) n;

update responses set completed_at = now(), duration_seconds = 38 where id = :'r2_response_id';

select 'week-6 KOOS-PS score (expect 50 -- worse, since higher = more difficulty)' as check, value from scores where response_id = :'r2_response_id';
select 'clinical_worsening alert fired (expect 1)' as check, count(*) from alerts
  where episode_id = :'ep_episode_a' and kind = 'clinical_worsening';
select explanation from alerts where episode_id = :'ep_episode_a' and kind = 'clinical_worsening';

\echo '--- functional: 2-week NRS pain comes back at 9/10 -- red flag ---'
select id as sched_id from scheduled_assessments
  where episode_id = :'ep_episode_a' and step_label = '2sem' \gset nrs_

insert into responses (scheduled_assessment_id, episode_id, instrument_code, instrument_version)
values (:'nrs_sched_id', :'ep_episode_a', 'nrs_pain', 1)
returning id as response_id \gset r3_

insert into response_items (response_id, item_code, raw_value) values (:'r3_response_id', 'q1', '9'::jsonb);

select 'red_flag alert fired immediately, before completion (expect 1)' as check, count(*) from alerts
  where episode_id = :'ep_episode_a' and kind = 'red_flag';
select explanation from alerts where episode_id = :'ep_episode_a' and kind = 'red_flag';

\echo '--- clinician A can see all three alerts on their patient ---'
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select kind, severity, left(explanation, 60) as explanation from alerts where episode_id = :'ep_episode_a' order by created_at;

\echo '--- clinician B cannot see patient A alerts at all ---'
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select 'clinician B sees patient A alerts (expect 0)' as check, count(*) from alerts where episode_id = :'ep_episode_a';

-- ------------------------------------------------------------- dropout risk

\echo '--- functional: patient B misses 3 consecutive windows -> dropout_risk ---'
reset role;
update scheduled_assessments set status = 'missed'
  where episode_id = (select :'ep_episode_b'::uuid)
  and step_label in ('basal', 'basal_sane', '2sem');
select fn_evaluate_dropout(:'ep_episode_b'::uuid);

set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select 'dropout_risk alert for patient B (expect 1, severity critical)' as check, kind, severity, explanation
  from alerts where episode_id = :'ep_episode_b';

reset role;
\echo '--- fn_daily_tick runs cleanly against real dates (patient A, index -50d) ---'
select fn_daily_tick();
select status, count(*) from scheduled_assessments where episode_id = :'ep_episode_a' group by status order by status;

\echo '=== ALL CHECKS RAN -- read the "expect" lines above to confirm ==='
