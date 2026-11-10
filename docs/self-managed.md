# Self-Managed and Dedicated

Everything in this repository works on GitLab Self-Managed and Dedicated, with
the extra steps below. Most setup problems show up here, so record what you hit
in `docs/validation-checklist.md`.

## Admin, once per instance

1. **GitLab Duo and the Agent Platform are available on the instance.** Check
   that the instance meets the minimum version and is connected to an AI gateway
   (GitLab-hosted or self-hosted). See the GitLab Duo setup documentation for
   your version.
2. **A runner for flows.** Flows run as CI jobs. Register a runner tagged
   `gitlab--duo` with a Docker-capable executor, available to the projects that
   use flows. Settings > General > GitLab Duo in the project shows a runner
   check; it must pass.
3. **One OAuth application for MCP clients.** Admin > Applications > New
   application, scope `mcp`, with **Confidential** cleared. Without it, each
   client registers its own app through dynamic client registration, which is
   rate-limited per IP and shows developers an "unverified application"
   warning.
4. **Push rules.** If you use push rules, allow the `duo-*` service accounts to
   push, or Fix CI/CD Pipeline and vulnerability resolution can't open MRs.

## Per group and project

Same as GitLab.com: `glab auth login --hostname <host>`, then the `setup.sh`
commands in the README. `setup.sh` uses whatever host `glab` is
authenticated to.

## Developers

The committed client config points at gitlab.com. Point it at your host:

| Client | How |
|---|---|
| Claude Code | `export GITLAB_MCP_URL=https://<host>/api/v4/mcp` (in your shell profile). `.mcp.json` picks it up. |
| Codex | Edit `url` in `.codex/config.toml`, or add the server to `~/.codex/config.toml` (`docs/clients.md`). |
| Cursor | Edit `url` in `.cursor/mcp.json`. For the marketplace plugin, edit its bundled `.mcp.json` in Cursor's plugin cache, and check it again after plugin updates. |

If you fork this repository for an internal template, commit your host in the
Codex and Cursor files so developers don't have to edit them.

Legacy personal access tokens are rejected by the MCP server. Use OAuth, or a
fine-grained token with the MCP tool Execute permission.
