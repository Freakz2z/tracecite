#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
moon build --target native --release --deny-warn
platform=$(uname -s | tr '[:upper:]' '[:lower:]')
architecture=$(uname -m)
bundle="tracecite-$platform-$architecture"
mkdir -p dist _build
staging=$(mktemp -d _build/native-package.XXXXXX)
trap 'rm -rf "$staging"' EXIT
mkdir "$staging/$bundle"
cp _build/native/release/build/cmd/main/main.exe "$staging/$bundle/tracecite"
chmod +x "$staging/$bundle/tracecite"
cp LICENSE "$staging/$bundle/"
cat > "$staging/$bundle/USAGE.md" <<'EOF'
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
Online HTTPS checks require the host's TLS library and certificate store.
License attributions are in THIRD_PARTY_NOTICES.md and licenses/. BUILD-INFO.json
records toolchain/dependency identities and SHA-256 values for the payload.
Source documentation: https://github.com/Freakz2z/tracecite
EOF
python3 scripts/package_notices.py "$staging/$bundle"
tar -czf "$staging/$bundle.tar.gz" -C "$staging" "$bundle"
python3 scripts/verify_native_package.py "$staging/$bundle.tar.gz"
mv "$staging/$bundle.tar.gz" "dist/$bundle.tar.gz"
python3 - "$bundle" <<'PY'
import hashlib
from pathlib import Path
import sys
archive = Path('dist') / (sys.argv[1] + '.tar.gz')
archive.with_suffix('.gz.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n')
PY
printf '%s\n' "dist/$bundle.tar.gz"
