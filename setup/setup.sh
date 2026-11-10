#!/usr/bin/env bash
# setup.sh — GitLab configuration for agentic engineering
#
# Admin: group Owner, project Maintainer
#   setup.sh check   group        <top-level-group>
#   setup.sh check   project      <group/project>
#   setup.sh apply   group        <top-level-group>   [--dry-run] [--yes]
#   setup.sh apply   project      <group/project>     [--dry-run] [--yes]
#   setup.sh apply   all-projects <group>             [--dry-run] [--yes]
#   setup.sh restore <backup-file>                    [--yes]
#   setup.sh profiles <top-level-group>                         (Ultimate)
#   setup.sh attach   <profile-gid> <group/project>             (Ultimate)
#
# Each project: run inside the repository, then review and commit the result
#   setup.sh init    [--host <host>] [--owners <@group/team>] [--force] [--dry-run]
#
# Developer
#   setup.sh connect [claude|codex|cursor|all] [--host <host>] [--dry-run]
#   setup.sh doctor  [--host <host>]
#
# apply shows what will change and asks before changing anything. It saves
# the previous values to setup-backup-<time>.json; `restore` puts them back.
#
# Requirements: git; glab (authenticated: `glab auth status`) and jq for the
# admin commands, connect and doctor; curl for doctor.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLSETS="core,merge_requests,repository,ci,duo_agent_platform,code_security"
MARK_BEGIN="BEGIN gitlab-agentic-engineering"
MARK_END="END gitlab-agentic-engineering"
PLACEHOLDER_OWNER="@REPLACE-ME/maintainers"
FIX_LABEL="pipeline::broken"

GROUP_FIELDS=(duo_features_enabled duo_agent_platform_enabled duo_workflow_mcp_enabled)
PROJECT_FIELDS=(duo_remote_flows_enabled duo_foundational_flows_enabled auto_duo_code_review_enabled)
ULTIMATE_FIELDS=(duo_sast_fp_detection_enabled duo_sast_vr_workflow_enabled)

DRY_RUN=0 YES=0 FORCE=0 HOST="" OWNERS=""

# ─────────────────────────────────────────────────────────────── helpers ────

usage() { sed -n '2,/^[^#]/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 1; }
die() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
enc() { printf '%s' "$1" | jq -sRr @uri; }
hr() { printf '\n%s\n' "────────────────────────────────────────────────────────"; }
say() { printf '  %-44s %s\n' "$1" "$2"; }

confirm() { # confirm <question>; exits unless the answer is yes
  [ "$YES" = 1 ] && return 0
  local a in=/dev/stdin
  if [ ! -t 0 ]; then # e.g. `curl ... | bash`: ask on the terminal instead
    { : </dev/tty; } 2>/dev/null || die "not a terminal; re-run with --yes to apply"
    in=/dev/tty
  fi
  read -r -p "$1 [y/N] " a <"$in"
  case "$a" in y|Y|yes) ;; *) echo "Nothing changed."; exit 0 ;; esac
}

remote_host() { # remote_host <dir>: host of the origin remote, or nothing
  local url; url="$(git -C "$1" remote get-url origin 2>/dev/null)" || return 0
  url="${url#*://}"; url="${url#*@}"; url="${url%%[:/]*}"
  printf '%s' "$url"
}

field() { # field <json> <name>: value as text, or "absent"
  printf '%s' "$1" | jq -r --arg f "$2" 'if has($f) then .[$f] | tostring else "absent" end'
}

# ───────────────────────────────────────────────────────────────── check ────

check_group() {
  need glab; need jq
  local group="$1" json f
  hr; echo "Top-level group: $group"
  json="$(glab api "groups/$(enc "$group")")"
  for f in "${GROUP_FIELDS[@]}" duo_availability; do say "$f" "$(field "$json" "$f")"; done
  cat <<'EOF'

Check in the UI (Settings > GitLab Duo > Change configuration > Flow execution):
  [ ] Allow flow execution
  [ ] Allow foundational flows
  [ ] Code Review
  [ ] Fix CI/CD Pipeline
  [ ] Recommend Reviewers
  [ ] Generate Workplan
  [ ] Security Review                      (Ultimate)
  [ ] SAST False Positive Detection        (Ultimate)
  [ ] Resolve SAST Vulnerability           (Ultimate)
Also confirm push rules allow the duo-* service accounts, and (Self-Managed)
a runner tagged gitlab--duo with a Docker-capable executor is online.
EOF
}

