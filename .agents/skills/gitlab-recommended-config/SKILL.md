---
name: gitlab-recommended-config
description: Check whether a GitLab project and its top-level group are on the recommended GitLab configuration for agentic engineering, and report exactly what is on, off, or missing with the settings page to fix each item. Use this whenever the user asks if GitLab Duo is set up, why a review or pipeline fix did not run, whether flows are enabled, how to turn on automatic code review or SAST remediation, or anything about "the recommended configuration", "DAP setup", "Duo settings", or "is this project ready". Also use it when gitlab-checks finds that a flow it expected is not running. Read-only: it reports, and gives the exact command or settings page for each change.
compatibility: Requires glab authenticated to the instance (glab auth status) and jq. Reading group settings requires the Owner role on the top-level group.
---

# gitlab-recommended-config

Settings that make GitLab run review, pipeline repair, and security flows
automatically live in several places: the top-level group, the project's GitLab
Duo settings, the project's Merge requests settings, AI > Triggers, and Secure.
When a flow "didn't run", the cause is nearly always one of them being off. This
skill reads them all and produces one readiness report.

This skill is read-only. It never changes a setting. For each change it gives
the user the command to run or the exact settings page.

## Step 1: Identify the project and group

- Project path from `git remote get-url origin` unless the user names one.
- Top-level group is the first path segment.
- Encode paths for the API: replace `/` with `%2F`.

## Step 2: Read the project

```
glab api "projects/<encoded path>"
```

Read these fields from the response (all documented on the Projects API):

| Field | Use case it enables | Where to turn on |
|---|---|---|
| `duo_remote_flows_enabled` | Any flow can run in this project | Settings > General > GitLab Duo > Allow flow execution |
| `duo_foundational_flows_enabled` | Foundational flows allowed here | Settings > General > GitLab Duo > Allow foundational flows |
| `auto_duo_code_review_enabled` | Review every MR | Settings > Merge requests > GitLab Duo Code Review > Enable automatic reviews |
| `duo_code_review_decisions_enabled` | Duo can approve / request changes (beta, optional) | Settings > Merge requests > GitLab Duo Code Review |
| `duo_sast_fp_detection_enabled` | SAST false positive detection (Ultimate) | Settings > General > GitLab Duo > Turn on SAST false positive detection |
| `duo_sast_vr_workflow_enabled` | Agentic vulnerability resolution (Ultimate) | Settings > General > GitLab Duo > Turn on SAST vulnerability resolution workflow |

If a field is missing from the response, the instance is older than the field or
the user cannot see it; report "unknown" rather than "off".

## Step 3: Read the group

```
glab api "groups/<encoded top-level group>"
```

Read `duo_features_enabled`, `duo_availability`, and if present
`duo_agent_platform_enabled` and `duo_workflow_mcp_enabled`. These confirm Duo,
the Agent Platform, and MCP access are on for the group.

Which foundational flows are selected for the group (Code Review, Fix CI/CD
Pipeline, SAST False Positive Detection, Resolve SAST Vulnerability, Security
Review, Recommend Reviewers, Generate Workplan) is not exposed as a plain group
field in the REST API. Check it from the project side instead:

```
list_duo_agents_and_flows   (MCP, project_id, item_type: "flow")
```

A flow that is selected for the group and allowed in the project appears with
`can_start_session: true`. One that is missing from the list is not enabled for
this project. Tell the user which of the seven are present.

## Step 4: Read the automation that is not a toggle

- **Fix pipeline trigger**: open AI > Triggers in the project and look for a
  trigger on Pipeline events → Failed using the Fix CI/CD Pipeline flow. There
  is no documented MCP tool for triggers; say so and link the page.
- **Security profiles (Ultimate)**: `glab security config status` (experimental)
  reports the profiles attached to the project. Look for a SAST profile and a
  Triage and Remediation profile. If the Triage and Remediation profile is
  attached, it replaces the two project-level SAST toggles above; report it as
  "covered by profile".
- **Repository files**: check that `.gitlab/duo/agent-config.yml` and
  `.gitlab/duo/mr-review-instructions.yaml` exist on the default branch.
- **Runner**: on GitLab Self-Managed, confirm Settings > General > GitLab Duo
  shows the CI/CD runner check as passing. On GitLab.com hosted runners are used.

## Step 5: Report

```
## Readiness: <project>

| Use case | Status | Fix |
|---|---|---|
| Flows can run here | on / off / unknown | <settings path or setup.sh command> |
| Review every MR | ... | ... |
| Repair failed pipelines (trigger) | present / missing / unchecked | ... |
| SAST false positive detection (Ultimate) | ... | ... |
| SAST vulnerability resolution (Ultimate) | ... | ... |
| Group: Duo + Agent Platform + MCP | ... | ... |
| Flows selected for the group | <n>/7 — missing: ... | Settings > GitLab Duo (top-level group) |
| agent-config.yml / review instructions | present / missing | commit from this repo |

Next: <the commands below that apply to the rows that are off>
```

For the project-level rows (Maintainer role), give the user one command. If the
repository contains `setup/setup.sh`, that is
`bash setup/setup.sh apply project <path>`. Otherwise:

```
glab api -X PUT "projects/<encoded path>" \
  -F duo_remote_flows_enabled=true \
  -F duo_foundational_flows_enabled=true \
  -F auto_duo_code_review_enabled=true
```

On Ultimate, add `-F duo_sast_fp_detection_enabled=true -F duo_sast_vr_workflow_enabled=true`.
Do not run these yourself. Selecting flows for the group is a one-time task for
an Owner of the top-level group: Settings > GitLab Duo > Change configuration >
Flow execution.

Keep every status to one of: `on`, `off`, `present`, `missing`, `covered by
profile`, `unknown`, `unchecked`. Do not infer a status from a related setting;
each row comes from its own field or page.
