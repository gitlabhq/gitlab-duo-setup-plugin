# Changelog

One version covers the kit: `setup.sh`, the templates, and the skills
(`metadata.version` in each `SKILL.md`). `setup.sh init` updates a project's
skills when the kit's version differs, and `setup.sh doctor` warns when they
are behind.

## 0.2.0 — unreleased

- Packaged as a kit for your own groups and projects. The demo app moved to
  `examples/inventory/`.
- `install.sh` installs or updates the kit and runs a `setup.sh` command, so
  setup is one line: `curl -fsSL .../install.sh | bash -s -- init`. `apply`
  asks for confirmation on the terminal when the script is piped.
- `setup.sh init` installs the templates into a repository: managed sections in
  `AGENTS.md` and CODEOWNERS, dependency setup detected from the repository, MCP
  config on your host merged into existing files, both skills.
- `setup.sh apply` shows changes and asks first, supports `--dry-run`, saves
  previous values for `setup.sh restore`, creates the `pipeline::broken`
  label, and can cover every project in a group (`apply all-projects`).
- `setup.sh connect` adds the GitLab MCP server to user-level config for each
  installed client; `setup.sh doctor` checks a developer's machine and
  repository.
- `gitlab-checks`: before saying nothing is running, also checks MR system
  notes, since automatically started sessions may not appear in
  `list_duo_sessions`. Checks whether automatic reviews are on before
  offering to start one.
- `gitlab-recommended-config`: points at the kit's commands; checks the
  `AGENTS.md` section and any CODEOWNERS location.
- Repair MRs use the `pipeline::broken` label (was `main::broken`).

## 0.1.0

- First version of `gitlab-checks` and `gitlab-recommended-config`.
