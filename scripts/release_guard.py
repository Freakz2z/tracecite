"""Refuse publishing from an untagged, changed or already published checkout."""
import argparse
from pathlib import Path
import re
import subprocess

from verify_release_package import module_metadata, registry_module


REPO = Path(__file__).resolve().parents[1]


def git(*arguments, root):
    return subprocess.check_output(["git", *arguments], cwd=root, text=True, timeout=30).strip()


def check_source(root=REPO, expected_revision=None):
    metadata = module_metadata((root / "moon.mod").read_text())
    if metadata["name"] != "Freakz2z/tracecite" or not re.fullmatch(r"\d+\.\d+\.\d+", metadata["version"]):
        raise ValueError("Unexpected release module or version")
    if git("status", "--porcelain", root=root):
        raise ValueError("Release requires a clean committed checkout")
    revision = git("rev-parse", "HEAD", root=root)
    if expected_revision is not None and revision != expected_revision:
        raise ValueError("Checkout changed during release verification")
    tag = "v" + metadata["version"]
    try:
        tagged = git("rev-parse", "refs/tags/" + tag + "^{commit}", root=root)
    except subprocess.CalledProcessError as error:
        raise ValueError(f"Missing release tag: {tag}") from error
    if tagged != revision:
        raise ValueError("Release tag does not point to the checked source")
    cli = (root / "cli/main.mbt").read_text()
    if f'TraceCite {metadata["version"]}\\n' not in cli:
        raise ValueError("CLI and module versions differ")
    return metadata, revision


def unpublished(metadata):
    if registry_module(metadata, allow_missing=True) is not None:
        raise ValueError(f"{metadata['name']}@{metadata['version']} is already published; choose a new version")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unpublished", action="store_true", help="Also require an explicit registry 404 for this version")
    parser.add_argument("--expected-revision")
    options = parser.parse_args()
    metadata, revision = check_source(expected_revision=options.expected_revision)
    if options.unpublished:
        unpublished(metadata)
    print(f"Release source verified: {metadata['name']}@{metadata['version']} ({revision})")
