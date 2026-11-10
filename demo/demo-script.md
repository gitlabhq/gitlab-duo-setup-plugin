# Demo script: the recommended GitLab configuration for agentic engineering

Hero video with Claude Code, 6–7 minutes. Codex and Cursor cuts reuse scenes 1,
2, 5 and 8 and re-record 3, 4, 6, 7 in the other client.

**Environment:** GitLab.com, Ultimate group, hosted runners. The project is a
clone of this repository with `setup/setup.sh apply project` run and the group
flows selected. The demo user has the Developer role; a second account with
Maintainer merges in scene 7.

**Pre-staged before recording (do not record live):**

- The vulnerable `search_items` route has been on `main` long enough for the
  default-branch SAST scan, false positive detection, and vulnerability
  resolution to finish. Confirm the FP badge and the fix MR exist.
- `demo/break-main.sh` has been run and merged once, so a `[FixPipeline]`
  repair MR exists for the B-roll in scene 5. Revert or merge it afterwards so
  `main` is green again before scene 4.
- Flow durations noted, so you know how long each cut covers.

---

## Scene 1 — Cold open (0:00–0:30)

**Screen:** the loop diagram (docs/loop.png when ready), then a terminal with a
Claude Code session being closed.

**Say:** You push from your coding agent and close the laptop. Who reviews the
MR, who fixes the pipeline, who checks the security scan? With this
configuration, GitLab does, and your agent picks up the results when you come
back.

## Scene 2 — Configure once (0:30–1:30)

**Screen, in order, no typing:**

1. Group → Settings → GitLab Duo → Change configuration: the seven flows checked.
2. Project → Settings → General → GitLab Duo: Allow flow execution, Allow
   foundational flows, SAST toggles, runner check green, agent-config present.
3. Project → Settings → Merge requests: Enable automatic reviews, Start a new
   review on push.
4. Project → AI → Triggers: Fix CI/CD Pipeline on Pipeline events → Failed.
5. Group → Secure → Security inventory: Triage and Remediation profile applied.

**Say:** An admin does this once per group and once per project. Today it's
five screens; we've scripted it, and it's becoming one switch per use case.

## Scene 3 — Developer setup (1:30–2:00)

**Screen:** terminal.

```
claude mcp add -s user --transport http GitLab https://gitlab.com/api/v4/mcp \
  --header "X-Gitlab-Enabled-Mcp-Server-Toolsets: core,merge_requests,repository,ci,duo_agent_platform,code_security"
claude
/mcp        → select GitLab → browser → Authorize
```

Then `ls .agents/skills` and `cat AGENTS.md | head -20`.

**Say:** One MCP connection, OAuth in the browser, no tokens copied. The
repository carries the instructions and two skills, so Codex and Cursor get the
same behavior.

## Scene 4 — Build and push (2:00–3:00)

**Screen:** Claude Code.

**Type:**
> Add a `GET /reports/low-stock?threshold=N` endpoint that returns items at or
> below the threshold, default 5, with tests. Commit and open an MR.

If the agent writes a correct implementation, that's fine for the review half
but you lose the pipeline failure. The reliable take is `demo/seed-mr.sh`,
presented as the agent's work: run it, then show the MR it opened.

**Then:** quit Claude Code on camera.

**Say:** The MR is open, the pipeline is running. I'm done for the day.

## Scene 5 — GitLab works alone (3:00–4:15)

**Screen:** GitLab UI, cut between:

1. AI → Sessions: Code Review session running, then finished.
2. The MR: GitLab Duo review threads on `app/reports.py`.
3. Pipeline tab: `test` job failed. System note: Fix CI/CD Pipeline session started.
4. The MR: Duo's inline suggestion changing `<` to `<=`.
5. (B-roll) Secure → Vulnerability report: the SQL injection finding with its
   false positive assessment; the "Resolve SAST Vulnerability" MR with a
   confidence score; the MR shows approval rules still required.
6. (B-roll) The `[FixPipeline]` repair MR from the pre-staged main break,
   labeled `main::broken`, awaiting approval.

**Say:** Nobody asked for any of this. The review, the pipeline fix, the
security triage and the fix MR all ran because the project is configured for
it. And every MR a flow opens still needs the same approvals as a human's.

## Scene 6 — Come back (4:15–5:30)

**Screen:** Claude Code, fresh session in the repo.

**Type:**
> What's the status of my MR?

**Expected (the `gitlab-checks` skill):** one report: nothing running now; N
Duo review threads with file and line; pipeline failed on
`tests/test_reports.py` with Duo's suggestion; the SAST finding on `main` with
its FP assessment and fix MR; proposed next steps, ending in a question.

**Say:** It checked what was already running before suggesting anything. The
suggestions came from GitLab; the agent is reading them, not redoing them.

## Scene 7 — Fix and verify (5:30–6:30)

**Type:**
> Apply Duo's pipeline suggestion and address the review threads, then verify.

**Expected:** edits, tests pass locally, commit, push. The skill does not request
a review; it reports that a follow-up review started on push, waits, then
replies in and resolves the threads, confirms the pipeline is green, and stops
with "waiting on approval".

**Screen:** cut to GitLab: the MR with resolved threads and a green pipeline.
Second account approves and merges.

**Say:** Same agent, same workflow, and GitLab's verification happened in the
background both times.

## Scene 8 — Close (6:30–7:00)

**Screen:** the loop diagram.

**Say:** Configure it once. Keep your coding agent. Get GitLab's review,
pipeline repair, and security remediation as part of the normal loop. This is
the foundation; what comes next makes it a lot more integrated.

---

## Recording notes

- Record scene 5 as the flows actually run; cut the waits. Don't speed-ramp the
  Sessions page, it reads as fake.
- Keep the Duo approve/request-changes beta out of the frame unless the flag is
  confirmed on for the group.
- Confirm before the first take that the pipeline-failed trigger does not fire
  on the flows' own workload pipelines; if it does, the Sessions page will show
  a second repair session and scene 5 needs re-staging.
- Use a fresh Claude Code session for scene 6 so the skill, not memory of
  scene 4, drives the report.
