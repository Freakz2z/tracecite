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
./tracecite check docs README.md --root /path/to/repository --strict
./tracecite check docs --root /path/to/repository --snapshot references.json
./tracecite check docs --root /path/to/repository --baseline references.json --strict
./tracecite check report.md --root /path/to/repository --online --strict
```

Checks are local by default. Source-bound snippets use `source=path` in their
Markdown code fence. Paths are relative to the document. `--help` lists options.
Source documentation: https://github.com/Freakz2z/tracecite
EOF
tar -czf "dist/$bundle.tar.gz" -C dist "$bundle"
printf '%s\n' "dist/$bundle.tar.gz"
