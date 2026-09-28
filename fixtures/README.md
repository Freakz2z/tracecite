# TraceCite fixtures

Fixtures include synthetic validation cases and sanitized captures from real Codex CLI runs. The real source data is intentionally harmless.

| File | Purpose |
| --- | --- |
| `simple-citation.md` | Minimal `claim + quote + URL` input; live IANA page re-fetch passes |
| `web-source-trace.jsonl` | JSONL evidence input for testing HTTP source re-fetch |
| `codex-two-run-before-events.jsonl` | Sanitized events from first real Codex CLI run |
| `codex-two-run-after-events.jsonl` | Sanitized events from second real Codex CLI run |
| `codex-two-run-before.jsonl` | First real run exported with the CLI adapter |
| `codex-two-run-after.jsonl` | Second real run exported with the same source URI |
| `codex-live-run-source.txt` | Current source content from the second run |
| `evidence-old.jsonl` / `evidence-new.jsonl` | Small synthetic example of a source content change |
| `evidence-false-quote.jsonl` | Quote mismatch in offline evidence mode |
| `codex-cli-trace.jsonl` | Earlier sanitized Codex CLI command and answer sample |
| `codex-cli-file-trace.jsonl` | Earlier sample bound to a local file |
| `codex-cli-file-tampered.jsonl` | Deliberately altered file capture for `verify-files` |

The real two-run event files retain command status, observed output, and final answer while replacing session and item IDs. See [`docs/live-validation.md`](../docs/live-validation.md) for the method and boundaries.
