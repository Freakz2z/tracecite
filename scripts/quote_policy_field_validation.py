"""Compare explicit quote policy on pinned upstream documents, without claiming adoption."""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess

from field_validation import REPO, validate


def compare(output, binary):
    baseline = validate(output, binary)
    cases = []
    for case in baseline["cases"]:
        before = json.loads((output / (case["name"] + "-report.json")).read_text())
        quotes = [item for item in before["items"] if item["code"] == "UNASSOCIATED_QUOTE"]
        # This budget measures the existing scope; it is not an endorsement of
        # ignoring these quotations. Authors must still review citation intent.
        budget = len(quotes)
        result = subprocess.run([str(binary.resolve()), "check", "--root", str(output / case["name"]),
                                 "--config", "tracecite-field.json", "--json", "--unassociated-quotes", "skip",
                                 "--max-skipped-quotes", str(budget)],
                                cwd=REPO, text=True, capture_output=True, timeout=180)
        if result.returncode != case["exit"]:
            raise ValueError("Quote policy changed the expected failing upstream exit")
        after = json.loads(result.stdout)
        (output / (case["name"] + "-skip-report.json")).write_text(result.stdout)
        for key in ("document_count", "checked_count", "failed_count", "skipped_count", "unbound_snippets"):
            if after[key] != before[key]:
                raise ValueError(f"Quote policy changed {key}")
        if after["skipped_quotes"] != budget or after["warning_count"] + budget != before["warning_count"]:
            raise ValueError("Quote coverage changed unexpectedly")
        retained = [item for item in before["items"] if item["code"] != "UNASSOCIATED_QUOTE"]
        observed = [item for item in after["items"] if item["code"] != "UNASSOCIATED_QUOTE_SKIPPED"]
        if retained != observed:
            raise ValueError("A source check or another diagnostic changed under skip")
        skipped = [item for item in after["items"] if item["code"] == "UNASSOCIATED_QUOTE_SKIPPED"]
        if Counter((item["document"], item["line"]) for item in quotes) != Counter(
                (item["document"], item["line"]) for item in skipped):
            raise ValueError("Skipped quotation locations differ from the raw warnings")
        cases.append({"name": case["name"], "repository": case["repository"], "revision": case["revision"],
                      "config": case["config"], "skip_policy": "skip", "max_skipped_quotes": budget,
                      "review_exit": case["exit"], "skip_exit": result.returncode,
                      "review_statistics": case["statistics"],
                      "skip_statistics": {key: after[key] for key in (*case["statistics"], "skipped_quotes")},
                      "other_items_unchanged": True,
                      "retained_warning_codes": dict(Counter(item["code"] for item in observed if item["status"] == "warning"))})
    receipt = {"schema": 1, "checked_at": baseline["checked_at"], "tool": baseline["tool"],
               "scope": "development policy comparison on fixed commits; skipped quotations remain unverified; not author intent or adoption evidence",
               "cases": cases}
    (output / "quote-policy-receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(receipt, ensure_ascii=False, indent=2))
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--binary", type=Path, required=True)
    options = parser.parse_args()
    compare(options.output.resolve(), options.binary)
