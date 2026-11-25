# Changelog

All notable changes to the `solnest-coding-agent` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.2.0] - 2026-11-25

### Added

- **One way to install.** Paste this repo's link into Claude Code and say "set this up".
  Claude puts the tool in `~/solnest/coding-agent`, installs the plugin from that folder
  and checks it. No slash commands to type.
- **Updates install themselves.** Once a day, in the background, the tool checks for a new
  published release and installs it. If a release does not load, it puts the old version
  back by itself. Only published releases are installed, never work in progress.
- **Your own changes are kept.** Ask Claude to change how the coding agent works for you
  and it saves that in `~/.solnest/coding-agent/my-instructions.md`, which no update
  touches. Every agent reads that file first.

### Fixed

- The secret check now catches a commit anywhere in a command (`git add . && git commit`,
  `cd dir && git commit`, `git -C dir commit`), not only a command that starts with
  `git commit`.
- The secret check also scans files that the same command is about to add (`git add`,
  `git commit -a`). Before, those were not staged yet when the check ran, so they went
  through.
- The secret check no longer skips every `.sh` file, and the password check now matches
  single quotes.
- The test check no longer reports a failure when there were no tests to run or when the
  test runner is not installed. Those now say "skipped".
- The test check treats a failing test right after you edit a test file as the normal
  "write the failing test first" step. Claude is told what failed, and the edit is not
  blocked.

### Changed

- The old install files (`START-HERE.md`, `INSTALL-SOLNEST-CODING-AGENT.md`) are gone.
  `CLAUDE.md` at the top of the repo is the one set of setup steps. Installed the old way?
  Paste the link and say "set this up" once. It moves you over and keeps the plugin on.

## [3.1.2] - 2026-08-30

### Fixed

- **Install path.** `START-HERE.md` told Claude to copy the plugin folder into
  `~/.claude/plugins/<name>/`. Claude Code never scans that directory, plugins
  load from `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, which
  only the `/plugin` commands create. Anyone who followed START-HERE got zero
  agents and zero hooks with no error explaining why. It now runs the same
  `/plugin marketplace add` + `/plugin install` flow as `INSTALL-…md`.
- **Update path.** `UPDATE.md` Step 0 looked in that same non-loading directory,
  so updating a correctly installed plugin reported "you never installed it" and
  stopped. It now checks the cache path and runs `/plugin update`.
- **`auto-test.sh` called `python`,** which does not exist on stock macOS 12.3+.
  On those machines every edit to a `.py` file ran a command that could not
  start, and the hook read that non-zero exit as "tests failed" and blocked the
  edit. It now resolves `python3` first and skips Python tests when no
  interpreter exists.
- **`auto-test.sh` failure feedback was malformed JSON** (an already-quoted
  string spliced inside quotes, plus `\n` that `echo` never expanded). Blocking
  mode now writes plain text to stderr, which is what exit code 2 consumes;
  warn mode builds its JSON with `jq`.
- **`VERSION` said 1.0.0** while `plugin.json` and the changelog said 3.1.x, so
  any version comparison gave the wrong answer.
- Removed three references to a `.mcp.json.example` that was never in the repo,
  and the Tier 0 instruction to run a `local-precheck.py` that only exists on
  the author's machine. Tier 0 is now described as optional and BYO.

### Added

- `SOLNEST_AUTOTEST` env var for the auto-test hook: `off` disables it, `warn`
  reports failures without blocking, unset/`block` keeps the old behaviour.
  Previously a repo with one pre-existing failing test refused every edit with
  no way out.

## [3.1.1] - 2026-06-10

### Changed

- THE LOOP's PLAN step now saves plans for complex/multi-session builds to
  `docs/plans/` in the project, making the plugin fully self-contained, no
  external planning plugin needed.
- Plugin README and CLAUDE.md genericized for public distribution (no
  machine-specific status, GitHub install as the primary path).

## [3.1.0] - 2026-06-10

Rolls up everything shipped since 3.0.0 (Sprint 1 + the Phase-0 upgrade) and the autonomy retune.

### Added

- Phase-0 operating model in `coding-agent.md` (recovered from the 2026-06-02 session): Clarify-First
  Gate, THE LOOP (clarify → plan + Definition of Done → build → inner test loop → verification
  panel → outer goal-loop), and an optional Tier 0 local pre-check.
- Plugin `README.md` and this changelog.

### Changed

- **Autonomy retuned: gates are now graduated by reversibility** (was: pause at every gate).
  Reversible → proceed with stated assumptions; costly to reverse → pause and confirm;
  irreversible/outward-facing → block. Autonomous runs convert pauses into board interactions.
- **Model pins**: `coding-agent`, `ai-engineer`, and `security-auditor` are unpinned and inherit the
  session model (so they ride the frontier); the 7 mechanical specialists stay pinned to
  `claude-sonnet-4-6` for cost control.
- Tool/skill references reconciled with what actually exists on the machine (T3/SOL-5).

## [3.0.0] - 2026-05-24

Initial tracked release of the Solnest Coding Agent coding plugin.

### Added

- `coding-agent` master orchestrator that routes any engineering task to the right specialist.
- 9 specialist agents: `ai-engineer`, `backend-architect`, `frontend-developer`,
  `ui-designer`, `code-reviewer`, `devops`, `security-auditor`, `performance-engineer`,
  and `project-shipper`.
- Plugin manifest (`.claude-plugin/plugin.json`) and `CLAUDE.md` plugin overview.
- Distribution via the local `solnest-local` marketplace (`marketplace.json`).
