# Solnest Coding Agent

A 10-agent coding plugin for [Claude Code](https://claude.com/claude-code) — a master orchestrator plus 9 engineering specialists, with automated quality gates baked in.

This is the same agent system Solnest AI uses every day to build client projects.

## Install (two commands)

Inside Claude Code, type:

```
/plugin marketplace add Solnest-AI/solnest-coding-agent
/plugin install solnest-coding-agent@solnest
```

Restart Claude Code, then type `/agents` — you should see **coding-agent** plus 9 specialists.

**Easiest path:** download `INSTALL-SOLNEST-CODING-AGENT.md` from this repo, drag it into Claude Code, and say *"set this up"* — Claude walks you through everything, checks your prerequisites, and verifies the install.

## What you get

| Agent | What it does |
|-------|--------------|
| **coding-agent** | Master orchestrator — runs THE LOOP: clarify → plan + Definition of Done → build → test → verify → repeat until done |
| **ai-engineer** | Claude API, prompts, RAG, embeddings, agent design |
| **backend-architect** | Python, Node.js, APIs, databases, cloud architecture |
| **frontend-developer** | React, Next.js, Tailwind, mobile |
| **ui-designer** | Layouts, design systems, accessibility, UX |
| **code-reviewer** | Code review, debugging, refactoring, build errors |
| **devops** | CI/CD, Docker, Terraform, Kubernetes, deployment |
| **security-auditor** | Security review, threat modeling, dependency audits |
| **performance-engineer** | Profiling, benchmarking, optimization, caching |
| **project-shipper** | Launch checklists, risk assessment, client delivery |

Plus two automated quality gates (no setup needed):

- **Secret scan** — blocks any `git commit` that contains hardcoded API keys or credentials.
- **Auto-test loop** — runs your project's tests after every code edit and feeds failures straight back to Claude to fix.

## How it works

The coding-agent doesn't just write code — it runs a closed loop: it asks clarifying questions up front (only when getting it wrong would be expensive), writes a Definition of Done, builds, tests after every edit, then dispatches **fresh-context critics** (code review + security audit, scaled up for complex work) that never review their own code, and loops until the Definition of Done is met.

See [`solnest-coding-agent/README.md`](solnest-coding-agent/README.md) for full agent docs.

## Updating

```
/plugin update solnest-coding-agent
```

New versions are announced in the Solnest AI community — see [CHANGELOG.md](CHANGELOG.md).

## Requirements

- Claude Code (latest)
- `git` and `jq` (the installer checks these for you)

---

Built by [Solnest AI](https://solnestai.com) — we help business owners implement AI so they can work *on* their business, not in it.

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Solnest AI.
