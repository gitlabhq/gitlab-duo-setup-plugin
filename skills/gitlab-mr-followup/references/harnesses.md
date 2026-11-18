# Installing gitlab-mr-followup in each coding agent

Copy the `gitlab-mr-followup/` folder into the agent's skills directory. One skill, the same files, in every agent.

| Agent | For you (all repos) | For the repo (teammates get it) | How to call it by name |
|---|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` | `/gitlab-mr-followup` |
| Codex | `~/.agents/skills/` | `.agents/skills/` | `$gitlab-mr-followup` |
| Cursor | `~/.cursor/skills/` | `.agents/skills/` or `.cursor/skills/` | `/gitlab-mr-followup` |
| Devin | `~/.config/devin/skills/` | `.devin/skills/` | `@skills:gitlab-mr-followup` |
| OpenCode | `~/.config/opencode/skills/` | `.opencode/skills/` | `@gitlab-mr-followup` |

Notes:

- Codex needs a restart to see a newly installed skill. The others usually pick it up in the running session.
- Devin and OpenCode also read `~/.claude/skills/` and `~/.agents/skills/`. If you use several agents, install in one shared place so the skill is not listed twice.
- Confirm the agent lists the skill before relying on it. If it doesn't reach for the skill by itself, add the `AGENTS.md` pointer below.

## Connect GitLab

The skill works with the GitLab MCP server (`https://<host>/api/v4/mcp`) or with `glab`. The `gitlab-duo-setup` skill in this repository adds the MCP server to your agent and walks you through sign-in.

## Help the agent reach for the skill

Agents do not always load a skill for a plain request such as "check my MR". A short pointer in the repo's `AGENTS.md` fixes most of that, because every one of these agents reads it (for Claude Code, put `@AGENTS.md` in `CLAUDE.md`):

```markdown
## Merge requests

After you push to a GitLab merge request, the work is not finished. GitLab runs a pipeline and a GitLab Duo
Code Review, and may start Fix CI/CD Pipeline on a failure. Wait for them, read what they found, fix it and
verify on the latest commit. Use the `gitlab-mr-followup` skill for this. Never approve a merge request or
change approval rules; GitLab decides what may merge.
```
