#!/usr/bin/env bash
# automations.sh: create the Fix CI/CD Pipeline automation in every project of a
# top-level group (or in the projects you name), in one predictable run.
#
# Does SKILL.md steps 3b and 3c: waits until GitLab has set up Fix CI/CD Pipeline
# in each project, skips projects that already have the automation, creates it
# in the rest, and retries when GitLab rate-limits saves. Automations an earlier
# version created get the push-and-MR-only rule added. Dry run by default.
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

# The automation this skill creates. The description marks it as made by the skill.
# Only pipelines from a push or a merge request start a session: a scheduled pipeline that
# keeps failing would otherwise start a new session on every run, and API, trigger and
# Duo's own session pipelines (source duo_workflow) are left out for the same reason.
DESC="Fix CI/CD Pipeline on failed pipelines (gitlab-duo-setup 0.5.9)"
DESC_PREFIX="Fix CI/CD Pipeline on failed pipelines"
FILTER='{"pipeline_hooks":{"match":"all","rules":[{"field":"object_attributes.status","operator":"eq","value":"failed"},{"field":"object_attributes.source","operator":"in","value":["push","merge_request_event"]}]}}'

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
  aiFlowTriggers(first:100){ nodes { id description active eventTypes filter aiCatalogItemConsumer { item { foundationalFlowReference } } } } } }'
CREATE_M='mutation($i: AiFlowTriggerCreateInput!){ aiFlowTriggerCreate(input:$i){ aiFlowTrigger { id } errors errorReason } }'
UPDATE_M='mutation($i: AiFlowTriggerUpdateInput!){ aiFlowTriggerUpdate(input:$i){ aiFlowTrigger { id } errors errorReason } }'

