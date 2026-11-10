# AGENTS.md

Instructions for coding agents working in this repository. This file is read by
Codex and Cursor directly, by Claude Code through `CLAUDE.md`, and by GitLab Duo
flows that run in GitLab (Fix CI/CD Pipeline, Developer, and others). Code
Review Flow does not read it; its guidance is in
`.gitlab/duo/mr-review-instructions.yaml`.

## What this project is

A small Flask inventory API used to demonstrate the recommended GitLab
configuration for agentic engineering. Code lives in `app/`, tests in `tests/`.

- Run tests: `pytest -q`
- Run the app: `flask --app app run`
- Dependencies: `requirements.txt` (pin exact versions)

## How work flows through GitLab

GitLab runs checks on every push whether or not an agent is connected:

1. Every merge request gets a GitLab Duo code review, and a follow-up review on
   each push that changes the diff.
2. A failed pipeline starts the Fix CI/CD Pipeline flow. On a merge request it
   posts inline suggestions; on the default branch it opens a repair MR.
3. A SAST scan on the default branch runs false positive detection and, for
   real Critical/High findings, opens a fix MR.

Before you report status, start any GitLab Duo work, or act on review feedback,
use the `gitlab-checks` skill. It checks what is already running so nothing is
reviewed or repaired twice.

## Working conventions

- Branch from `main`. Small, single-purpose merge requests.
- Conventional commits: `feat:`, `fix:`, `test:`, `ci:`, `docs:`.
- Open merge requests with `glab mr create --fill`, or push with
  `-o merge_request.create`. Do not merge; a human merges after approvals.
- Never resolve a GitLab Duo review thread without a code change or a reply
  that explains why the code is correct.
- Never interpolate user input into SQL. Use parameterized queries.
- Never commit secrets or `.db` files.

## Fix pipeline merge requests

When opening a merge request as part of the Fix Pipeline flow:

- If the pipeline failed on the default branch, title it `[FixPipeline] ...`
  and apply the label `main::broken`.
- Explain the root cause in one paragraph before the fix.
- If the failure is a dependency that cannot be installed, pin the most recent
  version that exists; do not remove the dependency.
- If the same failure has already been fixed once and failed again, post a
  comment describing what you found instead of attempting another fix.
