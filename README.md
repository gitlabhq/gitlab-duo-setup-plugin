# Agentic Engineering Configuration

Push from your coding agent and walk away. GitLab reviews the merge request,
repairs the broken pipeline, triages the SAST finding and opens the fix. Come
back, ask your agent what happened, and it picks up every finding without
re-running anything.

This kit sets that up in your own groups and projects, for developers using
Claude Code, Codex or Cursor:

- **`setup.sh`** turns on the GitLab Duo Agent Platform settings for a group and
  its projects, installs the configuration files into a repository, and
  connects and checks developers' clients.
- **Two skills** (`gitlab-checks`, `gitlab-recommended-config`) teach the
  coding agent to read what GitLab did, act on it, and explain why a flow
  didn't run.
- **Templates** for `AGENTS.md`, GitLab Duo review instructions and flow
  configuration, CODEOWNERS, and MCP config for each client.

```
developer ──push──▶ GitLab ──────────────────────────────▶ results on the MR
   ▲                 │ Code Review on every MR                    │
   │                 │ Fix CI/CD Pipeline on failure              │
   │                 │ SAST → false positive detection → fix MR   │
   └──── coding agent + gitlab-checks skill reads, acts, verifies ◀┘
```

> **Support status.** This kit is provided as-is, without an SLA, and is not
> covered by GitLab Support. Issues and merge requests are welcome. GitLab Duo
> and the features it configures are supported as usual.

## What you get on each tier

| When | Flow | Tier |
|---|---|---|
| An MR is created | Code Review (follow-up review on every push), Recommend Reviewers, Security Review | Code Review: Free (with GitLab Credits), Premium, Ultimate. Security Review: Ultimate |
| A pipeline fails | Fix CI/CD Pipeline: suggestions on an MR, a repair MR on the default branch | Free (with GitLab Credits), Premium, Ultimate |
| The default branch is scanned | SAST False Positive Detection, then Resolve SAST Vulnerability | Ultimate |
| Planning | Generate Workplan | Premium, Ultimate |

Flows use GitLab Credits. Each review, follow-up review and pipeline repair is a
flow run. To reduce volume, exclude merge requests in
`.gitlab/duo/mr-review-automated-rules.yaml`.

Protected branches and required approvals apply to every MR a flow opens.

Requires GitLab with the Duo Agent Platform available; the kit is written
against GitLab 19.6. On older versions, `setup.sh` reports settings it can't
find as "not available" and skips them. Self-Managed and Dedicated need a few
extra steps: `docs/self-managed.md`.

## Quick start

In your project's repository, paste into a terminal:

```
curl -fsSL https://gitlab.com/gitlab-da/projects/agentic-eng-config/-/raw/main/install.sh | bash -s -- init --owners @<group>/<maintainers>
```

Or paste into Claude Code, Codex or Cursor:

> Set up this repository for the GitLab Duo Agent Platform: ask me which group should own agent and CI config, run `curl -fsSL https://gitlab.com/gitlab-da/projects/agentic-eng-config/-/raw/main/install.sh | bash -s -- init --dry-run --owners <that group>`, explain the plan, then run it without `--dry-run` and summarize `git diff`.

Then review and commit the files (section 2), and open your agent to approve
the GitLab sign-in (section 3). Group and project settings are a separate,
admin step (section 1).

`install.sh` puts the kit in `~/.agentic-eng-config`, updates it on every run,
and passes its arguments to `setup.sh`. Read it first if you prefer: it is 40
lines. Without arguments it only installs or updates the kit.

Requirements: `bash`, `git`, `glab` (`glab auth login`), `jq`, and `curl`. On
Windows, use WSL or Git Bash.

## 1. Admin: turn it on for a group (once)

Owner of the top-level group, Maintainer of the projects.

```
curl -fsSL https://gitlab.com/gitlab-da/projects/agentic-eng-config/-/raw/main/install.sh | bash
KIT=~/.agentic-eng-config/setup/setup.sh

$KIT check group <top-level-group>
$KIT apply group <top-level-group> --dry-run    # shows what would change
$KIT apply group <top-level-group>              # asks before changing anything

$KIT apply all-projects <top-level-group> --dry-run
$KIT apply all-projects <top-level-group>       # or: apply project <group/project>
```

`apply` saves the previous values to `setup-backup-<time>.json`;
`$KIT restore <file>` puts them back. It also creates the `pipeline::broken`
label that repair MRs use.

Two steps are not automated yet; `apply` prints both with the settings path:

1. Select the foundational flows for the group (Settings > GitLab Duo).
2. Create the Fix CI/CD Pipeline trigger in each project (AI > Triggers).

On Ultimate, attach the Triage and Remediation scan profile:
`$KIT profiles <group>`, then `$KIT attach <profile-gid> <group/project>`.

## 2. Each project: install the files (once, then on updates)

Run in the project's repository, then review and commit:

```
cd <your-project>
$KIT init --owners @<group>/<maintainers> --dry-run
$KIT init --owners @<group>/<maintainers>
git status && git diff
```

| File | What it is | If it already exists |
|---|---|---|
| `AGENTS.md` | How work flows through GitLab, and rules for fix MRs | The GitLab section is added between markers; the rest is yours |
| `CLAUDE.md` | Imports `AGENTS.md` for Claude Code | Left alone; init tells you to add `@AGENTS.md` |
| `.gitlab/duo/agent-config.yml` | Dependency setup for flows, detected from your repo | Kept |
| `.gitlab/duo/mr-review-instructions.yaml` | Guidance for Duo Code Review | Kept |
| `.gitlab/duo/mr-review-automated-rules.yaml` | MRs automatic review skips | Kept |
| `CODEOWNERS` | Maintainer review for CI, Duo, agent and MCP config | A section is added between markers |
| `.mcp.json`, `.cursor/mcp.json`, `.codex/config.toml` | GitLab MCP server for Claude Code, Cursor, Codex, on your host | GitLab server added; other servers kept |
| `.agents/skills/`, `.claude/skills/` | The two skills | Updated when the kit's version is newer; local edits kept |

Then turn on "Require approval from code owners" for the default branch. The
MCP config decides where agents send their GitLab OAuth token, so changes to it
should be reviewed. Details and customization: `docs/customizing.md`.

## 3. Developers: connect (once per machine)

In a project that has run `init`, open Claude Code, Codex or Cursor and approve
the GitLab sign-in. That's it. To check everything:

```
$KIT doctor
```

For projects without the committed config, `$KIT connect` adds the GitLab
server to your user-level config for each installed client. Per-client detail:
`docs/clients.md`.

Then ask your agent:

> What's the status of my MR?

> Is this project on the recommended configuration?

## Docs

| | |
|---|---|
| `docs/clients.md` | Connecting Claude Code, Codex and Cursor |
| `docs/customizing.md` | What `init` installs, managed sections, updating the kit |
| `docs/self-managed.md` | Self-Managed and Dedicated |
| `docs/troubleshooting.md` | When a flow doesn't run, or the client won't connect |
| `examples/inventory/` | A small Flask app to try the whole loop in a demo project |
| `SECURITY.md` | Reporting issues, and what to protect |
| `CHANGELOG.md` | Changes by version |

## License

MIT. See `LICENSE`.
