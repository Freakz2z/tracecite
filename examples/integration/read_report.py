"""Summarize check/init reports; this reader does not replace the CLI exit code."""
import json
from pathlib import Path
import sys

STATUSES = {"ok", "error", "unavailable", "mismatch", "changed", "warning", "skipped"}
CATEGORIES = {"verified", "source_unavailable", "content_mismatch", "source_changed",
              "needs_review", "not_checked", "coverage", "invalid_document"}


def summarize(report):
    if not isinstance(report, dict):
        raise ValueError("Report must be a JSON object")
    if type(report.get("schema_version")) is not int or report["schema_version"] != 1:
        raise ValueError("Unsupported report schema; legacy unversioned reports require a separate reader")
    for field in ("failed_count", "warning_count", "skipped_count", "unbound_snippets"):
        if type(report.get(field)) is not int or report[field] < 0:
            raise ValueError("Invalid report count: " + field)
    if not isinstance(report.get("items"), list):
        raise ValueError("Report items must be an array")
    categories = {}
    unknown = 0
    for item in report["items"]:
        category = item.get("category") if isinstance(item, dict) else None
        status = item.get("status") if isinstance(item, dict) else None
        if (not isinstance(category, str) or category not in CATEGORIES
                or not isinstance(status, str) or status not in STATUSES):
            unknown += 1
        else:
            categories[category] = categories.get(category, 0) + 1
    return {"failed": report["failed_count"], "needs_review": report["warning_count"],
            "skipped_web": report["skipped_count"], "unbound_snippets": report["unbound_snippets"],
            "unknown_items_need_review": unknown, "categories": categories}


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 read_report.py report.json")
    try:
        print(json.dumps(summarize(json.loads(Path(sys.argv[1]).read_text())), indent=2))
    except (ValueError, OSError) as error:
        raise SystemExit(str(error))
