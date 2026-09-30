#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
moon build --target native --release --deny-warn
platform=$(uname -s | tr '[:upper:]' '[:lower:]')
architecture=$(uname -m)
bundle="tracecite-$platform-$architecture"
mkdir -p "dist/$bundle"
cp _build/native/release/build/cmd/main/main.exe "dist/$bundle/tracecite"
chmod +x "dist/$bundle/tracecite"
cp LICENSE "dist/$bundle/"
cat > "dist/$bundle/USAGE.md" <<'EOF'
# TraceCite native CLI

Run the executable directly; MoonBit, Python and Node are not required.

```sh
./tracecite init docs README.md --root /path/to/repository
./tracecite check --root /path/to/repository
./tracecite check --root /path/to/repository --snapshot .tracecite-docs.json
./tracecite check report.md --root /path/to/repository --online --strict
```

Checks are local by default. Source-bound snippets use `source=path` in their
Markdown code fence. Paths are relative to the document. init creates
tracecite.json and a baseline without replacing existing files. Commit both;
check reads the root's configuration so local and CI scans use the same rules.
Review source changes before replacing the baseline. `--help` lists options.
Source documentation: https://github.com/Freakz2z/tracecite
EOF
tar -czf "dist/$bundle.tar.gz" -C dist "$bundle"
printf '%s\n' "dist/$bundle.tar.gz"
