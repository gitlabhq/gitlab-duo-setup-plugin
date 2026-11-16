# GraphQL for flows, runners and automations

The REST API can't enable foundational flows or create automations. GraphQL
can. Run every query with `glab api graphql`, passing values as variables with
`-F`. Pass `--hostname "$HOST"` when the host isn't gitlab.com.

These fields and mutations were checked against the GitLab.com schema on
2026-11-16 (GitLab 19.6). GitLab marks the AI Catalog and flow trigger
mutations as **Experiment**, so they can change between releases. If a field
or mutation is missing, quote the error and fall back to the manual step in
SKILL.md 1c.

GitLab's GraphQL IDs are global IDs: `gid://gitlab/Project/<id>`,
`gid://gitlab/Group/<id>`, and so on. Use the numeric `id` values from the
REST responses in Step 1a.

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
  groupFlows: aiCatalogConfiguredItems(groupId: $groupId, first: 100) {
    nodes { id enabled webPath item { id name foundationalFlowReference } serviceAccount { id username } }
  }
  projectFlows: aiCatalogConfiguredItems(projectId: $projectId, first: 100) {
    nodes { id enabled webPath item { id name foundationalFlowReference } parentItemConsumer { id } }
  }
}'
```

How to read it:

- `duoWorkflowRunnerAvailable: false` means flows can't start. Give the
  runner step.
- `duoWorkflowStatusCheck.checks` lists any blocker, such as identity
  verification, each with a message. Report the ones with `value: false`. If
  `feature_available` or `developer_access` is `false`, Duo Agent Platform
  isn't available to this user in this project. Don't propose the flow or
  automation mutations; quote the check's message instead.
- `enabledFoundationalFlows` lists the project's enabled flow references, for
  example `code_review/v1`.
- `groupFlows` has one entry per flow the group enabled. `foundationalFlowReference`
  says which flow it is. Keep its `id` (the group consumer) and
  `serviceAccount.id`.
- `projectFlows` has the project's entries. Each points to its group entry
  through `parentItemConsumer`.
- In `aiFlowTriggers`, `eventTypes` are numbers. `3` is pipeline events. A
  Fix CI/CD Pipeline automation for failed pipelines has `eventTypes: [3]`, a
  filter on `object_attributes.status` = `failed`, and an
  `aiCatalogItemConsumer` whose `foundationalFlowReference` is
  `fix_pipeline/v1`. GitLab adds some default automations when a flow is
  turned on, so check for one before creating it.
- `webPath` on any entry is that flow's configuration page. Print it as
  `https://<HOST><webPath>`.

## Personal-namespace projects

If `namespace.kind` is `user`, there is no group ID, so the read above fails.
Use this project-only read instead:

```bash
glab api graphql -F project="$PROJECT" -F projectId="gid://gitlab/Project/<project id>" -f query='
query($project: ID!, $projectId: ProjectID!) {
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
  projectFlows: aiCatalogConfiguredItems(projectId: $projectId, first: 100) {
    nodes { id enabled webPath item { id name foundationalFlowReference } parentItemConsumer { id } }
  }
}'
```

For a personal project, don't run any of the mutations below. Enabling a flow
in a project needs the group entry it links to, and the automation needs that
group entry's service account. Report what the read returned.

On GitLab.com on 2026-11-16, a Free personal project returned
`feature_available: false` and `developer_access: false`, no enabled flows,
and `duoWorkflowRunnerAvailable: null`. Duo Agent Platform isn't available
there. Tell the user that flows need a project in a group on Premium or
Ultimate, or a group with GitLab Credits.

## Find a flow's catalog item

If the group hasn't enabled a flow yet, `groupFlows` doesn't list it, so you
need its catalog item ID first:

```bash
glab api graphql -f query='
{
  aiCatalogCustomAndFoundationalItems(itemTypes: [FLOW], first: 100) {
    pageInfo { hasNextPage endCursor }
    nodes { ... on AiCatalogFlow { id name foundationalFlowReference } }
  }
}'
```

Pick the item whose `foundationalFlowReference` matches, for example
`fix_pipeline/v1`. The list has more than 100 items, so if you don't find it
on the first page, pass `after: "<endCursor>"` and read the next page.

## Enable a flow in the group

Needs top-level group Owner. `itemId` is the catalog item from above.

```bash
glab api graphql -F itemId="gid://gitlab/Ai::Catalog::Item/<item id>" \
  -F groupId="gid://gitlab/Group/<group id>" -f query='
mutation($itemId: AiCatalogItemID!, $groupId: GroupID!) {
  aiCatalogItemConsumerCreate(input: { itemId: $itemId, target: { groupId: $groupId } }) {
    itemConsumer { id webPath serviceAccount { id username } }
    errors
  }
}'
```

## Enable a flow in the project

Needs project Maintainer. `parentItemConsumerId` is the group entry's `id`.

```bash
glab api graphql -F itemId="gid://gitlab/Ai::Catalog::Item/<item id>" \
  -F projectId="gid://gitlab/Project/<project id>" \
  -F parent="gid://gitlab/Ai::Catalog::ItemConsumer/<group consumer id>" -f query='
mutation($itemId: AiCatalogItemID!, $projectId: ProjectID!, $parent: AiCatalogItemConsumerID!) {
  aiCatalogItemConsumerCreate(input: {
    itemId: $itemId, target: { projectId: $projectId }, parentItemConsumerId: $parent
  }) {
    itemConsumer { id webPath }
    errors
  }
}'
```

## Create the Fix CI/CD Pipeline automation

Needs project Maintainer.

- `consumer` is the project's Fix CI/CD Pipeline entry from `projectFlows`.
- `user` is the service account from the matching group entry in
  `groupFlows`, the same account GitLab's default automations use.

`filter` is a JSON value, so send the whole request as JSON:

```bash
glab api graphql -H "Content-Type: application/json" --input - <<'EOF'
{
  "query": "mutation($input: AiFlowTriggerCreateInput!) { aiFlowTriggerCreate(input: $input) { aiFlowTrigger { id active eventTypes filter } errors errorReason } }",
  "variables": {
    "input": {
      "projectPath": "<PROJECT>",
      "description": "Fix CI/CD Pipeline on failed pipelines",
      "eventTypes": [3],
      "aiCatalogItemConsumerId": "gid://gitlab/Ai::Catalog::ItemConsumer/<project consumer id>",
      "userId": "gid://gitlab/User/<service account id>",
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

The filter shape matches the default automations GitLab creates (one of them
filters pipeline events on `status` = `success`). This request was tested on
GitLab.com on 2026-11-16: it created an active automation, linked to the Fix
CI/CD Pipeline flow and its service account. After it
runs, read the automations again to confirm it's active, and give the user
the project automations link.
