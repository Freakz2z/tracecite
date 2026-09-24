# TraceCite fixtures

Each file is a complete synthetic Agent run. URLs use the reserved
`example.org` domain and are never fetched by the validator.

| File | Expected exit | Main diagnostic |
| --- | ---: | --- |
| `valid.jsonl` | 0 | none |
| `unknown-source.jsonl` | 2 | `UNKNOWN_SOURCE` |
| `failed-result.jsonl` | 2 | `SOURCE_ON_FAILED_RESULT`, `UNKNOWN_SOURCE` |
| `duplicate-source.jsonl` | 2 | `DUPLICATE_SOURCE` |
| `mixed-run.jsonl` | 2 | `RUN_MISMATCH`, `MISSING_RESULT`, `UNKNOWN_SOURCE` |
| `codex-cli-trace.jsonl` | 0 | actual command event and cited answer, IDs redacted |
| `codex-cli-file-trace.jsonl` | 0 | actual output bound to local `facts.txt` |
| `codex-cli-file-tampered.jsonl` | 2 | `SOURCE_FILE_MISMATCH` with `verify-files` |
| `evidence-old.jsonl` | 0 | exact quote matches captured content |
| `evidence-new.jsonl` | 0 | same URI, changed captured content |
| `evidence-false-quote.jsonl` | 2 | `QUOTE_NOT_IN_SOURCE` in evidence mode |

The evidence fixtures exercise exact excerpt matching and cross-run source
changes. Exact matching does not establish semantic support or external truth.

`codex-cli-events.jsonl` is a redacted capture of one actual Codex CLI run.
`facts.txt` is the harmless local source used during the run. See
[`docs/live-validation.md`](../docs/live-validation.md) for the verification.
