# START HERE — Auto-installer (Claude reads this)

**You are Claude. The user just dragged in this folder to install the "Solnest Coding Agent." Walk them through the install now, one step at a time, in plain language. Never paste a raw error at them — fix it quietly or explain it in one friendly sentence.**

This is a **plugin**, not a plain skill — it's a team of 10 coding agents (one orchestrator plus nine specialists). There's nothing to compile and no API keys needed.

**Important: do NOT hand-copy this folder into `~/.claude/plugins/`.** Claude Code does not load loose folders from there. Plugins only load when they're registered through the `/plugin` commands below, which put the files where Claude Code actually looks (`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`). A hand-copied folder gives the user zero agents and zero hooks, with no error to explain why.

---

## Step 1 — Check their prerequisites

Run these and fix what's missing before anything else:

1. **git** — `git --version`. Missing? macOS: `xcode-select --install`. Windows: install from git-scm.com.
2. **jq** — `jq --version`. The quality-gate hooks need it. Missing? `brew install jq` (macOS) or `winget install jqlang.jq` (Windows).
3. **GitHub reachable** — `git ls-remote https://github.com/Solnest-AI/solnest-coding-agent.git HEAD` should return a commit hash.

Tell them what you found in one line (e.g. "✅ git and jq are ready").

## Step 2 — Have them run the two install commands

You can't run slash commands yourself. Give them these one at a time and wait for each to finish:

```
/plugin marketplace add Solnest-AI/solnest-coding-agent
```

then:

```
/plugin install solnest-coding-agent@solnest
```

If they're asked to confirm or trust the marketplace, that's expected — it's the Solnest AI repo they just added.

## Step 3 — Restart Claude Code

Tell them plainly: **fully quit and reopen Claude Code.** Plugins only load on startup. If they skip this, nothing will work and they'll think it's broken.

## Step 4 — Check it actually landed

1. Have them type `/agents` — they should see **coding-agent** plus 9 specialists.
2. Confirm the hooks landed: `~/.claude/plugins/cache/solnest/solnest-coding-agent/` exists and contains `hooks/hooks.json`. If the folder name looks different, find it with `ls ~/.claude/plugins/cache/`.

Nothing there? The usual fix is re-running the two commands in Step 2 and restarting again.

## Step 5 — Tell them they're done

> You're set. You've got a 10-agent coding team now — just talk to it normally. Say "build this feature," "fix this bug," "review this for launch," or "audit this for security," and it routes the job to the right specialist automatically. You don't have to name the agents.
>
> When a new version ships, run `/plugin update solnest-coding-agent`.

---

Want the longer version with a guided first mission? That's [`INSTALL-SOLNEST-CODING-AGENT.md`](INSTALL-SOLNEST-CODING-AGENT.md) in this repo — same install, more hand-holding.
