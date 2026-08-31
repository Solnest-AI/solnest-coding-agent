# UPDATE — Solnest Coding Agent (Claude reads this)

**You are Claude. The user pasted this repo's link and asked you to update their Solnest Coding Agent. Do it FOR them, in plain language.**

Good news: this plugin stores **no user config of its own**. The agents are just instruction files. So there's nothing of theirs to lose and nothing to back up.

---

## Step 0 — Confirm it's installed

Have them type `/plugin` and look under **Manage plugins**, or check that this folder exists:

- macOS / Linux: `~/.claude/plugins/cache/solnest/solnest-coding-agent/`
- Windows: `%USERPROFILE%\.claude\plugins\cache\solnest\solnest-coding-agent\`

Not there? They never installed it (or they hand-copied it into `~/.claude/plugins/`, which Claude Code doesn't load). Send them to [`START-HERE.md`](START-HERE.md) for a fresh install and stop here.

## Step 1 — Check if they even need this

The installed version is in `.claude-plugin/plugin.json` inside the folder above. Compare it to `solnest-coding-agent/.claude-plugin/plugin.json` in this repo. Match? Say so and stop:

> You're already on the latest version (`X.Y.Z`) — nothing to update.

## Step 2 — Run the update

One command, typed by them inside Claude Code:

```
/plugin update solnest-coding-agent
```

That re-pulls the marketplace and replaces the plugin files. **Do not hand-copy files** — a manual copy into `~/.claude/plugins/` is not a location Claude Code loads from, and it will look like the update silently did nothing.

If the update command says the marketplace is missing, have them re-add it first:

```
/plugin marketplace add Solnest-AI/solnest-coding-agent
```

## Step 3 — Restart

**Tell them to fully quit and reopen Claude Code.** Plugins only reload on startup — if they skip this, they'll swear the update didn't work.

## Step 4 — Verify

`/agents` should list **coding-agent** plus the 9 specialists, and `plugin.json` in the cache folder should show the new version number.

## Step 5 — Tell them what changed

Two or three plain bullets from `CHANGELOG.md`, new version only.

> Updated to `X.Y.Z`. Quit and reopen Claude Code and your agents are running the new version.
