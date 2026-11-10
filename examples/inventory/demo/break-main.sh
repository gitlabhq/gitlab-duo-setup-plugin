#!/usr/bin/env bash
# demo/break-main.sh — stage Scenario 3a: a failed default-branch pipeline.
#
# Opens an MR that renames the seed data constant in app/db.py but misses the
# one place it is used, so every test fails with a NameError. The MR pipeline
# fails too; merge it anyway (a Maintainer can, if "Pipelines must succeed" is
# off for the demo project). The main pipeline then fails and the Fix CI/CD
# Pipeline trigger opens a repair MR, titled [FixPipeline] and labeled
# pipeline::broken as AGENTS.md asks.
#
# This breaks a test rather than a dependency on purpose: Duo flows install
# dependencies from the default branch before they start (setup_script in
# .gitlab/duo/agent-config.yml), so a broken install would stop the repair
# flow too.
#
# Run from the repository root on a clean main.

set -euo pipefail

BRANCH="refactor/seed-rows"

git checkout -q main
git pull -q --ff-only
git checkout -q -b "$BRANCH"

python3 - <<'PY'
from pathlib import Path
p = Path("app/db.py")
s = p.read_text()
if "SEED_ITEMS = [" not in s:
    raise SystemExit("app/db.py does not define SEED_ITEMS; already staged?")
p.write_text(s.replace("SEED_ITEMS = [", "SEED_ROWS = [", 1))
PY

git add app/db.py
git commit -q -m "refactor(db): rename seed items to seed rows"

git push -q -u origin "$BRANCH" \
  -o merge_request.create \
  -o merge_request.title="refactor(db): rename seed items to seed rows" \
  -o merge_request.description="Rename for clarity. (Demo: misses one usage, so the main pipeline breaks once merged.)"

echo
echo "Pushed $BRANCH and opened the MR. Merge it to break main."
echo "Expected: main pipeline fails with NameError: SEED_ITEMS; Fix CI/CD Pipeline opens a"
echo "repair MR titled [FixPipeline] ... with label pipeline::broken, requiring the usual approvals."
