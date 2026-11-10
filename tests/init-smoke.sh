#!/usr/bin/env bash
# Smoke test for `setup.sh init`: installs into a copy of the example project
# and into a repository that already has its own AGENTS.md, CODEOWNERS and
# .mcp.json, then checks the result and that a second run changes nothing.

set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$KIT/setup/setup.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
fails=0
check() { if eval "$2"; then echo "  ok    $1"; else echo "  FAIL  $1"; fails=$((fails + 1)); fi; }

new_repo() { # new_repo <dir> <remote>
  git -C "$1" init -q -b main
  git -C "$1" config user.email smoke@example.com
  git -C "$1" config user.name smoke
  git -C "$1" remote add origin "$2"
}

echo "Example project, Self-Managed host from the remote"
A="$WORK/example"; cp -R "$KIT/examples/inventory" "$A"
new_repo "$A" "git@gitlab.example.com:acme/inventory.git"
(cd "$A" && bash "$SETUP" init --dry-run >/dev/null)
check "dry run writes nothing" '[ ! -e "$A/.mcp.json" ] && [ ! -e "$A/.agents" ]'
(cd "$A" && bash "$SETUP" init --owners @acme/maintainers >/dev/null)
check "AGENTS.md keeps the project section" 'grep -q "Flask inventory API" "$A/AGENTS.md"'
check "AGENTS.md gets the GitLab section" 'grep -q "BEGIN gitlab-agentic-engineering" "$A/AGENTS.md"'
check "CLAUDE.md imports AGENTS.md" 'grep -q "^@AGENTS.md" "$A/CLAUDE.md"'
check "example review instructions kept" 'grep -q "Python application code" "$A/.gitlab/duo/mr-review-instructions.yaml"'
check "agent-config detects pip" 'grep -q "  - pip install -r requirements.txt" "$A/.gitlab/duo/agent-config.yml"'
check "CODEOWNERS has the owner" 'grep -q "/.gitlab/duo/ *@acme/maintainers" "$A/.gitlab/CODEOWNERS"'
check "MCP config uses the host" 'grep -q "https://gitlab.example.com/api/v4/mcp" "$A/.mcp.json" "$A/.cursor/mcp.json" "$A/.codex/config.toml"'
check "MCP JSON is valid" 'jq -e .mcpServers.GitLab "$A/.mcp.json" "$A/.cursor/mcp.json" >/dev/null'
check "skills installed for every client" 'diff -rq "$KIT/skills/gitlab-checks" "$A/.agents/skills/gitlab-checks" && diff -rq "$KIT/skills/gitlab-checks" "$A/.claude/skills/gitlab-checks"'
git -C "$A" add -A && git -C "$A" commit -q -m init
(cd "$A" && bash "$SETUP" init >/dev/null)
check "second run changes nothing and keeps the owner" '[ -z "$(git -C "$A" status --porcelain)" ]'

echo "Existing repository with its own files"
B="$WORK/existing"; mkdir -p "$B/docs"
new_repo "$B" "https://gitlab.com/acme/web.git"
printf '# Our agents guide\n\nUse pnpm.\n' > "$B/AGENTS.md"
printf '* @acme/everyone\n' > "$B/docs/CODEOWNERS"
printf '{"mcpServers":{"Other":{"url":"https://example.com/mcp"}}}\n' > "$B/.mcp.json"
printf '# Ours\n' > "$B/CLAUDE.md"
touch "$B/pnpm-lock.yaml"
(cd "$B" && bash "$SETUP" init >/dev/null)
check "own AGENTS.md content kept" 'grep -q "Use pnpm." "$B/AGENTS.md" && grep -q "BEGIN gitlab-agentic-engineering" "$B/AGENTS.md"'
check "section added to the existing CODEOWNERS" 'grep -q "@acme/everyone" "$B/docs/CODEOWNERS" && grep -q "REPLACE-ME" "$B/docs/CODEOWNERS" && [ ! -e "$B/.gitlab/CODEOWNERS" ]'
check "existing MCP servers kept, GitLab added" 'jq -e ".mcpServers.Other and .mcpServers.GitLab" "$B/.mcp.json" >/dev/null'
check "existing CLAUDE.md left alone" '[ "$(cat "$B/CLAUDE.md")" = "# Ours" ]'
check "agent-config detects pnpm" 'grep -q "pnpm install --frozen-lockfile" "$B/.gitlab/duo/agent-config.yml"'
check "gitlab.com host from https remote" 'grep -q "https://gitlab.com/api/v4/mcp" "$B/.cursor/mcp.json"'
git -C "$B" add -A && git -C "$B" commit -q -m init
(cd "$B" && bash "$SETUP" init --owners @acme/platform >/dev/null)
check "re-run with --owners replaces only the managed block" 'grep -q "@acme/platform" "$B/docs/CODEOWNERS" && ! grep -q "REPLACE-ME" "$B/docs/CODEOWNERS" && grep -q "@acme/everyone" "$B/docs/CODEOWNERS"'
check "managed block appears once" '[ "$(grep -c "BEGIN gitlab-agentic-engineering" "$B/AGENTS.md")" = 1 ]'

