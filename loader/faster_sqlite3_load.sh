#!/usr/bin/env bash
# SQLite3 PRAGMA instructions for an hopefully faster load

set -euo pipefail

db="${1}"
dump="${2}"
sqlite3 "${db}" < ../sql/create_schema.sql
sqlite3 "${db}" < <(cat ./faster_sqlite3_load_pragma.sql "${dump}")

