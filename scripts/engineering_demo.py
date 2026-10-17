"""Reproduce independently checked source localization, diff and baseline cases.

All cases are controlled regressions, not external adoption or semantic truth
judgments. The driver uses real CLI calls; the runtime remains MoonBit.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

REPO = Path(__file__).resolve().parents[1]


def demonstrate_engineering(output, binary=None, compare_binary=None):
    output.mkdir(parents=True, exist_ok=False)
    reports = output / "reports"
    reports.mkdir()
    project = output / "project"
    project.mkdir()
    command = [str(binary.resolve())] if binary else ["moon", "run", "cmd/main"]
    phases = []

    def invoke(name, operation="check", arguments=(), expected=0, root=project, executable=None):
        cmd = [str(executable.resolve())] if executable else command
        result = subprocess.run([*cmd, operation, *arguments, "--root", str(root.resolve()), "--json"],
                                cwd=REPO, capture_output=True, text=True, timeout=180)
        (reports / (name + ".json")).write_text(result.stdout)
        if result.returncode != expected:
            raise ValueError(f"{name}: expected {expected}, got {result.returncode}: {result.stdout}{result.stderr}")
        report = json.loads(result.stdout)
        phases.append({"name": name, "exit_code": result.returncode,
                       "checked": report["checked_count"], "failed": report["failed_count"],
                       "warnings": report["warning_count"], "skipped_web": report["skipped_count"]})
        print(name, result.returncode)
        return report

    padding = "".join(f"Stable setting {i:03d}: " + "x" * 80 + ".\n" for i in range(120))
    source = "# Service\n## Settings\nTimeout: 20 seconds.\n" + padding + "Permission: read.\n## Other\nUnrelated: before.\n"
    (project / "source.md").write_text(source)
    # There is no quote to match: the dependency is the selected source section.
    (project / "guide.md").write_text("[Runtime settings](source.md#settings)\n")
    invoke("01-init", "init", ("guide.md",))
    baseline = project / ".tracecite-docs.json"
    baseline_before = hashlib.sha256(baseline.read_bytes()).hexdigest()
    (project / "source.md").write_text(source.replace("Unrelated: before.", "Unrelated: after."))
    outside = invoke("02-outside-selected-section")
    if outside["failed_count"] or any(i.get("change_analysis") for i in outside["items"]):
        raise ValueError("An unrelated source section changed the observed dependency")
    changed_source = source.replace("Timeout: 20", "Timeout: 30").replace("Permission: read", "Permission: write")
    (project / "source.md").write_text(changed_source)
    report = invoke("03-two-separated-changes", arguments=("--preview-baseline",), expected=2)
    item = next(i for i in report["items"] if i["status"] == "changed")
    diff = item["change_analysis"]
    if (not diff["complete"] or diff["total_hunks"] != 2
            or [h["previous_start_line"] for h in diff["hunks"]] != [2, 123]
            or [h["current_text"] for h in diff["hunks"]] != ["Timeout: 30 seconds.\n", "Permission: write."]):
        raise ValueError(f"Separated changes were not localized independently: {diff}")
    preview = report["baseline_preview"]
    candidate = preview["changes"][0]
    if not preview["can_update"] or "Permission: write." not in candidate["current"] or padding not in candidate["current"]:
        raise ValueError("Diff presentation lost complete source evidence")
    comparison = None
    if compare_binary:
        old = invoke("04-previous-release", arguments=("--preview-baseline",), expected=2, executable=compare_binary)
        old_item = next(i for i in old["items"] if i["status"] == "changed")
        fields = ("checked_count", "failed_count", "warning_count", "skipped_count", "unbound_snippets")
        if any(old[f] != report[f] for f in fields) or old["baseline_preview"] != preview:
            raise ValueError("The differential case changed validation or the full baseline candidate")
        if "Permission: write." in old_item.get("actual", ""):
            raise ValueError("This fixture does not reproduce the old display limitation")
        comparison = {"previous_version": old["tool_version"], "current_version": report["tool_version"],
                      "validation_and_full_preview_identical": True,
                      "previous_display_has_second_change": False, "current_diff_has_both_changes": True}
    if hashlib.sha256(baseline.read_bytes()).hexdigest() != baseline_before:
        raise ValueError("Read-only change inspection altered the baseline")
    # Large unrelated replacements exceed the independently bounded alignment.
    bulk = output / "bulk"
    bulk.mkdir()
    (bulk / "guide.md").write_text("[Selected region](source.md#settings)\n")
    (bulk / "source.md").write_text("# Settings\n" + "".join(f"old-{i}\n" for i in range(520)))
    invoke("05-bulk-init", "init", ("guide.md",), root=bulk)
    bulk_baseline = (bulk / ".tracecite-docs.json").read_bytes()
    (bulk / "source.md").write_text("# Settings\n" + "".join(f"new-{i}\n" for i in range(520)))
    limited = invoke("06-budget-fallback", expected=2, root=bulk)
    limited_diff = next(i for i in limited["items"] if i["status"] == "changed")["change_analysis"]
    if limited_diff["complete"] or limited_diff["reason"] != "cell_limit" or "added_lines" in limited_diff:
        raise ValueError("Uncomputed changes were presented as complete or zero edits")
    invoke("07-unreviewed-overwrite-rejected", arguments=("--baseline", ".tracecite-docs.json", "--snapshot", ".tracecite-docs.json"), expected=2, root=bulk)
    if (bulk / ".tracecite-docs.json").read_bytes() != bulk_baseline:
        raise ValueError("Rejected baseline update replaced existing evidence")
    mismatch = output / "mismatch"
    mismatch.mkdir()
    (mismatch / "guide.md").write_text("```toml source=config.toml#L1-L1\ntimeout = 20\n```\n")
    (mismatch / "config.toml").write_text("timeout = 20\n")
    invoke("08-snippet-init", "init", ("guide.md",), root=mismatch)
    unchanged = (mismatch / ".tracecite-docs.json").read_bytes()
    (mismatch / "config.toml").write_text("timeout = 30\n")
    invalid = invoke("09-invalid-excerpt-no-candidate", arguments=("--preview-baseline",), expected=2, root=mismatch)
    if invalid["baseline_preview"]["can_update"] or "snapshot" in invalid["baseline_preview"]:
        raise ValueError("Invalid source excerpt received a baseline candidate")
    invoke("10-invalid-excerpt-no-overwrite", arguments=("--snapshot", ".tracecite-docs.json"), expected=2, root=mismatch)
    if (mismatch / ".tracecite-docs.json").read_bytes() != unchanged:
        raise ValueError("Invalid excerpt overwrote the baseline")
    blocked = output / "blocked"
    blocked.mkdir()
    (output / "outside.txt").write_text("not in the permitted workspace\n")
    (blocked / "guide.md").write_text("[Outside](../outside.txt)\n")
    path_report = invoke("11-path-boundary", arguments=("guide.md", "--no-config", "--strict"), expected=2, root=blocked)
    if not any(i["code"] == "SOURCE_OUTSIDE_ROOT" for i in path_report["items"]):
        raise ValueError("An out-of-root source was accepted")
    (blocked / "guide.md").write_text("[Blocked address](http://127.0.0.1/secret)\n")
    network_report = invoke("12-network-boundary", arguments=("guide.md", "--no-config", "--strict", "--online"), expected=2, root=blocked)
    if not any(i["code"] == "INVALID_OR_BLOCKED_URL" for i in network_report["items"]):
        raise ValueError("A blocked source address was accepted")
    receipt = {"schema": 1, "case_type": "controlled_regression", "tool_version": report["tool_version"],
               "semantic_truth_checked": False, "external_adoption": False,
               "phases": phases, "multi_change_analysis": diff,
               "budget_fallback": limited_diff, "comparison": comparison,
               "baseline_unchanged_after_rejected_writes": True,
               "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest() if binary else None,
               "comparison_binary_sha256": hashlib.sha256(compare_binary.read_bytes()).hexdigest() if compare_binary else None,
               "implementation_sha256": {name: hashlib.sha256((REPO / name).read_bytes()).hexdigest()
                                         for name in ("document_diff.mbt", "cli/document.mbt", "cli/main.mbt")},
               "passed": True}
    (output / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--compare-binary", type=Path)
    args = parser.parse_args()
    demonstrate_engineering(args.out.resolve(), args.binary, args.compare_binary)
