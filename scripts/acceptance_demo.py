"""Reproduce a controlled, offline citation-maintenance lifecycle."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess


REPO = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def demonstrate(output, binary=None):
    output.mkdir(parents=True, exist_ok=False)
    project = output / "project"
    shutil.copytree(REPO / "examples/maintenance/project", project)
    reports = output / "reports"
    reports.mkdir()
    command = [str(binary.resolve())] if binary else ["moon", "run", "cmd/main"]
    steps = []

    def run(name, *arguments, expected=0, code=None):
        result = subprocess.run(command + list(arguments) + ["--root", str(project), "--json"],
                                cwd=REPO, text=True, capture_output=True, timeout=90)
        (reports / (name + ".json")).write_text(result.stdout)
        if result.stderr:
            (reports / (name + ".stderr.txt")).write_text(result.stderr)
        require(result.returncode == expected, f"{name}: expected exit {expected}, got {result.returncode}\n{result.stdout}\n{result.stderr}")
        report = json.loads(result.stdout)
        if code:
            require(any(item["code"] == code for item in report["items"]), f"{name}: missing {code}")
        steps.append({"name": name, "exit": result.returncode, "expected": expected,
                      "report": "reports/" + name + ".json"})
        print(f"{name}: exit {result.returncode} (expected {expected})")
        return report

    run("01-init", "init", "guide.md")
    config = json.loads((project / "tracecite.json").read_text())
    require(config["paths"] == ["guide.md"] and config["strict"] and not config["online"], "Unexpected initial policy")
    run("02-clean", "check")
    baseline = project / ".tracecite-docs.json"
    initial = baseline.read_bytes()
    (output / "initial-baseline.json").write_bytes(initial)

    source = project / "source.md"
    original = source.read_text()
    source.write_text(original.replace("## Other", "Retries now use exponential backoff.\n\n## Other"))
    drift = run("03-source-changed", "check", expected=2, code="REFERENCED_SOURCE_CHANGED")
    changed = next(item for item in drift["items"] if item["code"] == "REFERENCED_SOURCE_CHANGED")
    require(changed["document"] == "guide.md" and changed["line"] > 0, "Missing document location")
    require("exponential backoff" in changed["actual"] and "exponential backoff" not in changed["previous"], "Missing before/after evidence")
    require(baseline.read_bytes() == initial, "check changed the baseline")
    run("04-guarded-snapshot", "check", "--baseline", ".tracecite-docs.json",
        "--snapshot", ".tracecite-docs.json", expected=2, code="REFERENCED_SOURCE_CHANGED")
    require(baseline.read_bytes() == initial, "Rejected snapshot overwrote the baseline")
    # The simulated reviewer accepts the added context after seeing the diff.
    run("05-reviewed-snapshot", "check", "--snapshot", ".tracecite-docs.json")
    run("06-reviewed-clean", "check")

    (project / "config.toml").write_text("timeout = 30\nretries = 2\n")
    before = baseline.read_bytes()
    mismatch = run("07-stale-snippet", "check", expected=2, code="DOCUMENT_EXCERPT_MISMATCH")
    item = next(item for item in mismatch["items"] if item["code"] == "DOCUMENT_EXCERPT_MISMATCH")
    require(item["document"] == "guide.md" and item["line"] == 5, "Incorrect snippet location")
    require(item["actual"] == "timeout = 30", "Missing candidate excerpt")
    run("08-refuse-stale-snapshot", "check", "--snapshot", ".tracecite-docs.json",
        expected=2, code="DOCUMENT_EXCERPT_MISMATCH")
    require(baseline.read_bytes() == before, "Failed source check overwrote the baseline")
    guide = project / "guide.md"
    guide.write_text(guide.read_text().replace("timeout = 20", "timeout = 30"))
    run("09-repaired-snapshot", "check", "--snapshot", ".tracecite-docs.json")
    run("10-repaired-clean", "check")

    source.write_text(source.read_text().replace("## Timeouts", "## Request timeout"))
    run("11-broken-anchor", "check", expected=2, code="ANCHOR_NOT_FOUND")
    guide.write_text(guide.read_text().replace("#timeouts", "#request-timeout"))
    run("12-repaired-anchor-snapshot", "check", "--snapshot", ".tracecite-docs.json")
    run("13-final-clean", "check")
    receipt = {"schema": 1, "scenario": "controlled offline maintenance lifecycle",
               "scope": "Citation/source consistency; not semantic truth or user adoption evidence",
               "passed": True, "steps": steps}
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Verified {len(steps)} steps; evidence: {output / 'receipt.json'}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, help="Use an extracted standalone CLI instead of moon run")
    parser.add_argument("--out", type=Path, help="New output directory; existing directories are never replaced")
    options = parser.parse_args()
    output = options.out or REPO / "_build/acceptance" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    demonstrate(output.resolve(), options.binary)
