"""Regression checks for omissions, stale files and tampered native payloads."""
import io
import json
import os
from pathlib import Path
import shutil
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import package_notices
from verify_native_package import extract_verified


class NativePackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="tracecite-notices-test-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.fixture = Path(cls.temporary.name) / "bundle"
        cls.fixture.mkdir()
        # Extraction tests do not execute this synthetic payload. Real binary
        # execution is covered by package.sh's archive acceptance verification.
        for name in ("tracecite", "LICENSE", "USAGE.md"):
            (cls.fixture / name).write_text("fixture\n")
        package_notices.collect(cls.fixture)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tracecite-archive-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bundle = self.root / "bundle"
        shutil.copytree(self.fixture, self.bundle)

    def archive(self, extra=None):
        path = self.root / "bundle.tar.gz"
        with tarfile.open(path, "w:gz") as target:
            target.add(self.bundle, arcname="bundle")
            if extra:
                member = tarfile.TarInfo(extra)
                member.size = 4
                target.addfile(member, io.BytesIO(b"test"))
        return path

    def verify(self):
        destination = self.root / "extracted"
        destination.mkdir()
        return extract_verified(self.archive(), destination)

    def test_complete_bundle_retains_actual_core_notice(self):
        bundle, manifest = self.verify()
        sdk = Path(os.environ.get("MOON_HOME", str(Path.home() / ".moon")))
        self.assertEqual((bundle / "licenses/core-NOTICE.txt").read_bytes(),
                         (sdk / "lib/core/NOTICE").read_bytes())
        self.assertTrue(manifest["components"])

    def test_missing_notice_cannot_be_hidden_by_editing_manifest(self):
        missing = "licenses/core-NOTICE.txt"
        (self.bundle / missing).unlink()
        path = self.bundle / "BUILD-INFO.json"
        manifest = json.loads(path.read_text())
        del manifest["files"][missing]
        for component in manifest["components"]:
            component["notices"] = [n for n in component["notices"] if n != missing]
        path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "Missing notice"):
            self.verify()

    def test_stale_unrecorded_file_is_rejected(self):
        (self.bundle / "leftover.txt").write_text("old artifact")
        with self.assertRaisesRegex(ValueError, "unrecorded/stale"):
            self.verify()

    def test_altered_license_digest_is_rejected(self):
        (self.bundle / "licenses/mimalloc-LICENSE.txt").write_text("changed")
        with self.assertRaisesRegex(ValueError, "digest mismatch"):
            self.verify()

    def test_archive_parent_traversal_is_rejected_before_extraction(self):
        with self.assertRaisesRegex(ValueError, "Unsafe archive path"):
            extract_verified(self.archive("../escape.txt"), self.root / "extracted")
        self.assertFalse((self.root / "escape.txt").exists())

    def test_missing_build_sdk_notices_stop_collection(self):
        destination = self.root / "new-bundle"
        destination.mkdir()
        with patch.dict(os.environ, {"MOON_HOME": str(self.root / "missing-sdk")}):
            with self.assertRaises(FileNotFoundError):
                package_notices.collect(destination)
        self.assertFalse((destination / "BUILD-INFO.json").exists())

    def test_altered_vendored_license_stops_collection(self):
        repository = self.root / "repository"
        shutil.copytree(package_notices.REPO / "third_party", repository / "third_party")
        (repository / "third_party/licenses/simdutf-LICENSE-MIT.txt").write_text("changed")
        with patch.object(package_notices, "REPO", repository):
            with self.assertRaisesRegex(ValueError, "Changed upstream license"):
                package_notices.collect(self.root / "new-bundle")


if __name__ == "__main__":
    unittest.main()
