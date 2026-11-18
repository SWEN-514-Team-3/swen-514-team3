#!/usr/bin/env bash
# Builds the Lambda packages:
#   build/db_init - db-init handler, the pg8000 database driver, schema.sql, seed.sql
#   build/api     - API handler and the pg8000 database driver
# Terraform zips that folder, so run this before terraform plan/apply/destroy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/build/db_init"

rm -rf "$OUT"
mkdir -p "$OUT"
python3 -m pip install --quiet --no-compile --target "$OUT" pg8000
# The API Lambda needs the same driver, so copy the folder before adding
# the db-init files.
API_OUT="$ROOT/build/api"
rm -rf "$API_OUT"
cp -r "$OUT" "$API_OUT"
cp "$ROOT/lambda/handler.py" "$API_OUT/"

cp "$ROOT/lambda/db_init/handler.py" "$ROOT/schema.sql" "$ROOT/seed.sql" "$OUT/"
echo "Built $OUT and $API_OUT"
