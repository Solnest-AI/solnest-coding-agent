# Solnest Coding Agent

A team of 10 coding agents for [Claude Code](https://claude.com/claude-code). One lead agent plans the work, builds it, tests it and has a second agent check it. Nine specialists cover the rest: AI features, backend, frontend, design, code review, deployment, security, speed and launch.

This is the same agent team Solnest AI uses every day to build client projects.

## What you need

- Claude Code (a paid Claude plan).
- Nothing else. No accounts, no keys, no extra cost. Setup checks for two free helpers (git and jq) and tells you if one is missing.

## Install

1. Copy this page's link: `https://github.com/Solnest-AI/solnest-coding-agent`
2. Paste it into Claude Code and say **"set this up"**. Claude does the rest and tells you when to restart.
3. Try it. Open any project folder and say: **"Build me a single-file HTML page that works out the monthly payment on a loan. Make it look clean."**

Already installed the old way (two slash commands)? Do the same three steps. Setup moves you to the new way and keeps everything working.

## What you get

| Agent | What it does |
|-------|--------------|
| **coding-agent** | The lead. Asks the few questions that matter, writes down what "done" means, builds, tests, gets the work checked, and repeats until it is done |
| **ai-engineer** | Claude API, prompts, search over your own documents, agent design |
| **backend-architect** | Python, Node.js, APIs, databases, cloud |
| **frontend-developer** | React, Next.js, Tailwind, mobile |
| **ui-designer** | Layouts, design systems, accessibility |
| **code-reviewer** | Code review, debugging, cleanup, build errors |
| **devops** | Automated builds, Docker, deployment |
| **security-auditor** | Security review and dependency checks |
| **performance-engineer** | Finding and fixing slow code |
| **project-shipper** | Launch checklists, risk checks, client delivery |

You never have to name an agent. Just say "fix this", "build me X" or "review this for launch" and the lead picks the right one.

Two safety checks run by themselves:

- **Secret check.** Blocks any commit that contains a password or an API key.
- **Test check.** Runs your project's tests after every code edit and hands failures straight back to Claude to fix. If it gets in your way, ask Claude to "turn the test check down to warn" (or off).

## Updates

Updates install themselves. Once a day, in the background, the tool checks for a new release and installs it. Your own changes are never wiped: when you ask Claude to change how the coding agent works for you, it saves that in a file of your own that updates do not touch.

Want the newest version right now? Say **"update the coding agent"**. What changed is in [CHANGELOG.md](CHANGELOG.md).

## Help

Email hello@solnestai.com, or post in the Solnest AI Skool community with a screenshot.

Full agent and hook docs: [`solnest-coding-agent/README.md`](solnest-coding-agent/README.md).

---

Built by [Solnest AI](https://solnestai.com). We help business owners put AI to work so they can work on their business, not in it.

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Solnest AI.
