#!/bin/sh
set -eu

check_fixture() {
  file=$1
  expected_status=$2
  expected_code=$3
  status=0
  output=$(moon run cmd/main "$file" --json 2>&1) || status=$?
  if [ "$status" -ne "$expected_status" ]; then
    printf 'unexpected exit for %s: got %s, expected %s\n%s\n' "$file" "$status" "$expected_status" "$output" >&2
    exit 1
  fi
  if [ "$expected_code" != '-' ]; then
    case "$output" in
      *"$expected_code"*) ;;
      *) printf 'missing %s in %s output\n%s\n' "$expected_code" "$file" "$output" >&2; exit 1 ;;
    esac
  fi
  printf 'ok: %s (exit %s)\n' "$file" "$status"
}

check_fixture fixtures/valid.jsonl 0 -
check_fixture fixtures/codex-cli-trace.jsonl 0 -
status=0
output=$(moon run cmd/main fixtures/codex-cli-trace.jsonl --evidence 2>&1) || status=$?
if [ "$status" -ne 0 ]; then
  printf 'Codex evidence check failed\n%s\n' "$output" >&2
  exit 1
fi
check_fixture fixtures/evidence-old.jsonl 0 -
check_fixture fixtures/evidence-false-quote.jsonl 2 QUOTE_NOT_IN_SOURCE
status=0
output=$(moon run cmd/main compare fixtures/evidence-old.jsonl fixtures/evidence-new.jsonl 2>&1) || status=$?
if [ "$status" -ne 2 ] || ! printf '%s' "$output" | grep -q '\[changed\] file:///example/report.txt'; then
  printf 'source drift check failed\n%s\n' "$output" >&2
  exit 1
fi
check_fixture fixtures/unknown-source.jsonl 2 UNKNOWN_SOURCE
check_fixture fixtures/failed-result.jsonl 2 SOURCE_ON_FAILED_RESULT
check_fixture fixtures/duplicate-source.jsonl 2 DUPLICATE_SOURCE
check_fixture fixtures/mixed-run.jsonl 2 RUN_MISMATCH
