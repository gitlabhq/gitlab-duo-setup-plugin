# GitLab MCP server tools used by gitlab-checks

Distilled from https://docs.gitlab.com/user/model_context_protocol/mcp_server_tools/
(GitLab 19.6). Tool names are exact; parameters listed are the ones this skill uses.
Toolsets must be enabled on the connection: `duo_agent_platform` is on by default
when the Agent Platform is available; `code_security` is opt-in via the
`X-Gitlab-Enabled-Mcp-Server-Toolsets` header and requires Ultimate.

Rate limits apply per user (600 requests/minute on Premium and Ultimate, 60 on
Free). Follow `poll_after_seconds` instead of looping.

## Discover and start flows (`duo_agent_platform`)

**`list_duo_agents_and_flows`** `project_id`, optional `item_type: "flow"`.
Returns what is enabled in this project; entries with `can_start_session: true`
include an `ai_catalog_item_consumer_id`. Use it to confirm a flow is enabled
before offering to start it.

**`list_duo_sessions`** `project_id` or `url`; `statuses` (array of `created`,
`running`, `paused`, `finished`, `failed`, `stopped`, `input_required`,
`plan_approval_required`, `tool_call_approval_required`, `idle`) or
`status_group` (`active`, `paused`, `awaiting_input`, `completed`, `failed`,
`canceled`). Returns each session's status, goal preview, flow definition, and
URL. Lists the current user's sessions; sessions started automatically by a
service account on behalf of another user may not appear. Fall back to MR system
notes and `list_merge_requests` for those.

**`get_duo_session`** `workflow_id`. Returns status, the latest agent answer,
`created_merge_requests`, `created_work_items`, `created_notes`, and for failed
sessions `failure_reason` and `job_url`. Also returns a polling hint.

**`start_duo_session`** exactly one of `url` or `project_id`; `goal`; `flow`.
- `flow: "code_review/v1"` — `goal` is the MR URL or IID. Runs on the MR's source branch.
- `flow: "fix_pipeline/v1"` — `goal` is the failed pipeline URL in the same
  project. If the pipeline belongs to an open MR the flow posts suggestions on
  that MR; otherwise it opens a new MR.
No documented `flow` value starts SAST False Positive Detection, Resolve SAST
Vulnerability, Security Review, Recommend Reviewers, or Generate Workplan.

**`send_duo_session_input`** `workflow_id`, `human_approval` (true/false),
optional `human_message` (only with `false`). Answers a session that is waiting.

## Merge requests (`merge_requests`, `core`)

**`list_merge_requests`** one of `url`, `project_id`, `group_id`; `state`,
`author_username`, `search`, `labels`. Compact metadata; use it to find the MR
for a branch and to find Duo-authored fix MRs.

**`get_merge_request`** `url` or `project_id` + `merge_request_iid`;
`include` any of `diffs`, `commits`, `notes`, `pipelines`, `discussions`,
`approvals`, `conflicts`. Each note carries `position` and `discussion`
(thread id and resolved state). Response includes `resolvedDiscussionsCount`
and `resolvableDiscussionsCount`. For the newest notes use `notes_last`.

**`save_note`** `url` or ids; `method` one of `create_note`, `reply_discussion`,
`resolve_discussion`; `body`; `discussion_id`; `resolved`. Note bodies cannot
start a line with `/` (quick actions are blocked).

**`save_merge_request_review`** `method`: `post_duo_review` asks GitLab Duo to
review (requires Code Review); `approve` and `unapprove` act as the user and
return `diff_head_sha`. This skill only uses `post_duo_review`, and only when
automatic reviews are off.

**`accept_merge_request`** exists; this skill never calls it without an explicit
user instruction in the current conversation.

**`list_todos`** `action` (`review_requested`, `assigned`, `mentioned`),
`type`, `project_id`. The user's own to-do list; the nearest thing to a
notification feed.

## Pipelines (`ci`)

**`get_pipeline`** `id` (project), `pipeline_id`; facets for jobs, downstream
pipelines, artifacts.

**`get_job`** `id` (project), `job_id`; `include: ["log"]` with `from: "end"`
and `byte_limit` (max 512000) to read the tail of a failing job's log.
Response reports the total size and the offset for earlier windows.

**`list_pipelines`** `id`, `ref`, `status`. Use `ref: "main", status: "failed"`
to find a broken default branch.

## Security (`code_security`, Ultimate)

**`list_vulnerabilities`** `project_full_path`; `severity`, `report_type`,
`state`, `first`, `after`. Requires the security dashboard.

**`get_vulnerability`** `vulnerability_id`. Title, state, description, severity,
identifiers. The docs do not list the false-positive confidence score among the
returned fields; if it is absent, say "FP assessment: not available via MCP" and
link to the vulnerability page, where the badge is shown.

**`save_vulnerability`** exists (`dismiss`, `confirm`, `create_issue`, ...).
This skill does not call it; dismissal is a human decision.

## Repository (`repository`)

**`get_repository_file`**, **`list_repository_tree`**, **`add_commit`** are
available but this skill works on the local checkout and pushes with git.
