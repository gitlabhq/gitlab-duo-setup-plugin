# Self-Managed and Dedicated

The kit works on GitLab Self-Managed and Dedicated, with the extra steps
below.

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
commands in the README. The admin commands use the host `glab` is
authenticated to.

## Projects and developers

`setup.sh init` writes the host of the repository's `origin` remote into the
MCP config, so committed config already points at your instance. If `origin`
uses an SSH alias or a different SSH hostname, pass `--host <web host>`.

`setup.sh connect` does the same for user-level config, and `setup.sh doctor`
checks that the MCP endpoint answers on your host.

For the Cursor marketplace plugin, edit its bundled `.mcp.json` in Cursor's
plugin cache to point at your host, and check it again after plugin updates.

Legacy personal access tokens are rejected by the MCP server. Use OAuth, or a
fine-grained token with the MCP tool Execute permission.
