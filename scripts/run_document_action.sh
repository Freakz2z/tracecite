#!/usr/bin/env bash
set -euo pipefail

# Every input remains a quoted argument, including paths containing spaces.
input_path=${TRACECITE_PATH:-.}
online=${TRACECITE_ONLINE:-false}
strict=${TRACECITE_STRICT:-true}
if [[ -n ${TRACECITE_REPORT:-} ]]; then
  input_path=$TRACECITE_REPORT
  online=true
fi
if [[ $online != true && $online != false ]] || [[ $strict != true && $strict != false ]]; then
  printf '%s\n' 'online and strict must be true or false' >&2
  exit 1
fi
args=(check "$input_path" --root "$GITHUB_WORKSPACE" --github)
if [[ $online == true ]]; then args+=(--online); fi
if [[ $strict == true ]]; then args+=(--strict); fi
if [[ -n ${TRACECITE_BASELINE:-} ]]; then args+=(--baseline "$TRACECITE_BASELINE"); fi
while IFS= read -r excluded; do
  if [[ -n $excluded ]]; then args+=(--exclude "$excluded"); fi
done <<< "${TRACECITE_EXCLUDE:-}"
cd "$GITHUB_ACTION_PATH"
moon run cmd/main "${args[@]}"
