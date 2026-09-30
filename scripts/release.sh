#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mode=${1:-prepare}
if [[ $# -gt 1 || ( $mode != prepare && $mode != --package-only && $mode != --publish ) ]]; then
  printf '%s\n' 'Usage: bash scripts/release.sh [--package-only | --publish]' >&2
  exit 1
fi

if [[ $mode != --package-only ]]; then
  moon update
  moon check --deny-warn
  moon test --deny-warn
  moon test --target js --deny-warn
  moon test --target wasm --deny-warn
  python3 scripts/test_document_cli.py
  python3 scripts/test_native_package.py
  python3 -m unittest discover -s adapters -p 'test_*.py'
  sh scripts/smoke.sh
  moon run cmd/main check
fi

mkdir -p _build
if ! moon package > _build/package-release.log 2>&1; then
  cat _build/package-release.log >&2
  exit 1
fi
python3 scripts/verify_release_package.py

if [[ $mode == --publish ]]; then
  if [[ ! -f ${MOON_HOME:-$HOME/.moon}/credentials.json ]]; then
    printf '%s\n' 'Package verified. Run moon login with the module owner account, then rerun with --publish.' >&2
    exit 1
  fi
  moon publish
  python3 scripts/verify_release_package.py --registry
fi
