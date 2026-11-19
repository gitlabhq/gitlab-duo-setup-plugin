# Security triage and remediation (SKILL.md Step 5)

Only for groups on GitLab Ultimate, only in group mode, and only after the
core setup worked. If any call here fails, stop, quote the error, give the
link to finish by hand, and leave the core setup alone.

Checked against GitLab's source and docs (19.6). Security profiles and their
mutations are marked **Experiment** by GitLab.

## What gets turned on

| Flow | Reference | Maturity | What it does |
|---|---|---|---|
| SAST False Positive Detection | `sast_fp_detection/v1` | GA | Scores SAST findings (Medium and above with the Standard profile) and explains each one |
| Secret Detection False Positive Detection | `secrets_fp_detection/v1` | GA | The same for secret detection findings |
| Resolve SAST Vulnerability | `resolve_sast_vulnerability/v1` | GA | Opens a merge request that fixes a finding triage didn't flag as a false positive |

These flows work on findings from scans on the default branch (and other
tracked branches), not inside a merge request. Say so plainly: the outcome is
less security debt once code lands, not a gate on the merge request.

Without a scanner the flows have nothing to work on, which is why the SAST
and secret detection profiles go on first: SAST feeds SAST False Positive
Detection and Resolve SAST Vulnerability, and secret detection feeds Secret
Detection False Positive Detection.

## 1. Add the flows to the group

