# Solnest Coding Agent

A Claude Code plugin that gives you a full software-development team: a **`coding-agent`** master orchestrator plus **9 engineering specialists** covering the complete development lifecycle, AI engineering, backend, frontend, UI/UX, code review, DevOps, security, performance, and project delivery.

For code work only, marketing, content, and business operations live elsewhere.

- **Plugin name:** `solnest-coding-agent`
- **Version:** `3.2.0`

---

## The 10 agents

One orchestrator and nine specialists. This set matches the agents documented in [`CLAUDE.md`](./CLAUDE.md) and the files in [`agents/`](./agents).

| Agent | Invoke for |
|-------|-----------|
| **`coding-agent`** | Master orchestrator. Pass any file and any command (`fix this`, `make this better`, `add tests`, `review for launch`, `build this API`, `audit security`). It reads the input, picks the right specialist(s), and does the work. Start here when you're not sure who to call. |
| **`ai-engineer`** | Claude API integrations, prompt engineering, agent design, RAG pipelines, embeddings, tool use: any AI/LLM feature. Solnest AI's core competency. |
| **`backend-architect`** | Python/Node.js APIs, database and Supabase schema design, authentication, server logic, system architecture. |
| **`frontend-developer`** | React/Next.js components, pages, layouts, Tailwind CSS, responsive design, client-side logic. |
| **`ui-designer`** | App layouts, design systems, component specs, responsive design, and visual interface work. |
| **`code-reviewer`** | Code review, debugging, refactoring, and build-error resolution. The second pair of eyes. |
| **`devops`** | CI/CD pipelines, Docker, Terraform, Kubernetes, deployment, infrastructure-as-code, incident response. |
| **`security-auditor`** | Security reviews, threat modeling, vulnerability analysis, dependency auditing, auth review. |
| **`performance-engineer`** | Profiling, benchmarking, database optimization, load testing, memory analysis, bundle-size reduction, caching. |
| **`project-shipper`** | Launch checklists, readiness reviews, blocker identification, and client delivery. |

Each specialist has full tool access and domain-specific instructions. The `coding-agent` orchestrator carries the routing logic and can invoke any specialist on your behalf, so you can either call a specialist directly or hand everything to `coding-agent`.

---

## Installation

The plugin is distributed through a Claude Code marketplace defined at the repository root in [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json), which points at the `./solnest-coding-agent` source directory.

**Most users:** paste the repo link (`https://github.com/Solnest-AI/solnest-coding-agent`) into Claude Code and say "set this up". Claude follows the `CLAUDE.md` at the top of the repo: it puts the tool in `~/solnest/coding-agent`, installs the plugin from that folder and turns on automatic updates.

**Installing from a local clone** (development):

```text
# Point at the repo root: the folder that contains .claude-plugin/marketplace.json.
/plugin marketplace add /path/to/this/repo
/plugin install solnest-coding-agent@<marketplace-name>
```

After installation, restart Claude Code (or reload plugins) so the agents and hooks register. The running copy lives in the plugin cache (`~/.claude/plugins/cache/<marketplace>/solnest-coding-agent/<version>`) and is rebuilt whenever the plugin is updated.

> **Source of truth is this repo.** Do not edit the cached copy directly, anything changed only in the cache is destroyed on the next plugin update.

New versions install themselves: once a day, in the background when Claude Code starts, the tool checks for a new published release, installs it and reinstalls the plugin. The new version loads the next time Claude Code opens.

---

## Hooks

Two automated quality gates ship with the plugin, wired up in [`hooks/hooks.json`](./hooks/hooks.json). Both are part of the plugin and run automatically once it's installed.

### `secret-scan.sh`: pre-commit secret scanner

- **Trigger:** `PreToolUse` on `Bash` (15s timeout).
- **What it does:** Inspects the Bash command about to run. If it runs a `git commit` anywhere (including `git add . && git commit`, `cd dir && git commit`, `git -C dir commit`, or a multi-line command), it scans what that commit will contain for hardcoded secrets before the command is allowed through:
  - always the **staged diff** (added lines only);
  - plus unstaged and untracked changes when the same command stages files (`git add`, `git commit -a`), because the hook runs *before* the `git add` does.
- **Detects:** Anthropic and OpenAI API keys, AWS access key IDs, GitHub personal-access and OAuth tokens, Slack bot/user tokens, Apify tokens, GoHighLevel keys, JWTs, PEM private keys, and inline hardcoded passwords. (See [`hooks/scripts/secret-scan.sh`](./hooks/scripts/secret-scan.sh) for the exact patterns.)
- **On a match:** The commit is **blocked** (exit code 2) with a message listing the offending file and pattern. Remove the secret and use an environment variable instead.
- **Skips:** `*.lock` and `*.env.example` files, plus deleted files. Non-commit Bash commands pass straight through.

