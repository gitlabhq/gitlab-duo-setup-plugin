# Recommended GitLab configuration for agentic engineering — demo

Push from your coding agent and walk away. GitLab reviews the merge request,
repairs the broken pipeline, triages the SAST finding and opens the fix. Come
back, ask your agent what happened, and it picks up every finding without
re-running anything.

This repository is the working example: a small Flask app, the GitLab
configuration that makes the loop run, two skills that teach Claude Code, Codex
and Cursor to read the results, a setup script, and the demo scenarios.

```
developer ──push──▶ GitLab ──────────────────────────────▶ results on the MR
   ▲                 │ Code Review on every MR                    │
   │                 │ Fix CI/CD Pipeline on failure              │
   │                 │ SAST → false positive detection → fix MR   │
   └──── coding agent + gitlab-checks skill reads, acts, verifies ◀┘
```

## How the configuration is organized

**Step 1 — GitLab runs the checks (configure once per group and project)**

| When | Flow | Tier |
|---|---|---|
| Planning | Generate Workplan | Premium, Ultimate |
| An MR is created | Code Review (follow-up review on every push), Recommend Reviewers, Security Review | Code Review: Free (credits), Premium, Ultimate. Security Review: Ultimate |
| A pipeline fails | Fix CI/CD Pipeline, started by a trigger on pipeline failure | Free (credits), Premium, Ultimate |
| The default branch is scanned | SAST False Positive Detection, then Agentic Vulnerability Resolution | Ultimate |

Guardrails are unchanged: protected branches and required approvals apply to every
MR a flow opens.

**Step 2 — the developer's agent reads the results**

| Piece | Where |
|---|---|
| GitLab MCP server | `https://<host>/api/v4/mcp`; see `docs/clients.md` |
| Client MCP config | `.mcp.json` (Claude Code), `.codex/config.toml` (Codex), `.cursor/mcp.json` (Cursor) |
| Code owners | `.gitlab/CODEOWNERS`: Maintainer review for CI, Duo, agent and MCP config |
| `gitlab-checks` skill | `.agents/skills/gitlab-checks/` (copy in `.claude/skills/`) |
| `gitlab-recommended-config` skill | `.agents/skills/gitlab-recommended-config/` |
| Instructions | `AGENTS.md` (Codex, Cursor, GitLab Duo flows), `CLAUDE.md` (imports it) |
| Review guidance | `.gitlab/duo/mr-review-instructions.yaml` (Code Review Flow does not read AGENTS.md) |
| Flow runtime | `.gitlab/duo/agent-config.yml` |

## Quick start

**Admin (once).** Owner on the top-level group, Maintainer on the project.

```
glab auth login
bash setup/setup.sh check  group   <top-level-group>
bash setup/setup.sh apply  group   <top-level-group>
bash setup/setup.sh apply  project <group>/<project>
bash setup/setup.sh profiles       <top-level-group>          # Ultimate
bash setup/setup.sh attach <profile-gid> <group>/<project>    # Ultimate
```

The script prints the two things it does not automate yet (selecting the flows
for the group and creating the fix-pipeline trigger) with the exact settings
path. See "Status" below.

Before relying on `.gitlab/CODEOWNERS`, replace `@your-group/maintainers`
with a real group and turn on "Require approval from code owners" for `main`.
The MCP config files decide where agents send their GitLab OAuth token, so an
unreviewed change to them is a credential risk.

**Developer.** Clone and open Claude Code, Codex or Cursor. The GitLab MCP
server is already configured for the repository; approve OAuth on first use
(`docs/clients.md`, including Self-Managed). Then ask:

> Is this project on the recommended configuration?

> What's the status of my MR?

## Demo scenarios

| Scenario | Script | What you should see |
|---|---|---|
| 1. Push, then close the IDE | `demo/seed-mr.sh` | Code Review threads; pipeline fails on a seeded off-by-one; Fix CI/CD Pipeline posts a suggestion |
| 2. Return to the agent | ask "What's the status of my MR?" | One report; nothing re-run; fix, push, follow-up review, threads resolved |
| 3a. Main-branch repair | `demo/break-main.sh`, then merge it | Main fails; a `[FixPipeline]` MR opens, labeled `main::broken`, awaiting approval |
| 3b. SAST remediation | already on `main` (`app/routes.py`) | FP assessment on the SQL injection finding; a fix MR with a confidence score |

The full shot list for the video is in `demo/demo-script.md`.

## Status

| Item | State |
|---|---|
| Project-level settings via REST (`setup.sh apply project`) | Uses documented fields; run against a live instance to confirm |
| Group Duo/Agent Platform/MCP via REST (`setup.sh apply group`) | Uses documented fields; run to confirm |
| Security profiles list/attach via GraphQL | Uses documented mutation; run to confirm |
| Selecting the seven flows for the group | Manual for now; `aiCatalogItemConsumerCreate` is the documented mechanism, item ids to look up |
| Fix-pipeline trigger creation | Manual for now; `aiFlowTriggerCreate` is the documented mechanism, event-type code to confirm |
| `gitlab-checks` on Claude Code / Codex / Cursor | Not yet run; see `docs/validation-checklist.md` |
| Committed MCP config picked up per client | Not yet run; checklist C0, E9 |
| Open MCP questions (FP score field, Security Review output, automatic-session visibility) | Listed in the checklist, section E |

Nothing in this repository has been validated on a live GitLab instance yet.
Treat `docs/validation-checklist.md` as the first task.

## Development

```
pip install -r requirements.txt
make test
make sync-skills   # after editing anything under .agents/skills/
make check-skills  # what the skills-in-sync CI job runs
```

The SQL injection in `app/routes.py` is intentional. Do not fix it on `main`.

## License

MIT. See `LICENSE`.
