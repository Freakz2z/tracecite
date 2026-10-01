"""Verify native archive contents and exercise its extracted CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import tempfile

from acceptance_demo import demonstrate
from maintenance_review_demo import demonstrate_review


REPO = Path(__file__).resolve().parents[1]


def extract_verified(archive, destination):
    with tarfile.open(archive, "r:gz") as source:
        names = set()
        roots = set()
        for member in source.getmembers():
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts or "\\" in member.name or not path.parts:
                raise ValueError(f"Unsafe archive path: {member.name}")
            if not (member.isfile() or member.isdir()) or member.mode & 0o7000:
                raise ValueError(f"Unsafe archive entry: {member.name}")
            if member.name in names:
                raise ValueError(f"Duplicate archive entry: {member.name}")
            names.add(member.name)
            roots.add(path.parts[0])
        if len(roots) != 1:
            raise ValueError("Expected one native bundle root")
        if hasattr(tarfile, "data_filter"):
            source.extractall(destination, filter="data")
        else:
            # Older Python has no filter API; the validation above has already
            # rejected links, special files, traversal and privileged modes.
            source.extractall(destination)
    bundle = destination / roots.pop()
    manifest = json.loads((bundle / "BUILD-INFO.json").read_text())
    if manifest["schema"] != 1 or manifest["module"] != "Freakz2z/tracecite":
        raise ValueError("Unexpected bundle identity")
    required = {"tracecite", "LICENSE", "USAGE.md", "THIRD_PARTY_NOTICES.md", "licenses/provenance.json",
                "licenses/async-LICENSE.txt", "licenses/html-parser-LICENSE.txt", "licenses/JustHTML-MIT.txt",
                "licenses/core-LICENSE.txt", "licenses/core-NOTICE.txt", "licenses/moonbit-runtime-NOTICE.txt",
                "licenses/libbacktrace-NOTICE.txt", "licenses/mimalloc-LICENSE.txt",
                "licenses/simdutf-LICENSE-MIT.txt", "licenses/simdutf-LICENSE-APACHE.txt"}
    components = {component["name"] for component in manifest["components"]}
    if components != {"moonbitlang/async", "bobzhang/html_parser", "JustHTML", "moonbitlang/core",
                      "moonbit-runtime", "libbacktrace", "mimalloc", "simdutf"}:
        raise ValueError("Incomplete native component inventory")
    for component in manifest["components"]:
        if not component["notices"]:
            raise ValueError(f"Missing component notice: {component['name']}")
        required.update(component["notices"])
    files = {p.relative_to(bundle).as_posix() for p in bundle.rglob("*") if p.is_file()}
    expected = set(manifest["files"])
    if not required <= expected or files != expected | {"BUILD-INFO.json"}:
        raise ValueError("Missing notice or unrecorded/stale payload file")
    for name, digest in manifest["files"].items():
        if hashlib.sha256((bundle / name).read_bytes()).hexdigest() != digest:
            raise ValueError(f"Payload digest mismatch: {name}")
    return bundle, manifest


def verify(archive):
    with tempfile.TemporaryDirectory(prefix="tracecite-native-") as directory:
        root = Path(directory)
        bundle, manifest = extract_verified(archive, root)
        binary = bundle / "tracecite"
        # The executable itself runs with no Moon SDK on PATH.
        environment = dict(os.environ, PATH="/usr/bin:/bin")
        version = subprocess.check_output([str(binary), "--version"], text=True, env=environment, timeout=30).strip()
        if version != "TraceCite " + manifest["version"]:
            raise ValueError("Native executable version differs from manifest")
        demonstrate(root / "acceptance", binary)
        demonstrate_review(root / "review", binary)
    print(f"Verified native archive: {archive}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    verify(parser.parse_args().archive)
