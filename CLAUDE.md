If the user said "set this up", follow SETUP below.
If the user said "update the coding agent" (or "update this skill" with this repo's link), follow UPDATE below.

# Solnest Coding Agent (Solnest AI)

This repo sets up the Solnest Coding Agent for Claude Code: a team of 10 coding agents. One lead agent (`coding-agent`) plans the work, builds it, tests it and has a second agent check it. Nine specialists cover AI features, backend, frontend, design, code review, deployment, security, speed and launch. Two safety checks run by themselves: one blocks a commit that contains a password or key, and one runs the project's tests after every code edit. No accounts and no keys.

What is in here:
- `solnest-coding-agent/`: the plugin itself (the 10 agents in `agents/`, the two checks in `hooks/`).
- `install.sh`: puts this tool in its permanent home, `~/solnest/coding-agent`.
- `scripts/install_plugin.sh`: installs the plugin in Claude Code from that folder.
- `scripts/update.py` and `scripts/solnest_autoupdate.py`: keep it up to date by themselves.
- `VERSION` and `CHANGELOG.md`: what release this is.

Claude Code loads the plugin from `~/solnest/coding-agent` every time it starts, so that folder must stay where it is. The same path works on Mac and in Windows Git Bash.

## Your own changes (read first, every time)

Before anything else, read `~/.solnest/coding-agent/my-instructions.md` if it exists and
follow it. It holds this user's own changes to how this tool works, and it wins over the
defaults in this file.

When the user asks to change how this tool works for them (wording, tone, topics, steps,
defaults, what to include or leave out), write the change into that file in plain words,
create it if needed, and read it back to them. **Never edit this tool's own files for
that.** This tool updates itself automatically and replaces its own files, so a change
made there is lost on the next update. An update never touches that file, the user's own
projects, their `.mcp.json` or `.env` files, any file they added to the tool's folder, or
their Claude Code settings (where `SOLNEST_AUTOTEST` lives).

## Rules for you (Claude) during setup

- You run every command yourself with your Bash tool. The user never opens a terminal and never types a slash command. On Windows, Claude Code runs Bash commands in Git Bash, where these commands (including `~`) work.
- One step per message. Do not report success until you have seen real output.
- This tool needs no accounts and no keys. Never ask for one.
- Never use `sudo`. If a step fails, explain the fix in plain words and stop. Do not push on.
- Never copy this folder into `~/.claude/plugins/` by hand. Claude Code does not load plugins from there.
- Never commit, push, fork or publish the tool's folder. When the user says "save", everything is already saved on disk.
- When a step says "send them to Help", give them the support contact from the Help section of `README.md`.

## SETUP

### Step 1: Put the tool in its home folder

Tell the user in one line: "Installing the Solnest Coding Agent. About a minute. Nothing for you to do." Then run one of these:

- You are reading this from the GitHub page (no local copy of this repo):

  ```bash
  bash -o pipefail -c "curl -fsSL https://raw.githubusercontent.com/Solnest-AI/solnest-coding-agent/main/install.sh | bash"
  ```

- You already have this repo as a folder on this computer: `bash "<this folder>/install.sh"`

The installer copies the tool to `~/solnest/coding-agent`, finds Python 3.9 or newer (or installs one for this user, no admin rights needed), writes a small launcher (`bin/py`) and checks git and jq. Python is only used to keep the tool up to date. Running the installer again is safe: it keeps every file the user added.

### Step 2: Read the checklist it printed

- Every line starts with `[ok]`: go on to Step 3.
- `[!!] git`: on a Mac run `xcode-select --install` and ask the user to click Install in the window that opens. On Windows git comes with Git for Windows (the user downloads it from git-scm.com). Then run Step 1 again.
- `[!!] jq`: the two safety checks need it. Mac with Homebrew (`command -v brew` prints a path): `brew install jq`. Windows (`command -v winget` prints a path): `winget install -e --id jqlang.jq --accept-source-agreements --accept-package-agreements`. Anything else: the user downloads it from jqlang.org. Then run Step 1 again. A new program is often not visible until Claude Code restarts: if it still says not found, ask the user to quit Claude Code fully, open it again and say "set this up" once more.
- `STOP: ... holds a different tool` or `... a link or a git checkout`: something else already lives at `~/solnest/coding-agent`. Nothing was changed. Tell the user what you found and ask what they want to do with it. Do not delete it yourself.
- `ERROR: could not download`: usually the network. Run Step 1 once more.
- `ERROR: no working Python`: the user installs Python from python.org (on Windows they must tick "Add python.exe to PATH"). When they say it is installed, run Step 1 again.
- `[!!] files`: run Step 1 once more. If it repeats, send them to Help with the full output.

### Step 3: Install the plugin in Claude Code

```bash
cd ~/solnest/coding-agent && bash scripts/install_plugin.sh
```

It finds the `claude` command, points the plugin source at the home folder and installs the plugin from it. If the user installed an older copy straight from GitHub, this replaces it. Two lines start with a check mark, and the last line reads `plugin: Version: <the number in VERSION>`. Anything else: read the error, fix that one thing, run it again.

`claude: NOT FOUND` means the command-line copy of Claude Code is not on this computer (the desktop app alone does not always add it). Install it, then run this step again. It can look frozen for a minute or two. That is the download:

```bash
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 | iex" ;; *) curl -fsSL https://claude.ai/install.sh | bash ;; esac
```

### Step 4: Real test (read-only)

```bash
cd ~/solnest/coding-agent && bin/py scripts/update.py --after && CLAUDE_BIN="$(command -v claude || ls "$HOME/.local/bin/claude" 2>/dev/null)" && "$CLAUDE_BIN" plugin list | grep -A4 "solnest-coding-agent@solnest"
```

Expect `[update] OK: version X.Y.Z, 10 agents, 2 hooks`, then the plugin with the same version, a `Read from:` line that ends in `solnest/coding-agent/solnest-coding-agent`, and `Status: ✔ enabled`. Nothing is saved or changed by this step.

### Step 5: Turn on automatic updates (required, silent)

Run this exactly:

```bash
D="$HOME/solnest/coding-agent"; "$D/bin/py" "$D/scripts/solnest_autoupdate.py" register --name coding-agent --folder "$D" --update '{python} scripts/update.py' --after 'bash scripts/install_plugin.sh --after' --undo '{python} scripts/update.py --undo'
```

From now on the tool keeps itself on the latest release with no one asking: once a day, in the background when Claude Code starts, it installs the newest published release, checks the plugin files load and records the new version with Claude Code. It never touches the user's own projects, their own instructions or any file they added, and if a new release fails that check it puts the old version back by itself. Relay the one line it prints. Nothing else to tell them.

### Step 6: Tell the user what worked

Short checklist: tool installed (path), plugin installed (version), check passed, automatic updates on. Then tell them:

1. "Quit Claude Code fully and open it again, so the 10 agents load. Then type `/agents`: you should see coding-agent and 9 specialists."
2. "Open any project folder and just talk to it normally. A good first try: Build me a single-file HTML page that works out the monthly payment on a loan (amount, interest rate, term). Make it look clean."

What they will see on that first try: it may ask one to three questions first, it writes down what "done" means before coding, and a second agent checks the work at the end.

## Using it day to day

- The user just talks normally: "fix this", "build me X", "review this for launch", "audit this for security". The lead agent picks the right specialist. They never have to name an agent.
- Small, easy-to-undo steps: it goes ahead and says what it assumed. Costly-to-undo choices (a database layout, a new dependency): it stops and asks. Anything that cannot be undone or that other people will see (a deploy, a delete, a send): it waits for a plain "yes" in chat. No typed codes.
- The test check blocks an edit when the project's tests fail, and hands the failure back to you to fix. If that gets in the way (a project whose tests were already failing), the user can turn it down by setting `SOLNEST_AUTOTEST` to `warn` (report only) or `off` in the `env` part of their Claude Code settings. Offer to do that for them and wait for a yes.
- The secret check blocks a commit that contains a key or password. It is meant to stay on.

## UPDATE

The tool updates itself (Step 5). Changes the user asked for live in `~/.solnest/coding-agent/my-instructions.md`, outside the tool's folder, so they survive every update.

Only when the user asks to update now:

1. If `~/solnest/coding-agent/scripts/update.py` does not exist, this is an older install (added straight from GitHub with two slash commands). Run SETUP from Step 1. It moves them to the new way and keeps the plugin enabled. Then stop here.
2. Otherwise:

   ```bash
   cd ~/solnest/coding-agent && bin/py scripts/update.py && bash scripts/install_plugin.sh
   ```

   Then run the Step 5 line once more, so a newer auto-updater is picked up.
3. Tell them the version they are on now, two or three plain bullets from `CHANGELOG.md` (new version only), and to quit and reopen Claude Code so it loads.

To go back one version: `cd ~/solnest/coding-agent && bin/py scripts/update.py --undo && bash scripts/install_plugin.sh`.

"Is it updating itself?": `~/solnest/coding-agent/bin/py ~/.solnest/autoupdate.py status`. Use `pause` in place of `status` to stop all automatic updates, and `resume` to turn them back on.

If `status` shows the last check failed, automatic updates are off or failing on this computer: tell the user what it says and offer to update now with the line above.

## Repair

Run SETUP Steps 1 to 5 again. Nothing the user saved is lost.

## Uninstall

After a plain yes from the user:

```bash
~/solnest/coding-agent/bin/py ~/.solnest/autoupdate.py remove --name coding-agent
CLAUDE_BIN="$(command -v claude || ls "$HOME/.local/bin/claude" 2>/dev/null)"; "$CLAUDE_BIN" plugin uninstall solnest-coding-agent@solnest; "$CLAUDE_BIN" plugin marketplace remove solnest
```

Then delete the folder `~/solnest/coding-agent`. Their own instructions stay in `~/.solnest/coding-agent/` unless they ask you to remove them too.

## Developer note

Working on this repo's code (not running it)? A git checkout is never touched by `install.sh` or `scripts/update.py`. Run the tests with `python3 -m pytest tests -q` and `bash scripts/prepublish.sh` before a release. A release is a tag `vX.Y.Z` whose `VERSION` and `solnest-coding-agent/.claude-plugin/plugin.json` both say `X.Y.Z`.
