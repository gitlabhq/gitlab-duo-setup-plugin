# AGENTS.md

This repository holds two Agent Skills: `skills/gitlab-duo-setup/`, which turns
on GitLab Duo Agent Platform and connects Claude Code, Codex, Cursor, Devin or
OpenCode to the GitLab MCP server, and `skills/gitlab-mr-followup/`, which
follows a merge request to merge. The repository root is also a Claude plugin,
`gitlab-duo` (`.claude-plugin/plugin.json`). See `README.md`.

- Keep the skill harness-neutral: it must work in Claude Code, Codex, Cursor,
  Devin and OpenCode.
- Bump `metadata.version` in `SKILL.md` and add a `CHANGELOG.md` entry when you
  change the skill. Update the version in the Fix CI/CD Pipeline automation
  description too, in `scripts/automations.sh`, `references/graphql.md` and
  step 3c of `SKILL.md`.
- Docs are customer-facing: describe what the skill does today, and say plainly
  what is not automated yet.
- When a release changes either skill, bump `version` in
  `.claude-plugin/plugin.json` too. Claude Code uses it to tell installed
  copies there's an update. Keep the plugin layout: skills stay in `skills/`,
  and `README.md`, `LICENSE` and `assets/icon.png` stay at the root.
- Quote frontmatter values in `SKILL.md` that contain a colon.
