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
        return self.run_cli("check", *arguments, expected=expected, structured=structured)

    def run_cli(self, operation, *arguments, expected=0, structured=True):
        binary = os.environ.get("TRACECITE_BIN")
        command = [binary] if binary else ["moon", "run", "cmd/main"]
        command += [operation, "--root", str(self.root), *arguments]
        if structured:
            command.append("--json")
        result = subprocess.run(command, cwd=REPO, text=True, capture_output=True, timeout=90)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return json.loads(result.stdout) if structured else result

    def config(self, filename="tracecite.json", **settings):
        self.write(filename, json.dumps({"version": 1, "paths": ["docs/guide.md"], **settings}))

    def run_action(self, expected=0, **inputs):
        env = dict(os.environ, GITHUB_WORKSPACE=str(self.root), GITHUB_ACTION_PATH=str(REPO),
                   TRACECITE_PATH="", TRACECITE_CONFIG="", TRACECITE_ONLINE="",
                   TRACECITE_STRICT="", TRACECITE_REPORT="", TRACECITE_BASELINE="",
                   TRACECITE_EXCLUDE="")
        env.update({"TRACECITE_" + name.upper(): value for name, value in inputs.items()})
        result = subprocess.run(["bash", str(REPO / "scripts/run_document_action.sh")],
                                cwd=self.root, env=env, text=True, capture_output=True, timeout=90)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def test_init_then_same_local_and_ci_check_detects_and_accepts_source_change(self):
        self.run_cli("init", "docs/guide.md")
        config = json.loads((self.root / "tracecite.json").read_text())
        self.assertEqual(config["paths"], ["docs/guide.md"])
        self.assertEqual(config["baseline"], ".tracecite-docs.json")
        self.assertTrue(config["strict"])
        self.assertFalse(config["online"])
        self.assertNotIn(str(self.root), json.dumps(config))
        self.run_check()
        self.run_action()
        source = (self.root / "docs/source.md").read_text()
        self.write("docs/source.md", source.replace("## Other", "A new default applies.\n## Other"))
        report = self.run_check(expected=2)
        changed = next(item for item in report["items"] if item["status"] == "changed")
        self.assertIn("A new default applies.", changed["actual"])
        self.assertNotIn("A new default applies.", changed["previous"])
        self.run_action(expected=2)
        before = (self.root / ".tracecite-docs.json").read_bytes()
        self.run_check("--baseline", ".tracecite-docs.json", "--snapshot", ".tracecite-docs.json", expected=2)
        self.assertEqual((self.root / ".tracecite-docs.json").read_bytes(), before)
        self.run_check("--snapshot", ".tracecite-docs.json")
        self.run_check()
        self.run_action()

    def test_init_cannot_accept_a_mismatching_excerpt_or_overwrite_user_files(self):
        self.write("config.toml", "timeout = 30\n")
        self.run_cli("init", "docs/guide.md", expected=2)
        self.assertFalse((self.root / "tracecite.json").exists())
        self.assertFalse((self.root / ".tracecite-docs.json").exists())
        self.write("config.toml", 'timeout = 20\nname = "example"\n')
        for existing in ("tracecite.json", ".tracecite-docs.json", ".tracecite-docs.json.tmp"):
            self.write(existing, "keep this file")
            self.run_cli("init", "docs/guide.md", expected=1, structured=False)
            self.assertEqual((self.root / existing).read_text(), "keep this file")
            (self.root / existing).unlink()

    def test_init_destinations_and_symlinks_cannot_escape_root(self):
        with tempfile.TemporaryDirectory(prefix="tracecite-config-outside-") as other:
            (self.root / "linked").symlink_to(other, target_is_directory=True)
            for arguments in (("--config", "../outside.json"),
                              ("--snapshot", "linked/outside.json"),
                              ("--config", ".tracecite-docs.json"),
                              ("--config", "missing/project.json")):
                self.run_cli("init", "docs/guide.md", *arguments, expected=1, structured=False)
            self.assertEqual(list(Path(other).iterdir()), [])
            self.assertFalse((self.root / ".tracecite-docs.json").exists())

    def test_init_invalid_configuration_does_not_leave_a_partial_baseline(self):
        self.run_cli("init", "docs/guide.md", "--exclude", "../outside", expected=1, structured=False)
        self.assertFalse((self.root / "tracecite.json").exists())
        self.assertFalse((self.root / ".tracecite-docs.json").exists())
        self.assertFalse((self.root / ".tracecite-docs.json.tmp").exists())

    def test_excluding_the_root_does_not_silently_ignore_the_exclusion(self):
        self.config(exclude=["docs/.."])
        self.run_check(expected=1, structured=False)

    def test_custom_config_and_baseline_resolve_from_root_not_process_directory(self):
        self.run_cli("init", "docs/guide.md", "--config", "docs/project.json", "--snapshot", "docs/baseline.json")
        self.run_check("--config", "docs/project.json")
        self.run_action(config="docs/project.json")

    def test_config_path_overrides_and_exclusions_are_combined(self):
        self.write("docs/bad.md", "[broken](missing.md)\n")
        self.write("docs/draft.md", "[broken](missing.md)\n")
        self.config(paths=["docs"], exclude=["./docs//bad.md"])
        report = self.run_check("--exclude", "docs/draft.md")
        self.assertEqual(report["document_count"], 2)
        report = self.run_check("docs/guide.md")
        self.assertEqual(report["document_count"], 1)
        self.run_action(exclude="docs/draft.md")

    def test_explicit_false_flags_override_online_and_strict_config(self):
        self.write("docs/guide.md", '[local](../config.toml)\n[web](https://example.org/)\n“unassociated quote”\n')
        self.config(strict=True, online=True)
        report = self.run_check("--offline", "--no-strict")
        self.assertFalse(report["online"])
        self.assertEqual(report["warning_count"], 1)
        self.assertEqual(report["skipped_count"], 1)
        self.run_action(online="false", strict="false")

    def test_invalid_config_fails_instead_of_silently_widening_scope(self):
        for text in ('{"version":1,"strcit":true}', '{"version":1,"paths":[]}', '[',
                     '{"version":1,"paths":["../outside"]}', ' ' * 65537):
            self.write("tracecite.json", text)
            result = self.run_check(expected=1, structured=False)
            self.assertEqual(result.stdout, "")
        self.run_check("docs/guide.md", "--no-config")
        self.run_check("--config", "missing.json", expected=1, structured=False)
        self.run_check("--config", "tracecite.json", "--no-config", expected=1, structured=False)

    def test_config_strict_default_and_explicit_no_config_legacy_behavior(self):
        self.write("docs/guide.md", '[local](../config.toml)\n“unassociated quote”\n')
        self.config()
        self.run_check(expected=2)
        self.run_action(expected=2)
        self.run_check("--no-config")
        self.run_check("--no-strict")
        self.config(strict=False)
        self.run_check()
        self.run_action()
        self.run_check("--strict", expected=2)
        self.run_action(strict="true", expected=2)

    def test_action_without_config_preserves_strict_default_and_validates_flags(self):
        self.write("docs/guide.md", '[local](../config.toml)\n“unassociated quote”\n')
        self.run_action(expected=2)
        self.run_action(strict="false")
        self.run_action(expected=1, online="sometimes")

    def test_configured_baseline_override_and_legacy_action_report(self):
        self.config(baseline="missing.json")
        self.run_check(expected=1, structured=False)
        self.run_check("--snapshot", "references.json")
        self.run_check("--baseline", "references.json")
        self.run_action(baseline="references.json")
        self.run_action(report="docs/guide.md")

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

    def test_inline_code_examples_do_not_create_sources_or_hide_real_links(self):
        self.write("docs/guide.md", 'Use ``[fake](missing.md) `literal` "example"`` with [real](source.md).\n'
                   'Use `<!--` literally, then [config](../config.toml).\n'
                   'An unmatched ` still allows [source](source.md).\n')
        report = self.run_check("docs/guide.md", "--strict")
        self.assertEqual(report["checked_count"], 3)
        self.assertEqual(report["warning_count"], 0)
        self.assertEqual({item["source"] for item in report["items"]}, {"source.md", "../config.toml"})

    def test_inline_code_comment_marker_cannot_hide_a_broken_link(self):
        self.write("docs/guide.md", 'Use `<!--` literally. [broken](missing.md)\n[config](../config.toml)\n')
        report = self.run_check("docs/guide.md", "--strict", expected=2)
        self.assertEqual(report["checked_count"], 2)
        self.assertEqual(report["failed_count"], 1)
        self.assertEqual(report["items"][0]["code"], "SOURCE_NOT_FOUND")
        self.assertEqual(report["items"][0]["line"], 1)

    def test_html_attribute_examples_are_not_markdown_references(self):
        self.write("docs/guide.md", '<img src="../config.toml" alt="[fake](missing.md)"> [real](source.md)\n')
        report = self.run_check("docs/guide.md", "--strict")
        self.assertEqual(report["checked_count"], 2)
        self.assertEqual(report["failed_count"], 0)

    def test_commented_headings_are_not_valid_anchor_targets(self):
        self.write("docs/source.md", '# Source\n<!--\n## Hidden\n-->\n## Visible\nText\n')
        self.write("docs/guide.md", '[hidden](source.md#hidden)\n[visible](source.md#visible)\n')
        report = self.run_check("docs/guide.md", "--strict", expected=2)
        self.assertEqual(report["failed_count"], 1)
        self.assertEqual(report["items"][0]["code"], "ANCHOR_NOT_FOUND")
        self.assertEqual(report["items"][1]["status"], "ok")

    def test_formatted_heading_anchors_and_section_baselines(self):
        source = ('# Source\n## [Settings](../config.toml) ###\nCurrent settings.\n'
                  '<!--\n## Hidden\n-->\nStill in settings.\n## Next\nOther content.\n')
        self.write("docs/source.md", source)
        self.write("docs/guide.md", '[settings](source.md#settings)\n')
        self.run_check("docs/guide.md", "--snapshot", "references.json", "--strict")
        self.write("docs/source.md", source.replace("Other content.", "Unrelated revision."))
        self.run_check("docs/guide.md", "--baseline", "references.json", "--strict")
        self.write("docs/source.md", source.replace("Still in settings.", "Changed settings."))
        report = self.run_check("docs/guide.md", "--baseline", "references.json", "--strict", expected=2)
        changed = report["items"][0]
        self.assertEqual(changed["code"], "REFERENCED_SOURCE_CHANGED")
        self.assertIn("Still in settings.", changed["previous"])
        self.assertIn("Changed settings.", changed["actual"])

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

    def test_glob_config_discovers_new_documents_at_zero_and_nested_depth(self):
        self.config(paths=["docs/**/*.md"])
        initial = self.run_check()
        (self.root / "docs/nested").mkdir()
        self.write("docs/nested/new.md", "[config](../../config.toml)\n")
        report = self.run_check()
        self.assertEqual(report["document_count"], initial["document_count"] + 1)
        self.assertEqual(report["checked_count"], initial["checked_count"] + 1)
        self.run_action()

    def test_init_keeps_glob_patterns_and_action_shares_exclusions(self):
        self.write("docs/draft.md", "[bad](missing.md)\n")
        self.run_cli("init", "docs/**/*.md", "--exclude", "docs/**/*draft*.md")
        config = json.loads((self.root / "tracecite.json").read_text())
        self.assertEqual(config["paths"], ["docs/**/*.md"])
        self.assertEqual(self.run_check()["document_count"], 2)
        self.run_action()

    def test_every_empty_glob_fails_even_when_another_target_is_valid(self):
        result = self.run_check("docs/guide.md", "docs/no-match*.md", expected=1, structured=False)
        self.assertIn("matched no Markdown", result.stderr)
        self.config(paths=["docs/**/*.md"], exclude=["docs/**"])
        self.run_check(expected=1, structured=False)

    def test_glob_question_mark_and_overlapping_targets_are_deduplicated(self):
        self.write("docs/中.md", "[config](../config.toml)\n")
        report = self.run_check("docs/?.md", "docs/中.md")
        self.assertEqual(report["document_count"], 1)
        self.assertEqual(report["checked_count"], 1)
        report = self.run_check("docs/*.md", "docs/**/*.md")
        self.assertEqual(report["document_count"], 3)

    def test_invalid_globs_are_rejected_before_init_writes_files(self):
        for pattern in ("docs/**/../*.md", "docs/a**.md", "../*.md"):
            self.run_cli("init", pattern, expected=1, structured=False)
        self.assertFalse((self.root / "tracecite.json").exists())
        self.assertFalse((self.root / ".tracecite-docs.json").exists())

    def test_globs_do_not_follow_linked_directories_outside_the_root(self):
        with tempfile.TemporaryDirectory() as other:
            Path(other, "bad.md").write_text("[outside](missing.md)\n")
            (self.root / "docs/linked").symlink_to(other, target_is_directory=True)
            report = self.run_check("docs/**/*.md")
            self.assertEqual(report["document_count"], 2)
            self.run_check("docs/linked/**/*.md", expected=1, structured=False)

    def test_coverage_budgets_fail_even_without_strict_and_block_snapshots(self):
        self.write("docs/guide.md", '[local](../config.toml)\n[web](https://example.org/)\n```sh\nexample\n```\n')
        self.config(strict=False, coverage={"max_skipped_web": 0, "max_unbound_snippets": 0})
        report = self.run_check("--no-strict", expected=2)
        codes = {item["code"] for item in report["items"]}
        self.assertIn("SKIPPED_WEB_LIMIT_EXCEEDED", codes)
        self.assertIn("UNBOUND_SNIPPET_LIMIT_EXCEEDED", codes)
        self.assertEqual(report["skipped_count"], 1)
        self.assertEqual(report["unbound_snippets"], 1)
        self.run_action(expected=2)
        self.run_check("--snapshot", "references.json", expected=2)
        self.assertFalse((self.root / "references.json").exists())
        preview = self.run_check("--preview-baseline", expected=2)["baseline_preview"]
        self.assertFalse(preview["can_update"])
        self.assertIsNone(preview.get("snapshot"))

    def test_cli_coverage_override_and_init_round_trip(self):
        self.write("docs/guide.md", '[local](../config.toml)\n[web](https://example.org/)\n```sh\nexample\n```\n')
        self.config(coverage={"max_skipped_web": 0, "max_unbound_snippets": 0})
        self.run_check("--max-skipped-web", "1", "--max-unbound-snippets", "1")
        (self.root / "tracecite.json").unlink()
        self.run_cli("init", "docs/guide.md", "--max-skipped-web", "1", "--max-unbound-snippets", "1")
        config = json.loads((self.root / "tracecite.json").read_text())
        self.assertEqual(config["coverage"], {"max_skipped_web": 1, "max_unbound_snippets": 1})
        self.run_check()

    def test_invalid_coverage_values_are_configuration_errors(self):
        for value in (-1, 0.5, True, "0"):
            self.config(coverage={"max_skipped_web": value})
            self.run_check(expected=1, structured=False)
        for value in ("-1", "half", "2147483648"):
            self.run_check("--no-config", "--max-unbound-snippets", value, expected=1, structured=False)

    def test_setext_sections_participate_in_baseline_drift_checks(self):
        self.write("docs/source.md", "Source\n======\n\nSettings\n--------\nCurrent default.\n\nOther\n-----\nOther text.\n")
        self.write("docs/guide.md", "[settings](source.md#settings)\n")
        self.run_cli("init", "docs/guide.md")
        self.write("docs/source.md", (self.root / "docs/source.md").read_text().replace("Current default.", "New default."))
        report = self.run_check("--review", expected=2)
        self.assertEqual(report["review"][0]["source"], "docs/source.md")
        changed = report["review"][0]["locations"][0]
        self.assertIn("Current default.", changed["previous"])
        self.assertIn("New default.", changed["actual"])

    def test_review_groups_different_relative_links_to_the_same_source(self):
        (self.root / "docs/nested").mkdir()
        self.write("docs/nested/second.md", '[settings](../source.md#settings)\n')
        self.run_cli("init", "docs/**/*.md")
        self.write("docs/source.md", (self.root / "docs/source.md").read_text().replace("## Other", "Defaults changed.\n## Other"))
        report = self.run_check("--review", expected=2)
        self.assertEqual(len(report["review"]), 1)
        self.assertEqual(report["review"][0]["source"], "docs/source.md")
        self.assertEqual({item["document"] for item in report["review"][0]["locations"]}, {"docs/guide.md", "docs/nested/second.md"})

    def test_preview_exposes_add_change_remove_and_never_writes(self):
        self.run_cli("init", "docs/guide.md")
        baseline = self.root / ".tracecite-docs.json"
        before = baseline.read_bytes()
        self.write("docs/source.md", (self.root / "docs/source.md").read_text().replace("## Other", "Defaults changed.\n## Other"))
        guide = (self.root / "docs/guide.md").read_text().splitlines(keepends=True)
        self.write("docs/guide.md", "".join(guide[1:]) + "[other](source.md#other)\n")
        report = self.run_check("--preview-baseline", expected=2)
        preview = report["baseline_preview"]
        self.assertTrue(preview["can_update"])
        self.assertEqual((preview["added_count"], preview["changed_count"], preview["removed_count"]), (1, 1, 1))
        self.assertEqual(preview["scanned_documents"], ["docs/guide.md"])
        self.assertEqual(baseline.read_bytes(), before)
        self.assertFalse((self.root / ".tracecite-docs.json.tmp").exists())
        self.run_check("--snapshot", ".tracecite-docs.json")
        self.assertEqual(json.loads(baseline.read_text()), preview.get("snapshot"))
        self.run_check()

    def test_preview_failing_sources_have_no_candidate_and_review_keeps_previous(self):
        self.run_cli("init", "docs/guide.md")
        self.write("config.toml", "timeout = 30\n")
        report = self.run_check("--preview-baseline", expected=2)
        self.assertFalse(report["baseline_preview"]["can_update"])
        self.assertIsNone(report["baseline_preview"].get("snapshot"))
        self.assertEqual(report["baseline_preview"]["changes"], [])
        item = next(item for group in report["review"] for item in group["locations"] if item["code"] == "DOCUMENT_EXCERPT_MISMATCH")
        self.assertEqual(item["previous"], "timeout = 20")

    def test_preview_reports_deleted_documents_and_partial_scope_removals(self):
        self.write("docs/second.md", "[config](../config.toml)\n")
        self.run_cli("init", "docs/**/*.md")
        report = self.run_check("docs/guide.md", "--preview-baseline")
        self.assertEqual(report["baseline_preview"]["removed_count"], 1)
        self.assertEqual(report["baseline_preview"]["changes"][0]["document"], "docs/second.md")
        (self.root / "docs/second.md").unlink()
        report = self.run_check("--preview-baseline")
        self.assertEqual(report["baseline_preview"]["removed_count"], 1)

    def test_preview_cannot_be_combined_with_writing_commands(self):
        self.run_cli("init", "docs/guide.md", "--preview-baseline", expected=1, structured=False)
        self.run_check("docs/guide.md", "--preview-baseline", "--snapshot", "references.json", expected=1, structured=False)
        self.assertFalse((self.root / "references.json").exists())

    def test_review_and_preview_text_keep_github_line_annotations(self):
        self.run_cli("init", "docs/guide.md")
        self.write("config.toml", "timeout = 30\n")
        result = self.run_check("--review", "--preview-baseline", "--github", expected=2, structured=False)
        self.assertIn("Review:", result.stdout)
        self.assertIn("Source: config.toml", result.stdout)
        self.assertIn("Baseline preview: can_update=false", result.stdout)
        self.assertIn("::error file=docs/guide.md,line=2", result.stdout)


if __name__ == "__main__":
    unittest.main()