echo "Host change with --force"
printf '\n[mcp_servers.Other]\nurl = "https://example.com/mcp"\n' >> "$B/.codex/config.toml"
(cd "$B" && bash "$SETUP" init --host gitlab.acme.test --force >/dev/null)
check "--force moves the GitLab server to the new host" 'grep -q "gitlab.acme.test" "$B/.mcp.json" "$B/.cursor/mcp.json" "$B/.codex/config.toml"'
check "--force keeps other MCP servers" 'jq -e .mcpServers.Other "$B/.mcp.json" >/dev/null && grep -q "^\[mcp_servers.Other\]" "$B/.codex/config.toml"'
check "one GitLab server in Codex config" '[ "$(grep -c "^\[mcp_servers.GitLab\]" "$B/.codex/config.toml")" = 1 ] && ! grep -q "https://gitlab.com/api" "$B/.codex/config.toml"'

echo "Skill update"
sed -i.bak 's/^  version: .*/  version: "0.0.1"/' "$B/.agents/skills/gitlab-checks/SKILL.md" && rm "$B/.agents/skills/gitlab-checks/SKILL.md.bak"
echo "local edit" >> "$B/.claude/skills/gitlab-checks/SKILL.md"
(cd "$B" && bash "$SETUP" init >/dev/null)
check "older skill version updated" 'diff -rq "$KIT/skills/gitlab-checks" "$B/.agents/skills/gitlab-checks"'
check "locally modified skill kept" 'grep -q "local edit" "$B/.claude/skills/gitlab-checks/SKILL.md"'

echo "install.sh piped to bash"
S="$WORK/kit-src"; cp -R "$KIT" "$S"; rm -rf "$S/.git"; new_repo "$S" "https://gitlab.example.com/kit.git"
git -C "$S" add -A && git -C "$S" commit -q -m kit
export GITLAB_AGENTIC_KIT_REPO="file://$S" GITLAB_AGENTIC_KIT_DIR="$WORK/kit-installed"
bash < "$KIT/install.sh" 2>/dev/null
check "installs the kit" '[ -x "$GITLAB_AGENTIC_KIT_DIR/setup/setup.sh" ]'
echo "# update" >> "$S/README.md" && git -C "$S" commit -q -am update
C="$WORK/piped"; mkdir "$C"; new_repo "$C" "git@gitlab.example.com:acme/piped.git"
(cd "$C" && bash -s -- init --owners @acme/maintainers < "$KIT/install.sh" >/dev/null 2>&1)
check "updates the kit on the next run" 'grep -q "^# update" "$GITLAB_AGENTIC_KIT_DIR/README.md"'
check "runs the setup command" 'grep -q "/.gitlab/duo/ *@acme/maintainers" "$C/.gitlab/CODEOWNERS"'

echo
[ "$fails" -eq 0 ] && echo "All checks passed." || { echo "$fails checks failed."; exit 1; }
