# GitLab Duo Setup Skill

An Agent Skill for Claude Code, Codex, Cursor, Devin and OpenCode users. Load
it, ask your agent to "set up GitLab Duo", and it sets up GitLab for
agentic engineering:

1. **Turns on Code Review, Fix CI/CD Pipeline and Developer for your group.**
   Every new merge request gets a Duo review, and every failed pipeline gets a
   fix, whichever agent or tool the change came from. Your agent can hand an
   issue or a merge conflict to the Developer flow.
2. **Creates the automation that runs Fix CI/CD Pipeline on failed
   pipelines**, in every project of the group. Its description names the
   skill version, for example `Fix CI/CD Pipeline on failed pipelines
   (gitlab-duo-setup 0.5.8)`, so you can tell it apart from automations
   made by hand.
3. **Connects your agent to the GitLab MCP server**
   (`https://<host>/api/v4/mcp`) and walks you through signing in with OAuth,
   so your agent can read what the flows found and act on it.

On Ultimate, once that works, it asks one more question: whether to add
security triage and remediation (SAST false positive detection and agentic
vulnerability resolution, with SAST turned on where projects don't scan yet).
If that step fails, the core setup stays as it is.

It shows the full plan, with what each flow costs, and asks before changing
anything. Run it again any time: it skips what's already set up.

It works on GitLab.com, Self-Managed and Dedicated.

## Who can run it

Anyone on the team can run it. What it does depends on your role:

- **Owner of the top-level group**: sets up the whole group and every
  project in it. This is the recommended path.
- **Maintainer of a project**: sets up that project, then writes a
  ready-to-send request for your group Owner covering the group-wide parts.
- **Anyone else on the team**: changes no GitLab settings. It connects your
  agent to the GitLab MCP server, so your agent can work with Duo's reviews
  and pipeline results, and writes a ready-to-send request for your group
  Owner. If you say yes, it files the request as an issue that mentions the
  Owners.

## Requirements

- `git` and [`glab`](https://gitlab.com/gitlab-org/cli#installation),
  signed in: `glab auth login`
- Optional: `jq`, so the automation step in a large group runs as one script
  (`scripts/automations.sh`) instead of one call at a time
- GitLab Premium or Ultimate, or Free with GitLab Credits, for Duo Agent
  Platform. The security flows need Ultimate.
- Credits: the skill itself spends none. The flows it turns on do, and when an
  automation or a service account starts a flow, the credits are billed to your
  top-level namespace.

## Install

### Claude Code: install the plugin

This repository is also a Claude plugin, `gitlab-duo`, that installs both
skills (`gitlab-duo-setup` and [`gitlab-mr-followup`](#follow-up-on-merge-requests))
in one step. In Claude Code, run:

```text
/plugin marketplace add https://gitlab.com/gitlab-org/developer-relations/gitlab-duo-setup-plugin.git
/plugin install gitlab-duo@gitlab-duo
```

Or from a shell:

```bash
claude plugin marketplace add https://gitlab.com/gitlab-org/developer-relations/gitlab-duo-setup-plugin.git
```

```bash
claude plugin install gitlab-duo@gitlab-duo
```

To update later, run `/plugin marketplace update gitlab-duo`. To remove it,
run `/plugin uninstall gitlab-duo@gitlab-duo`.

Plugin skills are named after the plugin, so you call them as
`/gitlab-duo:gitlab-duo-setup` and `/gitlab-duo:gitlab-mr-followup`, or just
ask in plain words (see [Example prompts](#example-prompts)).

The plugin is not in Claude's public plugin directory yet. Once it is, you
can also add it from the directory in Claude.

### Any harness: copy the skill folder

Copy `skills/gitlab-duo-setup/` into your harness's skills directory:

| Harness | User-level | Project-level |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex | `~/.agents/skills/` | `.agents/skills/` |
| Cursor | `~/.cursor/skills/` | `.agents/skills/` |
| Devin | `~/.config/devin/skills/` | `.devin/skills/` |
| OpenCode | `~/.config/opencode/skills/` | `.opencode/skills/` |

```bash
git clone https://gitlab.com/gitlab-org/developer-relations/gitlab-duo-setup-plugin.git
cp -R gitlab-duo-setup-plugin/skills/gitlab-duo-setup ~/.claude/skills/
```

Then reload your harness so it sees the new skill:

| Harness | Reload |
|---|---|
| Claude Code | Picks it up in the running session. If it isn't listed, restart Claude Code. |
| Codex | Restart Codex. A running session doesn't see newly installed skills. |
| Cursor | Picks it up in the running session. If it isn't listed, restart Cursor. |
| Devin | Picks it up without a restart. Check with `devin skills list`. |
| OpenCode | Picks it up in the running session. If it isn't listed, restart OpenCode. |

Some harnesses read other harnesses' skill directories. Devin and OpenCode
both also read `~/.claude/skills/` (Claude Code) and `~/.agents/skills/`
(Codex). If you use more than one, install the skill in one shared place, so
it isn't listed twice.

## Run the skill

| Harness | Syntax |
| --- | --- |
| Claude Code (plugin) | `/gitlab-duo:gitlab-duo-setup` |
| Claude Code (copied folder) | `/gitlab-duo-setup` |
| Codex | `$gitlab-duo-setup` |
| Cursor | `/gitlab-duo-setup` |
| Devin | `@skills:gitlab-duo-setup` |
| OpenCode | `@gitlab-duo-setup` |

## Example prompts

You don't need the slash command. Ask in plain words, for example:

- "Set up GitLab Duo for this group."
- "Check whether Duo Code Review and Fix CI/CD Pipeline are turned on for
  this project, and fix what's missing."
- "Connect Claude to the GitLab MCP server for gitlab.example.com."
- "Add SAST false positive detection and vulnerability resolution to our
  Ultimate group."
- "I just pushed to my merge request. Wait for the pipeline and Duo's review,
  then fix what they find."
- "What's blocking !42 from merging?"

## Set it up by hand

If you prefer the GitLab UI, follow these steps for the core setup. A top-level
group Owner handles group settings; a project Maintainer can handle project
settings. On Self-Managed or Dedicated, ask an instance admin to check the
instance-level Agent Platform and MCP settings first.

1. Check the [requirements](#requirements), including GitLab Credits and a
   runner that can run flows in each project. Check project push rules if they
   might block the `duo-*` service accounts.
2. On GitLab.com, open the top-level group's **Settings > GitLab Duo > Change
   configuration** and select **Turn on GitLab Duo Agentic Chat, agents, and
   flows** under **GitLab Duo Agent Platform**. On Self-Managed or Dedicated,
   ask an instance admin to enable Agent Platform, then open
   the group's **Settings > General > GitLab Duo features**. Turn on **Allow
   flow execution** and **Allow foundational flows**, select **Code Review**,
   **Fix CI/CD Pipeline**, and **Developer**, then save. Wait for the settings
   to reach the projects. [Flow settings](https://docs.gitlab.com/user/duo_agent_platform/flows/foundational_flows/#turn-foundational-flows-on-or-off).
3. In the group, open **Settings > General > Merge requests > GitLab Duo Code
   Review** and select **Enable automatic reviews by GitLab Duo**. Check for
   project overrides under **Settings > Merge requests**. [Automatic reviews](https://docs.gitlab.com/user/duo_agent_platform/flows/foundational_flows/code_review/#automatic-reviews).
4. In each project with CI/CD, open **AI > Automations > New automation**.
   Name it, select **Fix CI/CD Pipeline** under **Runs with**, then add an
   **On an event** trigger for **Pipeline events > Failed** and create it.
   On GitLab 19.5 and earlier, look under **Automate > Triggers** instead.
   [Automation steps](https://docs.gitlab.com/user/duo_agent_platform/automations/#create-an-event-based-automation).
5. On GitLab.com, in the top-level group's **Settings > General > Permissions
   and group features**, turn on **Allow connection to GitLab** for MCP clients.
   On Self-Managed or Dedicated, an instance admin enables MCP access. Add
   `https://<host>/api/v4/mcp` to your coding agent and complete OAuth sign-in
   using the [instructions for your harness](skills/gitlab-duo-setup/references/harnesses.md).
6. Open a non-draft merge request and confirm Duo reviews it. Check that the
   next failed pipeline starts a Fix CI/CD Pipeline session under **AI >
   Sessions**. [Run a flow](https://docs.gitlab.com/user/duo_agent_platform/flows/foundational_flows/).

Optional on Ultimate: turn on **SAST False Positive Detection**, **Secret
Detection False Positive Detection**, and **Resolve SAST Vulnerability** in
the group, then apply the default SAST and secret detection profiles and an
automated triage profile from **Secure > Security inventory**. Review the
profile's included actions and credit use before applying it. The default
secret detection profile also blocks pushes containing secrets. Before
applying scan profiles, check the project's CI rules: without `workflow:rules`,
a separate MR scan pipeline can appear green while tests fail in a branch
pipeline. Make tests and scans run in the intended pipeline.
[Security profiles](https://docs.gitlab.com/user/application_security/configuration/security_configuration_profiles/#apply-profiles-in-the-ui)
and [pipeline rules](https://docs.gitlab.com/ci/yaml/workflow/#switch-between-branch-pipelines-and-merge-request-pipelines).

## After setup

The setup skill does not set the review-on-push preference or create these
instruction and exclusion files:

- **Review on push:** `Start a new review on push` is on by default. When
  automatic reviews are on, a push that changes the diff starts a follow-up
  review for an open, non-draft MR if Duo is already a reviewer and the author
  uses Code Review Flow. Change it under **Settings > Merge requests > GitLab
  Duo Code Review**. [Details](https://docs.gitlab.com/user/duo_agent_platform/flows/foundational_flows/code_review/#start-a-new-review-on-push).
- **Review instructions:** Add `.gitlab/duo/mr-review-instructions.yaml` to
  guide Code Review Flow on project-specific standards. [Format](https://docs.gitlab.com/user/duo_agent_platform/customize/review_instructions/#configure-custom-review-instructions-for-a-project).
- **Automatic review exclusions:** Add
  `.gitlab/duo/mr-review-automated-rules.yaml` to the default branch to skip
  automatic reviews by source branch, target branch or author. Manual reviews
  still work. [Rules](https://docs.gitlab.com/user/duo_agent_platform/flows/foundational_flows/code_review/#exclude-merge-requests-for-a-project).
- **Agent instructions:** Developer and Fix CI/CD Pipeline read
  [`AGENTS.md`](https://docs.gitlab.com/user/duo_agent_platform/customize/agents_md/);
  [Code Review Flow does not](https://docs.gitlab.com/user/duo_agent_platform/flows/foundational_flows/code_review/#custom-code-review-instructions).
  Put review guidance in the review instructions file instead.
- **Pipeline logs:** Fix CI/CD Pipeline processes only the last **150 KiB** of
  each job log. Keep key errors near the end or reduce verbose output.
  [Workarounds](https://docs.gitlab.com/user/duo_agent_platform/flows/foundational_flows/fix_pipeline/#flow-cannot-identify-the-root-cause-of-a-failure).

## What is not automated yet

No API covers these steps, so the skill stops and gives you a direct link for
each so that you can finish the configuration in the GitLab UI:

- **MCP client access (Allow connection to GitLab):** Group Owner turns this
  on under group permissions. The skill can't read the setting; a successful
  MCP sign-in is how you know it's on.
- **Runners for flow sessions:** Projects with no runner that can run flows
  need a Maintainer or Owner to add or enable one. The skill lists those
  projects and does not turn on hosted runners without asking.
- **Allow foundational flows (project override):** If a project turned this
  off on its own, a Maintainer or Owner turns it back on. The skill lists
  those projects.
- **Self-Managed AI gateway:** An instance admin connects the instance to an
  AI gateway before Duo Agent Platform can run.
- **Push rules and `duo-*` service accounts:** If push rules block those
  accounts, a Maintainer or Owner updates the rules so flows can push.
- **OAuth sign-in:** You complete sign-in in the browser when the skill opens
  it; the skill cannot click through that step for you.

## What has been tested

Tested on GitLab.com (Ultimate), in a fresh subgroup with 22 projects, on
2026-11-17:

- The group request for automatic Code Review and MCP for Agent Platform:
  both reached every project.
- `enabled_foundational_flows`: GitLab sets every project to exactly the list
  sent. A list missing flows turned those flows off in all 22 projects within
  seconds, and sending the full list restored them. That's why the skill
  builds the list from both the group and the project, and sends it only to
  the top-level group.
- The readiness check and creating the Fix CI/CD Pipeline automation in 21
  projects, without `userId`, with no duplicates on a second run. A project
  without CI/CD was skipped.
- Running Resolve SAST Vulnerability on one finding from the agent, with the
  MCP tool `start_duo_session`.

Run by Claude (an AI agent) on a top-level Ultimate group, not yet repeated
by a person (details in the CHANGELOG, 0.5.2):

- The group request on a top-level group with
  `duo_foundational_flows_availability` and a merged flow list, using a
  separate script that sends the same requests.
- `scripts/automations.sh` as a dry run.

Checked against GitLab's source (19.6) but not yet run against a live group:

- The group request on Premium.
- The `duo_remote_flows_availability` field (already on in both test groups).
- Applying security profiles to a group.

GitLab marks the automation mutation and the security profile mutations as
Experiment, so they can change between releases. If one fails, the skill
quotes the error and gives you the link to do it by hand.

## Follow up on merge requests

`skills/gitlab-mr-followup/` is a second skill, for after setup. It has your
agent wait for the pipeline and GitLab Duo Code Review after a push, read what
they found, fix it, answer the review threads, and check the result on the
latest commit. It works over the GitLab MCP server or `glab`. It never
approves a merge request, and it sets auto-merge only when you ask.

Install it the same way as the setup skill, from `skills/gitlab-mr-followup/`.
`references/harnesses.md` in that folder has the paths, how to call the skill
in each harness, and an `AGENTS.md` pointer that helps agents reach for it.

## Layout

The repository root is the plugin root.

```
.claude-plugin/plugin.json      Claude plugin manifest (name, version, icon, links)
.claude-plugin/marketplace.json lets Claude Code add this repository as a marketplace
assets/icon.png                 plugin icon (GitLab logomark)

skills/gitlab-duo-setup/
  SKILL.md                  the skill
  references/harnesses.md   MCP config and sign-in per harness
  references/graphql.md     queries and mutations for flows, runners and automations
  references/security.md    optional security step (Ultimate)
  scripts/automations.sh    optional: the automation step for a whole group in one run (needs jq)

skills/gitlab-mr-followup/
  SKILL.md                  the skill
  references/harnesses.md   install paths, how to call it, AGENTS.md pointer
```

## Privacy

The skills run inside your coding agent and send nothing to GitLab Inc. or
any third party on their own. They call your GitLab instance through `glab`
and the GitLab MCP server, using your own sign-in, and change only what you
approve. The GitLab Duo flows they turn on run on your GitLab instance under
GitLab's terms. See the [GitLab Privacy Statement](https://about.gitlab.com/privacy/).

## Support

Open an issue in this project:
<https://gitlab.com/gitlab-org/developer-relations/gitlab-duo-setup-plugin/-/issues>.
For problems with GitLab Duo itself, use your usual
[GitLab support](https://about.gitlab.com/support/) channel.

## Security

Please don't report security issues in a public issue. Follow GitLab's
[responsible disclosure process](https://about.gitlab.com/security/disclosure/).

## License

[MIT](LICENSE)
