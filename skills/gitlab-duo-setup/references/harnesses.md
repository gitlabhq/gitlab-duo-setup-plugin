# GitLab MCP server config per harness

Replace `<HOST>` with the GitLab web host (for example `gitlab.com`).

```
URL:     https://<HOST>/api/v4/mcp
Header:  X-Gitlab-Enabled-Mcp-Server-Toolsets: core,merge_requests,repository,ci,duo_agent_platform,code_security
```

## Claude Code

**User-level**: check first with `claude mcp get GitLab`, then:

```bash
claude mcp add -s user --transport http GitLab https://<HOST>/api/v4/mcp \
  --header "X-Gitlab-Enabled-Mcp-Server-Toolsets: core,merge_requests,repository,ci,duo_agent_platform,code_security"
```

**Project-level**: merge into `.mcp.json` at the repo root:

```json
{
  "mcpServers": {
    "GitLab": {
      "type": "http",
      "url": "https://<HOST>/api/v4/mcp",
      "headers": {
        "X-Gitlab-Enabled-Mcp-Server-Toolsets": "core,merge_requests,repository,ci,duo_agent_platform,code_security"
      }
    }
  }
}
```

With `jq`, keeping other servers:

```bash
f=.mcp.json; [ -f "$f" ] || echo '{}' > "$f"
jq --arg u "https://<HOST>/api/v4/mcp" \
   --arg t "core,merge_requests,repository,ci,duo_agent_platform,code_security" \
   '.mcpServers.GitLab = {type: "http", url: $u, headers: {"X-Gitlab-Enabled-Mcp-Server-Toolsets": $t}}' \
   "$f" > "$f.tmp" && mv "$f.tmp" "$f"
```

**Sign in**: restart Claude Code (project servers prompt for approval on first
start), then `/mcp` → GitLab → Authenticate → approve in the browser.

## Codex

**User-level**: `~/.codex/config.toml`. **Project-level**: `.codex/config.toml`
in the repo (only read for trusted projects, on Codex versions that support
project config). Check for an existing `[mcp_servers.GitLab]` table first;
append if absent:

```toml
[mcp_servers.GitLab]
url = "https://<HOST>/api/v4/mcp"
http_headers = { "X-Gitlab-Enabled-Mcp-Server-Toolsets" = "core,merge_requests,repository,ci,duo_agent_platform,code_security" }
```

Older Codex versions also need `rmcp_client = true` under `[features]`.

**Sign in**: `codex mcp login GitLab`, approve in the browser, restart Codex.

## Cursor

**User-level**: `~/.cursor/mcp.json`. **Project-level**: `.cursor/mcp.json`.
Merge with the same `jq` command as Claude Code, without the `type` field:

```json
{
  "mcpServers": {
    "GitLab": {
      "url": "https://<HOST>/api/v4/mcp",
      "headers": {
        "X-Gitlab-Enabled-Mcp-Server-Toolsets": "core,merge_requests,repository,ci,duo_agent_platform,code_security"
      }
    }
  }
}
```

**Sign in**: Settings → Cursor Settings → Tools & MCP → GitLab → Connect, and
approve in the browser.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| No GitLab tools after sign-in | The harness hasn't reloaded. Restart it. |
| Two `GitLab` servers, duplicate tools | Configured at user and project level, or alongside a marketplace plugin. Remove one. |
| No `duo_agent_platform` tools | `duo_agent_platform_enabled` or `duo_workflow_mcp_enabled` is off on the top-level group (Step 1). |
| No `code_security` tools | Header not sent, or the group isn't on Ultimate. |
| `insufficient_scope` | A legacy personal access token. Use OAuth. |
| "Unverified application" or registration fails (Self-Managed) | Dynamic client registration, rate-limited per IP. An admin creates an OAuth app: Admin > Applications, scope `mcp`, Confidential cleared. |
| 404 at `/api/v4/mcp` | The instance is too old or the MCP server isn't enabled. Ask an admin. |
