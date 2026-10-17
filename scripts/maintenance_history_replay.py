#!/usr/bin/env python3
"""Replay one reviewed upstream maintenance commit in an isolated checkout.

Network is needed only to fetch the pinned history. TraceCite runs offline.
This measures machine execution and display volume, not maintainer adoption or
human review time. Raw upstream excerpts stay in the chosen output directory.
"""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import time


REPOSITORY = "https://github.com/moonbitlang/moon.git"
BEFORE = "bfdd73d8ae88b5d2f1403c8c77f6d3912667d1ef"
AFTER = "37f067473211ada78d395883e21f0444c74e0fa0"
DOCUMENTS = ["docs/manual/src/commands.md", "docs/manual-zh/src/commands.md"]
CONFIG = "tracecite-history-replay.json"
SNAPSHOT = ".tracecite-history-replay.json"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, cwd):
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True, timeout=180)
    require(result.returncode == 0, f"{command}: {result.stdout}\n{result.stderr}")
    return result.stdout


def display_characters(report):
    return sum(len(item.get(field) or "") for item in report["items"]
               if item["status"] == "changed" for field in ("previous", "actual"))


def without_changed_display(report):
    result = copy.deepcopy(report)
    items = result["items"] + [item for group in result.get("review", [])
                              for item in group["locations"]]
    for item in items:
        if item["status"] == "changed":
            for field in ("previous", "actual", "change_analysis"):
                item.pop(field, None)
    # Different builds may identify themselves with different tool versions.
    result.pop("tool_version", None)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--compare-binary", type=Path,
                        help="optional earlier binary, checked against exactly the same baseline")
    parser.add_argument("--repository", type=Path,
                        help="reuse a local Git repository containing both pinned commits; no fetch")
    parser.add_argument("--out", type=Path, required=True, help="new output directory (must not exist)")
    args = parser.parse_args()
    binary = args.binary.resolve(strict=True)
    compare = args.compare_binary.resolve(strict=True) if args.compare_binary else None
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    root = output / "checkout"
    if args.repository:
        run(["git", "clone", "--shared", "--no-checkout", str(args.repository.resolve(strict=True)), str(root)], output)
    else:
        root.mkdir()
        run(["git", "init"], root)
        run(["git", "fetch", "--depth=2", REPOSITORY, AFTER], root)
    require(run(["git", "rev-parse", AFTER + "^"], root).strip() == BEFORE,
            "pinned before revision is not the parent of the after revision")
    run(["git", "checkout", "--detach", BEFORE], root)
    for name in (CONFIG, SNAPSHOT):
        require(not (root / name).exists(), f"upstream already uses reserved replay path {name}")
    phases = []

    def check(label, executable, arguments, expected):
        command = [str(executable), *arguments, "--root", str(root), "--json"]
        start = time.perf_counter()
        result = subprocess.run(command, cwd=root, text=True, capture_output=True, timeout=90)
        elapsed = time.perf_counter() - start
        (output / (label + ".json")).write_text(result.stdout, encoding="utf-8")
        (output / (label + ".stderr.txt")).write_text(result.stderr, encoding="utf-8")
        require(result.returncode == expected,
                f"{label}: expected exit {expected}, got {result.returncode}: {result.stdout}\n{result.stderr}")
        report = json.loads(result.stdout)
        phases.append({"phase": label, "binary_sha256": digest(executable),
                       "arguments": [*arguments, "--root", "<isolated-checkout>", "--json"],
                       "exit_code": result.returncode, "machine_seconds": round(elapsed, 6),
                       "counts": {key: report[key] for key in (
                           "document_count", "checked_count", "failed_count", "warning_count",
                           "skipped_count", "unbound_snippets", "skipped_quotes")},
                       "changed_display_characters": display_characters(report)})
        return report

    check("before-check", binary, ["check", *DOCUMENTS, "--no-config", "--strict"], 0)
    check("before-init", binary, ["init", *DOCUMENTS, "--config", CONFIG, "--snapshot", SNAPSHOT], 0)
    baseline_digest = digest(root / SNAPSHOT)
    run(["git", "checkout", "--detach", AFTER], root)
    # Human-readable upstream patch is retained locally for independent review.
    patch = run(["git", "diff", BEFORE, AFTER, "--", *DOCUMENTS], root)
    (output / "upstream-documents.diff").write_text(patch, encoding="utf-8")
    preview_args = ["check", "--config", CONFIG, "--preview-baseline"]
    previous = check("after-previous-build", compare, preview_args, 2) if compare else None
    current = check("after-current-build", binary, preview_args, 2)
    require(digest(root / SNAPSHOT) == baseline_digest, "read-only check altered baseline")
    changed = [item for item in current["items"] if item["status"] == "changed"]
    require({(item["document"], item["line"], item["source"], item["code"]) for item in changed}
            == {(doc, 26, "#moon-search", "REFERENCED_SOURCE_CHANGED") for doc in DOCUMENTS}
            and len(changed) == 2, "unexpected maintenance locations")
    require(current["failed_count"] == 2 and current["warning_count"] == 0,
            "unexpected extra diagnostics: do not approve replay baseline")
    preview = current["baseline_preview"]
    require(preview["can_update"] and preview["changed_count"] == 2
            and preview["added_count"] == 0 and preview["removed_count"] == 0,
            "unexpected baseline delta")
    for change in preview["changes"]:
        require(change["current"] == change["previous"].replace(
            "download count, and matching", "download count, repository link, and matching", 1)
            and change["current"] != change["previous"], "unreviewed source change")
    if previous:
        require(without_changed_display(previous) == without_changed_display(current),
                "comparison changed detection, coverage or complete snapshot evidence")
        require(display_characters(current) <= display_characters(previous),
                "legacy display volume increased")
    # Only this fixed, reviewed upstream wording change is accepted, in the
    # isolated replay checkout. This is not a general automatic approval tool.
    check("accept-reviewed-baseline", binary,
          ["check", "--config", CONFIG, "--snapshot", SNAPSHOT], 0)
    require(json.loads((root / SNAPSHOT).read_text()) == preview["snapshot"],
            "saved snapshot differs from the complete reviewed candidate")
    check("after-accepted-check", binary, ["check", "--config", CONFIG], 0)
    require(not run(["git", "diff", "--name-only", AFTER], root).strip(), "upstream files were edited")
    receipt = {
        "schema_version": 1, "mode": "historical_replay", "repository": REPOSITORY,
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "before": BEFORE, "after": AFTER, "documents": DOCUMENTS,
        "upstream_subject": run(["git", "show", "-s", "--format=%s", AFTER], root).strip(),
        "upstream_document_patch_sha256": digest(output / "upstream-documents.diff"),
        "tool_version": current["tool_version"],
        "baseline_before_sha256": baseline_digest, "baseline_after_sha256": digest(root / SNAPSHOT),
        "phases": phases,
        "comparison_preserves_detection_and_full_snapshot": True if previous else None,
        "legacy_display_reduced": display_characters(current) < display_characters(previous) if previous else None,
        "changed_source_analysis": [{"document": item["document"], "line": item["line"],
                                     "analysis": item["change_analysis"]}
                                    for item in changed if "change_analysis" in item],
        "review": {"classification": "expected_source_change", "locations": 2,
                   "newly_discovered_broken_documentation": 0,
                   "decision": "Both existing TOC links observe the updated search section. The upstream commit already documents repository links; accept the reviewed baseline.",
                   "human_review_seconds": None, "maintainer_feedback": None,
                   "external_adoption": False},
        "limits": ["Two selected documents, not a whole-repository acceptance result.",
                   "Two web references remain unchecked; no source snippets are unbound in this scope.",
                   "Historical replay is not prospective CI use or maintainer feedback.",
                   "Machine seconds exclude build/fetch and do not measure human review time.",
                   "Display characters count changed items once, excluding duplicated review groups and full preview JSON."]}
    (output / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
