# Connecting your coding agent

Claude Code, Codex and Cursor all connect to the same GitLab MCP server,
`https://<gitlab host>/api/v4/mcp`, over HTTP with OAuth in the browser. The
skills use the open Agent Skills format, so the same `SKILL.md` files work in
all three.

Clients send this header to choose toolsets. `code_security` lists tools only
on Ultimate.

```
X-Gitlab-Enabled-Mcp-Server-Toolsets: core,merge_requests,repository,ci,duo_agent_platform,code_security
```

## In a project that ran `setup.sh init`

The configuration is committed, pointing at your GitLab host. Open the
project and sign in:

| Client | File | First run |
|---|---|---|
| Claude Code | `.mcp.json` | Approve the project server when prompted, then `/mcp` → GitLab → authenticate |
| Codex | `.codex/config.toml` | Trust the project, then `codex mcp login GitLab` |
| Cursor | `.cursor/mcp.json` | Settings → Tools & MCP → GitLab → connect |

In Claude Code, `GITLAB_MCP_URL` overrides the committed URL, for example to
test against another instance.

Skills: Claude Code reads `.claude/skills/`; Codex and Cursor read
`.agents/skills/`. `init` installs both. Instructions: `AGENTS.md`, imported by
`CLAUDE.md` for Claude Code.

Check the setup with `setup.sh doctor`.

## Anywhere else: `setup.sh connect`

For repositories without the committed config, add the server to your
user-level config once:

```
setup.sh connect             # every installed client
setup.sh connect claude      # or one of: claude, codex, cursor
setup.sh connect --host gitlab.example.com
```

The host comes from the current repository's `origin` remote, or `--host`.
Don't combine both: a project server and a user-level server named `GitLab`
show duplicate tools. The same applies to a GitLab plugin installed from a
marketplace; keep one.

What `connect` does, if you'd rather do it by hand:

**Claude Code**

```
claude mcp add -s user --transport http GitLab https://gitlab.com/api/v4/mcp \
  --header "X-Gitlab-Enabled-Mcp-Server-Toolsets: core,merge_requests,repository,ci,duo_agent_platform,code_security"
claude
/mcp   # select GitLab, approve in the browser
```

**Codex**: add to `~/.codex/config.toml`, then `codex mcp login GitLab`.
Older Codex versions also need `rmcp_client = true` under `[features]`.

```toml
[mcp_servers.GitLab]
url = "https://gitlab.com/api/v4/mcp"
http_headers = { "X-Gitlab-Enabled-Mcp-Server-Toolsets" = "core,merge_requests,repository,ci,duo_agent_platform,code_security" }
```

**Cursor**: add to `~/.cursor/mcp.json`, or Settings → Cursor Settings →
Tools & MCP:

```json
{
  "mcpServers": {
    "GitLab": {
      "url": "https://gitlab.com/api/v4/mcp",
      "headers": {
        "X-Gitlab-Enabled-Mcp-Server-Toolsets": "core,merge_requests,repository,ci,duo_agent_platform,code_security"
      }
    }
  }
}
```

## Self-Managed and Dedicated

Use your host everywhere `gitlab.com` appears. Ask your admin to pre-register an
OAuth application so clients don't rely on dynamic client registration. Legacy
personal access tokens are rejected; use OAuth, or a fine-grained token with the
MCP tool Execute permission. Details: `docs/self-managed.md`.
