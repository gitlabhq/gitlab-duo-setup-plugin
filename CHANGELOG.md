# Changelog

## 0.5.5 (2026-11-18)

**Changed**
- The core setup now turns on the Developer flow (`developer/v1`) with Code
  Review and Fix CI/CD Pipeline, as one more line in the plan. Before, it was
  added only if the user asked. The blog's first workflow (hand an issue to
  the Developer flow) and the merge conflict path in `gitlab-mr-followup`
  both start it, and on a new group only Code Review is on by default, so
  those steps failed with "flow not enabled".
- Developer has no automation that runs on its own: it starts only when
  someone assigns it an issue, mentions it, or asks the agent to start it.
  The plan line says so, with its cost (credits per session).
- 4d checks that Developer is listed; Step 7 offers a prompt to try it.

**Not tested yet:** the group request with `developer/v1` added, on a new
group. Same request and rules as the other flows.

## 0.5.4 (2026-11-18)

**Removed**
- AddOn handling: the `addOnPurchases` read, the Code Review consent
  plan line, and `create_code_review_flow_consent` in the group request. The
  skill is for Duo Agent Platform users, and groups on unsupported
  add-ons can't use the other flows it sets up. Nothing else in the setup
  changes.

## 0.5.3 (2026-11-18)

**Fixes**
- `scripts/automations.sh` no longer stops on a new group. It looked up the
  Fix CI/CD Pipeline entry at group level before waiting, and right after
  step 3a GitLab hasn't created that entry yet (it does so in background
  jobs). So on a fresh group it exited at once with "Turn it on for the group
  first", and agents then sent the 3a request again. It now takes the flow
  from the AI Catalog when the group doesn't list it yet, says set-up is
  still running, and waits for each project as before.
- SKILL.md 3b: if projects are still pending, don't send the 3a request
  again. Each repeat queues another background job, and on a busy day an
  older one can finish last and change the flow list back.

**How this was tested.** By Claude (an AI agent) on GitLab.com, 2026-11-18:
- Seen in four of five harnesses on five new Ultimate trial groups: the
  v0.5.2 script exited at once after 3a; three of the sessions then re-sent
  the 3a request.
- The new catalog lookup returns the Fix CI/CD Pipeline item
  (`gid://gitlab/Ai::Catalog::Item/1800`) on the first page.
- shellcheck: no warnings (the same `SC2016` notes as before).
- Not run yet: the changed script end to end on a new group.

## 0.5.2 (2026-11-17)

**Fixes**
- Retry on GitLab's limit of about 30 automation saves a minute per user:
  wait 65 seconds and retry the same project, up to 3 times, instead of
  moving on. Before, in groups with more than about 30 projects, some
  projects silently got no automation until the skill was run again.
- Add `scripts/automations.sh` (optional, needs jq): does steps 3b and 3c in
  one run (readiness wait, duplicate check, create with the retry, summary)
  instead of the agent making hundreds of calls one project at a time.
  Without jq, the manual steps stay as they were, plus the retry rule.
- Runners: read `ip_restriction_ranges` and `shared_runners_setting` on
  GitLab.com and explain when hosted runners can't run flows; say that a
  registered runner isn't proof; treat a first session stuck in `created` as
  a runner problem.

**How this was tested.** These checks were run by Claude (an AI agent), not
yet repeated by a person end to end:
- `scripts/automations.sh` as a dry run on a top-level Ultimate group with
  unsupported addons (19 projects): 15 already had the automation, 3 empty
  projects were skipped, 1 would be created. shellcheck passes. The `--apply`
  path and the retry haven't run yet.
- The `addOnPurchases` read on that group returned `DUO_ENTERPRISE`.
- Earlier, with a separate script that sends the same requests, on the same
  top-level group: `duo_foundational_flows_availability` and a merged flow
  list (3 flows kept, Code Review and Fix CI/CD Pipeline added) with
  `create_code_review_flow_consent`, then automations in 18 projects. That run
  hit the "too many times" error. Afterwards, Code Review flow sessions
  reviewed new MRs and Fix CI/CD Pipeline started on failed pipelines.

## 0.5.1 (2026-11-17)

From testing 0.5.0 on a fresh Ultimate subgroup with 22 projects.

**Fixes**
- Build the group's current flow list from every page of `groupFlows` plus
  the project's `enabledFoundationalFlows`. In a subgroup `groupFlows` is
  empty, and a list built from it alone turned 11 flows off in every project.
  Send `enabled_foundational_flows` only to the top-level group, leave it out
  when nothing changes, and check afterwards that no project lost a flow.
- Skip `groupFlows` entries without a foundational flow reference (custom
  flows, null items), and read past the first page.