This gate is meant to stay **on**. Don't bypass it.

### `auto-test.sh`: post-edit test loop

- **Trigger:** `PostToolUse` on `Edit` or `Write` (120s timeout).
- **What it does:** After a source file is edited, it walks up from the file to find the project root, auto-detects the test runner, and runs the tests:

  | Project marker | Test command |
  |----------------|--------------|
  | `package.json` with a real `test` script | `npm test --silent` |
  | `pyproject.toml` / `setup.py` / `pytest.ini` / `setup.cfg` (or `requirements.txt` + a `tests/` dir) | `python3 -m pytest -q --tb=line --no-header` |
  | `Cargo.toml` | `cargo test --quiet` |
  | `go.mod` | `go test ./...` |

- **Only runs on source files:** `.ts .tsx .js .jsx .py .go .rs .java .vue .svelte .rb .php .swift .kt`. Anything else (docs, config, JSON, Markdown) is skipped: so editing this README does **not** trigger a test run.
- **On pass:** reports success as a system message.
- **On fail:** feeds the truncated test output back to Claude (exit code 2) so it can fix the failure and re-edit: which re-triggers the hook, forming a test → fail → fix → retest loop.
- **TDD red step:** if the edited file is itself a test (`test_*.py`, `*.test.ts`, `*_test.go`, anything under `tests/`, and so on), failures are passed to Claude as context instead of a "fix this" block, so writing a failing test first isn't treated as an error.
- **Not counted as failures:** no tests collected (pytest exit 5, jest/vitest "No tests found") and a missing test runner (`No module named pytest`, command not found). These report as skipped.
- **No-op when** no project root or no test command is found, or when no Python interpreter is on `PATH` for a Python project.
- **Turning it down.** By default a red suite blocks the edit. On a repo whose tests were already failing, or mid-refactor when red is expected, that gets in the way: so set the `SOLNEST_AUTOTEST` environment variable:

  | Value | Behaviour |
  |-------|-----------|
  | unset / `block` | Default. Tests run; a failure blocks the edit and is fed back to Claude. |
  | `warn` | Tests run; a failure is reported but never blocks. |
  | `off` | The hook exits immediately and runs nothing. |

---

## MCP prerequisites

The agents are designed to **degrade gracefully**: they use MCP servers "when available" and fall back to standard tools otherwise. None are hard-required to load the plugin, but the following unlock the full capability of the relevant specialists:

| MCP / tool | Used by | For |
|------------|---------|-----|
| **Supabase MCP** | `backend-architect`, `performance-engineer`, `ai-engineer`, `coding-agent` | Database operations, migrations, RLS policies, edge functions, pgvector. |
| **Figma MCP** | `ui-designer`, `frontend-developer` | Reading design files, extracting specs, screenshots, code connect. |
| **Playwright MCP** | `frontend-developer`, `ui-designer`, `code-reviewer` | Browser automation and UI testing. |
| **Magic 21st MCP** | `ui-designer`, `frontend-developer` | Pre-built component inspiration and scaffolding. |
| **`ui-ux-pro-max` skill** | `ui-designer`, `frontend-developer` | Comprehensive UI/UX design decisions (palette, typography, layout). |
| **`image-gen` skill** | `ui-designer` | Visual mockups. |

**Tool availability.** Every entry is optional. MCP servers are used only if you configure them; the two skills (`ui-ux-pro-max`, `image-gen`) are used only if registered on your machine, otherwise the agents apply the underlying principles directly. Agents check before using and fall back to their built-in toolset, so nothing breaks when a tool is absent.

Configure MCP servers through your Claude Code MCP settings, a local project `.mcp.json` (keep it gitignored, it holds keys) or your user-level config. If a server isn't configured, the agent notes it's unavailable and proceeds with its built-in toolset.

---

## Repository layout

```text
solnest-coding-agent/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest (name, version, description)
├── agents/                  # 10 agent definitions (coding-agent + 9 specialists)
│   ├── coding-agent.md
│   ├── ai-engineer.md
│   ├── backend-architect.md
│   ├── frontend-developer.md
│   ├── ui-designer.md
│   ├── code-reviewer.md
│   ├── devops.md
│   ├── security-auditor.md
│   ├── performance-engineer.md
│   └── project-shipper.md
├── hooks/
│   ├── hooks.json           # Hook wiring (PreToolUse / PostToolUse)
│   └── scripts/
│       ├── secret-scan.sh   # Pre-commit secret scanner
│       └── auto-test.sh     # Post-edit auto-test loop
├── CLAUDE.md                # Brand context + agent index (source of truth for the agent set)
└── README.md                # This file
```

The marketplace manifest lives one level up at the repo root: [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json).
