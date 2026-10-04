"""Run the documented standalone library project against local or registry code."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]


def verify_example(root, metadata, package=None):
    example = root / "library-example"
    shutil.copytree(REPO / "examples/library/project", example)
    module = example / "moon.mod"
    module.write_text(re.sub(r'Freakz2z/tracecite@[0-9]+\.[0-9]+\.[0-9]+',
                            metadata["name"] + "@" + metadata["version"], module.read_text()))
    if package is not None:
        # The workspace is only in the temporary verification directory. The
        # distributed example remains a standalone registry consumer.
        if package.parent != root:
            raise ValueError("Local package must be a sibling of the example")
        (root / "moon.work").write_text('members = ["./' + package.name + '", "./library-example"]\n')
    subprocess.run(["moon", "update"], cwd=example, check=True, timeout=90)
    results = {}
    for target in ("native", "js", "wasm"):
        subprocess.run(["moon", "test", ".", "--target", target, "--deny-warn"], cwd=example, check=True, timeout=180)
        result = subprocess.run(["moon", "run", ".", "--target", target, "--deny-warn"], cwd=example,
                                check=True, capture_output=True, text=True, timeout=180)
        report = json.loads(result.stdout)
        if (report["references"] != 1 or report["before_matches"] is not True
                or report["after_matches"] is not False or len(report["changes"]) != 1
                or report["changes"][0]["change"] != "changed"
                or report["changes"][0]["previous"] != "timeout = 20"
                or report["changes"][0]["current"] != "timeout = 30"):
            raise ValueError("Library example did not expose the configuration change")
        results[target] = report
    if not all(report == results["native"] for report in results.values()):
        raise ValueError("Library example results differ across targets")
    print("Standalone library example passed on native, JS and Wasm")
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", action="store_true")
    options = parser.parse_args()
    from verify_release_package import module_metadata
    metadata = module_metadata((REPO / "moon.mod").read_text())
    with tempfile.TemporaryDirectory(prefix="tracecite-library-") as temporary:
        root = Path(temporary)
        if options.registry:
            verify_example(root, metadata)
        else:
            package = root / "package"
            shutil.copytree(REPO, package, ignore=shutil.ignore_patterns(".git", "_build", ".mooncakes", "dist", "__pycache__"))
            verify_example(root, metadata, package)
