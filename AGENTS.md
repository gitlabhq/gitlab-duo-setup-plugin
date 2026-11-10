# AGENTS.md

This repository is the Agentic Engineering Configuration kit: a setup script,
templates it installs into other repositories, two Agent Skills, and an example
project. See `README.md` for what it does and `CONTRIBUTING.md` for rules.

- Run checks: `make check`
- `setup/setup.sh` must work on bash 3.2 and BSD/GNU tools. Keep `init`
  idempotent: a second run must change nothing (`tests/init-smoke.sh` checks).
- `templates/` is installed into customer repositories; keep it generic.
  Project-specific examples go in `examples/inventory/`.
- `skills/` is the only copy of the skills. Bump `metadata.version` and add a
  `CHANGELOG.md` entry when you change one.
- Docs are customer-facing: describe what the kit does today, and say plainly
  what is not automated yet.
