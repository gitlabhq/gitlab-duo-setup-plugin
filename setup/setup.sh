#!/usr/bin/env bash
# setup.sh — recommended GitLab configuration for agentic engineering
#
# Reads or applies the settings that make GitLab review every MR, repair failed
# pipelines, and triage/resolve SAST findings automatically.
#
# Usage:
#   setup/setup.sh check   group   <top-level-group-path>
#   setup/setup.sh check   project <group/project-path>
#   setup/setup.sh apply   group   <top-level-group-path>      # Owner role
#   setup/setup.sh apply   project <group/project-path>        # Maintainer role
#   setup/setup.sh profiles        <top-level-group-path>      # list security profiles (Ultimate)
#   setup/setup.sh attach          <profile-gid> <group/project-path>
#
# Requirements: glab (authenticated: `glab auth status`), jq.
#
# Everything marked CONFIRMED uses fields or mutations documented in the GitLab
# 19.6 API reference. Everything marked VERIFY is the documented mechanism but
# the exact ids or integer codes must be confirmed on a live instance before
# this script applies it. Until then those steps print what to do.

set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1" >&2; exit 1; }; }
need glab; need jq

enc() { printf '%s' "$1" | jq -sRr @uri; }

hr() { printf '\n%s\n' "────────────────────────────────────────────────────────"; }

show() { # show <json> <field...>
  local json="$1"; shift
  for f in "$@"; do
    printf '  %-40s %s\n' "$f" "$(printf '%s' "$json" | jq -r --arg f "$f" '.[$f] // "unknown"')"
  done
}

# ──────────────────────────────────────────────────────────────── group ────

