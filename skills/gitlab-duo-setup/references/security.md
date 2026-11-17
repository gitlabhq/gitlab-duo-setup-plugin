# Security flows

All of these need GitLab Ultimate. On Premium, skip this file and say the
security flows need Ultimate.

Checked against GitLab's source and docs (19.6). Profiles and their
mutations are marked **Experiment** by GitLab.

## The flows

| Flow | Reference | Maturity | What it needs |
|---|---|---|---|
| Security Review | `security_review/v1` | Beta | Nothing in CI. Reviews the MR diff. |
| SAST False Positive Detection | `sast_fp_detection/v1` | GA | SAST running in CI |
| Secret Detection False Positive Detection | `secrets_fp_detection/v1` | GA | Secret detection running in CI |
| Resolve SAST Vulnerability | `resolve_sast_vulnerability/v1` | GA | SAST in CI, and SAST False Positive Detection on |

Every flow is turned on once, for the top-level group, by adding its
reference to `enabled_foundational_flows` in the single group request
(SKILL.md 3a). Then each one starts in its own way:

- **Security Review** starts when someone assigns its service account as a
  reviewer on an MR, or mentions it. Take the username from
  `serviceAccount.username` on its `groupFlows` entry (it looks like
  `duo-security-review-<GROUP>`). The coding agent can assign it for the
  user. It posts findings as diff threads, keeps them in an internal note on
  public projects, and replies to mentions with internal notes on any project
  that isn't private. It never approves.
  Automatic reviews on new MRs need the Security Review profile (below).
  Cost: about 8 to 20 credits per review, billed to the MR author for
  automatic reviews.
- **SAST False Positive Detection** runs after a SAST scan finishes on the
  default branch (and other tracked branches), for High and Critical
  findings. It scores each finding and explains it.
- **Secret Detection False Positive Detection** does the same for secret
  detection findings.
- **Resolve SAST Vulnerability** opens an MR with a fix for each High or
  Critical SAST finding that triage didn't flag as a false positive. Each MR
  goes through the normal review.

Without SAST in CI, the three triage and remediation flows have nothing to
work on. Check before proposing them: if a project has never produced SAST
results, offer the SAST profile (level 3) or point to the SAST docs.

## Security Review is beta

GitLab only offers a beta flow to a group that has opted in to experiment and
beta features: on GitLab.com that's the group's `experiment_features_enabled`;
on Self-Managed and Dedicated it's an instance setting an admin controls.
Without it, Security Review can be selected but never runs. If the group's
`experiment_features_enabled` is `false`, tell the user:

- Security Review needs experiment and beta features on for the group.
- That setting turns on every beta and experimental AI feature in the group,
  not only this flow. It's a group policy decision.

Only if the user says yes, add `"experiment_features_enabled": true` to the
group request. Otherwise leave Security Review out, and say why. On
Self-Managed and Dedicated, give the admin the instance setting instead.

## Levels to offer

1. **Security Review only.** Add `security_review/v1`. Nothing else.
2. **Plus triage and remediation.** Also add `sast_fp_detection/v1`,
   `secrets_fp_detection/v1` and `resolve_sast_vulnerability/v1`. Then apply
   the automated triage and remediation profile to the group. Recommend the
   **Conservative** preset first: triage and fixes run on demand for High and
   above, with at most five open fix MRs per project. **Standard** runs
   automatically for Medium and above, with up to 15 open MRs. **Proactive**
   runs on everything with no MR limit. Use `FILL_PROFILE_GAPS` so projects
   that already have a profile keep it.
3. **Plus automatic coverage.** Apply the SAST profile with `FILL_SCAN_GAPS`,
   which turns on SAST only in projects that don't scan yet, without editing
   `.gitlab-ci.yml`. Optionally the secret detection profile the same way.
   And apply the Security Review profile, so new non-draft MRs get a security
   review automatically (beta).

Credits for the triage and remediation flows scale with the number of
findings. Say so in the plan.

## Read the available profiles

Needs the Security Manager, Maintainer or Owner role in the group.

```bash
glab api graphql -F group="$GROUP" -f query='
query($group: ID!) {
  group(fullPath: $group) {
    availableSecurityScanProfiles { id name scanType gitlabRecommended projectCount }
  }
}'
```

Default profiles that haven't been used yet have IDs built from their key,
for example:

- `gid://gitlab/Security::ScanProfile/sast`
- `gid://gitlab/Security::ScanProfile/triage_and_remediation_conservative`
  (also `_standard` and `_proactive`)
- `gid://gitlab/Security::ScanProfile/business_logic_security_review`
  (the Security Review profile)

Take the IDs from this read rather than typing them; the names and keys can
change.

## Apply a profile to the whole group

One mutation per profile. Passing the group applies the profile to every
project in the group and its subgroups, in the background.

```bash
glab api graphql -F profile="<profile id>" -F group="gid://gitlab/Group/<group id>" -f query='
mutation($profile: SecurityScanProfileID!, $group: GroupID!) {
  securityScanProfileAttach(input: {
    securityScanProfileId: $profile,
    groupIds: [$group],
    mode: FILL_PROFILE_GAPS
  }) {
    errors
  }
}'
```

- `mode`: `SET` (the default) replaces any profile of the same type on every
  project. The enum also has `REPLACE` and `APPEND`; this skill doesn't use
  them. Use `FILL_PROFILE_GAPS` to skip projects that already have one, or
  `FILL_SCAN_GAPS` for scanner profiles (SAST, secret detection) to skip
  projects that already scan. `FILL_SCAN_GAPS` doesn't work for the triage and
  remediation profile.
- Errors for individual projects aren't returned when you pass a group. After
  a minute, read the profiles again and report `projectCount`.
- To undo, use `securityScanProfileDetach` with the same IDs.

## Project mode

Without group Owner, the user can't turn the flows on for the group. If the
group already has them, a Maintainer or Security Manager can turn them on for
the project with the Projects API, one field per request:

```bash
glab api -X PUT "projects/$ENC" -F duo_sast_fp_detection_enabled=true
glab api -X PUT "projects/$ENC" -F duo_secret_detection_fp_enabled=true
glab api -X PUT "projects/$ENC" -F duo_sast_vr_workflow_enabled=true
```

A triage and remediation profile, if one is applied, replaces these
per-project settings.

## Docs

- Security Review: https://docs.gitlab.com/user/application_security/security_review/
- SAST false positive detection: https://docs.gitlab.com/user/application_security/vulnerabilities/false_positive_detection/
- Agentic SAST vulnerability resolution: https://docs.gitlab.com/user/application_security/vulnerabilities/agentic_vulnerability_resolution/
- Security configuration profiles: https://docs.gitlab.com/user/application_security/configuration/security_configuration_profiles/