check_project() {
  need glab; need jq
  local project="$1" json id branch f raw
  hr; echo "Project: $project"
  json="$(glab api "projects/$(enc "$project")")"
  for f in "${PROJECT_FIELDS[@]}" duo_code_review_decisions_enabled "${ULTIMATE_FIELDS[@]}"; do
    say "$f" "$(field "$json" "$f")"
  done
  id="$(printf '%s' "$json" | jq -r .id)"
  branch="$(printf '%s' "$json" | jq -r .default_branch)"
  echo
  echo "Repository files on $branch:"
  for f in .gitlab/duo/agent-config.yml .gitlab/duo/mr-review-instructions.yaml AGENTS.md .gitlab/CODEOWNERS; do
    if raw="$(glab api "projects/$id/repository/files/$(enc "$f")/raw?ref=$(enc "$branch")" 2>/dev/null)"; then
      if [ "$f" = AGENTS.md ] && ! grep -qF "$MARK_BEGIN" <<<"$raw"; then
        say "$f" "present, no GitLab section (run setup.sh init)"
      elif [ "$f" = .gitlab/CODEOWNERS ] && grep -qF "$PLACEHOLDER_OWNER" <<<"$raw"; then
        say "$f" "placeholder owner (run setup.sh init --owners)"
      else
        say "$f" "present"
      fi
    else
      say "$f" "missing"
    fi
  done
  cat <<'EOF'

Check in the UI:
  [ ] AI > Triggers: Fix CI/CD Pipeline on Pipeline events → Failed
  [ ] Settings > General > GitLab Duo: CI/CD runner check passing (Self-Managed)
  [ ] Secure: SAST profile and Triage and Remediation profile attached (Ultimate)
EOF
}

# ───────────────────────────────────────────────────────────────── apply ────

BACKUP_FILE=""
PLAN=()   # entries: kind<TAB>path<TAB>field<TAB>current

plan_fields() { # plan_fields <kind> <path> <json> <field>...
  local kind="$1" path="$2" json="$3" f v; shift 3
  for f in "$@"; do
    v="$(field "$json" "$f")"
    case "$v" in
      true) ;;
      absent) say "$path" "$f: not available on this instance, skipped" ;;
      *) PLAN+=("$kind	$path	$f	$v"); say "$path" "$f: $v → true" ;;
    esac
  done
}

plan_label() { # plan_label <path>
  if ! glab api "projects/$(enc "$1")/labels/$(enc "$FIX_LABEL")" >/dev/null 2>&1; then
    PLAN+=("label	$1	$FIX_LABEL	missing"); say "$1" "label $FIX_LABEL: missing → create"
  fi
}

write_backup() {
  BACKUP_FILE="setup-backup-$(date +%Y%m%d-%H%M%S).json"
  printf '%s\n' "${PLAN[@]}" | jq -R -s '
    split("\n") | map(select(length > 0) | split("\t")
      | select(.[0] != "label")
      | {kind: .[0], path: .[1], field: .[2], value: .[3]})' > "$BACKUP_FILE"
  echo "Previous values saved to $BACKUP_FILE (setup.sh restore $BACKUP_FILE)"
}

put_fields() { # put_fields <kind> <path> <field>...: PUT field=true, report
  local kind="$1" path="$2" args=() f out; shift 2
  [ $# -gt 0 ] || return 0
  for f in "$@"; do args+=(-F "$f=true"); done
  if ! out="$(glab api -X PUT "${kind}s/$(enc "$path")" "${args[@]}" 2>&1)"; then
    say "$path" "failed: $(printf '%s' "$out" | tail -n 1)"; return 0
  fi
  for f in "$@"; do
    if [ "$(field "$out" "$f")" = true ]; then say "$path" "$f: on"
    else say "$path" "$f: not applied (needs Ultimate, or not available)"; fi
  done
}

execute_plan() {
  local kind path entry fields ultimate
  for entry in "${PLAN[@]}"; do
    IFS=$'\t' read -r kind path _ _ <<<"$entry"
    case "$kind" in
      label)
        if glab api -X POST "projects/$(enc "$path")/labels" -f name="$FIX_LABEL" -f color="#dc143c" \
             -f description="Default-branch pipeline is broken; set by Fix CI/CD Pipeline MRs" >/dev/null 2>&1
        then say "$path" "label $FIX_LABEL: created"; else say "$path" "label $FIX_LABEL: could not create"; fi ;;
    esac
  done
  # One PUT per entity for the core fields, and a separate one for the
  # Ultimate-only fields so a lower tier keeps the core settings.
  for path in $(printf '%s\n' "${PLAN[@]}" | awk -F'\t' '$1 != "label" {print $1 "\t" $2}' | sort -u | tr '\t' '|'); do
    kind="${path%%|*}"; path="${path#*|}"
    fields=() ultimate=()
    while IFS=$'\t' read -r k p f _; do
      [ "$k" = "$kind" ] && [ "$p" = "$path" ] || continue
      case " ${ULTIMATE_FIELDS[*]} " in *" $f "*) ultimate+=("$f") ;; *) fields+=("$f") ;; esac
    done < <(printf '%s\n' "${PLAN[@]}")
    put_fields "$kind" "$path" ${fields[@]+"${fields[@]}"}
    put_fields "$kind" "$path" ${ultimate[@]+"${ultimate[@]}"}
  done
}

