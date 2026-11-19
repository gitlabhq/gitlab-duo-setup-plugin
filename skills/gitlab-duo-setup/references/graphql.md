# GraphQL for flows, runners and automations

Run every query with `glab api graphql`, passing values as variables with
`-F`. Pass `--hostname "$HOST"` when the host isn't gitlab.com.

These fields and mutations were checked against GitLab's source and schema
(19.6). GitLab marks the AI Catalog and automation mutations as
**Experiment**, so they can change between releases. If a field or mutation
is missing, quote the error and fall back to the manual step with its link.

GitLab's GraphQL IDs are global IDs: `gid://gitlab/Project/<id>`,
`gid://gitlab/Group/<id>`, and so on. Use the numeric `id` values from the
REST responses in Step 1a.

## Turning flows on: REST, not GraphQL

Turn foundational flows on for the group with the Groups API, in the single
request in SKILL.md 3a (`enabled_foundational_flows`). That's what the group
settings page and GitLab's own end-to-end tests do. It records the group's
flow selection, and GitLab then sets up every project in background jobs:
the service account, its project membership, and each flow's default
automations.

Earlier versions of this skill created the group and project entries
directly with `aiCatalogItemConsumerCreate`. Don't: that doesn't update the
group's flow selection, so the settings page shows the flow as off, and the
next save of that page can undo it.

## Read flows, runners and automations

```bash
glab api graphql -F project="$PROJECT" -F projectId="gid://gitlab/Project/<project id>" \
  -F groupId="gid://gitlab/Group/<group id>" -f query='
query($project: ID!, $projectId: ProjectID!, $groupId: GroupID!) {
  project(fullPath: $project) {
    duoWorkflowRunnerAvailable
    duoWorkflowStatusCheck {
      enabled
      remoteFlowsEnabled
      foundationalFlowsEnabled
      enabledFoundationalFlows
      checks { name value message }
    }
    aiFlowTriggers(first: 50) {
      nodes {
        id description active eventTypes filter
        aiCatalogItemConsumer { id item { name foundationalFlowReference } }
      }
    }
  }
  groupFlows: aiCatalogConfiguredItems(groupId: $groupId, itemTypes: [FLOW], first: 100) {
    pageInfo { hasNextPage endCursor }
    nodes { id enabled webPath item { id name foundationalFlowReference } serviceAccount { id username } }
  }
  projectFlows: aiCatalogConfiguredItems(projectId: $projectId, itemTypes: [FLOW], first: 100) {
    nodes { id enabled webPath item { id name foundationalFlowReference } parentItemConsumer { id } }
  }
}'
```

How to read it:

- `duoWorkflowRunnerAvailable: false` means flows can't start in this
  project. List it with the Runners link.
- `duoWorkflowStatusCheck.checks` lists any blocker, such as identity
  verification. Report the ones with `value: false`. If `feature_available`
  or `developer_access` is `false`, Duo Agent Platform isn't available to this
  user in this project: stop before the flow and automation steps.
- `groupFlows` has one entry per flow the group has on, custom flows
  included. `foundationalFlowReference` names a foundational flow, for
  example `code_review/v1`; it's `null` for custom flows, and `item` itself
  can be `null`, so skip those entries. On GitLab.com on 2026-11-17, a
  top-level group returned 63 flow entries, 13 of them foundational.
- If `groupFlows.pageInfo.hasNextPage` is `true`, read the next page before
  building `CURRENT_FLOWS`, with the same `groupFlows` field and
  `after: "<endCursor>"`. Missing a page means missing flows, and SKILL.md 3a
  would turn them off.
- `enabledFoundationalFlows` is the list the project actually runs. In a
  subgroup, `groupFlows` is empty even when the projects run flows, because
  the flows are configured on the top-level group. `CURRENT_FLOWS` in SKILL.md
  1c is the union of both lists.
- `webPath` on any entry is that flow's configuration page. Print it as
  `https://<HOST><webPath>`.

## Personal-namespace projects

If `namespace.kind` is `user`, there is no group ID, so the read above fails.
Use this project-only read instead:

```bash
glab api graphql -F project="$PROJECT" -f query='
query($project: ID!) {
  project(fullPath: $project) {
    duoWorkflowRunnerAvailable
    duoWorkflowStatusCheck { enabled foundationalFlowsEnabled enabledFoundationalFlows checks { name value message } }
  }
}'
```

Don't run any mutation for a personal project: flows need a group.

On GitLab.com on 2026-11-16, a Free personal project returned
`feature_available: false` and `developer_access: false`. Tell the user that
flows need a project in a group on Premium or Ultimate, or a group with
GitLab Credits.

## Find a flow's catalog item

The readiness check needs the catalog item ID of Fix CI/CD Pipeline. Take it
from `groupFlows` or `projectFlows` (`item.id` where
`foundationalFlowReference` is `fix_pipeline/v1`). On GitLab.com it was
`gid://gitlab/Ai::Catalog::Item/1800` on 2026-11-17. If neither list has it:

