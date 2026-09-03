-- Instrument catalog seed.
--
-- IMPORTANT -- read before shipping anything: item prompts for the eight
-- licensed/copyrighted PROMs below (KOOS-PS, HOOS-PS, IKDC, QuickDASH,
-- SPADI, ODI, Roland-Morris, FAAM) are PLACEHOLDERS, not the official
-- wording. Item counts, response-type shape and subscale splits match the
-- published instruments (public knowledge), but the exact question text is
-- each rights holder's property -- see license_note per instrument, and
-- plan section 02. Replace prompt_pt with the licensed text once each
-- license is confirmed. SANE, NRS pain and PGIC are single generic items
-- with no such restriction and carry real wording.
--
-- mdc95/mcid values are illustrative starting points drawn loosely from
-- published literature, not a substitute for validating them on this
-- app's own population during the pilot (plan section 04).

-- ------------------------------------------------------------- protocols

insert into protocols (code, body_region, name, description) values
  ('knee_acl_post_op', 'knee', 'Joelho — pós-operatório de LCA',
   'KOOS-PS/IKDC + SANE nos marcos principais; NRS + PGIC + SANE nas semanas intermediárias.'),
  ('hip_post_op', 'hip', 'Quadril — pós-operatório',
   'HOOS-PS + SANE nos marcos principais; NRS + PGIC + SANE nas semanas intermediárias.'),
  ('shoulder_conservative', 'shoulder', 'Ombro — tratamento conservador',
   'QuickDASH + SPADI + SANE nos marcos principais; NRS + PGIC + SANE nas semanas intermediárias.'),
  ('lumbar_conservative', 'lumbar_spine', 'Coluna lombar — tratamento conservador',
   'ODI + Roland-Morris + SANE nos marcos principais; NRS + PGIC + SANE nas semanas intermediárias.'),
  ('ankle_foot_post_injury', 'ankle_foot', 'Tornozelo/pé — pós-lesão',
   'FAAM + SANE nos marcos principais; NRS + PGIC + SANE nas semanas intermediárias.');

-- --------------------------------------------------------------- generic

insert into instruments (code, name, version, body_region, median_seconds, license_status, license_note) values
  ('sane', 'SANE — Single Assessment Numeric Evaluation', 1, 'generic', 10,
   'public_domain', 'Item único de autoria dos próprios pesquisadores em cada publicação; sem detentor de licença formal.'),
  ('nrs_pain', 'NRS — Escala Numérica de Dor (0–10)', 1, 'generic', 8,
   'public_domain', 'Domínio público, uso ubíquo em pesquisa clínica.'),
  ('pgic', 'PGIC — Impressão Global de Mudança do Paciente', 1, 'generic', 10,
   'public_domain', 'Âncora de mudança global amplamente publicada, sem detentor de licença formal.');

insert into instrument_subscales (instrument_code, subscale_code, name, min_value, max_value, higher_is_better, mdc95, mcid) values
  ('sane', 'total', 'SANE — % do normal', 0, 100, true, null, 10),
  ('nrs_pain', 'total', 'Dor (NRS)', 0, 10, false, 2, 2),
  ('pgic', 'total', 'Impressão global de mudança', 1, 7, true, null, null);

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code, red_flag_rule) values
  ('sane', 'q1', 1,
   'Em uma escala de 0% a 100%, sendo 100% o funcionamento normal, como você avalia o funcionamento da região tratada hoje?',
   'percent_slider', 'total', null),
  ('nrs_pain', 'q1', 1,
   'Em uma escala de 0 a 10, sendo 0 nenhuma dor e 10 a pior dor imaginável, qual é a sua dor na região tratada agora?',
   'nrs11', 'total', '{"operator": ">=", "value": 8}'::jsonb),
  ('pgic', 'q1', 1,
   'Comparando com o início do tratamento, como está a região tratada hoje? (1 = muito pior · 4 = sem mudança · 7 = muito melhor)',
   'likert7', 'total', null);

-- Two red-flag-only items, asked alongside the micro-battery -- not part of
-- any published PROM, but the safety net described in plan section 04.
insert into instruments (code, name, version, body_region, median_seconds, license_status, license_note) values
  ('safety_check', 'Checagem de sinais de alerta', 1, 'generic', 15,
   'public_domain', 'Itens de segurança de autoria do próprio protocolo Elo.');

