"""Reproduce glob discovery, grouped review, coverage policy and read-only preview."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess

from acceptance_demo import require


REPO = Path(__file__).resolve().parents[1]


def demonstrate_review(output, binary=None):
    output.mkdir(parents=True, exist_ok=False)
    project = output / "project"
    shutil.copytree(REPO / "examples/review/project", project)
    reports = output / "reports"
    reports.mkdir()
    command = [str(binary.resolve())] if binary else ["moon", "run", "cmd/main"]
    steps = []

    def run(name, *arguments, expected=0):
        result = subprocess.run(command + list(arguments) + ["--root", str(project), "--json"],
                                cwd=REPO, text=True, capture_output=True, timeout=90)
        (reports / (name + ".json")).write_text(result.stdout)
        if result.stderr:
            (reports / (name + ".stderr.txt")).write_text(result.stderr)
        require(result.returncode == expected, f"{name}: {result.stdout}\n{result.stderr}")
        report = json.loads(result.stdout)
        steps.append({"name": name, "exit": result.returncode, "expected": expected,
                      "report": "reports/" + name + ".json"})
        print(f"{name}: exit {result.returncode} (expected {expected})")
        return report

    run("01-init", "init", "docs/**/*.md", "--exclude", "docs/drafts/**",
        "--max-skipped-web", "0", "--max-unbound-snippets", "0")
    run("02-clean", "check")
    baseline = project / ".tracecite-docs.json"
    before = baseline.read_bytes()
    (output / "initial-baseline.json").write_bytes(before)
    nested = project / "docs/nested"
    nested.mkdir()
    new_guide = nested / "new.md"
    new_guide.write_text("[Defaults](../../source.md#defaults)\n")
    preview = run("03-new-document-preview", "check", "--preview-baseline", expected=2)["baseline_preview"]
    require(preview["can_update"] and preview["added_count"] == 1, "New document was not discovered")
    require(baseline.read_bytes() == before, "Preview modified the baseline")
    run("04-reviewed-snapshot", "check", "--snapshot", ".tracecite-docs.json")
    source = project / "source.md"
    source.write_text(source.read_text().replace("Other\n-----", "Retries now use backoff.\n\nOther\n-----"))
    before = baseline.read_bytes()
    report = run("05-grouped-review", "check", "--review", expected=2)
    require(len(report["review"]) == 1 and len(report["review"][0]["locations"]) == 2, "Missing grouped impact")
    require(report["review"][0]["source"] == "source.md", "Incorrect source identity")
    preview = run("06-source-change-preview", "check", "--preview-baseline", expected=2)["baseline_preview"]
    require(preview["can_update"] and preview["changed_count"] == 2, "Incorrect change preview")
    require(baseline.read_bytes() == before, "Review/preview modified the baseline")
    run("07-reviewed-snapshot", "check", "--snapshot", ".tracecite-docs.json")
    require(json.loads(baseline.read_text()) == preview["snapshot"], "Applied snapshot differs from preview")
    new_guide.write_text(new_guide.read_text() + "```toml\ntimeout = 20\n```\n")
    report = run("08-coverage-blocked", "check", "--preview-baseline", expected=2)
    require(any(item["code"] == "UNBOUND_SNIPPET_LIMIT_EXCEEDED" for item in report["items"]), "Coverage policy did not fail")
    require(not report["baseline_preview"]["can_update"] and "snapshot" not in report["baseline_preview"], "Failed coverage produced a candidate")
    before = baseline.read_bytes()
    run("09-refuse-incomplete-snapshot", "check", "--snapshot", ".tracecite-docs.json", expected=2)
    require(baseline.read_bytes() == before, "Failed coverage overwrote baseline")
    new_guide.write_text(new_guide.read_text().replace("```toml\n", "```toml source=../../config.toml\n"))
    preview = run("10-fixed-coverage-preview", "check", "--preview-baseline", expected=2)["baseline_preview"]
    require(preview["can_update"] and preview["added_count"] == 1, "Binding repair was not reviewable")
    run("11-reviewed-snapshot", "check", "--snapshot", ".tracecite-docs.json")
    new_guide.unlink()
    preview = run("12-removed-document-preview", "check", "--preview-baseline")["baseline_preview"]
    require(preview["removed_count"] == 2, "Removed document references were not exposed")
    run("13-reviewed-snapshot", "check", "--snapshot", ".tracecite-docs.json")
    run("14-final-clean", "check")
    receipt = {"schema": 1, "scenario": "controlled maintenance review lifecycle",
               "scope": "Feature validation, not adoption or time-saving evidence", "passed": True, "steps": steps}
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Verified {len(steps)} review steps; evidence: {output / 'receipt.json'}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--out", type=Path)
    options = parser.parse_args()
    output = options.out or REPO / "_build/acceptance" / ("review-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    demonstrate_review(output.resolve(), options.binary)