- Read readiness 5 projects per GraphQL request. 20 exceeded GitLab's query
  complexity limit.
- Step 7: run Resolve SAST Vulnerability on one finding from the agent with
  `start_duo_session`, and review the fix merge request before merging. Add a
  SAST findings read to `references/security.md`, and note that automatic and
  bulk runs need the triage and remediation profile or
  `duo_sast_vr_workflow_enabled`.
- Restore the copy-paste read for personal-namespace projects.

**Tested on GitLab.com:** automatic Code Review and MCP for Agent Platform
cascading from a group; the flow list cascade; the readiness check and the
automation in 21 projects without `userId`, with no duplicates on a rerun.

**Not tested end to end yet**
- The group request on a top-level group and on Premium, the availability
  fields, and Code Review flow consent.
- Applying security profiles to a group.

## 0.5.0 (2026-11-17)

**Group-wide setup**
- Add group mode for top-level group Owners: one run sets up the group and
  every project in it, instead of only the current project. Project mode
  stays for Maintainers who aren't group Owners.
- Turn on foundational flows with the Groups API (`enabled_foundational_flows`),
  the same path the group settings page and GitLab's end-to-end tests use.
  GitLab then provisions each project in the background. The skill always
  sends the group's current flows plus the new ones, so it never turns a flow
  off.
- Stop creating flow entries with `aiCatalogItemConsumerCreate`. It doesn't
  update the group's flow selection, so the settings page showed the flow as
  off.
- Turn on automatic Code Review at the group level
  (`auto_duo_code_review_enabled`), which cascades to every project. Then
  list any project that kept its own setting.
- Create the Fix CI/CD Pipeline automation in every project with CI/CD, after
  checking each project is provisioned and has no automation yet. Running the
  skill twice creates no duplicates. Fix CI/CD Pipeline has no default
  automation, so this step is always needed.
- Send all group changes in one request, because GitLab rate-limits changes
  that cascade to every project.

**Fixes**
- Group flow execution is now written with `duo_remote_flows_availability`.
  The Groups API ignores `duo_remote_flows_enabled`, so 0.4.0's group write
  had no effect.
- Allow foundational flows is now written with
  `duo_foundational_flows_availability` on the group. The Projects API doesn't
  accept `duo_foundational_flows_enabled`, so 0.4.0's project write had no
  effect; the setting cascades from the group.
- Only send settings that are off, since the `..._availability` fields also
  clear an Owner's lock.
- The automation request no longer sends `userId`. With a catalog entry,
  GitLab uses the entry's service account and rejects a `userId` that doesn't
  match it.
- The readiness check asks for the project's own flow entry
  (`includeInherited: false`), so a project doesn't look ready before GitLab
  has set it up.
- MCP: when an existing `GitLab` entry has a toolsets header without
  `work_items`, offer to rewrite it (from the review of !5).
- The prompts at the end now make each flow run, instead of only reading
  results (from the review of !5).

**Security (Ultimate, optional last step)**
- The core setup (Code Review, Fix CI/CD Pipeline, MCP) asks no security
  questions. After it works, Ultimate groups get one yes/no question (Step 5).
- On yes: turn on the GA SAST and secret false positive detection and Resolve
  SAST Vulnerability flows, apply the SAST profile to projects that don't scan
  yet (`FILL_SCAN_GAPS`, no CI file edits), and apply the automated triage and
  remediation profile (Conservative preset recommended).
- If anything in the security step fails, it stops there and leaves the core
  setup as it is.
- Security Review (beta) is mentioned in one line and only set up on request,
  because it needs experiment and beta features on for the whole group.
- Add `references/security.md`.

**Not tested end to end yet**
- The group request with `enabled_foundational_flows`, the availability
  fields and `auto_duo_code_review_enabled`. Checked against GitLab's source
  and its end-to-end test, not run against a live group.
- The readiness check and the automation loop across many projects.
- Creating the automation without `userId`.
- Applying security profiles to a group.

## 0.4.0 (2026-11-16)

- Enable the Developer, Code Review and Fix CI/CD Pipeline foundational flows
  through GraphQL (`aiCatalogItemConsumerCreate`), in the group and then the
  project. Before, this was a manual step.
- Create the Fix CI/CD Pipeline automation for failed pipelines through
  GraphQL (`aiFlowTriggerCreate`), after checking for an existing one. Before,
  this was a manual step. Both mutations are marked Experiment by GitLab. The
  automation mutation was tested on GitLab.com; enabling flows wasn't, because
  the test group already had them on. The skill falls back to a link if
  either fails.