insert into instrument_subscales (instrument_code, subscale_code, name, min_value, max_value, higher_is_better, mdc95, mcid) values
  ('safety_check', 'total', 'Sinais de alerta', 0, 1, true, null, null);

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code, red_flag_rule) values
  ('safety_check', 'night_pain', 1, 'Você teve dor nova que piora ou aparece à noite, atrapalhando o sono?', 'yes_no', 'total', '{"equals": "yes"}'::jsonb),
  ('safety_check', 'fever', 2, 'Você teve febre nos últimos dias?', 'yes_no', 'total', '{"equals": "yes"}'::jsonb),
  ('safety_check', 'neuro', 3, 'Você notou formigamento, dormência ou perda de força que é nova ou está piorando?', 'yes_no', 'total', '{"equals": "yes"}'::jsonb);

-- ------------------------------------------------------------------ knee

insert into instruments (code, name, version, body_region, median_seconds, license_status, license_note) values
  ('koos_ps', 'KOOS-PS — Knee injury and Osteoarthritis Outcome Score, Physical function Short form', 1, 'knee', 45,
   'free_with_registration', 'Grupo KOOS (koos.nu) solicita registro para uso de traduções oficiais; confirmar termos antes de embutir texto oficial.'),
  ('ikdc', 'IKDC — International Knee Documentation Committee Subjective Knee Form', 1, 'knee', 95,
   'free_clinical_use', 'Amplamente distribuído para uso clínico/pesquisa; confirmar termos de atribuição vigentes antes de embutir texto oficial.');

insert into instrument_subscales (instrument_code, subscale_code, name, min_value, max_value, higher_is_better, mdc95, mcid) values
  ('koos_ps', 'total', 'KOOS-PS — dificuldade funcional', 0, 100, false, 8, 6),
  ('ikdc', 'total', 'IKDC — função subjetiva do joelho', 0, 100, true, 11.5, 8);

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'koos_ps', 'q' || n, n,
  '[texto oficial licenciado — KOOS-PS item ' || n || '/7, confirmar com koos.nu antes de publicar]',
  'likert5', 'total'
from generate_series(1, 7) n;

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'ikdc', 'q' || n, n,
  '[texto oficial licenciado — IKDC Subjective Knee Form item ' || n || '/18, confirmar termos de atribuição antes de publicar]',
  'likert5', 'total'
from generate_series(1, 18) n;

-- -------------------------------------------------------------------- hip

insert into instruments (code, name, version, body_region, median_seconds, license_status, license_note) values
  ('hoos_ps', 'HOOS-PS — Hip disability and Osteoarthritis Outcome Score, Physical function Short form', 1, 'hip', 35,
   'free_with_registration', 'Grupo HOOS (hoos.nu) solicita registro para uso de traduções oficiais; confirmar termos antes de embutir texto oficial.');

insert into instrument_subscales (instrument_code, subscale_code, name, min_value, max_value, higher_is_better, mdc95, mcid) values
  ('hoos_ps', 'total', 'HOOS-PS — dificuldade funcional', 0, 100, false, 9, 6);

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'hoos_ps', 'q' || n, n,
  '[texto oficial licenciado — HOOS-PS item ' || n || '/5, confirmar com hoos.nu antes de publicar]',
  'likert5', 'total'
from generate_series(1, 5) n;

-- --------------------------------------------------------------- shoulder

insert into instruments (code, name, version, body_region, median_seconds, license_status, license_note) values
  ('quickdash', 'QuickDASH — Disabilities of the Arm, Shoulder and Hand (versão curta)', 1, 'shoulder', 55,
   'free_with_registration', 'Registro obrigatório via Institute for Work & Health antes de uso; confirmar termos antes de embutir texto oficial.'),
  ('spadi', 'SPADI — Shoulder Pain and Disability Index', 1, 'shoulder', 65,
   'public_domain', 'Publicado em domínio público (Roach et al., 1991); ainda assim, confirmar wording da tradução em PT-BR utilizada.');

insert into instrument_subscales (instrument_code, subscale_code, name, min_value, max_value, higher_is_better, mdc95, mcid) values
  ('quickdash', 'total', 'QuickDASH — incapacidade do braço/ombro/mão', 0, 100, false, 11, 8),
  ('spadi', 'pain', 'SPADI — dor', 0, 100, false, 18.9, 13),
  ('spadi', 'disability', 'SPADI — incapacidade', 0, 100, false, 13, 8),
  ('spadi', 'total', 'SPADI — total', 0, 100, false, 13, 8);

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'quickdash', 'q' || n, n,
  '[texto oficial licenciado — QuickDASH item ' || n || '/11, confirmar registro no IWH antes de publicar]',
  'likert5', 'total'
from generate_series(1, 11) n;

-- SPADI: 5 itens de dor + 8 itens de incapacidade (divisão publicada, não
-- protegida por direito autoral — apenas o texto exato de cada item é
-- placeholder).
insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'spadi', 'pain_q' || n, n,
  '[texto oficial — SPADI, subescala dor, item ' || n || '/5, confirmar tradução PT-BR antes de publicar]',
  'nrs11', 'pain'
