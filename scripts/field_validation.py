"""Check fixed upstream commits; preserve raw reports locally, export local diagnostics."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess

REPO = Path(__file__).resolve().parents[1]
CASES = [
    {"name": "async", "repository": "https://github.com/moonbitlang/async.git",
     "revision": "00aa493c5a674988dc0f4dc3f9bf0a0e654427ac",
     "paths": ["README.md", "src/**/*.md", "examples/**/*.md"]},
    {"name": "moon", "repository": "https://github.com/moonbitlang/moon.git",
     "revision": "0a3f0d43b228a5338417d8a569d3cdaa833e467d",
     "paths": ["README.md", "docs/**/*.md"]},
]


def validate(output, binary=None):
    output.mkdir(parents=True, exist_ok=False)
    command = [str(binary.resolve())] if binary else ["moon", "run", "cmd/main"]
    version = subprocess.check_output(command + ["--version"], cwd=REPO, text=True).strip()
    records = []
    for case in CASES:
        checkout = output / case["name"]
        subprocess.run(["git", "init", str(checkout)], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(checkout), "fetch", "--depth", "1",
                        case["repository"], case["revision"]], check=True)
        subprocess.run(["git", "-C", str(checkout), "checkout", "--detach", "FETCH_HEAD"], check=True)
        head = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
        if head != case["revision"]:
            raise RuntimeError("Upstream revision mismatch")
        config = {"version": 1, "paths": case["paths"], "exclude": [], "strict": True, "online": False}
        (checkout / "tracecite-field.json").write_text(json.dumps(config, indent=2) + "\n")
        result = subprocess.run(command + ["check", "--root", str(checkout.resolve()),
                                "--config", "tracecite-field.json", "--json"],
                                cwd=REPO, text=True, capture_output=True, timeout=180)
        (output / (case["name"] + "-report.json")).write_text(result.stdout)
        (output / (case["name"] + "-stderr.txt")).write_text(result.stderr)
        if result.returncode not in (0, 1, 2):
            raise RuntimeError(result.stderr or result.stdout)
        report = json.loads(result.stdout)
        # Public badge URLs may carry query strings; only local failure diagnostics
        # enter the shareable receipt. Raw upstream reports remain in the output.
        local = [item for item in report["items"]
                 if item["status"] in ("mismatch", "unavailable")
                 and not item["source"].startswith(("http://", "https://"))]
        stats = {key: report[key] for key in ("document_count", "checked_count", "failed_count",
                                             "warning_count", "skipped_count", "unbound_snippets")}
        records.append({**case, "config": config, "exit": result.returncode,
                        "statistics": stats, "local_diagnostics": local})
        print(case["name"], result.returncode, stats)
    receipt = {"schema": 1, "checked_at": datetime.now(timezone.utc).isoformat(),
               "tool": version, "scope": "offline fixed-commit upstream evaluation; not adoption or temporal drift evidence",
               "cases": records}
    (output / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--binary", type=Path)
    options = parser.parse_args()
    validate(options.output.resolve(), options.binary)
