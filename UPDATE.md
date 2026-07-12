# UPDATE — Solnest Coding Agent (Claude reads this)

**You are Claude. The user pasted this repo's link and asked you to update their Solnest Coding Agent. Do it FOR them, in plain language.**

Good news: this plugin stores **no user config of its own**. The agents are just instruction files. So there's nothing of theirs to lose and nothing to back up — a clean overwrite is safe.

---

## Step 0 — Find their install

- macOS / Linux: `~/.claude/plugins/solnest-coding-agent/`
- Windows: `%USERPROFILE%\.claude\plugins\solnest-coding-agent\`

Not there? They never installed it. Point them at the Skool zip for a fresh install and stop.

## Step 1 — Check if they even need this

Compare `VERSION` in this repo to theirs. Match? Say so and stop:

> You're already on the latest version (`X.Y.Z`) — nothing to update.

## Step 2 — What to preserve

**Nothing.** This plugin keeps no settings, no keys, and no state. Overwrite it cleanly.

One exception: if they've **added their own custom agents** into the plugin's `agents/` folder, leave those alone. Only replace the nine specialists and the orchestrator that ship with this repo.

## Step 3 — Pull the latest

```bash
git clone --depth 1 https://github.com/Solnest-AI/solnest-coding-agent.git /tmp/sca-update
```

No `git`? Download `https://github.com/Solnest-AI/solnest-coding-agent/archive/refs/heads/main.zip`.

## Step 4 — Copy the new files over

Copy `solnest-coding-agent/` from the fresh clone into their plugins folder, file over file. Include `agents/`, `hooks/`, `CLAUDE.md`, and `.claude-plugin/plugin.json`.

## Step 5 — Restart

**Tell them to fully quit and reopen Claude Code.** Plugins only reload on startup — if they skip this, they'll swear the update didn't work.

## Step 6 — Tell them what changed

Two or three plain bullets from `CHANGELOG.md`, new version only.

> Updated to `X.Y.Z`. Quit and reopen Claude Code and your agents are running the new version.
