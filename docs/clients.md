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

```
codex mcp add GitLab --url "https://gitlab.com/api/v4/mcp"
```

Edit `~/.codex/config.toml` and enable the client feature flag, then log in:

```toml
[features]
"rmcp_client" = true

[mcp_servers.GitLab]
url = "https://gitlab.com/api/v4/mcp"
```

```
codex mcp login GitLab
```

Skills: Codex discovers `.agents/skills/<name>/SKILL.md` in the repository.
Instructions: `AGENTS.md`.

Setting the toolsets header in Codex uses Codex's own configuration format; see
the Codex MCP documentation.

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