finish_apply() {
  echo
  if [ ${#PLAN[@]} -eq 0 ]; then echo "Already on the recommended settings. Nothing to change."; return 0; fi
  if [ "$DRY_RUN" = 1 ]; then echo "Dry run: nothing changed."; return 0; fi
  confirm "Apply these ${#PLAN[@]} changes?"
  write_backup
  execute_plan
}

plan_project() { # plan_project <path>
  local json; json="$(glab api "projects/$(enc "$1")")"
  if [ "$(printf '%s' "$json" | jq -r '.archived')" = true ]; then say "$1" "archived, skipped"; return 0; fi
  plan_fields project "$1" "$json" "${PROJECT_FIELDS[@]}" "${ULTIMATE_FIELDS[@]}"
  plan_label "$1"
}

apply_group() {
  need glab; need jq
  local group="$1" json
  hr; echo "Group: $group"
  json="$(glab api "groups/$(enc "$group")")"
  plan_fields group "$group" "$json" "${GROUP_FIELDS[@]}"
  finish_apply
  cat <<'EOF'

Not automated yet: select the foundational flows for the group.
  Settings > GitLab Duo > Change configuration > Flow execution
  → Allow flow execution, Allow foundational flows, then check each flow.
EOF
}

apply_project() {
  need glab; need jq
  hr; echo "Project: $1"
  plan_project "$1"
  finish_apply
  print_trigger_steps
}

apply_all_projects() {
  need glab; need jq
  local group="$1" p n=0
  hr; echo "All projects in $group (including subgroups)"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$((n + 1)); plan_project "$p"
  done < <(glab api --paginate "groups/$(enc "$group")/projects?include_subgroups=true&archived=false&simple=true&per_page=100" \
            | jq -r '.[].path_with_namespace')
  echo "  $n projects checked"
  finish_apply
  print_trigger_steps
}

print_trigger_steps() {
  cat <<'EOF'

Not automated yet: the Fix CI/CD Pipeline trigger, once per project.
  AI > Triggers > New trigger
  → Event: Pipeline events → Failed
  → Flow: Fix CI/CD Pipeline

On Ultimate, attaching the Triage and Remediation profile replaces the two
SAST settings:
  setup.sh profiles <top-level-group>
  setup.sh attach <profile-gid> <group/project>
EOF
}

restore() {
  need glab; need jq
  local file="$1" kind path f v
  [ -f "$file" ] || die "no such file: $file"
  hr; echo "Restoring from $file"
  jq -r '.[] | "\(.kind)\t\(.path)\t\(.field)\t\(.value)"' "$file" |
    while IFS=$'\t' read -r kind path f v; do say "$path" "$f: → $v"; done
  [ "$DRY_RUN" = 1 ] && { echo "Dry run: nothing changed."; return 0; }
  confirm "Restore these values?"
  jq -r '.[] | select(.value == "true" or .value == "false") | "\(.kind)\t\(.path)\t\(.field)\t\(.value)"' "$file" |
    while IFS=$'\t' read -r kind path f v; do
      if glab api -X PUT "${kind}s/$(enc "$path")" -F "$f=$v" >/dev/null 2>&1
      then say "$path" "$f: $v"; else say "$path" "$f: failed"; fi
    done
  echo "Labels created by apply are left in place."
}

# ────────────────────────────────────────────────────────────── profiles ────

list_profiles() {
  need glab; need jq
  hr; echo "Security scan profiles available to $1"
  glab api graphql -f query='query($g: ID!) { group(fullPath: $g) { availableSecurityScanProfiles { id name } } }' \
    -f g="$1" | jq -r '.data.group.availableSecurityScanProfiles[] | "  \(.id)\t\(.name)"'
}

attach_profile() {
  need glab; need jq
  local pid
  hr; echo "Attaching $1 to $2"
  pid="$(glab api "projects/$(enc "$2")" | jq -r .id)"
  glab api graphql -f query='mutation($p: ID!, $project: ID!) {
      securityScanProfileAttach(input: { securityScanProfileId: $p, projectIds: [$project] }) { errors } }' \
    -f p="$1" -f project="gid://gitlab/Project/$pid" \
    | jq -r '.data.securityScanProfileAttach.errors | if length == 0 then "  done" else "  errors: \(.)" end'
}

# ────────────────────────────────────────────────────────────────── init ────

ROOT="" CHANGES=0

status() { # status <path> <what>
  say "$1" "$2"
  case "$2" in created*|updated*|"would "*) CHANGES=$((CHANGES + 1)) ;; esac
}

