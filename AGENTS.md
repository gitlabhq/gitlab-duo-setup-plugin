# AGENTS.md

This repository holds one Agent Skill, `skills/gitlab-duo-setup/`, that turns on
GitLab Duo Agent Platform for a project and connects Claude Code, Codex,
Cursor, Devin or OpenCode to the GitLab MCP server. See `README.md`.

- Keep the skill harness-neutral: it must work in Claude Code, Codex, Cursor,
  Devin and OpenCode.
- Bump `metadata.version` in `SKILL.md` and add a `CHANGELOG.md` entry when you
  change the skill. Update the version in the Fix CI/CD Pipeline automation
  description too, in `scripts/automations.sh`, `references/graphql.md` and
  step 3c of `SKILL.md`.
- Docs are customer-facing: describe what the skill does today, and say plainly
  what is not automated yet.
