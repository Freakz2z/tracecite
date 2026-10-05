"""Verify multilingual anchors with the actual CLI and the pinned expected cases."""
import argparse
import json
import os
from pathlib import Path
import subprocess

REPO = Path(__file__).resolve().parents[1]


def verify_anchors(binary, environment=None):
    example = REPO / "examples/anchors"
    cases = json.loads((example / "expected-anchors.json").read_text())["cases"]
    result = subprocess.run([str(binary.resolve()), "check", "guide.md", "--root",
                             str(example / "project"), "--no-config", "--strict", "--json",
                             "--max-skipped-web", "0", "--max-unbound-snippets", "0"],
                            cwd=REPO, env=environment, text=True, capture_output=True, timeout=30)
    if result.returncode != 0:
        raise ValueError("Multilingual anchor check failed: " + result.stdout + result.stderr)
    report = json.loads(result.stdout)
    if report["checked_count"] != len(cases) or any(report[key] != 0 for key in
            ("failed_count", "warning_count", "skipped_count", "unbound_snippets")):
        raise ValueError("Incomplete multilingual anchor coverage")
    expected = ["source.md#" + case["anchor"] for case in cases]
    if [item["source"] for item in report["items"]] != expected or any(
            item["status"] != "ok" for item in report["items"]):
        raise ValueError("CLI results differ from the pinned anchor cases")
    receipt = {"tool_version": report["tool_version"], "references": report["checked_count"],
               "failed": report["failed_count"], "warnings": report["warning_count"],
               "skipped_web": report["skipped_count"], "unbound_snippets": report["unbound_snippets"]}
    print("Verified multilingual anchor example:", receipt)
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("--without-moon", action="store_true")
    options = parser.parse_args()
    verify_anchors(options.binary, dict(os.environ, PATH="/usr/bin:/bin") if options.without_moon else None)