render() { # render <template> <out>: fill {{HOST}} {{OWNERS}} {{TEST_COMMAND}} {{SETUP_SCRIPT}}
  T_HOST="$INIT_HOST" T_OWNERS="$INIT_OWNERS" T_TEST="$INIT_TEST" T_SETUP="$INIT_SETUP" awk '
    function repl(s, k, v,   i, out) {
      out = ""
      while ((i = index(s, k)) > 0) { out = out substr(s, 1, i - 1) v; s = substr(s, i + length(k)) }
      return out s
    }
    $0 == "{{SETUP_SCRIPT}}" { print ENVIRON["T_SETUP"]; next }
    {
      $0 = repl($0, "{{HOST}}", ENVIRON["T_HOST"])
      $0 = repl($0, "{{OWNERS}}", ENVIRON["T_OWNERS"])
      $0 = repl($0, "{{TEST_COMMAND}}", ENVIRON["T_TEST"])
      print
    }' "$1" > "$2"
}

place() { # place <rel-path> <new-file> <how>: how = keep (never replace) | replace
  local rel="$1" new="$2" how="$3" dest="$ROOT/$1"
  if [ ! -e "$dest" ]; then
    [ "$DRY_RUN" = 1 ] && { status "$rel" "would create"; return 0; }
    mkdir -p "$(dirname "$dest")"; cat "$new" > "$dest"; status "$rel" "created"
  elif cmp -s "$new" "$dest"; then
    status "$rel" "unchanged"
  elif [ "$how" = replace ] || [ "$FORCE" = 1 ]; then
    [ "$DRY_RUN" = 1 ] && { status "$rel" "would update"; return 0; }
    cat "$new" > "$dest"; status "$rel" "updated"
  else
    status "$rel" "exists, kept (--force replaces it)"
  fi
}

upsert_block() { # upsert_block <rel-path> <block-file>: insert or replace the managed block
  local rel="$1" block="$2" dest="$ROOT/$1" tmp
  tmp="$(mktemp)"
  if [ -f "$dest" ] && grep -qF "$MARK_BEGIN" "$dest"; then
    grep -qF "$MARK_END" "$dest" || die "$rel has a '$MARK_BEGIN' marker but no '$MARK_END'; fix it by hand"
    B="$MARK_BEGIN" E="$MARK_END" BLK="$block" awk '
      index($0, ENVIRON["B"]) && !done { while ((getline l < ENVIRON["BLK"]) > 0) print l; skip = 1; done = 1; next }
      skip && index($0, ENVIRON["E"]) { skip = 0; next }
      !skip { print }' "$dest" > "$tmp"
  elif [ -f "$dest" ]; then
    { cat "$dest"; [ -z "$(tail -c 1 "$dest")" ] || echo; echo; cat "$block"; } > "$tmp"
  else
    cat "$block" > "$tmp"
  fi
  place "$rel" "$tmp" replace
  rm -f "$tmp"
}

merge_mcp_json() { # merge_mcp_json <rel-path> <template-output>: add the GitLab server to an existing file
  local rel="$1" new="$2" dest="$ROOT/$1" tmp
  if [ -f "$dest" ]; then
    need jq
    if jq -e '.mcpServers.GitLab' "$dest" >/dev/null 2>&1 && [ "$FORCE" != 1 ]; then
      status "$rel" "has a GitLab server, kept (--force replaces it)"; return 0
    fi
    tmp="$(mktemp)"
    jq --slurpfile t "$new" '.mcpServers = ((.mcpServers // {}) + $t[0].mcpServers)' "$dest" > "$tmp"
    place "$rel" "$tmp" replace; rm -f "$tmp"
  else
    place "$rel" "$new" keep
  fi
}

