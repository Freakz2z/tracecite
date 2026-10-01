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


def verify_consumer(root, metadata, package=None):
    consumer = root / "consumer"
    consumer.mkdir()
    dependency = json.dumps(metadata["name"] + "@" + metadata["version"])
    (consumer / "moon.mod").write_text(
        'name = "release_checks/tracecite_consumer"\nversion = "0.0.0"\n'
        + 'import {\n  ' + dependency + ',\n}\n', encoding="utf-8")
    (consumer / "moon.pkg").write_text(
        'import {\n  ' + json.dumps(metadata["name"]) + ',\n'
        + '  "moonbitlang/core/json",\n} for "wbtest"\n', encoding="utf-8")
    if package is not None:
        (root / "moon.work").write_text('members = ["./package", "./consumer"]\n', encoding="utf-8")
    (consumer / "consumer_wbtest.mbt").write_text(
        (REPO / "scripts/consumer_tests.mbt.txt").read_text(encoding="utf-8"), encoding="utf-8")
    run("moon", "update", cwd=consumer)
    for target in ("native", "js", "wasm"):
        run("moon", "test", ".", "--target", target, "--deny-warn", cwd=consumer)
    return consumer


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
        "CHANGELOG.md", "ROADMAP.md", "THIRD_PARTY_NOTICES.md", "third_party/provenance.json",
        "docs/acceptance.md", "scripts/acceptance_demo.py", "scripts/package_notices.py",
        "scripts/verify_native_package.py", "scripts/package.sh",
        "scripts/test_native_package.py",
        "scripts/release_guard.py", "scripts/test_release.py", "scripts/prepare_github_release.py",
        "scripts/consumer_tests.mbt.txt",
        "document_glob.mbt", "document_review.mbt", "scripts/maintenance_review_demo.py",
        "examples/review/README.md", "examples/review/project/docs/guide.md",
        "examples/review/project/docs/drafts/draft.md", "examples/review/project/source.md",
        "examples/review/project/config.toml", "maintenance_v060_wbtest.mbt",
        "examples/maintenance/README.md", "examples/maintenance/project/guide.md",
        "examples/maintenance/project/source.md", "examples/maintenance/project/config.toml",
    )
    required += tuple(path.relative_to(REPO).as_posix()
                      for path in sorted((REPO / "third_party/licenses").glob("*.txt")))
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
                if name == "docs/重新申报书.md":
                    raise ValueError("Private application form must not be restored to the public package")
                local = REPO / name
                if local.is_file() and source.read(name) != local.read_bytes():
                    raise ValueError(f"Stale package file: {name}")
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
        run("python3", "scripts/acceptance_demo.py", "--binary", str(installed),
            "--out", str(Path(temporary) / "acceptance"), cwd=package)
        run("python3", "scripts/maintenance_review_demo.py", "--binary", str(installed),
            "--out", str(Path(temporary) / "review"), cwd=package)

        verify_consumer(Path(temporary), metadata, package=package)

    destination = REPO / "dist/mooncakes" / archive.name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(archive, destination)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix(".zip.sha256").write_text(f"{digest}  {destination.name}\n", encoding="utf-8")
    revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, text=True, capture_output=True)
    status = subprocess.run(["git", "status", "--porcelain"], cwd=REPO, text=True, capture_output=True)
    destination.with_suffix(".zip.json").write_text(json.dumps({
        "schema": 1, "module": metadata["name"], "version": metadata["version"],
        "revision": revision.stdout.strip() if revision.returncode == 0 else None,
        "modified_checkout": bool(status.stdout) if status.returncode == 0 else None,
        "archive": destination.name, "sha256": digest,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {metadata['name']}@{metadata['version']}: {destination}")


def registry_module(metadata, allow_missing=False):
    result = subprocess.run(["moon", "view", metadata["name"] + "@" + metadata["version"], "--json"],
                            cwd=REPO, text=True, capture_output=True, timeout=60)
    data = json.loads(result.stdout)
    errors = [item.get("message", "") for item in data.get("messages", []) if item.get("level") == "error"]
    if allow_missing and data.get("status") == "failure" and errors and all("404 Not Found" in error for error in errors):
        return None
    payload = data.get("result") or {}
    if result.returncode != 0 or data.get("status") != "success" or payload.get("module") != metadata["name"] or payload.get("version") != metadata["version"] or payload.get("yanked"):
        raise ValueError(f"Registry has not confirmed {metadata['name']}@{metadata['version']}")
    return payload


def verify_registry(metadata, consume=False):
    payload = registry_module(metadata)
    print(f"Mooncakes confirmed {metadata['name']}@{metadata['version']}")
    if not consume:
        return
    archive = REPO / "dist/mooncakes" / (metadata["name"].replace("/", "-") + "-" + metadata["version"] + ".zip")
    checksum = (payload.get("metadata") or {}).get("checksum")
    if not archive.is_file() or checksum != hashlib.sha256(archive.read_bytes()).hexdigest():
        raise ValueError("Published checksum differs from the verified source archive")
    from acceptance_demo import demonstrate
    from maintenance_review_demo import demonstrate_review
    with tempfile.TemporaryDirectory(prefix="tracecite-registry-") as temporary:
        root = Path(temporary)
        # No moon.work and no local package override: consume the actual registry.
        consumer = verify_consumer(root, metadata)
        binaries = root / "bin"
        run("moon", "install", metadata["name"] + "/cmd/tracecite@" + metadata["version"],
            "--bin", str(binaries), cwd=consumer)
        binary = binaries / ("tracecite.exe" if os.name == "nt" else "tracecite")
        version = subprocess.check_output([str(binary), "--version"], text=True, timeout=30).strip()
        if version != "TraceCite " + metadata["version"]:
            raise ValueError("Registry-installed CLI version mismatch")
        evidence = REPO / "_build/acceptance" / ("published-" + metadata["version"])
        demonstrate(evidence / os.path.basename(temporary), binary)
        demonstrate_review(evidence / (os.path.basename(temporary) + "-review"), binary)
    receipt = {"schema": 1, "module": metadata["name"], "version": metadata["version"],
               "registry_sha256": checksum, "targets": ["native", "js", "wasm"],
               "cli_install": "registry", "maintenance_steps": 13, "review_steps": 14, "passed": True}
    archive.with_suffix(".published.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("Actual registry consumers and installed CLI verified")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", action="store_true", help="Confirm the uploaded version instead of testing the local archive")
    parser.add_argument("--consume-registry", action="store_true", help="Check published checksum, fresh registry API consumers and CLI installation")
    options = parser.parse_args()
    module = module_metadata((REPO / "moon.mod").read_text(encoding="utf-8"))
    if options.registry or options.consume_registry:
        verify_registry(module, consume=options.consume_registry)
    else:
        verify_package(module)
