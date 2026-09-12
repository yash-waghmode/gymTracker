#!/usr/bin/env bash
set -euo pipefail

for command_name in initdb pg_ctl psql; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required PostgreSQL command: $command_name" >&2
    exit 1
  fi
done

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/gymtracker-db-test.XXXXXX)
data_dir="$test_root/data"
socket_dir="$test_root/socket"
server_started=false

cleanup() {
  if [[ "$server_started" == true ]]; then
    pg_ctl -D "$data_dir" stop --mode fast >/dev/null
  fi

  case "$test_root" in
    /tmp/gymtracker-db-test.*) rm -rf -- "$test_root" ;;
  esac
}
trap cleanup EXIT

mkdir "$socket_dir"
initdb -D "$data_dir" --auth=trust --encoding=UTF8 --no-locale >/dev/null
if ! pg_ctl -D "$data_dir" \
  -l "$test_root/postgres.log" \
  -o "-F -c listen_addresses='' -k $socket_dir" \
  start >/dev/null; then
  cat "$test_root/postgres.log" >&2
  exit 1
fi
server_started=true

psql -v ON_ERROR_STOP=1 -h "$socket_dir" -d postgres \
  -f "$project_dir/scripts/test-support/supabase-bootstrap.sql" >/dev/null
psql -v ON_ERROR_STOP=1 -h "$socket_dir" -d postgres \
  -f "$project_dir/supabase/migrations/20260912000100_core_training_schema.sql" >/dev/null
psql -v ON_ERROR_STOP=1 -h "$socket_dir" -d postgres \
  -f "$project_dir/supabase/tests/database/ownership.test.sql"
