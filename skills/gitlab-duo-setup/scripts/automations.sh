#!/usr/bin/env bash
# automations.sh: create the Fix CI/CD Pipeline automation in every project of a
# top-level group (or in the projects you name), in one predictable run.
#
# Does SKILL.md steps 3b and 3c: waits until GitLab has set up Fix CI/CD Pipeline
# in each project, skips projects that already have the automation, creates it
# in the rest, and retries when GitLab rate-limits saves. Dry run by default.
#
#   automations.sh --group my-group                 # show what it would do
#   automations.sh --group my-group --apply         # do it
#   automations.sh --project my-group/app --apply   # project mode
#
# Needs glab (signed in) and jq. Safe to re-run: it never creates duplicates.
# Exit codes: 0 done, 2 bad input, 3 finished with projects left (re-run later).
set -euo pipefail

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

GROUP="" ; PROJECTS=() ; HOST="" ; APPLY=0 ; WAIT=600
while [[ $# -gt 0 ]]; do
  case "$1" in
    --group|--project|--hostname|--wait)
      [[ $# -ge 2 && -n ${2:-} && ${2:-} != --* ]] || { echo "$1 needs a value" >&2; exit 2; } ;;
  esac
  case "$1" in
    --group) GROUP="${2%%/*}"; shift 2 ;;
    --project) PROJECTS+=("$2"); shift 2 ;;
    --hostname) HOST="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --wait) WAIT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n $GROUP || ${#PROJECTS[@]} -gt 0 ]] || { usage >&2; exit 2; }
[[ $WAIT =~ ^[0-9]+$ ]] || { echo "--wait must be a number of seconds" >&2; exit 2; }
for c in glab jq; do command -v "$c" >/dev/null || { echo "$c is required" >&2; exit 2; }; done
[[ -n $HOST ]] || HOST=$(glab config get host 2>/dev/null || true); [[ -n $HOST ]] || HOST=gitlab.com

TMP=$(mktemp -d); trap 'rm -rf -- "$TMP"' EXIT
api() { glab api --hostname "$HOST" "$@"; }
enc() { jq -rn --arg v "$1" '$v|@uri'; }
gql() {  # gql QUERY VARIABLES_JSON -> .data; non-zero on GraphQL errors
  jq -n --arg q "$1" --argjson v "$2" '{query:$q, variables:$v}' > "$TMP/q.json"
  local out; out=$(api graphql -H 'Content-Type: application/json' --input "$TMP/q.json") || return 1
  if [[ $(jq '.errors // [] | length' <<<"$out") != 0 ]]; then jq -c '[.errors[].message]' <<<"$out" >&2; return 1; fi
  jq '.data' <<<"$out"
}
say() { printf '%-60s %s\n' "$1" "$2"; }