- Check runners with `duoWorkflowRunnerAvailable` instead of
  `shared_runners_enabled`, and report the project's Duo enablement checks.
- Print direct links instead of menu paths, built from the host, group and
  project. Routes checked against GitLab's source (19.6).
- Read and write the group's `duo_remote_flows_enabled` (flow execution).
- Drop `jq` as a requirement. The agent reads API responses and merges config
  files itself.
- Add `references/graphql.md` with the queries and mutations, including a
  project-only read for projects in a personal namespace, which have no group.
- Stop before the flow and automation steps when the project's enablement
  checks show Duo Agent Platform isn't available (`feature_available` or
  `developer_access` is `false`), and quote the check.

## 0.3.0 (2026-11-16)

- Drop the `X-Gitlab-Enabled-Mcp-Server-Toolsets` header. With it set, the
  server returned only the named toolsets, which left out `work_items`, so the
  agent couldn't read issues through MCP. The defaults include `work_items` and
  follow GitLab's changes. `references/harnesses.md` explains how to add the
  header, defaults included, for opt-in toolsets such as `code_security`.
- Add the group's MCP client access setting (Allow connection to GitLab) as a
  manual check. This is the setting that allows connections to the MCP server.
  The Groups API doesn't expose it.
- Relabel `duo_workflow_mcp_enabled` as MCP support inside Duo Agent Platform,
  not access to the MCP server.
- Fix the troubleshooting rows: 403 at sign-in, missing `work_items` tools,
  and `duo_agent_platform` tools, which show up whenever Duo Agent Platform is
  available to the user.
- Rename triggers to automations (GitLab 19.6): AI > Automations > New
  automation. Keep the old name for 19.5 and earlier.
- Send `auto_duo_code_review_enabled` in a request of its own and report it on
  its own line. The Code Review Flow docs list automatic reviews for Premium
  and Ultimate, while the API reference says Ultimate only. Add the UI path as
  a fallback.
- Check `shared_runners_enabled` on every offering, not only Self-Managed, and
  explain how to fix it when it's off. Replaced in 0.4.0 by
  `duoWorkflowRunnerAvailable`, before this check reached `main`.
- Make `list_duo_agents_and_flows` the test of the setup. The summary lists
  the flows and flags Developer, Code Review or Fix CI/CD Pipeline if missing.
- End with one prompt to try for each available flow.
- State the tier and how credits are spent, in the skill and the README.
- Date the manual UI paths (checked against GitLab 19.6) and link a docs page
  for each.
- Claude Code: note that a `local` scope `GitLab` entry overrides a `user` one.

## 0.2.0 (2026-11-15)

- Read the group's `duo_agent_platform_enabled` and `duo_workflow_mcp_enabled`
  from the nested `ai_settings` object, where GitLab returns them. Before, the
  skill looked at the top level, didn't find them, and reported them as "not
  available" even when they were on (#5).
- Write those two group fields through `ai_settings_attributes`, as the GitLab
  API reference describes. This group write hasn't been tested end to end yet.
- If a field can't be read, report "can't read via API" and point to the UI,
  instead of "not available".
- Show every project `duo_*` field read-only, and say that UI toggles don't
  always map to API fields. If the user says they changed a setting in the UI,
  the skill re-reads it and still makes the approved change if it's off (#6).
- Move `auto_duo_code_review_enabled` into the Ultimate request: the API
  reference lists it as Ultimate only.
- Add Devin CLI as a supported harness: install path, MCP config, sign-in, and
  how to spot servers Devin imported from other harnesses (#4).
- Add OpenCode as a supported harness: install path, MCP config in
  `opencode.json` (checked against OpenCode 1.14.29), sign-in with
  `opencode mcp auth`, and a note that OpenCode also reads the Claude Code and
  Codex skill directories.
- Document how to reload each harness after installing the skill. Codex needs
  a restart (#3).
- List the manual steps (now Step 1c) before asking for approval and applying
  settings (now Step 1d), so the user sees them before anything changes (#7).
- Ask the user to say when they've finished OAuth sign-in; some harnesses
  don't hand the turn back to the agent.
- OpenCode 2.x: add the server with `opencode mcp add --global`, which writes
  `mcp.servers.GitLab`. Keep the 1.x `jq` path. Replace the README's
  `opencode debug skill` check, which 2.x removed (#8).
- Devin: the skill and MCP tools load without a restart. Note that Devin also
  reads `~/.claude/skills/`.

## 0.1.0 (2026-11-13)

- Replace the setup script, templates, example project and previous skills with
  a single skill, `gitlab-duo-setup`: turns on Duo Agent Platform settings with
  `glab api` and configures the GitLab MCP server for Claude Code, Codex or Cursor.
