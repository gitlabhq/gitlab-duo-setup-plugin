# GitLab Duo setup skill

An Agent Skill for Claude Code, Codex, Cursor, Devin and OpenCode users. Load
it, ask your agent to "set up GitLab Duo", and it sets up GitLab for
agentic engineering:

1. **Turns on Code Review and Fix CI/CD Pipeline for your group.** Every new
   merge request gets a Duo review, and every failed pipeline gets a fix,
   whichever agent or tool the change came from.
2. **Creates the automation that runs Fix CI/CD Pipeline on failed
   pipelines**, in every project of the group.
3. **Connects your agent to the GitLab MCP server**
   (`https://<host>/api/v4/mcp`) and walks you through signing in with OAuth,
   so your agent can read what the flows found and act on it.

On Ultimate, once that works, it asks one more question: whether to add
security triage and remediation (SAST false positive detection and agentic
vulnerability resolution, with SAST turned on where projects don't scan yet).
If that step fails, the core setup stays as it is.

It shows the full plan, with what each flow costs, and asks before changing
anything. Run it again any time: it skips what's already set up.

It works on GitLab.com, Self-Managed and Dedicated.

## Who can run it

- **Owner of the top-level group**: sets up the whole group and every
  project in it. This is the recommended path.
- **Maintainer of a project**: sets up that project, and tells you what to ask
  your group Owner to turn on.

## Requirements

- `git` and [`glab`](https://gitlab.com/gitlab-org/cli#installation),
  signed in: `glab auth login`
- GitLab Premium or Ultimate, or Free with GitLab Credits, for Duo Agent
  Platform. The security flows need Ultimate.
- Credits: the skill itself spends none. The flows it turns on do, and when an
  automation or a service account starts a flow, the credits are billed to your
  top-level namespace.

## Install

Copy `skills/gitlab-duo-setup/` into your harness's skills directory:

| Harness | User-level | Project-level |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex | `~/.agents/skills/` | `.agents/skills/` |
| Cursor | `~/.cursor/skills/` | `.agents/skills/` |
| Devin | `~/.config/devin/skills/` | `.devin/skills/` |
| OpenCode | `~/.config/opencode/skills/` | `.opencode/skills/` |

```bash
git clone https://gitlab.com/gitlab-da/projects/agentic-eng-config.git
cp -R agentic-eng-config/skills/gitlab-duo-setup ~/.claude/skills/
```

Then reload your harness so it sees the new skill:

| Harness | Reload |
|---|---|
| Claude Code | Picks it up in the running session. If it isn't listed, restart Claude Code. |
| Codex | Restart Codex. A running session doesn't see newly installed skills. |
| Cursor | Picks it up in the running session. If it isn't listed, restart Cursor. |
| Devin | Picks it up without a restart. Check with `devin skills list`. |
| OpenCode | Picks it up in the running session. If it isn't listed, restart OpenCode. |

Some harnesses read other harnesses' skill directories. Devin and OpenCode
both also read `~/.claude/skills/` (Claude Code) and `~/.agents/skills/`
(Codex). If you use more than one, install the skill in one shared place, so
it isn't listed twice.

## Run the skill

| Harness | Syntax |
| --- | --- |
| Claude Code | `/gitlab-duo-setup` |
| Codex | `$gitlab-duo-setup` |
| Cursor | `/gitlab-duo-setup` |
| Devin | `@skills:gitlab-duo-setup` |
| OpenCode | `@gitlab-duo-setup` |

## What is not automated yet

No API covers these, so the skill gives you a direct link for each:

- The group's MCP client access setting (Allow connection to GitLab). The
  skill can't read it, but a successful MCP sign-in shows it's on.
- Runners, for projects with none that can run flows. The skill lists those
  projects and doesn't turn on hosted runners without asking.
- The Allow foundational flows toggle on a project that turned it off on its
  own. The skill lists those projects.
- Self-Managed: connecting the instance to an AI gateway.
- Push rules, if a project has them: allowing the `duo-*` service accounts.
- The OAuth sign-in itself, which happens in your browser.

## What has been tested

Tested on GitLab.com: the GraphQL reads for flows, runners and automations,
and creating the Fix CI/CD Pipeline automation in one project.

Checked against GitLab's source (19.6) but not yet run against a live group:

- The single group request that turns on flow execution, foundational flows,
  the flows themselves, and automatic Code Review.
- Waiting for GitLab to provision each project, and creating the automation
  across many projects.
- Applying security profiles to a group.

GitLab marks the automation mutation and the security profile mutations as
Experiment, so they can change between releases. If one fails, the skill
quotes the error and gives you the link to do it by hand.

## Layout

```
skills/gitlab-duo-setup/
  SKILL.md                  the skill
  references/harnesses.md   MCP config and sign-in per harness
  references/graphql.md     queries and mutations for flows, runners and automations
  references/security.md    optional security step (Ultimate)
```
