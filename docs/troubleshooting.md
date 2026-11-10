# Troubleshooting

Start with the readiness check. Ask your agent "Is this project on the
recommended configuration?" (the `gitlab-recommended-config` skill), or run
`bash setup/setup.sh check project <group/project>`. Most "it didn't run"
problems are a setting that is off, and the report names it.

## A flow didn't run

**Code Review didn't review my MR**

- Automatic reviews are off: Settings > Merge requests > GitLab Duo Code Review.
- Flow execution or foundational flows are off for the project, or Code Review
  isn't selected for the top-level group.
- The MR matches an exclusion in `.gitlab/duo/mr-review-automated-rules.yaml`
  (target branch `release/*`, or an author matching `duo-*` or `*-bot`). You
  can still request a review by hand.
- No follow-up review after a push: check "Start a new review on push" in the
  same settings section.

**Fix CI/CD Pipeline didn't run on a failed pipeline**

- There is no trigger. The flow starts from AI > Triggers (Pipeline events →
  Failed), not from a toggle. `setup.sh` prints the steps.
- Self-Managed: no runner with the `gitlab--duo` tag and a Docker-capable
  executor is online. See `docs/self-managed.md`.
- On the default branch, the flow opens a repair MR but push rules reject the
  `duo-*` service account. Allow it in Settings > Repository > Push rules.

**SAST false positive detection or vulnerability resolution didn't run**

- Both need Ultimate. On Premium, `setup.sh apply project` reports them as
  skipped. That's expected.
- They act on default-branch scans only, and only on Critical and High
  findings. To stage one, run `demo/seed-sast.sh` and merge the MR.
- Only one SAST run can be active per project at a time.
- If you scan with a security configuration profile, remove the SAST template
  include from `.gitlab-ci.yml`, or the jobs run twice.

## Connecting the client

| Symptom | Cause and fix |
|---|---|
| Two `GitLab` servers, duplicate tools | The committed project config and a user-level server or marketplace plugin both define `GitLab`. Remove one. |
| No `code_security` tools | The toolsets header isn't sent, or the group isn't on Ultimate. Check the header in your client's config (`docs/clients.md`). |
| No `duo_agent_platform` tools | The Agent Platform or MCP access is off for the top-level group: `setup.sh check group <group>`. |
| "Unverified application" warning, or registration fails | The client registered its own OAuth app (dynamic client registration), which is rate-limited per IP. Ask an admin to pre-register one (`docs/self-managed.md`). |
| `insufficient_scope` | A legacy personal access token. Use OAuth, or a fine-grained token with the MCP tool Execute permission. |
| Self-Managed: client connects to gitlab.com | The committed config points at gitlab.com. Set `GITLAB_MCP_URL` (Claude Code) or edit the URL (Codex, Cursor). |

## The agent

**The skill isn't used.** Claude Code reads `.claude/skills/`, Codex and Cursor
read `.agents/skills/`. Run `make check-skills`; if they differ, run
`make sync-skills`. Asking "What's the status of my MR?" should trigger
`gitlab-checks`.

**The report doesn't show a session that is clearly running.** Sessions started
automatically by a service account may not appear in `list_duo_sessions` for
your user. The skill falls back to MR system notes and Duo-authored MRs. Check
AI > Sessions in the project to confirm.

**"You don't have permission" when starting a flow.** Starting flows and
replying in threads needs at least the Developer role on the project.

## setup.sh

| Output | Meaning |
|---|---|
| A field shows `unknown` | The instance is older than the field, or your role can't read it. |
| `skipped: SAST ...` | The instance didn't accept the Ultimate-only settings. Expected below Ultimate. |
| `placeholder owner` for CODEOWNERS | Replace `@your-group/maintainers` in `.gitlab/CODEOWNERS`. |
| 403 on `apply group` | You need the Owner role on the top-level group. `apply project` needs Maintainer. |
