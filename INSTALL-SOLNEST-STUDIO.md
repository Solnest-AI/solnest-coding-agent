# Solnest AI Studio — Setup Instructions

> **If you're a person reading this:** drag this file into Claude Code and say **"set this up"**. Claude takes it from there. That's the whole job.
>
> **If you're Claude Code reading this:** the rest of this file is for you. Follow it step by step, in order. Don't skip the verification.

---

## What you are installing

The **Solnest AI Studio** plugin: a master orchestrator agent (`studio`) plus 9 engineering specialists, with two automated quality gates (a pre-commit secret scanner and an auto-test loop). It installs from the public GitHub repo `Solnest-AI/solnest-ai-studio` as a Claude Code plugin, so future updates are one command.

The user you're helping is likely a business owner, not a developer. Be friendly, explain what you're doing in one plain sentence per step, and never dump raw error logs on them without a translation.

## Step 1 — Check prerequisites

Run these checks and fix what's missing **before** anything else:

1. **git** — `git --version`. If missing: on macOS run `xcode-select --install`; on Windows direct them to install Git from git-scm.com (offer to open the page).
2. **jq** — `jq --version`. The plugin's quality-gate hooks need it. If missing: `brew install jq` (macOS — install Homebrew first if needed) or `winget install jqlang.jq` (Windows).
3. **GitHub reachability** — `git ls-remote https://github.com/Solnest-AI/solnest-ai-studio.git HEAD` should return a commit hash. If it fails, diagnose their network before continuing.

Tell the user what you found in one line (e.g. "✅ git and jq are ready").

## Step 2 — Install the plugin

You cannot run slash commands yourself — the user has to type these two lines. Present them EXACTLY like this, one at a time, and wait for them to confirm each ran:

```
/plugin marketplace add Solnest-AI/solnest-ai-studio
```

then:

```
/plugin install solnest-ai-studio@solnest
```

If the install prompt asks them to confirm or trust the marketplace, tell them that's expected — it's the Solnest AI repo they just added.

## Step 3 — Restart and verify

1. Ask the user to restart Claude Code (quit and reopen, or `/exit` and relaunch) so the plugin loads.
2. After restart, have them type `/agents` — they should see **studio** plus 9 specialists (ai-engineer, backend-architect, frontend-developer, ui-designer, code-reviewer, devops, security-auditor, performance-engineer, project-shipper).
3. Verify the hooks landed: check that `~/.claude/plugins/cache/solnest/solnest-ai-studio/` exists and contains `hooks/hooks.json`. If the folder name differs slightly, find it with `ls ~/.claude/plugins/cache/`.

If anything is missing, the most common fix is re-running the two slash commands and restarting again.

## Step 4 — First mission (5 minutes, do not skip)

The fastest way for the user to *feel* what they just installed. Offer them this exact test-drive:

> Ask the studio agent: **"Build me a single-file HTML page that calculates the monthly payment on a loan — amount, interest rate, term. Make it look clean."**

Then narrate what's happening as it runs, because this demonstrates the whole system:

- **It may ask 1–3 questions first** (or state its assumptions and proceed) — that's the Clarify-First Gate deciding whether getting it wrong would be expensive.
- **It writes a Definition of Done before coding** — that's THE LOOP.
- **After it builds, a separate fresh-context reviewer checks the work** — the builder never grades its own homework.
- **If they later commit code with an API key in it, the commit gets blocked** — that's the secret-scan gate, always on.

## Step 5 — Tell them how to use it day-to-day

Close with this summary (adapt to your voice, keep it short):

- **Just talk normally.** "Fix this", "build me X", "review this for launch" — the studio routes it to the right specialist automatically.
- **Big or risky tasks** → it pauses and asks before doing anything expensive to undo. Reversible stuff → it just proceeds and tells you what it assumed.
- **Updates:** when Solnest AI ships a new version, run `/plugin update solnest-ai-studio`. New versions get announced in the community.
- **Optional power-up (advanced):** the verification loop mentions a free "Tier 0" local pre-check using a local model via Ollama. It auto-skips if not installed — nothing is broken. Members who want it can ask in the community for the local-models lesson.

## Troubleshooting quick hits

- **"marketplace add" fails** → they typed it in a terminal instead of inside Claude Code, or GitHub is unreachable (Step 1.3).
- **Agents don't show after install** → they didn't restart Claude Code (Step 3.1).
- **Hook errors mentioning `jq`** → Step 1.2 was skipped; install jq and restart.
- **Anything else** → post in the Solnest AI Skool community with a screenshot; include the output of `/plugin` → "Manage marketplaces".

---

*Solnest AI Studio v3.1.1 — built by Solnest AI. This installer is safe to re-run; every step is idempotent.*
