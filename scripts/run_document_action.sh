#!/usr/bin/env bash
set -euo pipefail

# Every input remains a quoted argument, including paths containing spaces.
input_path=${TRACECITE_PATH:-}
online=${TRACECITE_ONLINE:-}
strict=${TRACECITE_STRICT:-}
config=${TRACECITE_CONFIG:-}
args=(check --root "$GITHUB_WORKSPACE" --github)
if [[ -n ${TRACECITE_REPORT:-} ]]; then
  input_path=$TRACECITE_REPORT
  online=true
  args+=(--no-config)
  if [[ -z $strict ]]; then strict=true; fi
elif [[ -n $config ]]; then
  args+=(--config "$config")
elif [[ -z $strict && ! -e "$GITHUB_WORKSPACE/tracecite.json" ]]; then
  # Preserve the original Action default for repositories without configuration.
  strict=true
fi
if [[ -n $online && $online != true && $online != false ]] || [[ -n $strict && $strict != true && $strict != false ]]; then
  printf '%s\n' 'online and strict must be empty, true or false' >&2
  exit 1
fi
if [[ -n $input_path ]]; then args+=("$input_path"); fi
if [[ $online == true ]]; then args+=(--online); fi
if [[ $online == false ]]; then args+=(--offline); fi
if [[ $strict == true ]]; then args+=(--strict); fi
if [[ $strict == false ]]; then args+=(--no-strict); fi
if [[ -n ${TRACECITE_BASELINE:-} ]]; then args+=(--baseline "$TRACECITE_BASELINE"); fi
while IFS= read -r excluded; do
  if [[ -n $excluded ]]; then args+=(--exclude "$excluded"); fi
done <<< "${TRACECITE_EXCLUDE:-}"
cd "$GITHUB_ACTION_PATH"
moon run cmd/main "${args[@]}"
