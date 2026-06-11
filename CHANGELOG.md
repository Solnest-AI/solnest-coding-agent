# Changelog

All notable changes to the `solnest-ai-studio` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.1] - 2026-06-10

### Changed

- THE LOOP's PLAN step now saves plans for complex/multi-session builds to
  `docs/plans/` in the project, making the plugin fully self-contained — no
  external planning plugin needed.
- Plugin README and CLAUDE.md genericized for public distribution (no
  machine-specific status, GitHub install as the primary path).

## [3.1.0] - 2026-06-10

Rolls up everything shipped since 3.0.0 (Sprint 1 + the Phase-0 upgrade) and the autonomy retune.

### Added

- Phase-0 operating model in `studio.md` (recovered from the 2026-06-02 session): Clarify-First
  Gate, THE LOOP (clarify → plan + Definition of Done → build → inner test loop → verification
  panel → outer goal-loop), and the Tier 0 local pre-check (`local-precheck.py`, qwen3-coder-next).
- Plugin `README.md`, secret-free `.mcp.json.example`, this changelog.

### Changed

- **Autonomy retuned: gates are now graduated by reversibility** (was: pause at every gate).
  Reversible → proceed with stated assumptions; costly to reverse → pause and confirm;
  irreversible/outward-facing → block. Autonomous runs convert pauses into board interactions.
- **Model pins**: `studio`, `ai-engineer`, and `security-auditor` are unpinned and inherit the
  session model (so they ride the frontier); the 7 mechanical specialists stay pinned to
  `claude-sonnet-4-6` for cost control.
- Tool/skill references reconciled with what actually exists on the machine (T3/SOL-5).

## [3.0.0] - 2026-05-24

Initial tracked release of the Solnest AI Studio coding plugin.

### Added

- `studio` master orchestrator that routes any engineering task to the right specialist.
- 9 specialist agents: `ai-engineer`, `backend-architect`, `frontend-developer`,
  `ui-designer`, `code-reviewer`, `devops`, `security-auditor`, `performance-engineer`,
  and `project-shipper`.
- Plugin manifest (`.claude-plugin/plugin.json`) and `CLAUDE.md` plugin overview.
- Distribution via the local `solnest-local` marketplace (`marketplace.json`).
