# GitLab Duo setup skill

An Agent Skill for Claude Code, Codex, Cursor, Devin and OpenCode users. Load it, ask your agent
to "set up GitLab Duo", and it does two things:

1. **Turns on GitLab Duo Agent Platform** for the current project and its
   top-level group, using `glab api`. It shows what it will change and asks
   before changing anything.
2. **Connects your agent to the GitLab MCP server** (`https://<host>/api/v4/mcp`)
   and walks you through signing in with OAuth.

It works on GitLab.com, Self-Managed and Dedicated.

## Requirements

- `git`, `jq`, and [`glab`](https://gitlab.com/gitlab-org/cli#installation),
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

The REST API doesn't cover these, so the skill gives you the UI steps:

- Checking the group's MCP client access setting (Allow connection to
  GitLab), which the Groups API doesn't expose.
- Choosing which foundational flows the group allows (Code Review, Fix CI/CD
  Pipeline, and others).
- Creating the Fix CI/CD Pipeline automation for failed pipelines (AI >
  Automations; called Triggers on GitLab 19.5 and earlier).
- Runners: turning on hosted runners for the project if they're off, or a
  runner tagged `gitlab--duo`. On Self-Managed, also connecting the instance to
  an AI gateway.
- The OAuth sign-in itself, which happens in your browser.

The skill lists these with UI paths checked against GitLab 19.6 and a link to
the docs for each.

What has been observed on GitLab.com: the group's Duo Agent Platform and MCP
fields read correctly from `ai_settings`, and the skill confirms the setup by
listing the project's flows through the MCP server. Not yet observed: turning
those group fields on through the API, because they were already on in the
test group. The skill re-reads the group afterwards to confirm, and gives the
UI path if the change doesn't take.

Not yet tested: automatic Code Review (`auto_duo_code_review_enabled`) on a
Premium project. The skill sends it in a request of its own and reports the
result.

## Layout

```
skills/gitlab-duo-setup/
  SKILL.md                  the skill
  references/harnesses.md   MCP config and sign-in per harness
```