# ---------- projects ----------
if [[ -n $GROUP ]]; then
  GROUP_ID=$(api "groups/$(enc "$GROUP")?with_projects=false" | jq -r '.id')
  while IFS=$'\t' read -r path ci empty; do
    if [[ $ci == disabled ]]; then say "$path" "skipped: CI/CD is off"
    elif [[ $empty == true ]]; then say "$path" "skipped: empty repository"
    else PROJECTS+=("$path"); fi
  done < <(api --paginate "groups/$GROUP_ID/projects?include_subgroups=true&archived=false&per_page=100" |
             jq -rs 'flatten | .[] | select(.marked_for_deletion_on == null)
                     | [.path_with_namespace, (.builds_access_level // "enabled"), (.empty_repo // false | tostring)] | @tsv' | sort -u)
else
  GROUP="${PROJECTS[0]%%/*}"
  GROUP_ID=$(api "groups/$(enc "$GROUP")?with_projects=false" | jq -r '.id')
fi

# ---------- the Fix CI/CD Pipeline catalog item ----------
# From the group's flows if GitLab has set the flow up there. Right after step 3a it usually hasn't:
# GitLab does that in background jobs, which can take minutes or, on a busy day, hours. Then take the
# item from the catalog and let the per-project wait below decide when each project is ready.
ITEM=$(gql 'query($g: GroupID!){ aiCatalogConfiguredItems(groupId:$g, includeFoundationalConsumers:true, first:100){ nodes { enabled item { id foundationalFlowReference } } } }' \
  "$(jq -n --arg g "gid://gitlab/Group/$GROUP_ID" '{g:$g}')" |
  jq -r '[.aiCatalogConfiguredItems.nodes[] | select(.enabled and .item.foundationalFlowReference == "fix_pipeline/v1") | .item.id][0] // empty')
if [[ -z $ITEM ]]; then
  CURSOR=null
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    page=$(gql 'query($a: String){ aiCatalogCustomAndFoundationalItems(itemTypes:[FLOW], first:100, after:$a){ pageInfo { hasNextPage endCursor } nodes { ... on AiCatalogFlow { id foundationalFlowReference } } } }' \
      "$(jq -n --argjson a "$CURSOR" '{a:$a}')") || break
    ITEM=$(jq -r '[.aiCatalogCustomAndFoundationalItems.nodes[] | select(.foundationalFlowReference == "fix_pipeline/v1") | .id][0] // empty' <<<"$page")
    [[ -n $ITEM || $(jq -r '.aiCatalogCustomAndFoundationalItems.pageInfo.hasNextPage' <<<"$page") != true ]] && break
    CURSOR=$(jq '.aiCatalogCustomAndFoundationalItems.pageInfo.endCursor' <<<"$page")
  done
  [[ -n $ITEM ]] || { echo "Can't find the Fix CI/CD Pipeline flow in the AI Catalog on $HOST." >&2; exit 2; }
  echo "GitLab hasn't set up Fix CI/CD Pipeline for $GROUP yet. That runs in the background after step 3a."
  echo "Don't send the step 3a request again: waiting for each project instead."
fi

READY_Q='query($p: ID!, $i: AiCatalogItemID!){ project(fullPath:$p){
  duoWorkflowRunnerAvailable
  aiCatalogItemConsumerForItem(id:$i, includeInherited:false){ id serviceAccount { id state } parentItemConsumer { serviceAccount { id state } } }
  aiFlowTriggers(first:100){ nodes { active eventTypes aiCatalogItemConsumer { item { foundationalFlowReference } } } } } }'
CREATE_M='mutation($i: AiFlowTriggerCreateInput!){ aiFlowTriggerCreate(input:$i){ aiFlowTrigger { id } errors errorReason } }'

# state PROJECT -> one line: exists | inactive | notready | ready <consumer gid>; plus " norunner"
state() {
  gql "$READY_Q" "$(jq -n --arg p "$1" --arg i "$ITEM" '{p:$p, i:$i}')" | jq -r '
    .project as $p
    | ([$p.aiFlowTriggers.nodes[] | select(.aiCatalogItemConsumer.item.foundationalFlowReference == "fix_pipeline/v1" and (.eventTypes | index(3)))]) as $t
    | ($p.aiCatalogItemConsumerForItem) as $c
    | (($c.serviceAccount // $c.parentItemConsumer.serviceAccount) // null) as $sa
    | (if ($p.duoWorkflowRunnerAvailable == false) then " norunner" else "" end) as $r
    | if   any($t[]; .active) then "exists\($r)"
      elif ($t | length) > 0 then "inactive\($r)"
      elif $c == null or $sa == null or ($sa.state // "active") != "active" then "notready\($r)"
      else "ready \($c.id)\($r)" end'
}

create() {  # create PROJECT CONSUMER_GID
  # No userId: with a catalog entry GitLab uses the entry's own service account (references/graphql.md).
  local input out errs try=1
  input=$(jq -n --arg p "$1" --arg c "$2" '{projectPath:$p, description:"Fix CI/CD Pipeline on failed pipelines (gitlab-duo-setup 0.5.7)",
    eventTypes:[3], aiCatalogItemConsumerId:$c,
    filter:{pipeline_hooks:{match:"all", rules:[{field:"object_attributes.status", operator:"eq", value:"failed"}]}}}')
  while :; do
    out=$(gql "$CREATE_M" "$(jq -n --argjson i "$input" '{i:$i}')" 2>&1) || { echo "error: $out"; return 1; }
    errs=$(jq -c '.aiFlowTriggerCreate.errors' <<<"$out")
    [[ $errs == "[]" ]] && { echo "created"; return 0; }
    # GitLab allows about 30 saves of agents, flows or automations a minute per user.
    if [[ $errs == *"too many times"* && $try -le 3 ]]; then
      echo "rate limited by GitLab, waiting 65s (try $try of 3)" >&2; sleep 65; try=$((try+1)); continue
    fi
    echo "error: $errs $(jq -r '.aiFlowTriggerCreate.errorReason // ""' <<<"$out")"; return 1
  done
}

# ---------- run ----------
echo "Fix CI/CD Pipeline automation in ${#PROJECTS[@]} project(s) of $GROUP on $HOST ($([[ $APPLY == 1 ]] && echo apply || echo "dry run"))"
CREATED=0; EXISTING=0; INACTIVE=(); FAILED=(); NORUNNER=(); PENDING=()
handle() {  # handle PROJECT STATE_LINE -> 0 when settled, 1 when still waiting
  local p="$1" s="$2"
  [[ $s == *norunner* ]] && { NORUNNER+=("$p"); s="${s% norunner}"; }
  case "$s" in
    exists) say "$p" "already has it"; EXISTING=$((EXISTING+1)) ;;
    inactive) say "$p" "has one that's turned off; left alone"; INACTIVE+=("$p") ;;
    notready) return 1 ;;
    ready*)
      if [[ $APPLY == 0 ]]; then say "$p" "would create"; CREATED=$((CREATED+1)); return 0; fi
      local cons="${s#ready }"
      local r; if r=$(create "$p" "$cons"); then say "$p" "$r"; CREATED=$((CREATED+1)); else say "$p" "$r"; FAILED+=("$p"); fi ;;
  esac
  return 0
}
for p in "${PROJECTS[@]}"; do
  s=$(state "$p" 2>/dev/null) || { say "$p" "error: can't read the project"; FAILED+=("$p"); continue; }
  handle "$p" "$s" || PENDING+=("$p")
