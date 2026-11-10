# Example: inventory API

A small Flask app for trying the whole loop in a demo project: push from your
coding agent, let GitLab review, repair and remediate, then ask the agent what
happened.

Use a **private** project in a group where you can change settings. The demo
scripts plant bugs and a SQL injection on purpose (see `../../SECURITY.md`).

## Set up

```
KIT=~/gitlab-agentic-kit/setup/setup.sh

cp -R ~/gitlab-agentic-kit/examples/inventory ~/inventory-demo
cd ~/inventory-demo
git init -b main
git remote add origin git@gitlab.com:<group>/inventory-demo.git
$KIT init --owners @<you>
git add -A && git commit -m "Initial commit" && git push -u origin main

$KIT apply group <top-level-group>        # Owner, once per group
$KIT apply project <group>/inventory-demo
```

Then do the two manual steps `apply` prints: select the flows for the group,
and create the Fix CI/CD Pipeline trigger. This example keeps its own
`.gitlab/duo/mr-review-instructions.yaml` with Python rules, so `init` leaves it
in place.

## Scenarios

Run each script from the project root on a clean `main`.

| Scenario | Script | What you should see |
|---|---|---|
| 1. Push, then close the IDE | `demo/seed-mr.sh` | Code Review threads; the pipeline fails on a seeded off-by-one; Fix CI/CD Pipeline posts a suggestion |
| 2. Return to the agent | ask "What's the status of my MR?" | One report; nothing re-run; fix, push, follow-up review, threads resolved |
| 3a. Main-branch repair | `demo/break-main.sh`, then merge it | Main fails; a `[FixPipeline]` MR opens, labeled `pipeline::broken`, awaiting approval |
| 3b. SAST remediation (Ultimate) | `demo/seed-sast.sh`, then merge it | False positive assessment on the SQL injection finding; a fix MR with a confidence score |

`break-main.sh` and `seed-sast.sh` need you to merge an MR whose pipeline fails
or that adds a vulnerability. Do that only in the demo project.

## Development

```
pip install -r requirements.txt
pytest -q
```
