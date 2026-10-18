"""Reproduce post-scan input and baseline conflicts with a real CLI (Linux).

An explicitly bounded stdout pipe is a deterministic barrier: scanning has
finished when the first report byte arrives, but the CLI cannot commit until
the remaining report is drained. No timing sleeps or runtime test hooks.
"""
import argparse
import hashlib
import json
from pathlib import Path
import selectors
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]


def demonstrate_consistency(output, binary=None):
    if sys.platform != "linux":
        raise ValueError("The stdout barrier demonstration requires Linux pipe sizing; native MoonBit guard tests are portable")
    output.mkdir(parents=True, exist_ok=False)
    project = output / "project"
    project.mkdir()
    reports = output / "reports"
    reports.mkdir()
    original = {
        "source.toml": b"timeout = 20\n",
        "guide.md": ("[Local](source.toml)\n" * 150
                     + "```toml source=source.toml\ntimeout = 20\n```\n").encode(),
        "tracecite.json": json.dumps({"version": 1, "paths": ["guide.md"], "strict": True}).encode(),
    }
    command = [str(binary.resolve())] if binary else ["moon", "run", "cmd/main"]
    destination = project / "baseline.json"
    previous = b"previous baseline\n"
    concurrent = b"concurrently changed\n"
    phases = []
    for changed in (*original, "baseline.json"):
        for path, content in original.items():
            (project / path).write_bytes(content)
        destination.write_bytes(previous)
        process = subprocess.Popen([*command, "check", "--root", str(project.resolve()),
                                    "--snapshot", "baseline.json", "--json"],
                                   cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   pipesize=4096)
        try:
            with selectors.DefaultSelector() as ready:
                ready.register(process.stdout, selectors.EVENT_READ)
                if not ready.select(timeout=90):
                    raise ValueError("Timed out waiting for the scan report")
            prefix = process.stdout.read1(1)
            if prefix != b"{" or process.poll() is not None:
                raise ValueError("The scan did not reach the blocked report barrier")
            (project / changed).write_bytes(concurrent)
            remainder, errors = process.communicate(timeout=90)
            name = changed.replace(".", "-")
            (reports / (name + ".json")).write_bytes(prefix + remainder)
            (reports / (name + ".stderr.txt")).write_bytes(errors)
            report = json.loads(prefix + remainder)
            code = "SNAPSHOT_CONFLICT" if changed == "baseline.json" else "CHECK_INPUT_CHANGED"
            expected = concurrent if changed == "baseline.json" else previous
            if (process.returncode != 2 or code.encode() not in errors
                    or report["failed_count"] != 0 or report["warning_count"] != 0
                    or destination.read_bytes() != expected
                    or (project / "baseline.json.tmp").exists()):
                raise ValueError(f"{changed}: stale candidate was not refused safely: {errors.decode()}")
            phases.append({"changed_input": changed, "scan_failed_count": report["failed_count"],
                           "exit_code": process.returncode, "commit_diagnostic": code,
                           "preserved": "concurrent_writer" if changed == "baseline.json" else "original_baseline",
                           "baseline_before_sha256": hashlib.sha256(previous).hexdigest(),
                           "baseline_after_sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
                           "temporary_removed": True})
            print(changed, code, process.returncode)
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=10)
    receipt = {"schema": 1, "case_type": "controlled_concurrency_regression",
               "tool_version": report["tool_version"], "platform": "linux",
               "barrier": "stdout_pipe_4096_bytes_after_scan_before_commit",
               "filesystem_transaction": False, "external_adoption": False,
               "phases": phases,
               "implementation_sha256": {name: hashlib.sha256((REPO / name).read_bytes()).hexdigest()
                                         for name in ("cli/document.mbt", "cli/document_consistency.mbt")},
               "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest() if binary else None,
               "passed": True}
    (output / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--binary", type=Path)
    arguments = parser.parse_args()
    demonstrate_consistency(arguments.out.resolve(), arguments.binary)
