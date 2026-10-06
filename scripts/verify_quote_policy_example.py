"""Exercise explicit quote policy with a delivered CLI in an isolated project."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]


def verify_quote_policy(binary, environment=None):
    results = {}
    with tempfile.TemporaryDirectory(prefix="tracecite-quote-policy-") as temporary:
        root = Path(temporary) / "project"
        shutil.copytree(REPO / "examples/quote-policy/project", root)

        def check(name, operation="check", arguments=(), expected_exit=0, code=None):
            result = subprocess.run([str(binary.resolve()), operation, "--root", str(root),
                                     *arguments, "--json"], cwd=REPO, env=environment,
                                    text=True, capture_output=True, timeout=30)
            if result.returncode != expected_exit:
                raise ValueError(f"{name}: {result.returncode}: {result.stdout}{result.stderr}")
            report = json.loads(result.stdout)
            if (report["checked_count"] != 2 or report["skipped_count"] != 0
                    or report["unbound_snippets"] != 0
                    or report["skipped_quotes"] != (0 if name == "review_override" else 2)):
                raise ValueError(f"{name}: incorrect coverage")
            if code and code not in [item["code"] for item in report["items"]]:
                raise ValueError(f"{name}: missing {code}")
            if expected_exit == 0 and (report["failed_count"] or report["warning_count"]):
                raise ValueError(f"{name}: unexpected failures or warnings")
            results[name] = {"tool_version": report["tool_version"], "exit_code": result.returncode,
                             "checked": report["checked_count"], "skipped_quotes": report["skipped_quotes"],
                             "failed": report["failed_count"], "warnings": report["warning_count"],
                             "codes": [item["code"] for item in report["items"] if item["code"]]}
            return report

        check("configured_check")
        check("review_override", arguments=("--unassociated-quotes", "review"), expected_exit=2,
              code="UNASSOCIATED_QUOTE")
        preview = check("budget_preview", arguments=("--max-skipped-quotes", "1", "--no-strict", "--preview-baseline"),
                        expected_exit=2, code="SKIPPED_QUOTE_LIMIT_EXCEEDED")
        if preview["baseline_preview"]["can_update"] or "snapshot" in preview["baseline_preview"]:
            raise ValueError("Exceeded quote budget produced a baseline candidate")
        check("budget_snapshot", arguments=("--max-skipped-quotes", "1", "--snapshot", "rejected.json"),
              expected_exit=2, code="SKIPPED_QUOTE_LIMIT_EXCEEDED")
        if (root / "rejected.json").exists():
            raise ValueError("Exceeded quote budget wrote a snapshot")
        (root / "tracecite.json").unlink()
        check("init", operation="init", arguments=("guide.md", "--unassociated-quotes", "skip", "--max-skipped-quotes", "2"))
        config = json.loads((root / "tracecite.json").read_text())
        if config["unassociated_quotes"] != "skip" or config["coverage"]["max_skipped_quotes"] != 2:
            raise ValueError("init lost quote policy or budget")
        check("round_trip")
        source = (root / "source.md").read_text()
        (root / "source.md").write_text(source.replace("twenty", "thirty"))
        check("source_drift", expected_exit=2, code="DOCUMENT_EXCERPT_MISMATCH")
        (root / "source.md").write_text(source)
        with (root / "guide.md").open("a") as stream:
            stream.write('\nAn "unfinished expression.\n')
        check("unclosed_quote", expected_exit=2, code="UNCLOSED_QUOTE")
    print("Verified quote policy example:", json.dumps(results))
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("--without-moon", action="store_true")
    options = parser.parse_args()
    verify_quote_policy(options.binary, dict(os.environ, PATH="/usr/bin:/bin") if options.without_moon else None)