from generate_series(1, 5) n;

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'spadi', 'disab_q' || n, n + 5,
  '[texto oficial — SPADI, subescala incapacidade, item ' || n || '/8, confirmar tradução PT-BR antes de publicar]',
  'nrs11', 'disability'
from generate_series(1, 8) n;

-- ---------------------------------------------------------- lumbar spine

insert into instruments (code, name, version, body_region, median_seconds, license_status, license_note) values
  ('odi', 'ODI — Oswestry Disability Index', 1, 'lumbar_spine', 60,
   'free_clinical_use', 'Livre para uso clínico/pesquisa com atribuição; confirmar versão PT-BR validada (Vigatto et al.) antes de publicar.'),
  ('roland_morris', 'Roland-Morris Disability Questionnaire', 1, 'lumbar_spine', 55,
   'free_clinical_use', 'Livre para uso clínico/pesquisa com atribuição; confirmar versão PT-BR validada antes de publicar.');

insert into instrument_subscales (instrument_code, subscale_code, name, min_value, max_value, higher_is_better, mdc95, mcid) values
  ('odi', 'total', 'ODI — incapacidade por dor lombar', 0, 100, false, 10, 10),
  ('roland_morris', 'total', 'Roland-Morris — incapacidade por dor lombar', 0, 24, false, 5, 4);

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'odi', 'q' || n, n,
  '[texto oficial — ODI seção ' || n || '/10, confirmar tradução PT-BR validada antes de publicar]',
  'likert6', 'total'
from generate_series(1, 10) n;

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'roland_morris', 'q' || n, n,
  '[texto oficial — Roland-Morris item ' || n || '/24, confirmar tradução PT-BR validada antes de publicar]',
  'yes_no', 'total'
from generate_series(1, 24) n;

-- ----------------------------------------------------------- ankle / foot

insert into instruments (code, name, version, body_region, median_seconds, license_status, license_note) values
  ('faam', 'FAAM — Foot and Ankle Ability Measure', 1, 'ankle_foot', 90,
   'free_clinical_use', 'Livre para uso clínico/pesquisa com atribuição (Martin et al.); confirmar versão PT-BR validada antes de publicar.');

insert into instrument_subscales (instrument_code, subscale_code, name, min_value, max_value, higher_is_better, mdc95, mcid) values
  ('faam', 'adl', 'FAAM — atividades de vida diária', 0, 100, true, 8, 6),
  ('faam', 'sports', 'FAAM — subescala esportiva', 0, 100, true, 12, 9);

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'faam', 'adl_q' || n, n,
  '[texto oficial — FAAM AVD item ' || n || '/21, confirmar tradução PT-BR validada antes de publicar]',
  'likert5', 'adl'
from generate_series(1, 21) n;

insert into instrument_items (instrument_code, item_code, order_index, prompt_pt, response_type, subscale_code)
select 'faam', 'sports_q' || n, n + 21,
  '[texto oficial — FAAM subescala esportiva, item ' || n || '/8, confirmar tradução PT-BR validada antes de publicar]',
  'likert5', 'sports'
from generate_series(1, 8) n;

-- ---------------------------------------------------------- protocol steps

-- Knee, ACL post-op -- the example worked through in plan section 03.
insert into protocol_steps (protocol_code, step_label, offset_days, window_before_days, window_after_days, instrument_code, order_index) values
  ('knee_acl_post_op', 'basal',    0,   0,  3, 'koos_ps', 1),
  ('knee_acl_post_op', 'basal_sane', 0, 0,  3, 'sane',    2),
  ('knee_acl_post_op', '2sem',    14,   3,  4, 'nrs_pain', 3),
  ('knee_acl_post_op', '2sem_pgic', 14, 3,  4, 'pgic',     4),
  ('knee_acl_post_op', '2sem_sane', 14, 3,  4, 'sane',     5),
  ('knee_acl_post_op', '6sem',    42,   3,  7, 'koos_ps', 6),
  ('knee_acl_post_op', '6sem_sane', 42, 3,  7, 'sane',    7),
  ('knee_acl_post_op', '3meses',  90,   7,  7, 'ikdc',    8),
  ('knee_acl_post_op', '3meses_sane', 90, 7, 7, 'sane',   9),
  ('knee_acl_post_op', '6meses', 180,   7,  7, 'ikdc',   10),
  ('knee_acl_post_op', '6meses_sane', 180, 7, 7, 'sane',  11),
  ('knee_acl_post_op', '9meses', 270,   7,  7, 'nrs_pain', 12),
  ('knee_acl_post_op', '9meses_pgic', 270, 7, 7, 'pgic',    13),
  ('knee_acl_post_op', '12meses', 365,  7,  7, 'ikdc',   14),
  ('knee_acl_post_op', '12meses_sane', 365, 7, 7, 'sane',  15);

