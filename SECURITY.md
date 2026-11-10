# Security

## Reporting a vulnerability

Do not open a public issue. Open a
[confidential issue](https://docs.gitlab.com/user/project/issues/confidential_issues/)
in this project, or report through GitLab's
[responsible disclosure process](https://about.gitlab.com/security/disclosure/)
if it affects GitLab itself.

## Vulnerabilities planted on purpose

`main` is meant to be free of known vulnerabilities. The demo scripts add
problems on purpose, on branches, so that GitLab's flows have something to act
on:

| Script | What it adds | Why |
|---|---|---|
| `demo/seed-sast.sh` | SQL injection (CWE-89) in `GET /items/search` | Starts SAST False Positive Detection and Agentic Vulnerability Resolution |
| `demo/seed-mr.sh` | Off-by-one in a new report endpoint | Fails the MR pipeline so Fix CI/CD Pipeline runs |
| `demo/break-main.sh` | A pin to a Flask version that does not exist | Breaks the default-branch pipeline |

Run them only in a private demo project. A finding introduced by one of these
scripts is not a vulnerability in this repository.

## What to protect when you adopt this configuration

- **MCP config** (`.mcp.json`, `.cursor/mcp.json`, `.codex/config.toml`)
  decides which server a developer's client sends its GitLab OAuth token to.
- **`.gitlab/duo/agent-config.yml`**: `setup_script` runs before the flow's
  sandbox is applied and can read the flow's tokens.
- **`AGENTS.md` and the skills** tell coding agents and GitLab Duo flows what to
  do.
- **`.gitlab-ci.yml`** runs on every push.

`.gitlab/CODEOWNERS` covers all of these. Replace the placeholder owner and turn
on "Require approval from code owners" for the default branch.

**Prompt injection.** Skills and flows read MR descriptions, review threads, job
logs and vulnerability text. The `gitlab-checks` skill treats that content as
data and stops if it contains instructions. Anyone who can comment on an MR can
write text an agent will read.

**Public projects.** Automatic Code Review and Fix CI/CD Pipeline can run on
merge requests from forks. That spends the project's credits and puts text
written by outside contributors in front of the flows. On a public project,
turn automatic flows off for fork MRs, or run the demo in a private copy.
