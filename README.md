# GitLab Duo setup skill

An Agent Skill for Claude Code, Codex, Cursor, Devin and OpenCode users. Load it, ask your agent
to "set up GitLab Duo", and it does two things:

1. **Turns on GitLab Duo Agent Platform** for the current project and its
   top-level group, using `glab api` (REST and GraphQL): the Duo settings, the
   Developer, Code Review and Fix CI/CD Pipeline flows, and an automation that
   runs Fix CI/CD Pipeline on failed pipelines. It shows what it will change
   and asks before changing anything.
2. **Connects your agent to the GitLab MCP server** (`https://<host>/api/v4/mcp`)
   and walks you through signing in with OAuth.

It works on GitLab.com, Self-Managed and Dedicated.

## Requirements

- `git` and [`glab`](https://gitlab.com/gitlab-org/cli#installation),
  signed in: `glab auth login`
- Maintainer on the project to change project settings; Owner on the top-level
  group to change group settings. With less access, the skill tells you who to ask.
- GitLab Premium or Ultimate, or Free with GitLab Credits, for Duo Agent
  Platform.
- Credits: the skill itself spends none. The flows it turns on do, and when an
  automation starts a flow, the credits are billed to your top-level namespace.

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
(Codex). If you use more than one, install the
skill in one shared place, so it isn't listed twice.

## Run the skill

Once you have the skill installed in your harness, invoke using the syntax that your harness requires. For example, for Claude and Cursor use the `/gitlab-duo-setup` slash command.

| Harness | Syntax| 
| --- | --- | 
| Claude Code | `/gitlab-duo-setup` | 
| Codex | `$gitlab-duo-setup` | 
| Cursor | `/gitlab-duo-setup` | 
| Devin | `@skills:gitlab-duo-setup` | 
| OpenCode | `@gitlab-duo-setup` |

## What is not automated yet

No API covers these, so the skill gives you a direct link to the right page
for each:

- The group's MCP client access setting (Allow connection to GitLab). The
  skill can't read it, but a successful MCP sign-in shows it's on.
- Runners, if the project has none that can run flows: turning on hosted
  runners, or a runner tagged `gitlab--duo`. The skill checks this through
  GraphQL and only asks when it's needed.
- Self-Managed: connecting the instance to an AI gateway.
- Push rules, if the project has them: allowing the `duo-*` service accounts.
- The OAuth sign-in itself, which happens in your browser.

The links were checked against GitLab 19.6, and each manual step also links
its docs page.

What has been observed on GitLab.com: the group's Duo Agent Platform and MCP
fields read correctly from `ai_settings`, and the skill confirms the setup by
listing the project's flows through the MCP server. Not yet observed: turning
those group fields on through the API, because they were already on in the
test group. The skill re-reads the group afterwards to confirm, and gives the
UI path if the change doesn't take.

Not yet tested:

- Automatic Code Review (`auto_duo_code_review_enabled`) on a Premium
  project. The skill sends it in a request of its own and reports the result.
- Enabling foundational flows through GraphQL. GitLab marks this mutation as
  Experiment. If it fails, the skill gives you the link to do it in the UI.

Tested on GitLab.com: the GraphQL queries that read flows, runners and
automations, and creating the Fix CI/CD Pipeline automation. That mutation is
also marked Experiment by GitLab, so it could change between releases.

## Layout

```
skills/gitlab-duo-setup/
  SKILL.md                  the skill
  references/harnesses.md   MCP config and sign-in per harness
  references/graphql.md     queries and mutations for flows, runners and automations
```