insert into protocol_steps (protocol_code, step_label, offset_days, window_before_days, window_after_days, instrument_code, order_index) values
  ('hip_post_op', 'basal', 0, 0, 3, 'hoos_ps', 1),
  ('hip_post_op', 'basal_sane', 0, 0, 3, 'sane', 2),
  ('hip_post_op', '6sem', 42, 3, 7, 'hoos_ps', 3),
  ('hip_post_op', '6sem_sane', 42, 3, 7, 'sane', 4),
  ('hip_post_op', '3meses', 90, 7, 7, 'hoos_ps', 5),
  ('hip_post_op', '3meses_sane', 90, 7, 7, 'sane', 6),
  ('hip_post_op', '6meses', 180, 7, 7, 'hoos_ps', 7),
  ('hip_post_op', '6meses_sane', 180, 7, 7, 'sane', 8);

insert into protocol_steps (protocol_code, step_label, offset_days, window_before_days, window_after_days, instrument_code, order_index) values
  ('shoulder_conservative', 'basal', 0, 0, 3, 'quickdash', 1),
  ('shoulder_conservative', 'basal_spadi', 0, 0, 3, 'spadi', 2),
  ('shoulder_conservative', 'basal_sane', 0, 0, 3, 'sane', 3),
  ('shoulder_conservative', '4sem', 28, 3, 7, 'quickdash', 4),
  ('shoulder_conservative', '4sem_sane', 28, 3, 7, 'sane', 5),
  ('shoulder_conservative', '8sem', 56, 3, 7, 'quickdash', 6),
  ('shoulder_conservative', '8sem_spadi', 56, 3, 7, 'spadi', 7),
  ('shoulder_conservative', '8sem_sane', 56, 3, 7, 'sane', 8),
  ('shoulder_conservative', '12sem', 84, 7, 7, 'quickdash', 9),
  ('shoulder_conservative', '12sem_sane', 84, 7, 7, 'sane', 10);

insert into protocol_steps (protocol_code, step_label, offset_days, window_before_days, window_after_days, instrument_code, order_index) values
  ('lumbar_conservative', 'basal', 0, 0, 3, 'odi', 1),
  ('lumbar_conservative', 'basal_rm', 0, 0, 3, 'roland_morris', 2),
  ('lumbar_conservative', 'basal_sane', 0, 0, 3, 'sane', 3),
  ('lumbar_conservative', '4sem', 28, 3, 7, 'odi', 4),
  ('lumbar_conservative', '4sem_sane', 28, 3, 7, 'sane', 5),
  ('lumbar_conservative', '8sem', 56, 3, 7, 'odi', 6),
  ('lumbar_conservative', '8sem_rm', 56, 3, 7, 'roland_morris', 7),
  ('lumbar_conservative', '8sem_sane', 56, 3, 7, 'sane', 8),
  ('lumbar_conservative', '12sem', 84, 7, 7, 'odi', 9),
  ('lumbar_conservative', '12sem_sane', 84, 7, 7, 'sane', 10);

insert into protocol_steps (protocol_code, step_label, offset_days, window_before_days, window_after_days, instrument_code, order_index) values
  ('ankle_foot_post_injury', 'basal', 0, 0, 3, 'faam', 1),
  ('ankle_foot_post_injury', 'basal_sane', 0, 0, 3, 'sane', 2),
  ('ankle_foot_post_injury', '3sem', 21, 3, 4, 'nrs_pain', 3),
  ('ankle_foot_post_injury', '3sem_sane', 21, 3, 4, 'sane', 4),
  ('ankle_foot_post_injury', '6sem', 42, 3, 7, 'faam', 5),
  ('ankle_foot_post_injury', '6sem_sane', 42, 3, 7, 'sane', 6),
  ('ankle_foot_post_injury', '12sem', 84, 7, 7, 'faam', 7),
  ('ankle_foot_post_injury', '12sem_sane', 84, 7, 7, 'sane', 8);

-- The safety_check trio rides along on every intermediate (NRS/PGIC) step
-- across every protocol, so red flags are caught between milestones too --
-- not modeled as protocol_steps rows (safety_check has no fixed offset of
-- its own); the app triggers it whenever nrs_pain is scheduled. Documented
-- here rather than encoded, pending a decision on whether to promote it to
-- its own protocol_steps rows once the app layer exists.
