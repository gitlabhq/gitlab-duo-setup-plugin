# AGENTS.md

Instructions for coding agents working in this repository.

## This project

A small Flask inventory API used to demonstrate the recommended GitLab
Agentic Engineering Configuration. Code lives in `app/`, tests in `tests/`.

- Run tests: `pytest -q`
- Run the app: `flask --app app run`
- Dependencies: `requirements.txt` (pin exact versions)
- Branch from `main`. Small, single-purpose merge requests.
- Conventional commits: `feat:`, `fix:`, `test:`, `ci:`, `docs:`.
- Never interpolate user input into SQL. Use parameterized queries.
- Never commit `.db` files.