done

if [[ ${#PENDING[@]} -gt 0 && $APPLY == 1 && $WAIT -gt 0 ]]; then
  echo "Waiting up to ${WAIT}s for GitLab to set up Fix CI/CD Pipeline in ${#PENDING[@]} project(s)..."
  START=$(date +%s)
  while [[ ${#PENDING[@]} -gt 0 ]] && (( $(date +%s) - START < WAIT )); do
    sleep 30; LEFT=()
    for p in "${PENDING[@]}"; do
      s=$(state "$p" 2>/dev/null) || { LEFT+=("$p"); continue; }
      handle "$p" "$s" || LEFT+=("$p")
    done
    PENDING=(${LEFT[@]+"${LEFT[@]}"})
  done
fi
for p in ${PENDING[@]+"${PENDING[@]}"}; do say "$p" "not set up by GitLab yet; re-run later"; done

echo
echo "$([[ $APPLY == 1 ]] && echo Created || echo "Would create") $CREATED, already there $EXISTING, turned off ${#INACTIVE[@]}, not ready ${#PENDING[@]}, failed ${#FAILED[@]}."
[[ ${#NORUNNER[@]} -gt 0 ]] && echo "No runner can pick up flow jobs in: ${NORUNNER[*]}"
jq -cn --argjson created "$CREATED" --argjson existing "$EXISTING" \
  --arg inactive "${INACTIVE[*]-}" --arg pending "${PENDING[*]-}" --arg failed "${FAILED[*]-}" --arg norunner "${NORUNNER[*]-}" \
  '{created:$created, existing:$existing} + ([["inactive",$inactive],["pending",$pending],["failed",$failed],["no_runner",$norunner]]
    | map({(.[0]): (.[1] | split(" ") | map(select(. != "")))}) | add) | "RESULT " + tojson' -r
[[ ${#PENDING[@]} -eq 0 && ${#FAILED[@]} -eq 0 ]] || exit 3
