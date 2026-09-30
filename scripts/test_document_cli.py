"""Exercise maintenance workflows using the MoonBit CLI and temporary repositories.

Python is a development test runner, not a TraceCite runtime dependency.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class DocumentMaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tracecite-docs-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "docs").mkdir()
        self.write("config.toml", 'timeout = 20\nname = "example"\n')
        self.write("docs/source.md", "# Source\n## Settings\nThe timeout is twenty seconds.\n## Other\nUnrelated material.\n")
        self.write("docs/guide.md", '[Configuration](../config.toml)\n```toml source=../config.toml\ntimeout = 20\n```\n"The timeout is twenty seconds." ([source](source.md#settings))\n')

    def write(self, path, text):
        (self.root / path).write_text(text, encoding="utf-8")

    def run_check(self, *arguments, expected=0, structured=True):
        binary = os.environ.get("TRACECITE_BIN")
        command = [binary] if binary else ["moon", "run", "cmd/main"]
        command += ["check", "--root", str(self.root), *arguments]
        if structured:
            command.append("--json")
        result = subprocess.run(command, cwd=REPO, text=True, capture_output=True, timeout=90)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return json.loads(result.stdout) if structured else result

    def test_recursive_scan_and_strict_local_snippets(self):
        report = self.run_check("docs", "--strict")
        self.assertEqual(report["document_count"], 2)
        self.assertEqual(report["checked_count"], 3)
        self.assertEqual(report["failed_count"], 0)
        self.write("config.toml", 'timeout = 30\nname = "example"\n')
        report = self.run_check("docs", expected=2)
        mismatch = next(item for item in report["items"] if item["code"] == "DOCUMENT_EXCERPT_MISMATCH")
        self.assertEqual(mismatch["document"], "docs/guide.md")
        self.assertEqual(mismatch["line"], 2)
        self.assertEqual(mismatch["actual"], "timeout = 30")

    def test_mixed_quote_styles_do_not_hide_bad_citations(self):
        self.write("docs/guide.md", '“The timeout is twenty seconds.” ([source](source.md))\n"invented claim" ([source](source.md))\n')
        report = self.run_check("docs/guide.md", expected=2)
        self.assertEqual(report["checked_count"], 2)
        self.assertEqual(report["failed_count"], 1)

    def test_snapshot_is_portable_and_ignores_document_line_movement(self):
        self.run_check("docs/guide.md", "--snapshot", "references.json")
        snapshot = json.loads((self.root / "references.json").read_text())
        self.assertEqual(snapshot["version"], 1)
        self.assertNotIn(str(self.root), json.dumps(snapshot))
        original = (self.root / "docs/guide.md").read_text()
        self.write("docs/guide.md", "# Updated title\n\n" + original)
        report = self.run_check("docs/guide.md", "--baseline", "references.json", "--strict")
        self.assertEqual(report["failed_count"], 0)

    def test_changed_referenced_section_is_flagged_with_both_versions(self):
        self.run_check("docs/guide.md", "--snapshot", "references.json")
        baseline = (self.root / "references.json").read_bytes()
        self.write("docs/source.md", "# Source\n## Settings\nThe timeout is twenty seconds.\nDefaults changed.\n## Other\nUnrelated material.\n")
        report = self.run_check("docs/guide.md", "--baseline", "references.json", "--snapshot", "references.json", expected=2)
        changed = next(item for item in report["items"] if item["status"] == "changed")
        self.assertIn("Defaults changed.", changed["actual"])
        self.assertNotIn("Defaults changed.", changed["previous"])
        self.assertEqual((self.root / "references.json").read_bytes(), baseline)

    def test_unrelated_section_changes_do_not_break_the_baseline(self):
        self.run_check("docs/guide.md", "--snapshot", "references.json")
        source = (self.root / "docs/source.md").read_text().replace("Unrelated material.", "Completely revised unrelated material.")
        self.write("docs/source.md", source)
        self.run_check("docs/guide.md", "--baseline", "references.json", "--strict")

    def test_missing_sources_and_anchors_have_distinct_diagnostics(self):
        (self.root / "config.toml").unlink()
        self.write("docs/guide.md", "[missing](../config.toml)\n[heading](source.md#removed-heading)\n")
        report = self.run_check("docs/guide.md", expected=2)
        self.assertEqual({item["code"] for item in report["items"]}, {"SOURCE_NOT_FOUND", "ANCHOR_NOT_FOUND"})

    def test_percent_encoded_paths_and_reference_style_links(self):
        self.write("config example.toml", "timeout = 20\n")
        self.write("docs/guide.md", '"timeout = 20" ([settings][CONFIG])\n[config]: ../config%20example.toml\n')
        report = self.run_check("docs/guide.md", "--strict")
        self.assertEqual(report["checked_count"], 1)

    def test_unbound_code_and_skipped_web_sources_are_counted(self):
        self.write("docs/guide.md", '[local](../config.toml)\n[web](https://example.org/)\n```sh\nnot-executed\n```\n')
        report = self.run_check("docs/guide.md")
        self.assertEqual(report["checked_count"], 1)
        self.assertEqual(report["skipped_count"], 1)
        self.assertEqual(report["unbound_snippets"], 1)

    def test_warnings_fail_strict_checks_and_cannot_create_a_baseline(self):
        self.write("docs/guide.md", '[local](../config.toml)\n“unassociated quote”\n')
        report = self.run_check("docs/guide.md", "--strict", expected=2)
        self.assertEqual(report["warning_count"], 1)
        self.run_check("docs/guide.md", "--snapshot", "references.json", expected=2)
        self.assertFalse((self.root / "references.json").exists())

    def test_zero_verified_references_does_not_report_success(self):
        self.write("docs/guide.md", "# Empty guide\n```sh\nnot-executed\n```\n")
        result = self.run_check("docs/guide.md", expected=2, structured=False)
        self.assertIn("NO_CHECKS", result.stdout)
        self.assertIn("nothing has been verified", result.stderr)

    def test_local_sources_cannot_escape_the_root_through_symlinks(self):
        with tempfile.TemporaryDirectory(prefix="tracecite-outside-") as other:
            outside = Path(other) / "secret.txt"
            outside.write_text("outside root\n")
            (self.root / "outside.txt").symlink_to(outside)
            self.write("docs/guide.md", "[outside](../outside.txt)\n")
            report = self.run_check("docs/guide.md", expected=2)
            self.assertEqual(report["items"][0]["code"], "SOURCE_OUTSIDE_ROOT")

    def test_exclusions_and_overlapping_targets_do_not_double_count(self):
        self.write("docs/ignored.md", "[broken](missing.md)\n")
        report = self.run_check("docs", "docs/guide.md", "--exclude", "docs/ignored.md")
        self.assertEqual(report["document_count"], 2)

    def test_github_annotations_locate_document_errors(self):
        self.write("config.toml", "timeout = 30\n")
        result = self.run_check("docs/guide.md", "--github", expected=2, structured=False)
        self.assertIn("::error file=docs/guide.md,line=2,title=DOCUMENT_EXCERPT_MISMATCH::", result.stdout)

    def test_new_references_need_review_before_baseline_update(self):
        self.run_check("docs/guide.md", "--snapshot", "references.json")
        original = (self.root / "docs/guide.md").read_text()
        self.write("docs/guide.md", original + "[new](source.md#other)\n")
        report = self.run_check("docs/guide.md", "--baseline", "references.json", "--strict", expected=2)
        self.assertEqual(report["warning_count"], 1)
        self.assertEqual(report["items"][-1]["code"], "REFERENCE_NOT_IN_BASELINE")

    def test_directory_links_are_valid_local_dependencies(self):
        self.write("docs/guide.md", "[documentation](../docs/)\n")
        self.run_check("docs/guide.md", "--strict")

    def test_readme_html_presentation_attributes_are_not_citations(self):
        self.write("hero.svg", "<svg></svg>\n")
        self.write("docs/guide.md", '<p align="center">\n<img src="../hero.svg" width="100%" alt="Documentation hero">\n</p>\n')
        report = self.run_check("docs/guide.md", "--strict")
        self.assertEqual(report["checked_count"], 1)
        self.assertEqual(report["warning_count"], 0)

    def test_action_uses_caller_root_and_keeps_spaces_in_paths(self):
        self.write("docs/guide with spaces.md", (self.root / "docs/guide.md").read_text())
        env = dict(os.environ, GITHUB_WORKSPACE=str(self.root), GITHUB_ACTION_PATH=str(REPO),
                   TRACECITE_PATH="docs/guide with spaces.md", TRACECITE_ONLINE="false",
                   TRACECITE_STRICT="true", TRACECITE_REPORT="", TRACECITE_BASELINE="",
                   TRACECITE_EXCLUDE="")
        result = subprocess.run(["bash", str(REPO / "scripts/run_document_action.sh")],
                                cwd=self.root, env=env, text=True, capture_output=True, timeout=90)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("3 references checked", result.stdout)


if __name__ == "__main__":
    unittest.main()