Build `CURRENT_FLOWS` again as in SKILL.md 1c (`groupFlows` to the last page,
plus the project's `enabledFoundationalFlows`), because Step 3 changed it. If
all three flows are already in it, skip this request. Otherwise send one
request:

```bash
glab api -X PUT "groups/$GROUP_ID" -H "Content-Type: application/json" --input - <<'EOF'
{
  "enabled_foundational_flows": ["<CURRENT_FLOWS...>", "sast_fp_detection/v1", "secrets_fp_detection/v1", "resolve_sast_vulnerability/v1"]
}
EOF
```

Same rules as SKILL.md 3a: current flows plus the new ones, never fewer. If
GitLab answers with a rate limit error, because Step 3 just changed the group,
wait a minute and send it once more. Then read `groupFlows` again and check
the three flows are listed, and that the project has no fewer flows than
before.

Resolve SAST Vulnerability starts on its own (after a scan, or in bulk from
the vulnerability report) only in projects where the triage and remediation
profile in step 3 applies, or where the project setting
`duo_sast_vr_workflow_enabled` is on. GitLab checks either one. A manual run
on a single finding works without them.

## Find SAST findings

To list a project's SAST findings, for the summary or for a manual run:

```bash
glab api graphql -F project="<path_with_namespace>" -f query='
query($project: ID!) {
  project(fullPath: $project) {
    sast: vulnerabilitySeveritiesCount(reportType: [SAST]) { critical high medium low }
    vulnerabilities(first: 20, reportType: [SAST], state: [DETECTED, CONFIRMED], sort: severity_desc) {
      nodes { id title severity webUrl location { ... on VulnerabilityLocationSast { file startLine } } }
    }
  }
}'
```

The numeric part of `id` is the goal for a manual Resolve SAST Vulnerability
run (SKILL.md Step 7). Before starting one, check `mergeRequest` on the
vulnerability, so you don't rerun a finding that already has a fix MR.
Don't skip a finding because `falsePositive` is `true`: it's `true` whenever
the finding has any false positive flag, including one that concluded the
finding is real. Dismissed findings are already left out by the `state`
filter above. SAST here includes infrastructure-as-code findings (KICS): the
flow takes them too.

## Read findings over MCP

If the user turned on the `code_security` toolset (SKILL.md Step 5), prefer
the MCP tools over the `glab` read above:

- `list_vulnerabilities`: a project's findings, filterable by severity,
  report type and state.
- `get_vulnerability`: one finding. Since gitlab-org/gitlab!271041 (merged
  2026-11-17; Self-Managed from 19.7) it also returns `dismissalReason`,
  `stateComment`, `confirmedBy` and `dismissedBy`, so the agent can tell why
  a finding was dismissed, not only that it was.

These tools need Ultimate. If they aren't listed after the reload, check the
header includes `code_security` and the defaults (`references/harnesses.md`).

## 2. Read the available profiles

```bash
glab api graphql -F group="$GROUP" -f query='
query($group: ID!) {
  group(fullPath: $group) {
    availableSecurityScanProfiles { id name scanType gitlabRecommended projectCount }
  }
}'
```

Three profiles are needed from this read:

- The default SAST profile (`scanType: SAST`, `gitlabRecommended: true`).
- The default secret detection profile (`scanType: SECRET_DETECTION`,
  `gitlabRecommended: true`).
- The triage and remediation profile named
  `Triage and Remediation (Standard)`.

Default profiles that haven't been used yet have IDs built from their key:

- `gid://gitlab/Security::ScanProfile/sast`
- `gid://gitlab/Security::ScanProfile/triage_and_remediation_standard`
  (also `_standard` and `_proactive`)

Take the IDs from this read rather than typing them; the names and keys can
change. That goes for the secret detection profile too: pick it by its
`scanType`, not by a guessed ID.

## 3. Apply the SAST and secret detection profiles, then the triage and remediation profile

Before the first profile mutation, make sure the user heard the Step 5 CI
warning and agreed to proceed: in projects without `workflow:rules`, scan
profiles can create a separate MR pipeline that appears green while tests
fail in a branch pipeline. The skill does not change `.gitlab-ci.yml`. Tell
the user to check both pipeline types and configure `workflow:rules` and job
rules so the intended MR pipeline includes both tests and scans. See
https://docs.gitlab.com/ci/yaml/workflow/#switch-between-branch-pipelines-and-merge-request-pipelines.

One mutation per profile, three in all, in this order: SAST, secret
detection, triage and remediation. Passing the group applies the profile to every
project in the group and its subgroups, in the background.

```bash
glab api graphql -F profile="<profile id>" -F group="gid://gitlab/Group/<group id>" -f query='
mutation($profile: SecurityScanProfileID!, $group: GroupID!) {
  securityScanProfileAttach(input: {
    securityScanProfileId: $profile,
    groupIds: [$group],
    mode: FILL_SCAN_GAPS
  }) {
    errors
  }
}'
```

- **SAST profile**: `mode: FILL_SCAN_GAPS`. It turns on SAST only in projects
  that don't scan yet, and skips the rest. No `.gitlab-ci.yml` edits.
  - **Secret detection profile:** `mode: FILL_SCAN_GAPS`. It turns on secret
  detection only in projects that have no pipeline secret detection yet, and
  skips the rest. No `.gitlab-ci.yml` edits. Only pipeline scans count as
  coverage here, so a project that has secret push protection but no
  pipeline scan still gets the profile. Tell the user before applying it:
  the default profile also turns on secret push protection, which blocks
  pushes that contain a secret, in the projects it's applied to.
- **Triage and remediation profile**: `mode: FILL_PROFILE_GAPS`, so projects
  that already have one keep it. `FILL_SCAN_GAPS` doesn't work for this
  profile.

Presets for the triage and remediation profile:

| Preset | False positive detection | Vulnerability resolution |
|---|---|---|
| Conservative | High and above, on demand | High and above, on demand, at most 5 open fix MRs per project |
| Standard (Default) | Medium and above, automatic | Medium and above, automatic, at most 15 open fix MRs |
| Proactive | Everything, automatic | Everything, automatic, no MR limit |

Apply Standard. Before applying it, tell the user what it means: the flows
run automatically after every scan on findings of Medium severity and above,
and credits scale with the number of findings. Offer Conservative instead if
the user wants to see results and cost before going automatic; it runs only
on demand, on High and above.

Errors for individual projects aren't returned when you pass a group. After
a minute, read the profiles again and report `projectCount` for each of the three. To
undo, use `securityScanProfileDetach` with the same IDs.

## Security Review (beta), only if the user asks

Security Review (`security_review/v1`) reviews merge request changes for
business logic vulnerabilities and posts findings as review threads. It
doesn't need a scanner. It's beta: GitLab only offers it to a group that has
experiment and beta features on (`experiment_features_enabled` on GitLab.com;
an instance setting on Self-Managed and Dedicated). That setting turns on
every beta AI feature in the group, so it's a group policy decision.

If the user asks for it:

1. If `experiment_features_enabled` is `false`, explain the above and ask.
   Only on yes, include `"experiment_features_enabled": true`.
2. Add `security_review/v1` to `enabled_foundational_flows` (current flows
   plus this one).
3. A review starts when someone assigns its service account as a reviewer.
   Take the username from `serviceAccount.username` on its `groupFlows`
   entry. The coding agent can assign it for the user. About 8 to 20 credits
   per review.

## Docs

- SAST false positive detection: https://docs.gitlab.com/user/application_security/vulnerabilities/false_positive_detection/
- Secret detection false positive detection: https://docs.gitlab.com/user/application_security/vulnerabilities/secret_false_positive_detection/
- Agentic SAST vulnerability resolution: https://docs.gitlab.com/user/application_security/vulnerabilities/agentic_vulnerability_resolution/
- Security configuration profiles: https://docs.gitlab.com/user/application_security/configuration/security_configuration_profiles/
- Security Review: https://docs.gitlab.com/user/application_security/security_review/
