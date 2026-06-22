# Solnest Coding Agent — Coding Agent

Full-stack engineering plugin for Solnest AI — 10 agents covering the complete software development lifecycle.

## What This Is

A Claude Code plugin with 9 engineering specialists and a master orchestrator. Based on the AI Agent Org Chart v2 (8 departments, 45+ roles). For code work only — marketing, content, and business operations live in `solnest-business-agents`.

## Agents

| Agent | Domain | Org Chart Mapping |
|-------|--------|-------------------|
| **Coding Agent** | Master orchestrator — routes any task to the right specialist(s) | Chief of Staff |
| **AI Engineer** | Claude API, prompt engineering, RAG, embeddings, agent design, MLOps | ML Engineer + Data Engineer |
| **Backend Architect** | Python, Node.js, APIs, databases, cloud architecture, monorepo design | Architect (System Design) |
| **Frontend Developer** | React, Next.js, Tailwind, mobile (React Native, Flutter) | Frontend Dev (Web & Mobile) |
| **UI Designer** | Layouts, design systems, accessibility, UX research, Figma | UX Designer (UI & Experience) |
| **Code Reviewer** | Code review, debugging, refactoring, build error resolution | Code Reviewer (Quality Assurance) |
| **DevOps** | CI/CD, Docker, Terraform, Kubernetes, deployment, incident response | DevOps (Deploy & Operate) |
| **Security Auditor** | Security review, threat modeling, vulnerability analysis, dependency audit | Security Auditor (Threat & Compliance) |
| **Performance Engineer** | Profiling, benchmarking, database optimization, caching, scaling | Performance Eng. (Speed & Scale) |
| **Project Shipper** | Launch checklists, risk assessment, planning, client delivery | Leadership (Coordination) |

## Tools Available

These are **optional integrations** the agents use when present. The plugin loads and works without any of them — agents check what's configured and degrade gracefully to their built-in toolset.

| Tool / skill | Used for | If configured |
|--------------|----------|---------------|
| **Supabase MCP** | Database operations, migrations | Agents use it for DB work |
| **Figma MCP** | Design context, screenshots, code connect | ui-designer pulls live design context |
| **Playwright MCP** | Browser automation, testing | Agents use it for end-to-end verification |
| **Magic 21st MCP** | Component building / inspiration | frontend-developer uses it for components |
| **`ui-ux-pro-max` skill** | Comprehensive UI/UX design decisions | Used if registered; otherwise the principles are applied directly |
| **`image-gen` skill** | Visual mockups | Used if registered; otherwise skipped |

### Tool availability

- Agents **check before using**: if a tool or skill above isn't configured on your machine, they note the gap and fall back to their built-in toolset — nothing breaks.
- To enable an optional MCP server, add it to your project's `.mcp.json` (see `.mcp.json.example` for a secret-free template) or your user-level Claude Code config.

## Rules

- **Run THE LOOP** (see coding-agent.md) for any non-trivial task: clarify → plan + Definition of Done → build (worker, or parallel specialists for independent workstreams) → inner test loop → verification panel (fresh-context critics, scaled to complexity) → outer goal-loop until done. **Gate by reversibility** — proceed with stated assumptions on reversible steps; pause to confirm spec/plan on costly-to-reverse choices; block on irreversible or outward-facing actions. In autonomous runs, pauses become board interactions, not stalls.
- **Verification is dispatched, never self-reviewed:** code-reviewer / security-auditor / performance-engineer / spec-judge run as fresh Task-tool subagents. Scale the panel up for complex or high-stakes work; trivial work just needs the test loop.
- **Tier 0 = local pre-check (free):** before frontier critics, run `python3 ~/.claude/scripts/local-precheck.py <files|--diff>` — local qwen3-coder-next catches obvious bugs/security/spec issues at $0. Fix those first, then escalate only what's left to the frontier critics. Non-blocking on error. If the script or local model isn't installed on this machine, this tier auto-skips — it's an optional power-up, not a requirement.
- This loop is a self-contained unit so it can be hired as a single "employee" by an orchestration layer (e.g. Paperclip) via AGENTS.md.
- Always read files fully before editing
- Run tests before and after code changes
- Never commit `.env` files
- Never commit `node_modules/`
- Build what was asked for — no speculative abstractions
