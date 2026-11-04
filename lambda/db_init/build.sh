#!/usr/bin/env bash
# Builds the package for the db-init Lambda into build/db_init:
# its handler, the pg8000 database driver, and schema.sql / seed.sql.
# Terraform zips that folder, so run this before terraform plan/apply/destroy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/build/db_init"

rm -rf "$OUT"
mkdir -p "$OUT"
python3 -m pip install --quiet --no-compile --target "$OUT" pg8000
cp "$ROOT/lambda/db_init/handler.py" "$ROOT/schema.sql" "$ROOT/seed.sql" "$OUT/"
echo "Built $OUT"
