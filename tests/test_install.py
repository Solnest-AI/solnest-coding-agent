"""install.sh: puts the tool in <home>/solnest/coding-agent without the git link or the
private editor rules, writes the launcher, keeps the member's own files on a second run,
and refuses to overwrite something that is not this tool. scripts/install_plugin.sh is run
against a fake `claude` command, so Claude Code's real settings are never touched.
Offline: it installs from this copy of the repo, or from a local archive."""
import os
import pathlib
import shutil
import subprocess
import tarfile
import tempfile
import textwrap
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent
BASH = shutil.which("bash")
TOOLS = bool(shutil.which("git") and shutil.which("jq"))
SKIP = {".git", ".cursor", ".claude", "node_modules", "bin", ".update-backup", ".pytest_cache", "__pycache__",
        ".env", ".mcp.json"}
VERSION = (REPO / "VERSION").read_text().strip()

# A stand-in for the `claude` command: remembers the plugin source and version in a file.
FAKE_CLAUDE = textwrap.dedent('''\
    #!/usr/bin/env bash
    S="$FAKE_CLAUDE_STATE"; echo "$*" >> "$S/calls"
    case "$1 $2 $3" in
      "plugin marketplace list") if [ -f "$S/market" ]; then printf '[{"name": "solnest", "source": "directory", "path": "%s"}]\\n' "$(cat "$S/market")"; else echo "[]"; fi ;;
      "plugin marketplace remove") rm -f "$S/market" "$S/version" ;;
      "plugin marketplace add") echo "$4" > "$S/market"; echo "added" ;;
      "plugin install "*|"plugin update "*) sed -n 's/.*"version": *"\\([^"]*\\)".*/\\1/p' "$(cat "$S/market")/solnest-coding-agent/.claude-plugin/plugin.json" > "$S/version"; echo "installed" ;;
      "plugin list --json") if [ -f "$S/version" ]; then printf '[{"id": "solnest-coding-agent@solnest", "version": "%s"}]\\n' "$(cat "$S/version")"; else echo "[]"; fi ;;
    esac
''')


