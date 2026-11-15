# GitLab Duo setup skill

An Agent Skill for Claude Code, Codex, Cursor and Devin users. Load it, ask your agent
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

## Install

Copy `skills/gitlab-duo-setup/` into your harness's skills directory:

| Harness | User-level | Project-level |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex | `~/.agents/skills/` | `.agents/skills/` |
| Cursor | `~/.cursor/skills/` | `.agents/skills/` |
| Devin | `~/.config/devin/skills/` | `.devin/skills/` |

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
| Devin | Restart Devin CLI. Check with `devin skills list`. |

Devin also reads `~/.agents/skills/`, the Codex directory. If you use both,
install the skill in one place only, so Devin doesn't list it twice.

Then, in your project, ask: "Set up GitLab Duo for this project."

## What is not automated yet

The REST API doesn't cover these, so the skill gives you the UI steps:

- Choosing which foundational flows the group allows (Code Review, Fix CI/CD
  Pipeline, and others).
- Creating the Fix CI/CD Pipeline trigger on failed pipelines.
- Self-Managed: connecting the instance to an AI gateway, and a runner tagged
  `gitlab--duo` for flows.
- The OAuth sign-in itself, which happens in your browser.

Not yet tested end to end: turning on Duo Agent Platform and MCP at the group
level through the API. The skill follows the GitLab API reference for this and
re-reads the group afterwards to confirm. If the change doesn't take, it falls
back to the UI path.

## Layout

```
skills/gitlab-duo-setup/
  SKILL.md                  the skill
  references/harnesses.md   MCP config and sign-in per harness
```
