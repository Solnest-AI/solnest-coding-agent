"""scripts/update.py: installs only a published release into the tool's folder, keeps the
member's own files (.env, .mcp.json, .claude/, bin/, anything they added), and --undo puts
the old version back. Offline: releases are read from a local folder
(CODING_AGENT_RELEASE_DIR)."""
import io
import json
import os
import pathlib
import sys
import tarfile
import tempfile
import unittest
from unittest import mock

REPO = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

import update  # noqa: E402

FAKE_ENV = "SOME_KEY=fake_test_" + "0" * 24 + "\n"   # made up, never a real key
P = update.PLUGIN_DIR
MARKET = json.dumps({"name": "solnest", "plugins": [{"name": P, "source": f"./{P}"}]}) + "\n"
HOOKS = json.dumps({"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [
    {"type": "command", "command": 'bash "$CLAUDE_PLUGIN_ROOT/hooks/scripts/secret-scan.sh"'}]}]}}) + "\n"
AGENT = "---\nname: coding-agent\ndescription: x\n---\n\nYou are the lead.\n"


def files_for(version, **extra):
    base = {".claude-plugin/marketplace.json": MARKET,
            f"{P}/.claude-plugin/plugin.json": json.dumps({"name": P, "version": version}) + "\n",
            f"{P}/hooks/hooks.json": HOOKS,
            f"{P}/hooks/scripts/secret-scan.sh": "#!/bin/bash\nexit 0\n",
            f"{P}/agents/coding-agent.md": AGENT,
            "scripts/update.py": "print('updater')\n",
            "CLAUDE.md": f"setup steps {version}\n"}
    base.update(extra)
    return base


def tarball(folder, version, files, top=None):
    """A GitHub-style source tarball: one top folder, the tool at its root."""
    top = top or f"solnest-coding-agent-{version}"
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        def add(rel, data):
            info = tarfile.TarInfo(f"{top}/{rel}")
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
        add("VERSION", f"{version}\n".encode())
        for rel, text in files.items():
            add(rel, text.encode())
    (pathlib.Path(folder) / f"v{version}.tar.gz").write_bytes(buf.getvalue())


class UpdateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = pathlib.Path(self.tmp.name)
        self.rel = base / "releases"
        self.rel.mkdir()
        self.root = base / "solnest" / "coding-agent"
        self.root.mkdir(parents=True)
        env = mock.patch.dict(os.environ, {update.LOCAL_RELEASES: str(self.rel)})
        env.start()
        self.addCleanup(env.stop)
        self.addCleanup(self.tmp.cleanup)
        old = files_for("1.0.0", **{f"{P}/agents/dropped.md": "---\nname: dropped\n---\n\ngone next\n"})
        tarball(self.rel, "1.0.0", old)
        for rel, text in old.items():
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.root / rel).write_text(text, encoding="utf-8")
        (self.root / "VERSION").write_text("1.0.0\n", encoding="utf-8")
        # the member's own things
        self.mine = {".env": FAKE_ENV, ".mcp.json": '{"mcpServers": {"mine": {}}}\n',
                     ".claude/settings.local.json": '{"env": {"SOLNEST_AUTOTEST": "warn"}}\n',
                     "bin/py": "fake launcher\n", "my-notes.md": "mine\n",
                     f"{P}/agents/my-agent.md": "---\nname: my-agent\n---\n\nmine too\n"}
        for rel, text in self.mine.items():
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.root / rel).write_text(text, encoding="utf-8")

    def _new_release(self):
        tarball(self.rel, "1.1.0", files_for("1.1.0", **{
            f"{P}/agents/new.md": "---\nname: new\n---\n\nbrand new\n",
            "bin/py": "release must not win\n", ".env": "EVIL=from_release\n",
            ".mcp.json": "evil\n", ".claude/settings.local.json": "evil\n"}))

    def _member_files_intact(self):
        for rel, text in self.mine.items():
            self.assertEqual((self.root / rel).read_bytes(), text.encode(), rel)

    def test_update_keeps_member_files_and_undo_goes_back(self):
        self._new_release()
        r = update.update(self.root)
        self.assertEqual(r["status"], "updated")
        self.assertEqual((self.root / "VERSION").read_text().strip(), "1.1.0")
        self.assertEqual((self.root / "CLAUDE.md").read_text(), "setup steps 1.1.0\n")
        self.assertTrue((self.root / P / "agents" / "new.md").is_file())
        self.assertFalse((self.root / P / "agents" / "dropped.md").exists())   # shipped by 1.0.0, not 1.1.0
        self._member_files_intact()
        self.assertIn("version 1.1.0", update.after(self.root))
        self.assertEqual(update.update(self.root)["status"], "current")

        update.undo(self.root)
        self.assertEqual((self.root / "VERSION").read_text().strip(), "1.0.0")
        self.assertEqual((self.root / "CLAUDE.md").read_text(), "setup steps 1.0.0\n")
        self.assertTrue((self.root / P / "agents" / "dropped.md").is_file())
        self.assertFalse((self.root / P / "agents" / "new.md").exists())
        self.assertFalse((self.root / update.BACKUP_DIR).exists())
        self._member_files_intact()
        self.assertIn("version 1.0.0", update.after(self.root))

    def test_manifest_lists_what_shipped_and_removal_follows_it(self):
        self._new_release()
        update.update(self.root)
        listed = set(update.load_manifest(self.root))
        self.assertEqual(listed, set(files_for("1.1.0")) | {"VERSION", f"{P}/agents/new.md"})
        # the next release drops agents/new.md: the manifest is what gets it removed
        tarball(self.rel, "1.2.0", files_for("1.2.0"))
        r = update.update(self.root)
        self.assertEqual(r["removed"], [f"{P}/agents/new.md"])
        self.assertFalse((self.root / P / "agents" / "new.md").exists())
        self._member_files_intact()

    def test_edited_tool_file_is_reported_and_saved(self):
        (self.root / "CLAUDE.md").write_text("the member edited this\n", encoding="utf-8")
        self._new_release()
        r = update.update(self.root)
        self.assertIn("CLAUDE.md", r["edited"])
        self.assertEqual((pathlib.Path(r["backup"]) / "CLAUDE.md").read_text(), "the member edited this\n")

    def test_protected_paths(self):
        want = {".env": True, "sub/.env": True, ".env.local": True, ".env.example": False, ".mcp.json": True,
                ".claude/settings.local.json": True, "settings.local.json": True, "bin/py": True,
                ".cursor/rules/private.mdc": True, "tokens.json": True, "node_modules/a.js": True,
                ".update-backup/1/undo.json": True, update.MANIFEST: True,
                ".claude-plugin/marketplace.json": False, f"{P}/.claude-plugin/plugin.json": False,
                f"{P}/agents/coding-agent.md": False, f"{P}/hooks/scripts/secret-scan.sh": False,
                "CLAUDE.md": False, "scripts/update.py": False, "install.sh": False}
        for rel, protected in want.items():
            self.assertEqual(update._protected(rel), protected, rel)

    def test_refuses_a_git_checkout(self):
        (self.root / ".git").mkdir()
        self._new_release()
        with self.assertRaises(update.UpdateError):
            update.update(self.root)
        self.assertEqual((self.root / "VERSION").read_text().strip(), "1.0.0")

    def test_unsafe_release_changes_nothing(self):
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode="w:gz") as tar:
            for name in ("top/VERSION", "../evil"):
                info = tarfile.TarInfo(name)
                info.size = 1
                tar.addfile(info, io.BytesIO(b"x"))
        (self.rel / "v1.1.0.tar.gz").write_bytes(buf.getvalue())
        with self.assertRaises(update.UpdateError):
            update.update(self.root)
        self.assertEqual((self.root / "VERSION").read_text().strip(), "1.0.0")
        self.assertEqual((self.root / "CLAUDE.md").read_text(), "setup steps 1.0.0\n")

    def test_release_without_the_plugin_is_refused(self):
        tarball(self.rel, "1.1.0", {"CLAUDE.md": "no plugin in here\n"})
        with self.assertRaises(update.UpdateError):
            update.update(self.root)
        self.assertEqual((self.root / "VERSION").read_text().strip(), "1.0.0")

    def test_mislabelled_release_is_refused(self):
        tarball(self.rel, "1.1.0", files_for("1.1.0"))
        blob = (self.rel / "v1.1.0.tar.gz").read_bytes()
        (self.rel / "v1.1.0.tar.gz").unlink()
        (self.rel / "v1.3.0.tar.gz").write_bytes(blob)     # tag says 1.3.0, VERSION inside says 1.1.0
        with self.assertRaises(update.UpdateError):
            update.update(self.root)
        self.assertEqual((self.root / "VERSION").read_text().strip(), "1.0.0")

    def test_no_release_yet_is_a_plain_error(self):
        for p in self.rel.glob("*"):
            p.unlink()
        with self.assertRaises(update.UpdateError):
            update.update(self.root)

    def test_after_fails_on_broken_files(self):
        self.assertIn("1 hooks", update.after(self.root))
        plugin_json = self.root / P / ".claude-plugin" / "plugin.json"
        good = plugin_json.read_text()
        plugin_json.write_text(json.dumps({"name": P, "version": "9.9.9"}), encoding="utf-8")   # not VERSION
        with self.assertRaises(update.UpdateError):
            update.after(self.root)
        plugin_json.write_text("{not json", encoding="utf-8")
        with self.assertRaises(update.UpdateError):
            update.after(self.root)
        plugin_json.write_text(good, encoding="utf-8")
        (self.root / P / "hooks" / "scripts" / "secret-scan.sh").unlink()
        with self.assertRaises(update.UpdateError):
            update.after(self.root)

    def test_after_ignores_a_file_the_member_added_to_agents(self):
        (self.root / P / "agents" / "notes.md").write_text("just my notes, not an agent\n", encoding="utf-8")
        self.assertIn("3 agents", update.after(self.root))     # the two shipped ones and their own my-agent, not notes.md

    def test_the_real_repo_passes_after(self):
        self.assertIn("10 agents, 2 hooks", update.after(REPO))


if __name__ == "__main__":
    unittest.main()
