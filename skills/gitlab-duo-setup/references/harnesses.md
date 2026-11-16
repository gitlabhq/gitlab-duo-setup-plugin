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

## Devin

**User-level**: `~/.config/devin/mcp_config.json`. **Project-level**:
`.devin/mcp_config.json` (committed) or `.devin/mcp_config.local.json` (not
committed).

Check first with `devin mcp get GitLab` and read its `Source` line. Devin also
shows servers it imported from other harnesses' configs (for example
`~/.claude/settings.json`). An imported entry isn't in Devin's own config, so
treat it as "no Devin entry yet". Don't edit or remove the other harness's
config.

`devin mcp add` defaults to `local` scope, so always pass `-s`:

```bash
devin mcp add -s user --transport http GitLab https://<HOST>/api/v4/mcp \
  -H "X-Gitlab-Enabled-Mcp-Server-Toolsets: core,merge_requests,repository,ci,duo_agent_platform,code_security"
```

Use `-s project` for `.devin/mcp_config.json`.

**Sign in**: `devin mcp add` usually opens the browser sign-in itself. If
`devin mcp get GitLab` still shows it needs authentication, run
`devin mcp login GitLab` and approve in the browser. The tools usually load
without a restart; if they don't appear, restart Devin CLI.

## OpenCode

Check the version first with `opencode --version`. The config shape changed in
OpenCode 2.

**OpenCode 2.x** (checked against 2.3.0): use the CLI, which merges into the
config and keeps other servers.

- **User-level**: `~/.config/opencode/opencode.json`:

  ```bash
  opencode mcp add GitLab --global --url https://<HOST>/api/v4/mcp \
    --header "X-Gitlab-Enabled-Mcp-Server-Toolsets=core,merge_requests,repository,ci,duo_agent_platform,code_security"
  ```

- **Project-level**: the same command without `--global`, which writes the
  project's `opencode.json`.

Check first with `opencode mcp list`. The entry lands under `mcp.servers`:

```json
{
  "mcp": {
    "servers": {
      "GitLab": {
        "type": "remote",
        "url": "https://<HOST>/api/v4/mcp",
        "headers": {
          "X-Gitlab-Enabled-Mcp-Server-Toolsets": "core,merge_requests,repository,ci,duo_agent_platform,code_security"
        }
      }
    }
  }
}
```

**OpenCode 1.x** (checked against 1.14.29): `opencode mcp add` is interactive
and servers go directly under `mcp`, keyed by name, with `"enabled": true`.
Merge with `jq`, keeping other servers and settings:

```bash
f=~/.config/opencode/opencode.json; mkdir -p "$(dirname "$f")"; [ -f "$f" ] || echo '{"$schema": "https://opencode.ai/config.json"}' > "$f"
jq --arg u "https://<HOST>/api/v4/mcp" \
   --arg t "core,merge_requests,repository,ci,duo_agent_platform,code_security" \
   '.mcp.GitLab = {type: "remote", url: $u, headers: {"X-Gitlab-Enabled-Mcp-Server-Toolsets": $t}, enabled: true}' \
   "$f" > "$f.tmp" && mv "$f.tmp" "$f"
```

Then run `opencode debug config`, which prints an error if the config is
invalid. If the user has `opencode.jsonc` with comments, `jq` can't parse it:
show the user the entry and edit the file by hand, keeping their comments.

**Sign in** (both versions): `opencode mcp auth GitLab` (or `/mcps` in
OpenCode → GitLab → sign in), approve in the browser, then check
`opencode mcp list` shows GitLab connected. Restart OpenCode if the tools
don't appear.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| No GitLab tools after sign-in | The harness hasn't reloaded. Restart it. |
| Two `GitLab` servers, duplicate tools | Configured at user and project level, or alongside a marketplace plugin. Remove one. |
| No `duo_agent_platform` tools | `ai_settings.duo_agent_platform_enabled` or `ai_settings.duo_workflow_mcp_enabled` is off on the top-level group (Step 1). |
| Devin shows a `GitLab` server you didn't add | Devin imports servers from other harnesses' configs. Check the `Source` line in `devin mcp get GitLab`. |
| OpenCode doesn't list the `GitLab` server | The entry uses the other version's shape: OpenCode 2 reads `mcp.servers.GitLab`, 1.x reads `mcp.GitLab`. Check `opencode --version` and use the matching section above. |
| No `code_security` tools | Header not sent, or the group isn't on Ultimate. |
| `insufficient_scope` | A legacy personal access token. Use OAuth. |
| "Unverified application" or registration fails (Self-Managed) | Dynamic client registration, rate-limited per IP. An admin creates an OAuth app: Admin > Applications, scope `mcp`, Confidential cleared. |
| 404 at `/api/v4/mcp` | The instance is too old or the MCP server isn't enabled. Ask an admin. |
