#!/usr/bin/env bash
# install.sh — install or update the GitLab agentic engineering kit, then
# optionally run a setup.sh command with it.
#
#   curl -fsSL https://gitlab.com/gitlab-da/projects/agentic-eng-config/-/raw/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- init --owners @<group>/<maintainers>
#   curl -fsSL .../install.sh | bash -s -- doctor
#
# The kit is kept in $GITLAB_AGENTIC_KIT_DIR (default ~/.gitlab-agentic-kit)
# and updated on every run. GITLAB_AGENTIC_KIT_REPO and GITLAB_AGENTIC_KIT_REF
# install from a fork or mirror, or pin a tag.

set -euo pipefail

main() {
  local repo="${GITLAB_AGENTIC_KIT_REPO:-https://gitlab.com/gitlab-da/projects/agentic-eng-config.git}"
  local dir="${GITLAB_AGENTIC_KIT_DIR:-$HOME/.gitlab-agentic-kit}"
  local ref="${GITLAB_AGENTIC_KIT_REF:-}"

  command -v git >/dev/null 2>&1 || { echo "error: missing dependency: git" >&2; exit 1; }

  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch -q --depth 1 origin "${ref:-HEAD}"
    git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD
  elif [ -e "$dir" ]; then
    echo "error: $dir exists and is not the kit; set GITLAB_AGENTIC_KIT_DIR" >&2; exit 1
  else
    git clone -q --depth 1 ${ref:+--branch "$ref"} "$repo" "$dir"
  fi
  echo "GitLab agentic engineering kit $(git -C "$dir" rev-parse --short HEAD) in $dir" >&2

  if [ $# -eq 0 ]; then
    echo "Next: $dir/setup/setup.sh init   (run in your project's repository)" >&2
  else
    exec bash "$dir/setup/setup.sh" "$@"
  fi
}

# Everything is inside main, so a partial download runs nothing.
main "$@"