# state PROJECT -> one line: exists | inactive | notready | ready <consumer gid>;
# then " norunner" if no runner can run flows, then " upgrade=<trigger gids>" for automations
# an earlier version of this skill created with only the status rule.
state() {
  gql "$READY_Q" "$(jq -n --arg p "$1" --arg i "$ITEM" '{p:$p, i:$i}')" | jq -r --arg pre "$DESC_PREFIX" '
    .project as $p
    | ([$p.aiFlowTriggers.nodes[] | select(.aiCatalogItemConsumer.item.foundationalFlowReference == "fix_pipeline/v1" and (.eventTypes | index(3)))]) as $t
    | ([$t[] | select((.description // "" | startswith($pre))
                      and (((.filter | if type == "string" then (try fromjson catch {}) else (. // {}) end)
                            | .pipeline_hooks.rules // [] | map(.field)) == ["object_attributes.status"]))
           | .id]) as $old
    | ($p.aiCatalogItemConsumerForItem) as $c
    | (($c.serviceAccount // $c.parentItemConsumer.serviceAccount) // null) as $sa
    | (if ($p.duoWorkflowRunnerAvailable == false) then " norunner" else "" end) as $r
    | (if ($old | length) > 0 then " upgrade=" + ($old | join(",")) else "" end) as $u
    | if   any($t[]; .active) then "exists\($r)\($u)"
      elif ($t | length) > 0 then "inactive\($r)\($u)"
      elif $c == null or $sa == null or ($sa.state // "active") != "active" then "notready\($r)"
      else "ready \($c.id)\($r)" end'
}

mutate() {  # mutate MUTATION VARIABLES_JSON PAYLOAD_KEY -> 0 on success, else prints the error
  local out errs try=1
  while :; do
    out=$(gql "$1" "$2" 2>&1) || { echo "error: $out"; return 1; }
    errs=$(jq -c --arg k "$3" '.[$k].errors' <<<"$out")
    [[ $errs == "[]" ]] && return 0
    # GitLab allows about 30 saves of agents, flows or automations a minute per user.
    if [[ $errs == *"too many times"* && $try -le 3 ]]; then
      echo "rate limited by GitLab, waiting 65s (try $try of 3)" >&2; sleep 65; try=$((try+1)); continue
    fi
    echo "error: $errs $(jq -r --arg k "$3" '.[$k].errorReason // ""' <<<"$out")"; return 1
  done
}

create() {  # create PROJECT CONSUMER_GID
  # No userId: with a catalog entry GitLab uses the entry's own service account (references/graphql.md).
  local input
  input=$(jq -n --arg p "$1" --arg c "$2" --arg d "$DESC" --argjson f "$FILTER" \
    '{projectPath:$p, description:$d, eventTypes:[3], aiCatalogItemConsumerId:$c, filter:$f}')
  mutate "$CREATE_M" "$(jq -n --argjson i "$input" '{i:$i}')" aiFlowTriggerCreate && echo "created"
}

upgrade() {  # upgrade PROJECT COMMA_SEPARATED_TRIGGER_GIDS
  # Adds the push-and-MR-only rule and the new description. Leaves active as it is.
  local id r
  for id in ${2//,/ }; do
    if [[ $APPLY == 0 ]]; then
      say "$1" "would limit its automation to push and MR pipelines"; UPGRADED=$((UPGRADED+1)); continue
    fi
    if r=$(mutate "$UPDATE_M" "$(jq -n --arg id "$id" --arg d "$DESC" --argjson f "$FILTER" '{i:{id:$id, description:$d, filter:$f}}')" aiFlowTriggerUpdate); then
      say "$1" "limited its automation to push and MR pipelines"; UPGRADED=$((UPGRADED+1))
    else
      say "$1" "$r"; FAILED+=("$1")
    fi
  done
}

# ---------- run ----------
echo "Fix CI/CD Pipeline automation in ${#PROJECTS[@]} project(s) of $GROUP on $HOST ($([[ $APPLY == 1 ]] && echo apply || echo "dry run"))"
CREATED=0; EXISTING=0; UPGRADED=0; INACTIVE=(); FAILED=(); NORUNNER=(); PENDING=()
handle() {  # handle PROJECT STATE_LINE -> 0 when settled, 1 when still waiting
  local p="$1" s="$2" up=""
  if [[ $s == *" upgrade="* ]]; then up="${s##* upgrade=}"; s="${s% upgrade=*}"; fi
  [[ $s == *norunner* ]] && { NORUNNER+=("$p"); s="${s% norunner}"; }
  case "$s" in
    exists) say "$p" "already has it"; EXISTING=$((EXISTING+1)); [[ -n $up ]] && upgrade "$p" "$up" ;;
    inactive) say "$p" "has one that's turned off; left off"; INACTIVE+=("$p"); [[ -n $up ]] && upgrade "$p" "$up" ;;
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
echo "$([[ $APPLY == 1 ]] && echo Created || echo "Would create") $CREATED, already there $EXISTING, $([[ $APPLY == 1 ]] && echo limited || echo "would limit") to push and MR pipelines $UPGRADED, turned off ${#INACTIVE[@]}, not ready ${#PENDING[@]}, failed ${#FAILED[@]}."
[[ ${#NORUNNER[@]} -gt 0 ]] && echo "No runner can pick up flow jobs in: ${NORUNNER[*]}"
jq -cn --argjson created "$CREATED" --argjson existing "$EXISTING" --argjson upgraded "$UPGRADED" \
  --arg inactive "${INACTIVE[*]-}" --arg pending "${PENDING[*]-}" --arg failed "${FAILED[*]-}" --arg norunner "${NORUNNER[*]-}" \
  '{created:$created, existing:$existing, upgraded:$upgraded} + ([["inactive",$inactive],["pending",$pending],["failed",$failed],["no_runner",$norunner]]
    | map({(.[0]): (.[1] | split(" ") | map(select(. != "")))}) | add) | "RESULT " + tojson' -r
[[ ${#PENDING[@]} -eq 0 && ${#FAILED[@]} -eq 0 ]] || exit 3
