# Changelog

## 1.3 (2026-11-18)

Changes after running 1.2-draft once in each of five coding agents (Claude Code, Codex, Cursor CLI, Devin, OpenCode) on four kinds of merge request: review feedback, a failed pipeline, a merge conflict, and one taken through to merge behind an approval rule. The agents were told to use only the GitLab MCP server. These changes have not been re-run.

- **A failed review is not a pending review.** A `code_review/v1` session with the status failed now counts as "the review did not run". GitLab leaves no note on the merge request when that happens, and several sessions failed during the run.
- **Stay inside the interfaces you were given.** New rule: if the MCP server fails or glab is off limits, stop and say which step is blocked. Never read stored credentials to call the API directly. One agent did that during the run.
- **Suggestions.** Applying a suggestion does not resolve its thread, so resolve it afterwards. When you make the edit yourself, say so in the thread.
- **Polling.** Check about once a minute. One session made several hundred calls while waiting for a pipeline.
- **Conflicts and commits.** The MCP server has no tool for resolving a conflict, and `add_commit` cannot create a merge commit. `add_commit` works for an ordinary commit when the agent cannot write to the local checkout.
- **Push identity.** Git may push as a different account from the one the MCP server acts as. Tell the user when that shows on the merge request.
- **Install notes** for Cursor CLI and OpenCode in `references/harnesses.md`.

What the run showed with 1.2-draft: all five agents resolved the conflict and kept both sides, all five took a merge request to merge and stopped at the approval rule until a person approved, and none approved, merged by itself or weakened a test. Four of the five loaded the skill for a request that did not name it.

## 1.2-draft (2026-11-18)

Rewritten from v1.1 around one idea: any agent drives the merge request, GitLab decides whether it merges.

- **Interfaces:** v1.1 allowed only the interface the user assigned and treated a fallback as a failure. Now: MCP first, `glab` when MCP cannot, and say which was used.
- **Merging:** v1.1 forbade merging. Now the agent may set auto-merge when the user asks for the merge request to be merged. It still never approves and never changes approval rules or merge checks.
- **Merge conflicts:** new step. Resolve locally, keep what both sides intended, test, push.
- **Knowing when Duo's review has landed:** spelled out (a finished `code_review/v1` session for this merge request, the reviewer state, or Duo's summary after the latest commit).
- **Finding the right session:** uses the merge request link that Duo sessions carry, instead of matching on goal text and timestamps.
- **Fix CI/CD Pipeline:** assumes an automation may start it. Wait for a running session, do not push a competing fix, judge the suggestion before applying it.
- **All pipelines for the commit:** check every pipeline on the latest commit and the test jobs in them. A merge request can show a green pipeline that never ran the tests.
- **Flow errors:** a Duo error note or a refused flow start is reported as blocked, not retried.
- **Description:** names the read-only requests ("what is blocking it", "does it have feedback") and "get this merged", so agents load the skill for them.

Kept from v1.1: three fix rounds and about 15 minutes of waiting, never weaken a test, reply inside threads, resolve only after the fix is pushed, ask before starting a flow, verify on the final commit.
