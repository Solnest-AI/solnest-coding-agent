# Solnest Coding Agent

A Claude Code plugin that gives you a full software-development team: a **`coding-agent`** master orchestrator plus **9 engineering specialists** covering the complete development lifecycle — AI engineering, backend, frontend, UI/UX, code review, DevOps, security, performance, and project delivery.

For code work only — marketing, content, and business operations live elsewhere.

- **Plugin name:** `solnest-coding-agent`
- **Version:** `3.1.0`

---

## The 10 agents

One orchestrator and nine specialists. This set matches the agents documented in [`CLAUDE.md`](./CLAUDE.md) and the files in [`agents/`](./agents).

| Agent | Invoke for |
|-------|-----------|
| **`coding-agent`** | Master orchestrator. Pass any file and any command (`fix this`, `make this better`, `add tests`, `review for launch`, `build this API`, `audit security`). It reads the input, picks the right specialist(s), and does the work. Start here when you're not sure who to call. |
| **`ai-engineer`** | Claude API integrations, prompt engineering, agent design, RAG pipelines, embeddings, tool use — any AI/LLM feature. Solnest AI's core competency. |
| **`backend-architect`** | Python/Node.js APIs, database and Supabase schema design, authentication, server logic, system architecture. |
| **`frontend-developer`** | React/Next.js components, pages, layouts, Tailwind CSS, responsive design, client-side logic. |
| **`ui-designer`** | App layouts, design systems, component specs, responsive design, and visual interface work. |
| **`code-reviewer`** | Code review, debugging, refactoring, and build-error resolution. The second pair of eyes. |
| **`devops`** | CI/CD pipelines, Docker, Terraform, Kubernetes, deployment, infrastructure-as-code, incident response. |
| **`security-auditor`** | Security reviews, threat modeling, vulnerability analysis, dependency auditing, auth review. |
| **`performance-engineer`** | Profiling, benchmarking, database optimization, load testing, memory analysis, bundle-size reduction, caching. |
| **`project-shipper`** | Launch checklists, readiness reviews, blocker identification, and client delivery. |

Each specialist has full tool access and domain-specific instructions. The `coding-agent` orchestrator carries the routing logic and can invoke any specialist on your behalf — so you can either call a specialist directly or hand everything to `coding-agent`.

---

## Installation

The plugin is distributed through a Claude Code marketplace defined at the repository root in [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json), which points at the `./solnest-coding-agent` source directory.

**Installing from GitHub** (most users — public repo `Solnest-AI/solnest-coding-agent`):

```text
/plugin marketplace add Solnest-AI/solnest-coding-agent
/plugin install solnest-coding-agent@solnest
```

**Installing from a local clone** (development):

```text
# Point at the repo root — the folder that contains .claude-plugin/marketplace.json.
/plugin marketplace add /path/to/this/repo
/plugin install solnest-coding-agent@<marketplace-name>
```

After installation, restart Claude Code (or reload plugins) so the agents and hooks register. The running copy lives in the plugin cache (`~/.claude/plugins/cache/<marketplace>/solnest-coding-agent/<version>`) and is rebuilt whenever the plugin is updated.

> **Source of truth is this repo.** Do not edit the cached copy directly — anything changed only in the cache is destroyed on the next plugin update.

To pick up new versions:

```text
/plugin update solnest-coding-agent
```

---

## Hooks

Two automated quality gates ship with the plugin, wired up in [`hooks/hooks.json`](./hooks/hooks.json). Both are part of the plugin and run automatically once it's installed.

### `secret-scan.sh` — pre-commit secret scanner

- **Trigger:** `PreToolUse` on `Bash` (15s timeout).
- **What it does:** Inspects the Bash command about to run. If it's a `git commit`, it scans the **staged diff** (added lines only) for hardcoded secrets before the commit is allowed through.
- **Detects:** Anthropic and OpenAI API keys, AWS access key IDs, GitHub personal-access and OAuth tokens, Slack bot/user tokens, Apify tokens, GoHighLevel keys, JWTs, PEM private keys, and inline hardcoded passwords. (See [`hooks/scripts/secret-scan.sh`](./hooks/scripts/secret-scan.sh) for the exact patterns.)
- **On a match:** The commit is **denied** (the hook exits non-zero and returns a `deny` decision) with a message listing the offending file and pattern. Remove the secret and use an environment variable instead.
- **Skips:** `*.sh`, `*.lock`, and `*.env.example` files, plus deleted files. Non-commit Bash commands pass straight through.

This gate is meant to stay **on**. Don't bypass it.

### `auto-test.sh` — post-edit test loop

- **Trigger:** `PostToolUse` on `Edit` or `Write` (120s timeout).
- **What it does:** After a source file is edited, it walks up from the file to find the project root, auto-detects the test runner, and runs the tests:

  | Project marker | Test command |
  |----------------|--------------|
  | `package.json` with a real `test` script | `npm test --silent` |
  | `pyproject.toml` / `setup.py` / `pytest.ini` / `setup.cfg` (or `requirements.txt` + a `tests/` dir) | `python -m pytest -q --tb=line --no-header` |
  | `Cargo.toml` | `cargo test --quiet` |
  | `go.mod` | `go test ./...` |

- **Only runs on source files:** `.ts .tsx .js .jsx .py .go .rs .java .vue .svelte .rb .php .swift .kt`. Anything else (docs, config, JSON, Markdown) is skipped — so editing this README does **not** trigger a test run.
- **On pass:** reports success as a system message.
- **On fail:** feeds the truncated test output back to Claude (exit code 2) so it can fix the failure and re-edit — which re-triggers the hook, forming a test → fail → fix → retest loop.
- **No-op when** no project root or no test command is found (it reminds rather than blocks).

---

## MCP prerequisites

The agents are designed to **degrade gracefully** — they use MCP servers "when available" and fall back to standard tools otherwise. None are hard-required to load the plugin, but the following unlock the full capability of the relevant specialists:

| MCP / tool | Used by | For |
|------------|---------|-----|
| **Supabase MCP** | `backend-architect`, `performance-engineer`, `ai-engineer`, `coding-agent` | Database operations, migrations, RLS policies, edge functions, pgvector. |
| **Figma MCP** | `ui-designer`, `frontend-developer` | Reading design files, extracting specs, screenshots, code connect. |
| **Playwright MCP** | `frontend-developer`, `ui-designer`, `code-reviewer` | Browser automation and UI testing. |
| **Magic 21st MCP** | `ui-designer`, `frontend-developer` | Pre-built component inspiration and scaffolding. |
| **`ui-ux-pro-max` skill** | `ui-designer`, `frontend-developer` | Comprehensive UI/UX design decisions (palette, typography, layout). |
| **`image-gen` skill** | `ui-designer` | Visual mockups. |

**Tool availability.** Every entry is optional. MCP servers are used only if you configure them; the two skills (`ui-ux-pro-max`, `image-gen`) are used only if registered on your machine — otherwise the agents apply the underlying principles directly. Agents check before using and fall back to their built-in toolset, so nothing breaks when a tool is absent.

Configure MCP servers through your Claude Code MCP settings — a local project `.mcp.json` (gitignored; copy `.mcp.json.example` for a secret-free template) or your user-level config. If a server isn't configured, the agent notes it's unavailable and proceeds with its built-in toolset.

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
