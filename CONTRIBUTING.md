# Contributing

Issues and merge requests are welcome. The kit is provided as-is, without an
SLA, and is not covered by GitLab Support.

## Reporting a problem

Include your GitLab version and tier (GitLab.com, Self-Managed or Dedicated),
your client and its version (Claude Code, Codex, Cursor), the command you ran,
and the output of `setup.sh doctor` from the repository. Remove hostnames or
paths you don't want to share. Security issues: see `SECURITY.md`.

## Changing the kit

- `setup/setup.sh` must run on bash 3.2 (macOS) and with BSD and GNU tools.
- `templates/` holds what `init` installs. Placeholders: `{{HOST}}`,
  `{{OWNERS}}`, `{{TEST_COMMAND}}`, and a `{{SETUP_SCRIPT}}` line.
- `skills/` is the single source for both skills. When you change one, bump
  `metadata.version` in its `SKILL.md` and add a `CHANGELOG.md` entry.
- Run `make check` before opening a merge request: example tests, the `init`
  smoke test, and shellcheck if installed.
