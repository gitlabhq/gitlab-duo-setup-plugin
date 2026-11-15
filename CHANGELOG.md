# Changelog

## 0.2.0 (2026-11-15)

- Read the group's `duo_agent_platform_enabled` and `duo_workflow_mcp_enabled`
  from the nested `ai_settings` object, where GitLab returns them. Before, the
  skill looked at the top level, didn't find them, and reported them as "not
  available" even when they were on (#5).
- Write those two group fields through `ai_settings_attributes`, as the GitLab
  API reference describes. This group write hasn't been tested end to end yet.
- If a field can't be read, report "can't read via API" and point to the UI,
  instead of "not available".
- Show every project `duo_*` field read-only, and say that UI toggles don't
  always map to API fields. If the user says they changed a setting in the UI,
  the skill re-reads it and still makes the approved change if it's off (#6).
- Move `auto_duo_code_review_enabled` into the Ultimate request: the API
  reference lists it as Ultimate only.
- Add Devin CLI as a supported harness: install path, MCP config, sign-in, and
  how to spot servers Devin imported from other harnesses (#4).
- Document how to reload each harness after installing the skill. Codex needs
  a restart (#3).

## 0.1.0 (2026-11-13)

- Replace the setup script, templates, example project and previous skills with
  a single skill, `gitlab-duo-setup`: turns on Duo Agent Platform settings with
  `glab api` and configures the GitLab MCP server for Claude Code, Codex or Cursor.
