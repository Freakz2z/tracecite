"""Check reference parsing and duplicate-definition failure with a delivered CLI."""
import argparse
import json
import os
from pathlib import Path
import subprocess

REPO = Path(__file__).resolve().parents[1]


def verify_links(binary, environment=None):
    results = {}
    for document, expected_exit in (("guide.md", 0), ("broken-first.md", 2)):
        process = subprocess.run(
            [str(binary.resolve()), "check", document, "--root",
             str(REPO / "examples/link-parsing/project"), "--no-config", "--strict",
             "--json", "--max-skipped-web", "0", "--max-unbound-snippets", "0"],
            cwd=REPO, env=environment, text=True, capture_output=True, timeout=30)
        if process.returncode != expected_exit:
            raise ValueError(f"Unexpected exit for {document}: {process.stdout}{process.stderr}")
        report = json.loads(process.stdout)
        expected_sources = (["valid.md"] * 5 + ["other.md"] + ["valid.md"] * 2
                            + ["guide(v2.md", "guide(v2).md", "valid.md", "valid.md"]
                            if expected_exit == 0 else ["missing.md"])
        if (report["document_count"] != 1 or report["online"] is not False
                or report["checked_count"] != len(expected_sources)
                or report["failed_count"] != (0 if expected_exit == 0 else 1)
                or any(report[key] != 0 for key in
                       ("warning_count", "skipped_count", "unbound_snippets"))
                or [item["source"] for item in report["items"]] != expected_sources):
            raise ValueError(f"Incomplete or incorrect reference coverage: {document}")
        if expected_exit == 0:
            if (any(item["status"] != "ok" for item in report["items"])
                    or [item["kind"] for item in report["items"]] != ["link"] * 10 + ["quote", "snippet"]):
                raise ValueError("Reference kinds or successful checks differ from the example")
        elif report["items"][0]["code"] != "SOURCE_NOT_FOUND":
            raise ValueError("A later definition masked the first broken source")
        results[document] = {
            "tool_version": report["tool_version"], "exit_code": process.returncode,
            "references": report["checked_count"], "failed": report["failed_count"],
            "warnings": report["warning_count"], "skipped_web": report["skipped_count"],
            "unbound_snippets": report["unbound_snippets"],
            "sources": [item["source"] for item in report["items"]],
            "codes": [item["code"] for item in report["items"]],
        }
    print("Verified reference parsing examples:", results)
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("--without-moon", action="store_true")
    options = parser.parse_args()
    verify_links(options.binary, dict(os.environ, PATH="/usr/bin:/bin") if options.without_moon else None)
