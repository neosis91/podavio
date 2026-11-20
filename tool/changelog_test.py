#!/usr/bin/env python3
"""Tests du journal à fragments."""

import datetime as dt
import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "changelog", Path(__file__).with_name("changelog.py")
)
changelog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(changelog)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


PREAMBLE = """# Journal des versions

Avant une release, rassemblez les fragments.

## 2026.11.9

- Activity counts an episode on the day it was marked played.

"""


class ChangelogTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.changelog = self.root / "CHANGELOG.md"
        self.fragments = self.root / "changelog.d"
        write(self.changelog, PREAMBLE)
        self.fragments.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def add(self, name, text):
        write(self.fragments / name, text)

    def collected(self, today, released):
        return changelog.collect(
            self.changelog,
            self.fragments,
            today,
            released,
            self.root,
        )

    def test_same_month_bumps_the_patch_when_the_last_release_is_tagged(self):
        self.add("export.md", "Exporting the database writes the file in pieces.")
        version = self.collected(dt.date(2026, 11, 19), lambda _version: True)
        self.assertEqual(version, "2026.11.10")
        text = self.changelog.read_text(encoding="utf-8")
        self.assertIn("## 2026.11.10\n\n- Exporting the database writes the file in pieces.\n\n## 2026.11.9", text)
        self.assertEqual(list(self.fragments.iterdir()), [])

    def test_a_new_month_starts_at_zero(self):
        self.add("windows.md", "The GitHub release includes a Windows installer.")
        version = self.collected(dt.date(2026, 12, 1), lambda _version: True)
        self.assertEqual(version, "2026.12.0")

    def test_an_unreleased_heading_receives_the_new_fragments(self):
        self.add("first.md", "First change.")
        self.collected(dt.date(2026, 11, 19), lambda _version: True)
        self.add("second.md", "Second change.")
        version = self.collected(dt.date(2026, 11, 20), lambda version: version != "2026.11.10")
        self.assertEqual(version, "2026.11.10")
        text = self.changelog.read_text(encoding="utf-8")
        self.assertIn("- First change.\n\n- Second change.", text)
        self.assertEqual(text.count("## 2026.11.10"), 1)

    def test_a_blank_line_stays_one_bullet(self):
        self.add("listen.md", "Listening language follows the phone.\n\nIt updates when the phone language changes.")
        self.collected(dt.date(2026, 11, 19), lambda _version: True)
        notes = changelog.notes_for("2026.11.10", self.changelog)
        self.assertEqual(
            notes,
            ["Listening language follows the phone. It updates when the phone language changes."],
        )

    def test_fragments_are_ordered_by_filename(self):
        self.add("b.md", "Second.")
        self.add("a.md", "First.")
        self.collected(dt.date(2026, 11, 19), lambda _version: True)
        notes = changelog.notes_for("2026.11.10", self.changelog)
        self.assertEqual(notes, ["First.", "Second."])

    def test_an_empty_fragment_is_refused(self):
        self.add("empty.md", " \n")
        with self.assertRaises(SystemExit):
            self.collected(dt.date(2026, 11, 19), lambda _version: True)

    def test_a_capitalized_filename_is_refused(self):
        self.add("Export.md", "Export.")
        with self.assertRaises(SystemExit):
            changelog.fragment_paths(self.fragments)

    def test_check_release_names_the_fragments_still_there(self):
        self.add("export.md", "Export.")
        changelog.check_release(self.fragments)

    def test_the_repository_changelog_still_parses(self):
        releases = changelog.load()
        self.assertEqual(releases[0][0], "2026.11.9")
        self.assertGreaterEqual(len(releases[0][1]), 1)


class PullRequestTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        subprocess.run(["git", "init", "-q", "-b", "develop"], cwd=self.root, check=True)
        write(self.root / "README.md", "podavio\n")
        self.commit("base")
        subprocess.run(["git", "checkout", "-q", "-b", "feature"], cwd=self.root, check=True)

    def tearDown(self):
        self.tmp.cleanup()

    def commit(self, message):
        subprocess.run(["git", "add", "-A"], cwd=self.root, check=True)
        subprocess.run(
            [
                "git",
                "-c",
                "user.email=test@example.com",
                "-c",
                "user.name=Test",
                "commit",
                "-q",
                "-m",
                message,
            ],
            cwd=self.root,
            check=True,
        )

    def test_a_fragment_is_accepted(self):
        write(self.root / "changelog.d" / "export.md", "Export writes the file in pieces.\n")
        self.commit("Export the database")
        changelog.check_pr("develop", root=self.root)

    def test_a_title_skip_is_accepted_without_a_fragment(self):
        write(self.root / "tool" / "ci" / "note.sh", "echo ok\n")
        self.commit("Fix the linux package fetch")
        changelog.check_pr("develop", title="Fix apt [skip changelog]", root=self.root)

    def test_a_label_skip_is_accepted(self):
        write(self.root / "README.md", "docs\n")
        self.commit("Clarify the readme")
        changelog.check_pr("develop", labels=["skip-changelog"], root=self.root)

    def test_a_missing_fragment_is_refused(self):
        write(self.root / "lib" / "main.dart", "void main() {}\n")
        self.commit("Add a button")
        with self.assertRaises(SystemExit):
            changelog.check_pr("develop", root=self.root)


if __name__ == "__main__":
    unittest.main()
