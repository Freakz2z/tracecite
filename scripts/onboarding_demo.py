"""Reproduce a new project's shared local/CI configuration and maintenance cycle."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess

REPO = Path(__file__).resolve().parents[1]


def demonstrate_onboarding(output, binary=None, include_action=True):
    output.mkdir(parents=True, exist_ok=False)
    project = output / "project"
    shutil.copytree(REPO / "examples/compatibility/project", project)
    (project / "docs").mkdir()
    (project / "guide.md").rename(project / "docs/guide.md")
    command = [str(binary.resolve())] if binary else ["moon", "run", "cmd/main"]
    reports = output / "reports"
    reports.mkdir()
    steps = []

    def run(name, operation, *arguments, expected=0):
        result = subprocess.run(command + [operation, *arguments, "--root", str(project.resolve()), "--json"],
                                cwd=REPO, capture_output=True, text=True, timeout=120)
        (reports / (name + ".json")).write_text(result.stdout)
        if result.returncode != expected:
            raise ValueError(name + ": " + result.stdout + result.stderr)
        report = json.loads(result.stdout)
        if report.get("schema_version") != 1:
            raise ValueError("Onboarding report lacks the documented schema version")
        steps.append({"name": name, "exit": result.returncode})
        print(name, result.returncode)
        return report

    def action(name, expected):
        env = dict(os.environ, GITHUB_WORKSPACE=str(project.resolve()), GITHUB_ACTION_PATH=str(REPO),
                   TRACECITE_REPORT="", TRACECITE_PATH="", TRACECITE_CONFIG="", TRACECITE_ONLINE="",
                   TRACECITE_STRICT="", TRACECITE_BASELINE="", TRACECITE_EXCLUDE="")
        result = subprocess.run(["bash", str(REPO / "scripts/run_document_action.sh")],
                                cwd=REPO, env=env, text=True, capture_output=True, timeout=120)
        (reports / (name + ".txt")).write_text(result.stdout + result.stderr)
        if result.returncode != expected:
            raise ValueError("Action did not reproduce the project's local check: " + result.stdout + result.stderr)
        steps.append({"name": name, "exit": result.returncode})
        print(name, result.returncode)

    run("01-init", "init", "docs/**/*.md", "--max-skipped-web", "0", "--max-unbound-snippets", "0")
    config = json.loads((project / "tracecite.json").read_text())
    if config["paths"] != ["docs/**/*.md"] or config["strict"] is not True:
        raise ValueError("init did not preserve the documented shared configuration")
    run("02-configured-check", "check")
    if include_action:
        action("03-action-check", 0)
    (project / "config.toml").write_text("timeout = 30\n")
    drift = run("04-source-drift", "check", expected=2)
    if not any(item["category"] == "content_mismatch" for item in drift["items"]):
        raise ValueError("Source change was not exposed as content mismatch")
    if include_action:
        action("05-action-drift", 2)
    guide = project / "docs/guide.md"
    guide.write_text(guide.read_text().replace("timeout = 20", "timeout = 30"))
    baseline = project / ".tracecite-docs.json"
    before = baseline.read_bytes()
    preview = run("06-reviewed-fix-preview", "check", "--preview-baseline", expected=2)
    if not preview["baseline_preview"]["can_update"] or baseline.read_bytes() != before:
        raise ValueError("Review preview changed the baseline or failed to validate the fix")
    run("07-reviewed-snapshot", "check", "--snapshot", ".tracecite-docs.json")
    final = run("08-final-check", "check")
    if final["failed_count"] or final["warning_count"] or final["skipped_count"] or final["unbound_snippets"]:
        raise ValueError("Onboarding ended with failed or unchecked references")
    receipt = {"schema": 1, "created_at": datetime.now(timezone.utc).isoformat(),
               "scope": "controlled new-project onboarding through the Action check script, not external adoption", "action_checked": include_action,
               "steps": steps, "passed": True}
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--skip-action", action="store_true")
    options = parser.parse_args()
    demonstrate_onboarding(options.out.resolve(), options.binary, not options.skip_action)
