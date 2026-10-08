"""Verify valid and missing standalone HTML anchor targets with an installed CLI."""
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1] / "examples/html-anchors/project"


def verify(binary):
    reports = {}
    for document, expected in (("guide.md", 0), ("broken.md", 2)):
        result = subprocess.run(
            [str(binary), "check", document, "--root", str(ROOT),
             "--no-config", "--strict", "--json"],
            text=True, capture_output=True, timeout=90,
        )
        if result.returncode != expected:
            raise RuntimeError(f"{document}: {result.returncode}\n{result.stdout}\n{result.stderr}")
        reports[document] = json.loads(result.stdout)
    valid = reports["guide.md"]
    if (valid["checked_count"], valid["failed_count"], valid["warning_count"],
            valid["skipped_count"], valid["unbound_snippets"]) != (4, 0, 0, 0, 0):
        raise RuntimeError(f"Unexpected valid-example coverage: {valid}")
    broken = reports["broken.md"]
    if broken["failed_count"] != 1 or not any(
            item["code"] == "ANCHOR_NOT_FOUND" for item in broken["items"]):
        raise RuntimeError("Missing anchor no longer fails")
    print("Standalone HTML anchors: 4 valid references pass; missing target exits 2")
    return reports


if __name__ == "__main__":
    verify(Path(sys.argv[1]).resolve(strict=True))
