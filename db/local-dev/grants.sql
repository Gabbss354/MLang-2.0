-- LOCAL DEV ONLY. Mirrors the privilege split Supabase's `authenticated`
-- role gets automatically -- broad SELECT, narrow INSERT/UPDATE, and every
-- write that has clinical consequences (scores, alerts, scheduling status)
-- reachable only through the SECURITY DEFINER functions, never a direct
-- table write. This is what lets the RLS test below run as a real
-- low-privilege role instead of the postgres superuser, which bypasses RLS
-- entirely and would prove nothing.

create role authenticated nologin;
grant usage on schema public to authenticated;
grant select on all tables in schema public to authenticated;
grant insert on episodes, responses, response_items to authenticated;
grant update on responses to authenticated;
grant execute on all functions in schema public to authenticated;
