#!/usr/bin/env bash
# LOCAL DEV ONLY. Rebuilds the `elo` database from scratch (stub auth ->
# migrations -> seed -> grants) and runs the RLS/alert-engine proof.
set -euo pipefail
cd "$(dirname "$0")/../.."

sudo -u postgres psql -d elo -c "drop owned by authenticated;" >/dev/null 2>&1 || true
sudo -u postgres psql -d elo -c "drop role if exists authenticated;" >/dev/null 2>&1 || true
sudo -u postgres psql -d elo -v ON_ERROR_STOP=1 -c "drop schema if exists public cascade; create schema public;" >/dev/null
sudo -u postgres psql -d elo -v ON_ERROR_STOP=1 -c "drop schema if exists auth cascade;" >/dev/null

sudo -u postgres psql -d elo -v ON_ERROR_STOP=1 -f db/local-dev/auth_stub.sql
for f in supabase/migrations/*.sql; do
  sudo -u postgres psql -d elo -v ON_ERROR_STOP=1 -f "$f" >/dev/null
done
sudo -u postgres psql -d elo -v ON_ERROR_STOP=1 -f supabase/seed.sql >/dev/null
sudo -u postgres psql -d elo -v ON_ERROR_STOP=1 -f db/local-dev/grants.sql >/dev/null

echo "=== schema + seed applied cleanly, running proof ==="
sudo -u postgres psql -d elo -v ON_ERROR_STOP=1 -f db/local-dev/rls_test.sql
