"""Verify the actual Mooncakes archive and a fresh public-API consumer.

Python is release tooling; the published library and native CLI do not need it.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import zipfile


REPO = Path(__file__).resolve().parents[1]


def module_metadata(text):
    values = {}
    for key in ("name", "version"):
        match = re.search(rf'^{key}\s*=\s*("[^"\n]+")\s*$', text, re.MULTILINE)
        if match is None:
            raise ValueError(f"Missing module metadata: {key}")
        values[key] = json.loads(match.group(1))
    return values


def run(*command, cwd):
    subprocess.run(command, cwd=cwd, check=True, timeout=180)


def verify_package(metadata):
    archive = REPO / "_build/publish" / (metadata["name"].replace("/", "-") + "-" + metadata["version"] + ".zip")
    required = (
        "moon.mod", "moon.pkg", "LICENSE", "README.mbt.md", "README.md",
        "pkg.generated.mbti", "project.mbt", "document.mbt", "document_match.mbt",
        "cmd/main/main.mbt", "cmd/main/moon.pkg", "cmd/tracecite/main.mbt", "cmd/tracecite/moon.pkg",
        "cli/main.mbt", "cli/moon.pkg", "cli/document.mbt", "cli/remote.mbt", "cli/proxy.mbt",
        "tracecite.json", ".tracecite-docs.json", ".moonignore", "action.yml",
        ".github/workflows/ci.yml", ".github/workflows/binaries.yml",
        "assets/readme/document-maintenance.svg", "docs/maintenance.md",
        "docs/publishing.md", "scripts/release.sh", "scripts/verify_release_package.py",
    )
    with tempfile.TemporaryDirectory(prefix="tracecite-release-") as temporary:
        package = Path(temporary) / "package"
        with zipfile.ZipFile(archive) as source:
            names = source.namelist()
            if len(set(names)) != len(names):
                raise ValueError("Duplicate archive entries")
            for name in names:
                path = PurePosixPath(name)
                if path.is_absolute() or ".." in path.parts or "\\" in name:
                    raise ValueError(f"Invalid archive path: {name}")
                if any(part in (".git", "_build", "target", "dist", ".mooncakes", "__pycache__") for part in path.parts):
                    raise ValueError(f"Build or dependency file in archive: {name}")
            for name in required:
                if name not in names:
                    raise ValueError(f"Missing release file: {name}")
                local = REPO / name
                if local.is_file() and source.read(name) != local.read_bytes():
                    raise ValueError(f"Stale release file: {name}")
            if module_metadata(source.read("moon.mod").decode()) != metadata:
                raise ValueError("Archive module identity differs from the source")
            source.extractall(package)

        # Missing resources cannot be supplied by the original working checkout.
        run("moon", "update", cwd=package)
        run("moon", "run", "cmd/main", "check", cwd=package)
        binaries = Path(temporary) / "bin"
        run("moon", "install", "./cmd/tracecite", "--bin", str(binaries), cwd=package)
        installed = binaries / ("tracecite.exe" if os.name == "nt" else "tracecite")
        version = subprocess.check_output([str(installed), "--version"], cwd=package, text=True, timeout=30)
        if version.strip() != "TraceCite " + metadata["version"]:
            raise ValueError("Installed CLI version differs from the module version")
        run(str(installed), "check", cwd=package)

        consumer = Path(temporary) / "consumer"
        consumer.mkdir()
        dependency = json.dumps(metadata["name"] + "@" + metadata["version"])
        (consumer / "moon.mod").write_text(
            'name = "release_checks/tracecite_consumer"\nversion = "0.0.0"\n'
            + 'import {\n  ' + dependency + ',\n}\n', encoding="utf-8")
        (consumer / "moon.pkg").write_text(
            'import {\n  ' + json.dumps(metadata["name"]) + ',\n'
            + '  "moonbitlang/core/json",\n} for "wbtest"\n', encoding="utf-8")
        (Path(temporary) / "moon.work").write_text(
            'members = ["./package", "./consumer"]\n', encoding="utf-8")
        (consumer / "consumer_wbtest.mbt").write_text(r'''///|
test "public document parser and portable project policy" {
  let document = @tracecite.parse_document("[配置](config.toml)\n")
  assert_eq(document.references.length(), 1)
  assert_eq(document.references[0].source, "config.toml")
  let project = @tracecite.parse_document_project_config("{\"version\":1,\"paths\":[\"docs\"]}")
  assert_true(project.config.unwrap().strict)
  assert_false(project.config.unwrap().online)
  assert_true(project.diagnostics.is_empty())
  let json = @json.to_json(project.config.unwrap()).stringify()
  assert_true(@tracecite.parse_document_project_config(json).config is Some(_))
}

///|
test "public source selection, excerpt matching and baseline serialization" {
  let selected = @tracecite.select_document_source("# Settings\ntimeout = 20\n# Other\nUnused.\n", "settings")
  assert_true(selected.ok)
  assert_true(@tracecite.document_excerpt_matches(selected.text, "timeout = 20", "snippet"))
  assert_false(@tracecite.document_excerpt_matches(selected.text, "timeout = 30", "snippet"))
  let baseline = @tracecite.DocumentSnapshot::{
    version: 1,
    entries: [{ document: "README.md", source: "config.toml", kind: "snippet", excerpt: Some("timeout = 20"), observed: "timeout = 20" }],
  }
  let decoded : @tracecite.DocumentSnapshot = @json.from_json(@json.to_json(baseline))
  assert_eq(decoded.entries[0].observed, "timeout = 20")
}
''', encoding="utf-8")
        run("moon", "update", cwd=consumer)
        for target in ("native", "js", "wasm"):
            run("moon", "test", ".", "--target", target, "--deny-warn", cwd=consumer)

    destination = REPO / "dist/mooncakes" / archive.name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(archive, destination)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix(".zip.sha256").write_text(f"{digest}  {destination.name}\n", encoding="utf-8")
    print(f"Verified {metadata['name']}@{metadata['version']}: {destination}")


def verify_registry(metadata):
    result = subprocess.run(["moon", "view", metadata["name"] + "@" + metadata["version"], "--json"],
                            cwd=REPO, check=True, text=True, capture_output=True, timeout=60)
    data = json.loads(result.stdout)
    payload = data.get("result") or {}
    if data.get("status") != "success" or payload.get("module") != metadata["name"] or payload.get("version") != metadata["version"]:
        raise ValueError(f"Registry has not confirmed {metadata['name']}@{metadata['version']}")
    print(f"Mooncakes confirmed {metadata['name']}@{metadata['version']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", action="store_true", help="Confirm the uploaded version instead of testing the local archive")
    options = parser.parse_args()
    module = module_metadata((REPO / "moon.mod").read_text(encoding="utf-8"))
    if options.registry:
        verify_registry(module)
    else:
        verify_package(module)
