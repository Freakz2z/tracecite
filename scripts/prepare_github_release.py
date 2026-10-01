"""Validate both native platforms and prepare immutable GitHub release assets."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import tempfile

from verify_native_package import extract_verified
from verify_release_package import module_metadata


REPO = Path(__file__).resolve().parents[1]


def prepare(directory, metadata, revision, tag, changelog):
    if tag != "v" + metadata["version"] or not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("Release tag, version or source revision mismatch")
    archives = sorted(directory.glob("*.tar.gz"))
    if len(archives) != 2:
        raise ValueError("Release requires one Linux and one macOS archive")
    platforms = set()
    assets = []
    for archive in archives:
        match = re.fullmatch(r"tracecite-" + re.escape(metadata["version"]) + r"-(linux|darwin)-(x86_64|arm64)\.tar\.gz", archive.name)
        if match is None or match[1] in platforms:
            raise ValueError("Unexpected or duplicate native platform")
        platforms.add(match[1])
        checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
        sidecar = archive.with_suffix(".gz.sha256")
        if sidecar.read_text().strip() != f"{checksum}  {archive.name}":
            raise ValueError(f"Archive checksum mismatch: {archive.name}")
        with tempfile.TemporaryDirectory(prefix="tracecite-release-asset-") as temporary:
            _, manifest = extract_verified(archive, Path(temporary))
        if manifest["module"] != metadata["name"] or manifest["version"] != metadata["version"]:
            raise ValueError("Native asset module or version mismatch")
        if manifest["revision"] != revision or manifest["modified_checkout"] is not False:
            raise ValueError("Native asset was not built from the clean release commit")
        assets.append({"file": archive.name, "sha256": checksum, "platform": match[1],
                       "architecture": match[2], "moonc": manifest["moonc"], "moon": manifest["moon"]})
    if platforms != {"linux", "darwin"}:
        raise ValueError("Missing release platform")
    heading = re.search(r"^## " + re.escape(metadata["version"]) + r"(?: —[^\n]*)?\n", changelog, re.MULTILINE)
    if heading is None:
        raise ValueError("Missing release changelog section")
    notes = changelog[heading.end():].split("\n## ", 1)[0].strip()
    (directory / "RELEASE-NOTES.md").write_text(notes + "\n\nSource: " + revision + "\n")
    receipt = {"schema": 1, "module": metadata["name"], "version": metadata["version"],
               "tag": tag, "revision": revision, "assets": assets}
    (directory / "release-assets.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Verified release assets for {tag}: {revision}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--revision", required=True)
    options = parser.parse_args()
    prepare(options.directory, module_metadata((REPO / "moon.mod").read_text()),
            options.revision, options.tag, (REPO / "CHANGELOG.md").read_text())
