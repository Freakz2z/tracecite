"""Collect licenses from the actual native build dependencies (offline)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


REPO = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metadata(path, key):
    match = re.search(rf'^{key}\s*=\s*"([^"\n]+)"', path.read_text(), re.MULTILINE)
    if match is None:
        raise ValueError(f"Missing {key}: {path}")
    return match.group(1)


def collect(destination):
    # Verify the checked-in upstream copies before redistributing any of them.
    provenance = json.loads((REPO / "third_party/provenance.json").read_text())
    for record in provenance["records"]:
        if digest(REPO / "third_party" / record["file"]) != record["sha256"]:
            raise ValueError(f"Changed upstream license: {record['file']}")

    sdk = Path(os.environ.get("MOON_HOME", str(Path.home() / ".moon")))
    licenses = destination / "licenses"
    licenses.mkdir()
    components = []

    def add(name, version, files):
        paths = []
        for source, filename in files:
            if source.stat().st_size == 0:
                raise ValueError(f"Empty upstream notice: {source}")
            target = licenses / filename
            shutil.copyfile(source, target)  # Missing required notices fail the build.
            paths.append(target.relative_to(destination).as_posix())
        components.append({"name": name, "version": version, "notices": paths})

    for name, prefix in (("moonbitlang/async", "async"), ("bobzhang/html_parser", "html-parser")):
        dependency = REPO / ".mooncakes" / name
        files = [(dependency / "LICENSE", prefix + "-LICENSE.txt")]
        if (dependency / "NOTICE").is_file():
            files.append((dependency / "NOTICE", prefix + "-NOTICE.txt"))
        add(name, metadata(dependency / "moon.mod", "version"), files)

    add("JustHTML", "attribution retained by html_parser",
        [(REPO / ".mooncakes/bobzhang/html_parser/tests/fixtures/justhtml/LICENSE.justhtml", "JustHTML-MIT.txt")])
    add("moonbitlang/core", metadata(sdk / "lib/core/moon.mod", "version"),
        [(sdk / "lib/core/LICENSE", "core-LICENSE.txt"), (sdk / "lib/core/NOTICE", "core-NOTICE.txt")])
    # runtime.c in the installed SDK carries the Apache notice. Retain its header
    # alongside the full Apache license rather than assigning our own copyright.
    for name, source in (("moonbit-runtime", sdk / "lib/runtime/runtime.c"),
                         ("libbacktrace", sdk / "include/backtrace.h")):
        match = re.search(r"/\*.*?\*/", source.read_text(), re.DOTALL)
        if match is None or "Copyright" not in match.group():
            raise ValueError(f"Missing copyright/license header: {source}")
        if name == "moonbit-runtime" and "Apache" not in match.group():
            raise ValueError(f"Runtime license changed; review its full license before packaging: {source}")
        filename = name + "-NOTICE.txt"
        (licenses / filename).write_text(match.group() + "\n")
        notices = ["licenses/" + filename]
        if name == "moonbit-runtime":
            notices.append("licenses/core-LICENSE.txt")
        components.append({"name": name, "version": "provided by the recorded MoonBit SDK", "notices": notices})

    for name in ("mimalloc", "simdutf"):
        records = [r for r in provenance["records"] if r["component"] == name]
        add(name, "SDK embedded version unspecified; upstream license snapshots",
            [(REPO / "third_party" / r["file"], Path(r["file"]).name) for r in records])
    shutil.copyfile(REPO / "third_party/provenance.json", licenses / "provenance.json")
    shutil.copyfile(REPO / "THIRD_PARTY_NOTICES.md", destination / "THIRD_PARTY_NOTICES.md")
    revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True)
    status = subprocess.run(["git", "status", "--porcelain"], cwd=REPO, capture_output=True, text=True)
    manifest = {
        "schema": 1,
        "module": metadata(REPO / "moon.mod", "name"),
        "version": metadata(REPO / "moon.mod", "version"),
        "revision": revision.stdout.strip() if revision.returncode == 0 else None,
        "modified_checkout": bool(status.stdout) if status.returncode == 0 else None,
        "moonc": subprocess.check_output(["moonc", "-v"], text=True).strip(),
        "moon": subprocess.check_output(["moon", "version"], text=True).strip(),
        "components": components,
        "files": {p.relative_to(destination).as_posix(): digest(p)
                  for p in sorted(destination.rglob("*")) if p.is_file()},
    }
    (destination / "BUILD-INFO.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    collect(parser.parse_args().destination)
