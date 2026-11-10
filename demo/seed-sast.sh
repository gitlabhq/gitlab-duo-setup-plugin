#!/usr/bin/env bash
# demo/seed-sast.sh — stage Scenario 3b: a SAST finding on the default branch.
#
# Opens an MR that rewrites the /items/search query to interpolate user input
# into SQL (CWE-89). Once a human merges it, the default-branch SAST scan
# reports a Critical/High finding, which starts SAST False Positive Detection
# and then Agentic Vulnerability Resolution (Ultimate). Code Review should
# also flag it on the MR; merge anyway, that is the demo.
#
# main stays safe until you run this, so forks and project templates made from
# this repository don't inherit a vulnerability. Run it only in a private demo
# copy, never in a project that serves real traffic. Revert or merge the fix MR
# afterwards.
#
# Run from the repository root on a clean main. Pushes and opens the MR.

set -euo pipefail

BRANCH="demo/seed-sast-finding"

git checkout -q main
git pull -q --ff-only
git checkout -q -b "$BRANCH"

python3 - <<'PY'
from pathlib import Path
p = Path("app/routes.py")
s = p.read_text()
safe = '''    rows = conn.execute(
        "SELECT id, name, qty, price FROM items WHERE name = ?", (name,)
    ).fetchall()'''
vulnerable = '''    query = f"SELECT id, name, qty, price FROM items WHERE name = '{name}'"
    rows = conn.execute(query).fetchall()'''
if safe not in s:
    raise SystemExit("app/routes.py does not contain the parameterized search query; already seeded?")
p.write_text(s.replace(safe, vulnerable))
PY

git add app/routes.py
git commit -q -m "refactor(items): build search query inline"

git push -q -u origin "$BRANCH" \
  -o merge_request.create \
  -o merge_request.title="refactor(items): build search query inline" \
  -o merge_request.description="Demo only: introduces a SQL injection in \`/items/search\` so the default-branch SAST scan starts false positive detection and vulnerability resolution. Do not merge outside a demo project."

echo
echo "Pushed $BRANCH and opened the MR. Merge it to put the finding on main."
echo "Expected: SAST reports SQL injection in app/routes.py; FP detection assesses it;"
echo "Resolve SAST Vulnerability opens a fix MR with a confidence score."
