.PHONY: check test smoke lint

check: test smoke lint

test:
	cd examples/inventory && pytest -q

smoke:
	bash tests/init-smoke.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck -S warning setup/setup.sh tests/init-smoke.sh examples/inventory/demo/*.sh; \
	else echo "shellcheck not installed, skipped"; fi
