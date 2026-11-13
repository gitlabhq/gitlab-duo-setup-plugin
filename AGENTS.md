# AGENTS.md

This repository holds one Agent Skill, `skills/gitlab-duo-setup/`, that turns on
GitLab Duo Agent Platform for a project and connects Claude Code, Codex or
Cursor to the GitLab MCP server. See `README.md`.

- Keep the skill harness-neutral: it must work in Claude Code, Codex and Cursor.
- Bump `metadata.version` in `SKILL.md` and add a `CHANGELOG.md` entry when you
  change the skill.
- Docs are customer-facing: describe what the skill does today, and say plainly
  what is not automated yet.