@unittest.skipUnless(BASH, "needs bash")
class InstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = pathlib.Path(self.tmp.name) / "home"
        self.home.mkdir()
        self.dest = self.home / "solnest" / "coding-agent"
        self.ok = 0 if TOOLS else 4

    def run_bash(self, script=None, *args, stdin=None, **extra):
        env = dict(os.environ, HOME=str(self.home), **extra)
        cmd = [BASH, str(script), *args] if script else [BASH]
        return subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=300,
                              stdin=stdin or subprocess.DEVNULL, cwd=self.tmp.name)

    def test_installs_and_a_second_run_keeps_member_files(self):
        r = self.run_bash(REPO / "install.sh")
        self.assertEqual(r.returncode, self.ok, r.stdout + r.stderr)
        self.assertIn("[ok] files     version " + VERSION + ", 10 agents, 2 hooks", r.stdout)
        for rel in ("VERSION", "CLAUDE.md", "bin/py", "scripts/update.py", "scripts/install_plugin.sh",
                    "scripts/solnest_autoupdate.py", ".claude-plugin/marketplace.json",
                    "solnest-coding-agent/.claude-plugin/plugin.json", "solnest-coding-agent/agents/coding-agent.md",
                    "solnest-coding-agent/hooks/scripts/secret-scan.sh"):
            self.assertTrue((self.dest / rel).is_file(), rel)
        for rel in (".git", ".cursor"):        # the updater refuses a git checkout; .cursor is private
            self.assertFalse((self.dest / rel).exists(), rel)
        self.assertEqual((self.dest / "VERSION").read_text(), (REPO / "VERSION").read_text())

        (self.dest / ".mcp.json").write_text('{"mine": true}\n', encoding="utf-8")
        (self.dest / "my-notes.md").write_text("mine\n", encoding="utf-8")
        r = self.run_bash(REPO / "install.sh")
        self.assertEqual(r.returncode, self.ok, r.stdout + r.stderr)
        self.assertEqual((self.dest / ".mcp.json").read_text(), '{"mine": true}\n')
        self.assertEqual((self.dest / "my-notes.md").read_text(), "mine\n")

        # repair from inside the installed copy: nothing is copied over itself
        r = self.run_bash(self.dest / "install.sh")
        self.assertEqual(r.returncode, self.ok, r.stdout + r.stderr)
        self.assertIn("already here", r.stdout)

    def test_a_source_copy_never_leaks_private_files_into_the_install(self):
        src = pathlib.Path(self.tmp.name) / "clone"
        shutil.copytree(REPO, src, ignore=lambda d, names: [n for n in names if n in SKIP])
        (src / ".env").write_text("SOME_KEY=someone_elses_fake\n", encoding="utf-8")
        (src / ".mcp.json").write_text("{}\n", encoding="utf-8")
        (src / ".git").mkdir()
        (src / ".cursor" / "rules").mkdir(parents=True)
        (src / ".cursor" / "rules" / "private.mdc").write_text("private\n", encoding="utf-8")
        r = self.run_bash(src / "install.sh")
        self.assertEqual(r.returncode, self.ok, r.stdout + r.stderr)
        self.assertTrue((self.dest / "solnest-coding-agent" / "agents" / "coding-agent.md").is_file())
        for rel in (".env", ".mcp.json", ".git", ".cursor"):
            self.assertFalse((self.dest / rel).exists(), rel)

    def test_piped_install_from_an_archive(self):
        """The `curl ... | bash` path: no local repo, the tool comes from an archive."""
        archive = pathlib.Path(self.tmp.name) / "main.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(REPO, "solnest-coding-agent-main",
                    filter=lambda t: None if set(pathlib.PurePosixPath(t.name).parts) & SKIP else t)
        with open(REPO / "install.sh", "rb") as script:
            r = self.run_bash(stdin=script, CODING_AGENT_ARCHIVE_URL=archive.as_uri())
        self.assertEqual(r.returncode, self.ok, r.stdout + r.stderr)
        self.assertIn("downloading the tool", r.stdout)
        self.assertTrue((self.dest / "bin" / "py").is_file())
        self.assertEqual((self.dest / "VERSION").read_text(), (REPO / "VERSION").read_text())

    def test_refuses_a_different_tool_and_a_git_checkout(self):
        mark = self.dest / ".claude-plugin" / "marketplace.json"
        mark.parent.mkdir(parents=True)
        mark.write_text('{"name": "something-else"}\n', encoding="utf-8")
        r = self.run_bash(REPO / "install.sh")
        self.assertEqual(r.returncode, 3, r.stdout + r.stderr)
        self.assertEqual(mark.read_text(), '{"name": "something-else"}\n')
        self.assertFalse((self.dest / "scripts").exists())
        shutil.rmtree(mark.parent)
        (self.dest / ".git").mkdir()
        r = self.run_bash(REPO / "install.sh")
        self.assertEqual(r.returncode, 3, r.stdout + r.stderr)
        self.assertFalse((self.dest / "scripts").exists())

    def _installed_with_fake_claude(self):
        r = self.run_bash(REPO / "install.sh")
        self.assertEqual(r.returncode, self.ok, r.stdout + r.stderr)
        fake = pathlib.Path(self.tmp.name) / "fakebin"
        state = pathlib.Path(self.tmp.name) / "state"
        fake.mkdir()
        state.mkdir()
        (fake / "claude").write_text(FAKE_CLAUDE, encoding="utf-8")
        (fake / "claude").chmod(0o755)
        return fake, state

    def test_install_plugin_points_the_source_at_the_folder(self):
        fake, state = self._installed_with_fake_claude()
        (state / "market").write_text("/somewhere/else/from-github\n", encoding="utf-8")   # an older install
        (state / "version").write_text("3.1.2\n", encoding="utf-8")
        env = {"PATH": f"{fake}{os.pathsep}{os.environ['PATH']}", "FAKE_CLAUDE_STATE": str(state)}
        r = self.run_bash(self.dest / "scripts" / "install_plugin.sh", **env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("plugin: Version: " + VERSION, r.stdout)
        self.assertEqual(pathlib.Path((state / "market").read_text().strip()).resolve(), self.dest.resolve())
        self.assertIn("plugin marketplace remove solnest", (state / "calls").read_text())

        # a second run leaves a source that already is this folder alone
        (state / "calls").write_text("")
        r = self.run_bash(self.dest / "scripts" / "install_plugin.sh", "--after", **env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn("marketplace remove", (state / "calls").read_text())

        # a release whose plugin.json is not VERSION fails (the auto-updater then undoes it)
        (self.dest / "VERSION").write_text("9.9.9\n", encoding="utf-8")
        r = self.run_bash(self.dest / "scripts" / "install_plugin.sh", "--after", **env)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)

    def test_install_plugin_without_the_claude_command(self):
        self._installed_with_fake_claude()
        # a PATH with bash and the basics but no claude, and a home with no ~/.local/bin/claude
        bare = pathlib.Path(self.tmp.name) / "bare"
        bare.mkdir()
        for tool in ("bash", "sh", "dirname", "tr", "ls", "head", "cat", "sed", "grep", "pwd", "env"):
            found = shutil.which(tool)
            if found:
                (bare / tool).symlink_to(found)
        r = self.run_bash(self.dest / "scripts" / "install_plugin.sh", PATH=str(bare))
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)        # setup: say so, stop
        self.assertIn("claude: NOT FOUND", r.stdout)
        r = self.run_bash(self.dest / "scripts" / "install_plugin.sh", "--after", PATH=str(bare))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)        # background: a good release stays
        self.assertIn("load the next time Claude Code starts", r.stdout)


if __name__ == "__main__":
    unittest.main()
