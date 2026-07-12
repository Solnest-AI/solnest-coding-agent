# START HERE — Auto-installer (Claude reads this)

**You are Claude. The user just dragged in this folder to install the "Solnest Coding Agent." Do the install FOR them now, one step at a time, in plain language. Never paste a raw error at them — fix it quietly or explain it in one friendly sentence.**

This is a **plugin**, not a plain skill — it's a team of 10 coding agents (one orchestrator plus nine specialists). There's nothing to compile and no API keys needed.

---

## Step 1 — Find the two paths

- **Source:** the folder this file is sitting in (it contains a `solnest-coding-agent/` subfolder with `agents/` inside).
- **Destination:** the user's Claude plugins folder:
  - macOS / Linux: `~/.claude/plugins/solnest-coding-agent`
  - Windows: `%USERPROFILE%\.claude\plugins\solnest-coding-agent`

If it's already there, tell them you're updating their existing copy and carry on.

## Step 2 — Copy the plugin into place

**macOS / Linux:**
```bash
mkdir -p ~/.claude/plugins
cp -R "<<THIS_FOLDER>>/solnest-coding-agent" ~/.claude/plugins/solnest-coding-agent
```

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\plugins" | Out-Null
Copy-Item -Recurse -Force "<<THIS_FOLDER>>\solnest-coding-agent" "$env:USERPROFILE\.claude\plugins\solnest-coding-agent"
```

(Replace `<<THIS_FOLDER>>` with the real path you're reading this from.)

## Step 3 — Restart Claude Code

Tell them plainly: **fully quit and reopen Claude Code.** Plugins only load on startup. If they skip this, nothing will work and they'll think it's broken.

## Step 4 — Check it actually landed

Have them start a new chat and say: **"review this code for bugs."** If a specialist agent picks it up, it's working. ✅

## Step 5 — Tell them they're done

> You're set. You've got a 10-agent coding team now — just talk to it normally. Say "build this feature," "fix this bug," "review this for launch," or "audit this for security," and it routes the job to the right specialist automatically. You don't have to name the agents.
