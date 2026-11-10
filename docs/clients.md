# Connecting your coding agent

All three clients connect to the same GitLab MCP server endpoint,
`https://<gitlab host>/api/v4/mcp`, over HTTP with OAuth in the browser. The
skills in this repository are in the open Agent Skills format, so the same
`SKILL.md` files work everywhere.

Request these toolsets. `code_security` is opt-in and lists tools only on
Ultimate.

```
X-Gitlab-Enabled-Mcp-Server-Toolsets: core,merge_requests,repository,ci,duo_agent_platform,code_security
```

## Fastest path: the config is already in the repository

This repository commits a project-scoped MCP configuration for each client,
with the toolsets header set. Clone, open your client, and approve OAuth in
the browser.

| Client | File | First run |
|---|---|---|
| Claude Code | `.mcp.json` | Approve the project server when prompted, then `/mcp` → GitLab → authenticate |
| Codex | `.codex/config.toml` | Trust the project, then `codex mcp login GitLab` |
| Cursor | `.cursor/mcp.json` | Settings → Tools & MCP → GitLab → connect |

Self-Managed or Dedicated:

- Claude Code: `export GITLAB_MCP_URL=https://<host>/api/v4/mcp`. `.mcp.json`
  expands it and falls back to gitlab.com.
- Codex and Cursor: edit the URL in the file locally, or use the per-user
  setup below. These files don't take a default value from an environment
  variable.

If you already have a GitLab MCP server configured at user level, or a GitLab
marketplace plugin installed, you will see two `GitLab` servers. Keep one.

The rest of this page is the per-user setup, for projects that don't commit
these files.

## Claude Code

```
claude mcp add -s user --transport http GitLab https://gitlab.com/api/v4/mcp \
  --header "X-Gitlab-Enabled-Mcp-Server-Toolsets: core,merge_requests,repository,ci,duo_agent_platform,code_security"
claude
/mcp   # select GitLab, approve in the browser
```

Skills: Claude Code reads `.claude/skills/`. This repository keeps copies there
(`make sync-skills`). `CLAUDE.md` imports `AGENTS.md`.

If a GitLab plugin is already installed from a marketplace, it also defines a
server named `GitLab`; keep one or the other to avoid duplicate tools.

## Codex

Add the server to `~/.codex/config.toml`, with the toolsets header:

```toml
[mcp_servers.GitLab]
url = "https://gitlab.com/api/v4/mcp"
http_headers = { "X-Gitlab-Enabled-Mcp-Server-Toolsets" = "core,merge_requests,repository,ci,duo_agent_platform,code_security" }
```

Then log in:

```
codex mcp login GitLab
```

Older Codex versions also need `rmcp_client = true` under `[features]` for
HTTP servers.

Skills: Codex discovers `.agents/skills/<name>/SKILL.md` in the repository.
Instructions: `AGENTS.md`.

## Cursor

Install the GitLab plugin from the Cursor Marketplace, or add the server by hand
under Settings → Cursor Settings → Tools & MCP:

```json
{
  "mcpServers": {
    "GitLab": {
      "type": "http",
      "url": "https://gitlab.com/api/v4/mcp",
      "headers": {
        "X-Gitlab-Enabled-Mcp-Server-Toolsets": "core,merge_requests,repository,ci,duo_agent_platform,code_security"
      }
    }
  }
}
```

Skills: Cursor reads `.agents/skills/` and `.cursor/skills/` (confirm on your
version during validation). Instructions: `AGENTS.md`.

Self-Managed users of the marketplace plugin: the bundled `.mcp.json` points at
gitlab.com and lives in Cursor's plugin cache; see the plugin README for the
edit, and re-check after plugin updates.

## Self-Managed and Dedicated

Full instructions are in `docs/self-managed.md`. In short:

- Replace `gitlab.com` with your host in every example.
- Ask your admin to pre-register one OAuth application (scope `mcp`,
  Confidential cleared) so clients don't rely on dynamic client registration,
  which is rate-limited per IP and shows an "unverified application" warning.
- Legacy personal access tokens are rejected by the MCP server. Use OAuth or a
  fine-grained token with the MCP tool Execute permission.

## glab

The skills use `glab` for git operations and for the readiness check.

```
glab auth login
glab auth status
```
