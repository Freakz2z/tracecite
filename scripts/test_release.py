"""Check release refusal paths without publishing or modifying real repositories."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import prepare_github_release
import release_guard
import verify_release_package


METADATA = {"name": "Freakz2z/tracecite", "version": "1.2.3"}


class RegistryGuardTests(unittest.TestCase):
    def response(self, status, payload=None, errors=(), code=0):
        return subprocess.CompletedProcess([], code, json.dumps({"status": status, "result": payload,
            "messages": [{"level": "error", "message": e} for e in errors]}), "")

    def test_only_explicit_not_found_allows_a_new_version(self):
        with patch.object(verify_release_package.subprocess, "run", return_value=self.response("failure", errors=["HTTP status client error (404 Not Found)"], code=1)):
            self.assertIsNone(verify_release_package.registry_module(METADATA, allow_missing=True))
            release_guard.unpublished(METADATA)

    def test_existing_version_is_refused(self):
        result = self.response("success", {"module": METADATA["name"], "version": METADATA["version"], "yanked": False})
        with patch.object(verify_release_package.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(ValueError, "already published"):
                release_guard.unpublished(METADATA)

    def test_auth_server_and_unknown_failures_cannot_mean_unpublished(self):
        for message in ("403 Forbidden", "500 Internal Server Error", "network disconnected", ""):
            with self.subTest(message=message), patch.object(verify_release_package.subprocess, "run", return_value=self.response("failure", errors=[message], code=1)):
                with self.assertRaises(ValueError):
                    release_guard.unpublished(METADATA)

    def test_malformed_and_timed_out_registry_responses_stop_release(self):
        with patch.object(verify_release_package.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "not json", "")):
            with self.assertRaises(ValueError):
                release_guard.unpublished(METADATA)
        with patch.object(verify_release_package.subprocess, "run", side_effect=subprocess.TimeoutExpired("moon", 60)):
            with self.assertRaises(subprocess.TimeoutExpired):
                release_guard.unpublished(METADATA)

    def test_wrong_module_version_or_yanked_result_is_refused(self):
        for changed in ({"module": "another/library"}, {"version": "9.9.9"}, {"yanked": True}):
            payload = {"module": METADATA["name"], "version": METADATA["version"], **changed}
            with self.subTest(changed=changed), patch.object(verify_release_package.subprocess, "run", return_value=self.response("success", payload)):
                with self.assertRaises(ValueError):
                    release_guard.unpublished(METADATA)


class SourceGuardTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tracecite-source-guard-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Release Tests")
        self.git("config", "user.email", "release-tests@example.invalid")
        (self.root / "moon.mod").write_text('name = "Freakz2z/tracecite"\nversion = "1.2.3"\n')
        (self.root / "cli").mkdir()
        (self.root / "cli/main.mbt").write_text('TraceCite 1.2.3\\n')
        self.commit()
        self.git("tag", "v1.2.3")

    def git(self, *arguments):
        return release_guard.git(*arguments, root=self.root)

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")

    def test_clean_tagged_matching_source_passes(self):
        metadata, revision = release_guard.check_source(self.root)
        self.assertEqual(metadata, METADATA)
        self.assertEqual(revision, self.git("rev-parse", "HEAD"))

    def test_tracked_and_untracked_changes_stop_release(self):
        for path in ("new.txt", "cli/main.mbt"):
            with self.subTest(path=path):
                target = self.root / path
                before = target.read_bytes() if target.exists() else None
                target.write_text("changed")
                with self.assertRaisesRegex(ValueError, "clean"):
                    release_guard.check_source(self.root)
                if before is None:
                    target.unlink()
                else:
                    target.write_bytes(before)

    def test_tag_from_another_commit_stops_release(self):
        (self.root / "extra.txt").write_text("new commit")
        self.commit()
        with self.assertRaisesRegex(ValueError, "tag"):
            release_guard.check_source(self.root)

    def test_revision_change_and_cli_mismatch_stop_release(self):
        with self.assertRaisesRegex(ValueError, "changed during"):
            release_guard.check_source(self.root, expected_revision="0" * 40)
        (self.root / "cli/main.mbt").write_text('TraceCite 1.2.4\\n')
        self.commit()
        self.git("tag", "-f", "v1.2.3")
        with self.assertRaisesRegex(ValueError, "versions differ"):
            release_guard.check_source(self.root)


class ReleaseAssetTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tracecite-release-assets-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for platform, architecture in (("linux", "x86_64"), ("darwin", "arm64")):
            archive = self.root / f"tracecite-1.2.3-{platform}-{architecture}.tar.gz"
            archive.write_bytes(b"synthetic archive")
            archive.with_suffix(".gz.sha256").write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n")
        self.manifest = {"module": METADATA["name"], "version": "1.2.3", "revision": "a" * 40,
                         "modified_checkout": False, "moonc": "test compiler", "moon": "test moon"}
        self.extract = patch.object(prepare_github_release, "extract_verified", return_value=(self.root, self.manifest))
        self.extract.start()
        self.addCleanup(self.extract.stop)

    def prepare(self):
        prepare_github_release.prepare(self.root, METADATA, "a" * 40, "v1.2.3", "## 1.2.3 — test\n\nChanges.\n")

    def test_both_platforms_have_version_source_and_checksum_receipt(self):
        self.prepare()
        receipt = json.loads((self.root / "release-assets.json").read_text())
        self.assertEqual({a["platform"] for a in receipt["assets"]}, {"linux", "darwin"})
        self.assertEqual(receipt["revision"], "a" * 40)

    def test_missing_platform_and_wrong_checksum_stop_release(self):
        archive = next(self.root.glob("*linux*.tar.gz"))
        archive.with_suffix(".gz.sha256").write_text("wrong")
        with self.assertRaisesRegex(ValueError, "checksum"):
            self.prepare()
        archive.unlink()
        with self.assertRaisesRegex(ValueError, "one Linux"):
            self.prepare()

    def test_modified_or_wrong_source_cannot_be_uploaded(self):
        for changed in ({"modified_checkout": True}, {"revision": "b" * 40}, {"version": "1.2.4"}):
            with self.subTest(changed=changed):
                old = dict(self.manifest)
                self.manifest.update(changed)
                with self.assertRaises(ValueError):
                    self.prepare()
                self.manifest.clear()
                self.manifest.update(old)


if __name__ == "__main__":
    unittest.main()