merge_codex_toml() {
  local rel=.codex/config.toml new="$1" dest="$ROOT/.codex/config.toml" tmp
  if [ -f "$dest" ]; then
    if grep -q '^\[mcp_servers\.GitLab\]' "$dest" && [ "$FORCE" != 1 ]; then
      status "$rel" "has a GitLab server, kept (--force replaces it)"; return 0
    fi
    tmp="$(mktemp)"
    { awk '/^\[/ { skip = ($0 ~ /^\[mcp_servers\.GitLab(\.|\])/) } !skip' "$dest"
      echo; sed -n '/^\[mcp_servers\.GitLab\]/,$p' "$new"; } > "$tmp"
    place "$rel" "$tmp" replace; rm -f "$tmp"
  else
    place "$rel" "$new" keep
  fi
}

skill_version() { sed -n 's/^  version: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$1/SKILL.md" 2>/dev/null | head -n 1; }

install_skill() { # install_skill <kit-skill-dir> <rel-dest-parent>
  local src="$1" name; name="$(basename "$1")"
  local rel="$2/$name" dest="$ROOT/$2/$name" have want
  want="$(skill_version "$src")"
  if [ ! -d "$dest" ]; then
    [ "$DRY_RUN" = 1 ] && { status "$rel/" "would create (v$want)"; return 0; }
    mkdir -p "$ROOT/$2"; cp -R "$src" "$dest"; status "$rel/" "created (v$want)"; return 0
  fi
  if diff -rq "$src" "$dest" >/dev/null 2>&1; then status "$rel/" "unchanged (v$want)"; return 0; fi
  have="$(skill_version "$dest")"
  if [ "$have" = "$want" ] && [ "$FORCE" != 1 ]; then
    status "$rel/" "modified locally, kept (--force replaces it)"; return 0
  fi
  [ "$DRY_RUN" = 1 ] && { status "$rel/" "would update (v${have:-?} → v$want)"; return 0; }
  rm -rf "$dest"; cp -R "$src" "$dest"; status "$rel/" "updated (v${have:-?} → v$want)"
}

detect_stack() { # sets INIT_SETUP and INIT_TEST from files in the repository
  local s="" t=""
  if   [ -f "$ROOT/requirements.txt" ];  then s="pip install -r requirements.txt"; t="pytest -q"
  elif [ -f "$ROOT/pyproject.toml" ];    then s="pip install ."; t="pytest -q"
  elif [ -f "$ROOT/pnpm-lock.yaml" ];    then s="pnpm install --frozen-lockfile"; t="pnpm test"
  elif [ -f "$ROOT/yarn.lock" ];         then s="yarn install --frozen-lockfile"; t="yarn test"
  elif [ -f "$ROOT/package-lock.json" ]; then s="npm ci"; t="npm test"
  elif [ -f "$ROOT/go.mod" ];            then s="go mod download"; t="go test ./..."
  elif [ -f "$ROOT/Gemfile" ];           then s="bundle install"; t="bundle exec rake test"
  elif [ -f "$ROOT/pom.xml" ];           then s="mvn -B -q dependency:go-offline"; t="mvn -B test"
  elif [ -f "$ROOT/gradlew" ];           then s="./gradlew --no-daemon dependencies"; t="./gradlew test"
  elif [ -f "$ROOT/Cargo.toml" ];        then s="cargo fetch"; t="cargo test"
  fi
  if [ -n "$s" ]; then
    INIT_SETUP="setup_script:
  - $s"
    INIT_TEST="$t"
  else
    INIT_SETUP="# setup_script:
#   - <command that installs your dependencies>"
    INIT_TEST="<how to run the tests>"
  fi
}

existing_owner() { # owner named in an existing managed CODEOWNERS block, if any
  local f
  for f in CODEOWNERS docs/CODEOWNERS .gitlab/CODEOWNERS; do
    [ -f "$ROOT/$f" ] || continue
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
      index($0, b) { on = 1; next } index($0, e) { on = 0 }
      on && $0 !~ /^#/ && $0 !~ /^\[/ && NF >= 2 { print $2; exit }' "$ROOT/$f"
    return 0
  done
}

codeowners_path() { # first existing CODEOWNERS location, as GitLab looks them up
  local f
  for f in CODEOWNERS docs/CODEOWNERS .gitlab/CODEOWNERS; do [ -f "$ROOT/$f" ] && { echo "$f"; return 0; }; done
  echo .gitlab/CODEOWNERS
}

init_repo() {
  need git; need awk
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run setup.sh init inside a git repository"
  [ "$ROOT" != "$KIT_DIR" ] || die "run init in your project's repository, not in the kit itself"
  INIT_HOST="${HOST:-$(remote_host "$ROOT")}"; INIT_HOST="${INIT_HOST:-gitlab.com}"
  INIT_OWNERS="${OWNERS:-$(existing_owner)}"; INIT_OWNERS="${INIT_OWNERS:-$PLACEHOLDER_OWNER}"
  detect_stack

  local T="$KIT_DIR/templates" tmp s
  INIT_TMP="$(mktemp -d)"; trap 'rm -rf "$INIT_TMP"' EXIT; tmp="$INIT_TMP"
  hr; echo "Installing into $ROOT"
  say "GitLab host" "$INIT_HOST$([ -n "$HOST" ] || echo ' (from origin; --host overrides)')"
  say "Code owners" "$INIT_OWNERS"
  say "Dependency setup" "$(printf '%s' "$INIT_SETUP" | sed -n 's/^  - //p' | head -n 1)"
  [ "$DRY_RUN" = 1 ] && echo "  (dry run: nothing is written)"
  echo

  render "$T/AGENTS.gitlab.md" "$tmp/agents-block"
  if [ ! -f "$ROOT/AGENTS.md" ]; then
    render "$T/AGENTS.new.md" "$tmp/agents"; cat "$tmp/agents-block" >> "$tmp/agents"
    place AGENTS.md "$tmp/agents" keep
  else
    upsert_block AGENTS.md "$tmp/agents-block"
  fi

  if [ ! -f "$ROOT/CLAUDE.md" ]; then
    place CLAUDE.md "$T/CLAUDE.md" keep
  elif grep -q '^@AGENTS.md' "$ROOT/CLAUDE.md"; then
    status CLAUDE.md "imports AGENTS.md"
  else
    status CLAUDE.md "exists; add a line '@AGENTS.md' so Claude Code reads AGENTS.md"
  fi

  for s in agent-config.yml mr-review-instructions.yaml mr-review-automated-rules.yaml; do
    render "$T/.gitlab/duo/$s" "$tmp/$s"; place ".gitlab/duo/$s" "$tmp/$s" keep
  done

  render "$T/.gitlab/CODEOWNERS" "$tmp/codeowners"
  upsert_block "$(codeowners_path)" "$tmp/codeowners"

  render "$T/.mcp.json" "$tmp/mcp.json"; merge_mcp_json .mcp.json "$tmp/mcp.json"
  render "$T/.cursor/mcp.json" "$tmp/cursor.json"; merge_mcp_json .cursor/mcp.json "$tmp/cursor.json"
  render "$T/.codex/config.toml" "$tmp/codex.toml"; merge_codex_toml "$tmp/codex.toml"

  for s in "$KIT_DIR"/skills/*/; do
    install_skill "${s%/}" .agents/skills
    install_skill "${s%/}" .claude/skills
  done

  echo
  if [ "$DRY_RUN" = 1 ]; then echo "Dry run: $CHANGES files would change."; return 0; fi
  echo "$CHANGES changes. Next:"
  echo "  - Review them: git status && git diff"
  [ "$INIT_OWNERS" != "$PLACEHOLDER_OWNER" ] ||
    echo "  - Set real code owners: setup.sh init --owners @<group>/<team>"
  grep -qs 'SAST' "$ROOT/.gitlab-ci.yml" ||
    echo "  - On Ultimate, add SAST: include 'template: Jobs/SAST.gitlab-ci.yml' in .gitlab-ci.yml, or attach a scan profile"
  echo "  - Commit and merge, then turn on \"Require approval from code owners\" for the default branch"
  echo "  - After updating the kit, run init again: it updates the skills and the GitLab sections only"
}

# ─────────────────────────────────────────────────────────────── connect ────

connect() {
  local which="${1:-all}" host url
  host="${HOST:-$(remote_host .)}"; host="${host:-gitlab.com}"
  url="https://$host/api/v4/mcp"
  hr; echo "Connecting your clients to $url (user-level config)"
  if [ -f .mcp.json ] && grep -q '"GitLab"' .mcp.json 2>/dev/null; then
    echo "  Note: this repository already configures the GitLab server for its clients."
    echo "  User-level config is for repositories that don't; having both shows duplicate tools."
  fi
  case "$which" in all|claude|codex|cursor) ;; *) usage ;; esac
  [ "$which" = all ] || [ "$which" = claude ] && connect_claude "$url"
  [ "$which" = all ] || [ "$which" = codex ] && connect_codex "$url"
  [ "$which" = all ] || [ "$which" = cursor ] && connect_cursor "$url"
  return 0
}

connect_claude() {
  if ! command -v claude >/dev/null 2>&1; then say "Claude Code" "not installed, skipped"; return 0; fi
  if claude mcp get GitLab >/dev/null 2>&1; then say "Claude Code" "GitLab server already configured"; return 0; fi
  [ "$DRY_RUN" = 1 ] && { say "Claude Code" "would run: claude mcp add -s user --transport http GitLab $1"; return 0; }
  claude mcp add -s user --transport http GitLab "$1" --header "X-Gitlab-Enabled-Mcp-Server-Toolsets: $TOOLSETS" >/dev/null
  say "Claude Code" "added; run claude, then /mcp → GitLab → authenticate"
}

connect_codex() {
  local cfg="$HOME/.codex/config.toml"
  if ! command -v codex >/dev/null 2>&1; then say "Codex" "not installed, skipped"; return 0; fi
  if grep -qs '^\[mcp_servers\.GitLab\]' "$cfg"; then say "Codex" "GitLab server already in $cfg"; return 0; fi
  [ "$DRY_RUN" = 1 ] && { say "Codex" "would add [mcp_servers.GitLab] to $cfg"; return 0; }
  mkdir -p "$(dirname "$cfg")"
  printf '\n[mcp_servers.GitLab]\nurl = "%s"\nhttp_headers = { "X-Gitlab-Enabled-Mcp-Server-Toolsets" = "%s" }\n' "$1" "$TOOLSETS" >> "$cfg"
  say "Codex" "added to $cfg; run: codex mcp login GitLab"
}

connect_cursor() {
  need jq
  local cfg="$HOME/.cursor/mcp.json" tmp entry
  if [ ! -d "$HOME/.cursor" ]; then say "Cursor" "not installed, skipped"; return 0; fi
  if jq -e '.mcpServers.GitLab' "$cfg" >/dev/null 2>&1; then say "Cursor" "GitLab server already in $cfg"; return 0; fi
  [ "$DRY_RUN" = 1 ] && { say "Cursor" "would add GitLab to $cfg"; return 0; }
  entry="$(jq -n --arg u "$1" --arg t "$TOOLSETS" '{url: $u, headers: {"X-Gitlab-Enabled-Mcp-Server-Toolsets": $t}}')"
  tmp="$(mktemp)"
  if [ -f "$cfg" ]; then jq --argjson e "$entry" '.mcpServers.GitLab = $e' "$cfg" > "$tmp"
  else jq -n --argjson e "$entry" '{mcpServers: {GitLab: $e}}' > "$tmp"; fi
  cat "$tmp" > "$cfg"; rm -f "$tmp"
  say "Cursor" "added to $cfg; Settings → Tools & MCP → GitLab → connect"
}

# ──────────────────────────────────────────────────────────────── doctor ────

FAILS=0
ok()   { printf '  ok    %s\n' "$*"; }
warn() { printf '  warn  %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; FAILS=$((FAILS + 1)); }

doctor() {
  local host path code json level f v kitv
  hr; echo "Checking this machine and repository"

  git rev-parse --show-toplevel >/dev/null 2>&1 || die "run doctor inside your project's repository"
  host="${HOST:-$(remote_host .)}"
  if [ -n "$host" ]; then ok "origin is on $host"; else fail "no origin remote; pass --host"; host=gitlab.com; fi
  path="$(git remote get-url origin 2>/dev/null | sed -E 's#^[a-z+]+://[^/]+/##; s#^[^@]+@[^:]+:##; s#\.git$##')"

  for f in glab jq curl; do command -v "$f" >/dev/null 2>&1 && ok "$f installed" || fail "$f not installed"; done
  if command -v glab >/dev/null 2>&1; then
    glab auth status --hostname "$host" >/dev/null 2>&1 && ok "glab authenticated to $host" ||
      fail "glab not authenticated to $host: glab auth login --hostname $host"
  fi

  if command -v curl >/dev/null 2>&1; then
    code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "https://$host/api/v4/mcp" || true)"
    case "$code" in
      401|403) ok "MCP endpoint answers at https://$host/api/v4/mcp (needs sign-in, as expected)" ;;
      2??|405|406) ok "MCP endpoint answers at https://$host/api/v4/mcp" ;;
      404) fail "MCP endpoint not found on $host: the instance is too old or MCP is off for the group" ;;
      *)   warn "MCP endpoint returned HTTP $code" ;;
    esac
  fi

  if command -v glab >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && [ -n "$path" ] &&
     json="$(glab api --hostname "$host" "projects/$(enc "$path")" 2>/dev/null)"; then
    level="$(printf '%s' "$json" | jq -r '[.permissions.project_access.access_level // 0, .permissions.group_access.access_level // 0] | max')"
    if [ "$level" -ge 30 ]; then ok "your role on $path can start flows (access level $level)"
    else fail "your role on $path is below Developer (access level $level); flows and replies need Developer"; fi
    for f in duo_remote_flows_enabled auto_duo_code_review_enabled; do
      v="$(field "$json" "$f")"
      [ "$v" = true ] && ok "$f on" || warn "$f: $v (ask a Maintainer to run setup.sh apply project $path)"
    done
  else
    warn "could not read the project from GitLab; skipped role and settings checks"
  fi

  grep -qsF "$MARK_BEGIN" AGENTS.md && ok "AGENTS.md has the GitLab section" || fail "AGENTS.md has no GitLab section: run setup.sh init"
  grep -qs '^@AGENTS.md' CLAUDE.md && ok "CLAUDE.md imports AGENTS.md" || warn "CLAUDE.md doesn't import AGENTS.md (Claude Code)"
  for f in .mcp.json .cursor/mcp.json .codex/config.toml; do
    if [ ! -f "$f" ]; then warn "$f missing (or use setup.sh connect)"
    elif ! grep -qs 'duo_agent_platform' "$f"; then warn "$f has no toolsets header; Duo and security tools may be missing"
    elif ! grep -qs "$host" "$f"; then warn "$f doesn't point at $host"
    else ok "$f points at $host"; fi
  done
  for f in "$KIT_DIR"/skills/*/; do
    f="$(basename "$f")"; kitv="$(skill_version "$KIT_DIR/skills/$f")"
    for d in .agents/skills .claude/skills; do
      v="$(skill_version "$d/$f")"
      if [ -z "$v" ]; then fail "$d/$f missing: run setup.sh init"
      elif [ "$v" != "$kitv" ]; then warn "$d/$f is v$v, kit has v$kitv: run setup.sh init"
      else ok "$d/$f v$v"; fi
    done
  done

  echo
  if [ "$FAILS" -eq 0 ]; then echo "No problems found."; else echo "$FAILS problems found."; exit 1; fi
}

# ────────────────────────────────────────────────────────────────── main ────

POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  YES=1 ;;
    --force)   FORCE=1 ;;
    --host)    HOST="${2:?--host needs a value}"; shift ;;
    --owners)  OWNERS="${2:?--owners needs a value}"; shift ;;
    -h|--help) usage ;;
    --*)       die "unknown option: $1" ;;
    *)         POS+=("$1") ;;
  esac
  shift
done
set -- ${POS[@]+"${POS[@]}"}

cmd="${1:-}"; shift || true
case "$cmd" in
  check)
    [ $# -eq 2 ] || usage
    case "$1" in group) check_group "$2" ;; project) check_project "$2" ;; *) usage ;; esac ;;
  apply)
    [ $# -eq 2 ] || usage
    case "$1" in
      group) apply_group "$2" ;; project) apply_project "$2" ;; all-projects) apply_all_projects "$2" ;;
      *) usage ;;
    esac ;;
  restore)  [ $# -eq 1 ] || usage; restore "$1" ;;
  profiles) [ $# -eq 1 ] || usage; list_profiles "$1" ;;
  attach)   [ $# -eq 2 ] || usage; attach_profile "$1" "$2" ;;
  init)     [ $# -eq 0 ] || usage; init_repo ;;
  connect)  [ $# -le 1 ] || usage; connect "${1:-all}" ;;
  doctor)   [ $# -eq 0 ] || usage; doctor ;;
  *) usage ;;
esac
