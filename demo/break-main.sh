#!/usr/bin/env bash
# demo/break-main.sh — stage Scenario 3a: a failed default-branch pipeline.
#
# Opens an MR that pins a Flask version that does not exist. When a human
# merges it (approvals and protected-branch rules still apply), the main
# pipeline fails at `pip install`, and the Fix CI/CD Pipeline trigger opens a
# repair MR. AGENTS.md tells the flow to pin the latest version that exists
# rather than remove the dependency, and to label the MR main::broken.
#
# Run from the repository root on a clean main.

set -euo pipefail

BRANCH="chore/bump-flask"

git checkout -q main
git pull -q --ff-only
git checkout -q -b "$BRANCH"

sed -i.bak 's/^flask==.*/flask==99.0.0/' requirements.txt && rm -f requirements.txt.bak

git add requirements.txt
git commit -q -m "chore(deps): bump flask"

git push -q -u origin "$BRANCH" \
  -o merge_request.create \
  -o merge_request.title="chore(deps): bump flask" \
  -o merge_request.description="Routine dependency bump. (Demo: this version does not exist and will break the main pipeline once merged.)"

echo
echo "Pushed $BRANCH and opened the MR. Merge it to break main."
echo "Expected: main pipeline fails on pip install; Fix CI/CD Pipeline opens a repair MR"
echo "titled [FixPipeline] ... with label main::broken, requiring the usual approvals."