check_group() {
  local group="$1"
  hr; echo "Top-level group: $group"
  local json; json="$(glab api "groups/$(enc "$group")")"
  echo "CONFIRMED fields (REST Groups API):"
  show "$json" duo_features_enabled duo_availability duo_agent_platform_enabled duo_workflow_mcp_enabled
  cat <<'EOF'

Not readable as plain REST fields, check in the UI
(Settings > GitLab Duo > Change configuration > Flow execution):
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

apply_group() {
  local group="$1"
  hr; echo "Applying group settings: $group"
  echo "CONFIRMED: PUT groups/:id duo_features_enabled, duo_agent_platform_enabled, duo_workflow_mcp_enabled"
  glab api -X PUT "groups/$(enc "$group")" \
    -F duo_features_enabled=true \
    -F duo_agent_platform_enabled=true \
    -F duo_workflow_mcp_enabled=true >/dev/null
  echo "  done"
  cat <<'EOF'

VERIFY before automating — selecting the foundational flows for the group.
The documented mechanism is the GraphQL mutation aiCatalogItemConsumerCreate
with the top-level group as target and consumerKind INHERITANCE, one call per
flow. The catalog item ids for the foundational flows must be looked up on the
instance first. Until that is confirmed, select them in the UI:
  Settings > GitLab Duo > Change configuration > Flow execution
  → Allow flow execution, Allow foundational flows, then check each flow.

Example shape (fill itemId after lookup):
  glab api graphql -f query='
    mutation {
      aiCatalogItemConsumerCreate(input: {
        itemId: "gid://gitlab/Ai::Catalog::Item/<ID>",
        consumerKind: INHERITANCE,
        target: { groupId: "gid://gitlab/Group/<GROUP_ID>" }
      }) { errors }
    }'
EOF
}

# ──────────────────────────────────────────────────────────── project ────

PROJECT_FIELDS=(duo_remote_flows_enabled duo_foundational_flows_enabled auto_duo_code_review_enabled duo_code_review_decisions_enabled duo_sast_fp_detection_enabled duo_sast_vr_workflow_enabled)

check_project() {
  local project="$1"
  hr; echo "Project: $project"
  local json; json="$(glab api "projects/$(enc "$project")")"
  echo "CONFIRMED fields (REST Projects API):"
  show "$json" "${PROJECT_FIELDS[@]}"
  local id; id="$(printf '%s' "$json" | jq -r .id)"
  local default_branch; default_branch="$(printf '%s' "$json" | jq -r .default_branch)"
  echo
  echo "Repository files on $default_branch:"
  for f in .gitlab/duo/agent-config.yml .gitlab/duo/mr-review-instructions.yaml .gitlab/CODEOWNERS AGENTS.md; do
    if [ "$f" = .gitlab/CODEOWNERS ] &&
       glab api "projects/$id/repository/files/$(enc "$f")/raw?ref=$default_branch" 2>/dev/null |
         grep -q '@your-group/maintainers'; then
      printf '  %-40s placeholder owner, replace @your-group/maintainers\n' "$f"
    elif glab api "projects/$id/repository/files/$(enc "$f")?ref=$default_branch" >/dev/null 2>&1; then
      printf '  %-40s present\n' "$f"
    else
      printf '  %-40s missing\n' "$f"
    fi
  done
  cat <<'EOF'

Check in the UI (no documented read API used here):
  [ ] AI > Triggers: Fix CI/CD Pipeline on Pipeline events → Failed
  [ ] Settings > General > GitLab Duo: CI/CD runner check passing (Self-Managed)
  [ ] Secure: SAST profile and Triage and Remediation profile attached (Ultimate)
      or run: glab security config status
EOF
}

apply_project() {
  local project="$1"
  hr; echo "Applying project settings: $project"
  echo "CONFIRMED: PUT projects/:id with the duo_* and auto_duo_code_review_enabled fields"
  glab api -X PUT "projects/$(enc "$project")" \
    -F duo_remote_flows_enabled=true \
    -F duo_foundational_flows_enabled=true \
    -F auto_duo_code_review_enabled=true >/dev/null
  echo "  done: flow execution, foundational flows, automatic code review"
  echo "  (duo_code_review_decisions_enabled left unchanged; it is beta)"

  # The SAST fields are Ultimate-only. Apply them in a separate call so a lower
  # tier keeps the settings above, and confirm they stuck rather than trusting
  # a 200 that may have ignored them.
  local out
  if out="$(glab api -X PUT "projects/$(enc "$project")" \
      -F duo_sast_fp_detection_enabled=true \
      -F duo_sast_vr_workflow_enabled=true 2>/dev/null)" &&
     printf '%s' "$out" | jq -e '.duo_sast_fp_detection_enabled == true and .duo_sast_vr_workflow_enabled == true' >/dev/null; then
    echo "  done: SAST false positive detection, SAST vulnerability resolution"
  else
    echo "  skipped: SAST false positive detection and vulnerability resolution"
    echo "           were not applied (they need Ultimate)"
  fi
  cat <<'EOF'

VERIFY before automating — the fix-pipeline trigger.
The documented mechanism is the GraphQL mutation aiFlowTriggerCreate with
projectPath, description, eventTypes (integers; the enum value is
PIPELINE_HOOKS), the Fix CI/CD Pipeline flow's aiCatalogItemConsumerId, and the
flow's service account as userId. Confirm the integer for PIPELINE_HOOKS and
whether `filter` can scope to the default branch, then automate. Until then:
  AI > Triggers > New trigger
  → Condition: On an event → Pipeline events → Failed
  → Service account: duo-fix-pipeline-<group>
  → Flow: Fix CI/CD Pipeline

On Ultimate, attach the Triage and Remediation profile instead of relying on
the two per-project SAST toggles:
  setup/setup.sh profiles <top-level-group>
  setup/setup.sh attach <profile-gid> <project-path>
EOF
}

# ───────────────────────────────────────────────────────────── profiles ────

list_profiles() {
  local group="$1"
  hr; echo "Security scan profiles available to $group (CONFIRMED: Group.availableSecurityScanProfiles)"
  glab api graphql -f query="
    query { group(fullPath: \"$group\") { availableSecurityScanProfiles { id name } } }" \
    | jq -r '.data.group.availableSecurityScanProfiles[] | "  \(.id)\t\(.name)"'
}

attach_profile() {
  local profile_gid="$1" project="$2"
  hr; echo "Attaching $profile_gid to $project (CONFIRMED: securityScanProfileAttach)"
  local pid; pid="$(glab api "projects/$(enc "$project")" | jq -r .id)"
  glab api graphql -f query="
    mutation {
      securityScanProfileAttach(input: {
        securityScanProfileId: \"$profile_gid\",
        projectIds: [\"gid://gitlab/Project/$pid\"]
      }) { errors }
    }" | jq -r '.data.securityScanProfileAttach.errors | if length == 0 then "  done" else "  errors: \(.)" end'
}

# ───────────────────────────────────────────────────────────────── main ────

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

cmd="${1:-}"; shift || true
case "$cmd" in
  check)
    [ $# -eq 2 ] || usage
    case "$1" in group) check_group "$2";; project) check_project "$2";; *) usage;; esac ;;
  apply)
    [ $# -eq 2 ] || usage
    case "$1" in group) apply_group "$2";; project) apply_project "$2";; *) usage;; esac ;;
  profiles) [ $# -eq 1 ] || usage; list_profiles "$1" ;;
  attach)   [ $# -eq 2 ] || usage; attach_profile "$1" "$2" ;;
  *) usage ;;
esac
