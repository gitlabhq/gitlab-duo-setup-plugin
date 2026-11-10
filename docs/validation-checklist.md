# Validation checklist

Run on a fresh clone of this repository in a GitLab.com Ultimate group (hero
path) and, separately, on a Self-Managed instance (setup pain shows there).
Record pass / partial / fail and open an issue for every gap.

## A. Configuration (admin)

| # | Check | Result |
|---|---|---|
| A1 | `setup/setup.sh check group <g>` reports Duo, Agent Platform, MCP on | |
| A2 | Seven flows selected for the group; `list_duo_agents_and_flows` on the project lists each with `can_start_session: true` | |
| A3 | `setup/setup.sh apply project <p>` sets all five project fields in one call | |
| A4 | Runner check passes in Settings > General > GitLab Duo (Self-Managed) | |
| A5 | Push rules allow `duo-*` service accounts to push | |
| A6 | Fix CI/CD Pipeline trigger on Pipeline events → Failed created | |
| A7 | Triage and Remediation profile attached via `setup.sh attach` | |
| A8 | Step count, by hand vs with the script, recorded | |

## B. Scenario 1 — push, then close the IDE

| # | Check | Result |
|---|---|---|
| B1 | `demo/seed-mr.sh` opens the MR and the pipeline starts | |
| B2 | Code Review session starts without any client connected | |
| B3 | Review threads appear on `app/reports.py` | |
| B4 | Pipeline fails on `tests/test_reports.py` | |
| B5 | Fix CI/CD Pipeline session starts from the trigger (not manually) | |
| B6 | Inline suggestion posted on the MR, changing `<` to `<=` | |
| B7 | Trigger does **not** fire on the flows' own workload pipelines | |

## C. Scenario 2 — return to the agent (repeat per client)

| # | Check | Claude Code | Codex | Cursor |
|---|---|---|---|---|
| C1 | Skill is discovered from the repo (`.agents/skills` or `.claude/skills`) | | | |
| C2 | "What's the status of my MR?" produces the report format | | | |
| C3 | Report lists running sessions and starts nothing | | | |
| C4 | Review threads, pipeline failure, Duo suggestion, SAST finding all present | | | |
| C5 | After approval, agent fixes, pushes, and does not request a review | | | |
| C6 | Follow-up review starts on push; skill waits using `poll_after_seconds` | | | |
| C7 | Threads replied to and resolved; pipeline green; stops at "waiting on approval" | | | |

## D. Scenario 3 — failure paths

| # | Check | Result |
|---|---|---|
| D1 | `demo/break-main.sh` merged → main pipeline fails → repair MR opens | |
| D2 | Repair MR follows AGENTS.md (title prefix, `main::broken` label, pins an existing version) | |
| D3 | Repair MR cannot merge without required approvals | |
| D4 | SAST finding on main gets an FP assessment | |
| D5 | Resolve SAST Vulnerability opens a fix MR with a confidence score | |
| D6 | Fix MR attributed to the vulnerability's author, needs approval | |
| D7 | Developer-role user completes the loop; Guest gets a clear error | |
| D8 | OAuth via pre-registered app works; legacy PAT is rejected with `insufficient_scope` | |

## E. MCP verification (open questions from the design)

| # | Question | Finding |
|---|---|---|
| E1 | Does `get_vulnerability` return the false-positive confidence score? | |
| E2 | Where does Security Review Flow write its findings (MR notes? report?) | |
| E3 | Can `list_duo_sessions` see sessions started automatically on behalf of another user? If not, how does the skill find the VR session? | |
| E4 | Does `get_work_item` return the Workplan widget? | |
| E5 | Does `start_duo_session` accept any `flow` value beyond `code_review/v1` and `fix_pipeline/v1`? | |
| E6 | Does the `filter` argument of `aiFlowTriggerCreate` accept a ref condition? | |
| E7 | What integer does `aiFlowTriggerCreate.eventTypes` use for `PIPELINE_HOOKS`? | |
| E8 | Does Claude Code expand `@AGENTS.md` in `CLAUDE.md` on the current version? | |

## Exit criteria

All of B and C pass on all three clients; every D and E row has a recorded
answer; every fail has an issue link.
