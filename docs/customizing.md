# Customizing and updating

`setup.sh init` installs the kit's files into a repository. It doesn't remove
your content or overwrite a file you own; run it with `--dry-run` first to
see what it would do.

## What init decides for you

| Setting | Default | Change it with |
|---|---|---|
| GitLab host in the MCP config | Host of the `origin` remote | `--host gitlab.example.com` |
| Code owners | `@REPLACE-ME/maintainers`, or the owner already in the managed CODEOWNERS section | `--owners @group/team` |
| Dependency setup for flows | Detected from `requirements.txt`, `pyproject.toml`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `go.mod`, `Gemfile`, `pom.xml`, `gradlew` or `Cargo.toml` | Edit `.gitlab/duo/agent-config.yml` |
| Test command in a new `AGENTS.md` | From the same detection | Edit `AGENTS.md` |

## Files you own and files init manages

**Managed sections.** `AGENTS.md` and `CODEOWNERS` get a section between
`BEGIN gitlab-agentic-engineering` and `END gitlab-agentic-engineering`
markers. Running `init` again replaces only that section. Write your own
content outside the markers; edits inside them are lost on update. To stop
updates, delete the markers along with the section.

**Files init creates once.** The three files in `.gitlab/duo/` and `CLAUDE.md` are
created if missing and then left alone. They're yours to edit. `--force`
replaces them with the kit's templates.

**MCP config.** If `.mcp.json`, `.cursor/mcp.json` or `.codex/config.toml`
already exists, `init` adds a `GitLab` server and keeps the others. If a
`GitLab` server is already there, it is left as is; `--force` replaces it,
for example after changing `--host`.

**Skills.** `.agents/skills/<name>` and `.claude/skills/<name>` are replaced
when the kit has a different version (`metadata.version` in `SKILL.md`). If you
changed a skill without changing its version, `init` keeps your copy and says
so; `--force` replaces it.

## Review instructions

Code Review Flow reads `.gitlab/duo/mr-review-instructions.yaml`, not
`AGENTS.md`. The template has two generic rules; add your own per path, as in
the commented example at the top of the file.
`examples/inventory/.gitlab/duo/mr-review-instructions.yaml` shows Python rules.

## Updating the kit

```
cd <your-project>
curl -fsSL https://gitlab.com/gitlab-da/projects/agentic-eng-config/-/raw/main/install.sh | bash -s -- init --dry-run
curl -fsSL https://gitlab.com/gitlab-da/projects/agentic-eng-config/-/raw/main/install.sh | bash -s -- init
```

`CHANGELOG.md` lists what changed. `setup.sh doctor` warns when a project's
skills are older than the kit's.

## Many projects

`init` works on one checkout at a time. To roll it out widely, run it in each
repository and open an MR from each, or add the files to your group's project
template so new projects start with them.
