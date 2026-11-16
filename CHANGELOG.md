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
- Add OpenCode as a supported harness: install path, MCP config in
  `opencode.json` (checked against OpenCode 1.14.29), sign-in with
  `opencode mcp auth`, and a note that OpenCode also reads the Claude Code and
  Codex skill directories.
- Document how to reload each harness after installing the skill. Codex needs
  a restart (#3).
- List the manual steps (now Step 1c) before asking for approval and applying
  settings (now Step 1d), so the user sees them before anything changes (#7).
- Ask the user to say when they've finished OAuth sign-in; some harnesses
  don't hand the turn back to the agent.
- OpenCode 2.x: add the server with `opencode mcp add --global`, which writes
  `mcp.servers.GitLab`. Keep the 1.x `jq` path. Replace the README's
  `opencode debug skill` check, which 2.x removed (#8).
- Devin: the skill and MCP tools load without a restart. Note that Devin also
  reads `~/.claude/skills/`.

## 0.1.0 (2026-11-13)

- Replace the setup script, templates, example project and previous skills with
  a single skill, `gitlab-duo-setup`: turns on Duo Agent Platform settings with
  `glab api` and configures the GitLab MCP server for Claude Code, Codex or Cursor.
