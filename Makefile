.PHONY: test sync-skills check-skills check

test:
	pytest -q

# Codex and Cursor read .agents/skills/. Claude Code reads .claude/skills/.
# Keep one source of truth and copy.
sync-skills:
	mkdir -p .claude/skills
	rm -rf .claude/skills/gitlab-checks .claude/skills/gitlab-recommended-config
	cp -R .agents/skills/gitlab-checks .claude/skills/
	cp -R .agents/skills/gitlab-recommended-config .claude/skills/

check-skills:
	diff -r .agents/skills .claude/skills

check:
	bash setup/setup.sh check project "$(PROJECT)"