```bash
glab api graphql -f query='
{
  aiCatalogCustomAndFoundationalItems(itemTypes: [FLOW], first: 100) {
    pageInfo { hasNextPage endCursor }
    nodes { ... on AiCatalogFlow { id name foundationalFlowReference } }
  }
}'
```

The list has more than 100 items. If you don't find the flow on the first
page, pass `after: "<endCursor>"` and read the next one.

## Check a project is ready

After the group request, GitLab sets up each project in the background. A
project is ready for the automation when it has a Fix CI/CD Pipeline entry
and that entry has an active service account, its own or its group parent's.

```bash
glab api graphql -F project="<path_with_namespace>" \
  -F item="gid://gitlab/Ai::Catalog::Item/<fix pipeline item id>" -f query='
query($project: ID!, $item: AiCatalogItemID!) {
  project(fullPath: $project) {
    id
    duoWorkflowRunnerAvailable
    aiCatalogItemConsumerForItem(id: $item, includeInherited: false) {
      id
      serviceAccount { id username state }
      parentItemConsumer { serviceAccount { id username state } }
    }
    aiFlowTriggers(first: 50) {
      nodes {
        id active eventTypes filter
        aiCatalogItemConsumer { item { foundationalFlowReference } }
      }
    }
  }
}'
```

- `aiCatalogItemConsumerForItem` is `null`: not ready yet. Check again later.
  `includeInherited: false` matters: without it, a project with no entry of
  its own can return the group's entry and look ready too early.
- The consumer's `id` is the project entry for the automation. Its service
  account is `serviceAccount`, or `parentItemConsumer.serviceAccount` if the
  first is `null`. It must have `state: active`.
- The same response has the project's automations, for the duplicate check.

For many projects, put several projects in one request with aliases
(`p1: project(fullPath: "a/b") { ... }`, `p2: ...`), 5 at a time. Each
project costs about 38 against GitLab's query complexity limit of 250, so 20
in one request fails with "Query has complexity of 760, which exceeds max
complexity of 250".

In a test on GitLab.com on 2026-11-17, 21 new projects were ready as soon as
they were created, and a change to the group's flow list reached 22 projects
in under 30 seconds.

## Read a project's automations

The readiness check above already returns them. A project already has the
automation if any node has:

- `aiCatalogItemConsumer.item.foundationalFlowReference` = `fix_pipeline/v1`
- `eventTypes` containing `3` (pipeline events)

If that node has `active: true`, skip the project. If `active: false`, list it
and leave it alone.

Fix CI/CD Pipeline has no default automation: GitLab doesn't create one when
the flow is turned on, so this step is always needed.

## Create the Fix CI/CD Pipeline automation

Needs Maintainer on the project (a group Owner has it everywhere).

- `aiCatalogItemConsumerId` is the project entry from the readiness check.
- Don't send `userId`. With a catalog entry, GitLab uses the entry's own
  service account and discards `userId`; a `userId` that doesn't match that
  account fails the request.
- Send `description` exactly as below. The version in it marks the
  automation as created by this skill, so it can be told apart from ones
  made by hand.

`filter` is a JSON value, so send the whole request as JSON:

```bash
glab api graphql -H "Content-Type: application/json" --input - <<'EOF'
{
  "query": "mutation($input: AiFlowTriggerCreateInput!) { aiFlowTriggerCreate(input: $input) { aiFlowTrigger { id active eventTypes filter } errors errorReason } }",
  "variables": {
    "input": {
      "projectPath": "<path_with_namespace>",
      "description": "Fix CI/CD Pipeline on failed pipelines (gitlab-duo-setup 0.5.7)",
      "eventTypes": [3],
      "aiCatalogItemConsumerId": "gid://gitlab/Ai::Catalog::ItemConsumer/<project consumer id>",
      "filter": {
        "pipeline_hooks": {
          "match": "all",
          "rules": [{ "field": "object_attributes.status", "operator": "eq", "value": "failed" }]
        }
      }
    }
  }
}
EOF
```

The flow itself only runs on failed, finished pipelines, so the filter
matches what the flow accepts. Tested on GitLab.com on 2026-11-17 without
`userId`, in 21 projects: each request created an active automation that
runs as the Fix CI/CD Pipeline service account, and a second run of the loop
found them all and created none. With a `userId` that isn't the entry's
service account, the request fails with "You are not authorized to use this
service account in this project". Check `errors` and `errorReason` in every
response.

### Rate limit

GitLab allows about 30 saves of agents, flows and automations a minute per
user. Past that, `aiFlowTriggerCreate` returns an error saying the user saved
them "too many times. Try again in a minute." Wait 65 seconds and send the
same request again, up to 3 times; don't skip the project.
`scripts/automations.sh` does this. Seen on GitLab.com in an automated run
(by Claude, an AI agent) that created automations for 18 projects in a row.
