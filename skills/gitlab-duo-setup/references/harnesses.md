# GitLab MCP server config per harness

Replace `<HOST>` with the GitLab web host (for example `gitlab.com`).

When a config file needs editing, merge into it: read the file, add or
replace only the `GitLab` entry, and keep every other server and setting. If
the file doesn't exist, create it with just the entry shown. Edit the file
directly; no extra tools are needed.

```
URL:     https://<HOST>/api/v4/mcp
Header:  none (the server's default toolsets)
```

The defaults are `core`, `merge_requests`, `work_items`, `repository` and
`ci`, plus `duo_agent_platform` when the user has Duo Agent Platform. Send no
toolsets header unless the user asks for an opt-in toolset. See
[Opt-in toolsets](#opt-in-toolsets).

## Claude Code

**User-level**: check first with `claude mcp list` and `claude mcp get GitLab`,
then:

```bash
claude mcp add -s user --transport http GitLab https://<HOST>/api/v4/mcp
```

Always pass `-s user`. Without it, the server is added at `local` scope, which
works only in the directory where you ran the command. A `local` entry also
takes precedence over a `user` entry with the same name, and older setup
instructions created `local` entries. If `claude mcp list` shows a `local`
`GitLab` entry, ask before removing it: `claude mcp remove GitLab -s local`.

**Project-level**: merge into `.mcp.json` at the repo root:

```json
{
  "mcpServers": {
    "GitLab": {
      "type": "http",
      "url": "https://<HOST>/api/v4/mcp"
    }
  }
}
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
```

Older Codex versions also need `rmcp_client = true` under `[features]`.

**Sign in**: `codex mcp login GitLab`, approve in the browser, restart Codex.

## Cursor

**User-level**: `~/.cursor/mcp.json`. **Project-level**: `.cursor/mcp.json`.
Merge this entry in. Unlike Claude Code, it has no `type` field:

```json
{
  "mcpServers": {
    "GitLab": {
      "url": "https://<HOST>/api/v4/mcp"
    }
  }
}
```

**Sign in (IDE)**: Settings → Cursor Settings → Tools & MCP → GitLab → Connect,
and approve in the browser.

**Sign in (CLI)**: in the project folder, run `cursor-agent mcp enable GitLab`,
then `cursor-agent mcp login GitLab`, and approve in the browser. `mcp login`
fails until the server is enabled. The CLI keeps the approval and the sign-in
per folder, so a new project folder needs both again. `cursor-agent mcp list`
shows `GitLab: ready` when it's signed in.

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
devin mcp add -s user --transport http GitLab https://<HOST>/api/v4/mcp
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
  opencode mcp add GitLab --global --url https://<HOST>/api/v4/mcp
  ```

- **Project-level**: the same command without `--global`, which writes the
  project's `opencode.json`.

Check first with `opencode mcp list`. For the first few seconds in a new folder
it can show no servers, or "pending": run it again before you add anything. The
entry lands under `mcp.servers`:

```json
{
  "mcp": {
    "servers": {
      "GitLab": {
        "type": "remote",
        "url": "https://<HOST>/api/v4/mcp"
      }
    }
  }
}
```

**OpenCode 1.x** (checked against 1.14.29): `opencode mcp add` is interactive
and servers go directly under `mcp`, keyed by name, with `"enabled": true`.
Merge this entry into `~/.config/opencode/opencode.json` (user-level) or the
project's `opencode.json`. A new file starts with
`"$schema": "https://opencode.ai/config.json"`:

```json
{
  "mcp": {
    "GitLab": {
      "type": "remote",
      "url": "https://<HOST>/api/v4/mcp",
      "enabled": true
    }
  }
}
```

If the user has `opencode.jsonc`, keep their comments when you edit it. Then
run `opencode debug config`, which prints an error if the config is invalid.

**Sign in** (both versions): `opencode mcp auth GitLab` (or `/mcps` in
OpenCode → GitLab → sign in), approve in the browser, then check
`opencode mcp list` shows GitLab connected. Restart OpenCode if the tools
don't appear.

## Opt-in toolsets

Add a header only if the user asks for an opt-in toolset: `code_security`
(which has tools only on Ultimate), `wikis` or `orbit`. Once the header is
set, the server limits itself to the toolsets named in it, so list the
defaults as well:

```
X-Gitlab-Enabled-Mcp-Server-Toolsets: core,merge_requests,work_items,repository,ci,duo_agent_platform,code_security
```

`all` turns on every toolset, the opt-in ones included. An unknown toolset name
gets a 400 error.

| Harness | How to send the header |
|---|---|
| Claude Code | `--header "X-Gitlab-Enabled-Mcp-Server-Toolsets: <list>"` on `claude mcp add`, or `"headers": {...}` in `.mcp.json` |
| Codex | `http_headers = { "X-Gitlab-Enabled-Mcp-Server-Toolsets" = "<list>" }` in the `[mcp_servers.GitLab]` table (the key comes from Codex's MCP docs; GitLab's docs don't show a Codex example) |
| Cursor | `"headers": {...}` in `mcp.json` |
| Devin | `-H "X-Gitlab-Enabled-Mcp-Server-Toolsets: <list>"` on `devin mcp add` |
| OpenCode 2.x | `--header "X-Gitlab-Enabled-Mcp-Server-Toolsets=<list>"` on `opencode mcp add` |
| OpenCode 1.x | `"headers": {...}` in the `mcp.GitLab` entry |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| No GitLab tools after sign-in | The harness hasn't reloaded. Restart it. |
| Two `GitLab` servers, duplicate tools | Configured at user and project level, or alongside a marketplace plugin. Remove one. |
| Claude Code uses an old `GitLab` config | A `local` scope entry overrides the `user` one. Check `claude mcp list`, then `claude mcp remove GitLab -s local`. |
| 403 at sign-in, or "MCP server not enabled for any of your groups" | MCP client access is off for the top-level group. A group Owner opens `https://<HOST>/groups/<GROUP>/-/edit#js-permissions-settings` and checks MCP client access > Allow connection to GitLab. The result is cached for up to an hour. On Self-Managed and Dedicated, an admin turns it on for the instance. |
| No `work_items` tools (can't read issues) | A toolsets header that leaves out `work_items`. Remove the header, or add the defaults to it (see [Opt-in toolsets](#opt-in-toolsets)). |
| No `duo_agent_platform` tools | Duo Agent Platform isn't available to this user. These tools show up only when it is, even with the header set to `all`. Check the tier, the user's seat or credits, and `ai_settings.duo_agent_platform_enabled` on the top-level group (Step 1). |
| Devin shows a `GitLab` server you didn't add | Devin imports servers from other harnesses' configs. Check the `Source` line in `devin mcp get GitLab`. |
| OpenCode doesn't list the `GitLab` server | The entry uses the other version's shape: OpenCode 2 reads `mcp.servers.GitLab`, 1.x reads `mcp.GitLab`. Check `opencode --version` and use the matching section above. |
| No `code_security` tools | It's opt-in: add the header with the defaults plus `code_security`. Its tools also need Ultimate. |
| `insufficient_scope` | A legacy personal access token. Use OAuth. |
| "Unverified application" or registration fails (Self-Managed) | Dynamic client registration, rate-limited per IP. An admin creates an OAuth app: Admin > Applications, scope `mcp`, Confidential cleared. |
| 404 at `/api/v4/mcp` | The instance is too old or the MCP server isn't enabled. Ask an admin. |
