# TraceCite

TraceCite is a MoonBit project for checking whether citations in an AI Agent's answer can be traced back to the tool results in the same run. The first release targets offline checks of a small JSONL event format, with deterministic diagnostics suitable for local tests and CI.

## Problem

An Agent may attach a citation to its answer even when the cited source was never returned by a tool, belongs to another run, or was returned by a tool call that failed. A readable answer alone cannot expose those errors.

TraceCite will check the recorded chain from tool call to tool result to source to final answer. It will not judge whether the source text actually proves the claim; that requires a separate semantic review.

## First release scope

- Parse one run of newline-delimited JSON events, reporting invalid lines with line numbers.
- Match tool results to their calls by `call_id`.
- Record source IDs and their originating successful tool results.
- Check every structured answer citation against a source from the same run.
- Report missing results, duplicate IDs, unknown citations, and sources from failed calls.
- Provide a MoonBit library API, a CLI command, passing and failing fixtures, and tests.

The first release will not invoke an LLM, crawl URLs, infer citations from prose, or claim that a cited source supports a statement.

## Draft JSONL contract

Each line is one JSON object. The contract will be finalized before the validator is implemented.

```jsonl
{"type":"tool_call","run_id":"demo-1","call_id":"search-1","tool":"search"}
{"type":"tool_result","run_id":"demo-1","call_id":"search-1","ok":true,"sources":[{"id":"doc-1","uri":"https://example.org/report","title":"Example report"}]}
{"type":"answer","run_id":"demo-1","claims":[{"text":"The report is available.","source_ids":["doc-1"]}]}
```

Expected result: zero structural diagnostics. Changing `doc-1` in the answer to an unknown ID should produce an error that points to the answer line.

## Planned acceptance check

1. `moon check`, `moon test`, and `moon run cmd/main` work on a fresh clone.
2. Both passing and failing JSONL fixtures have documented expected results.
3. A small adapter exports a real Agent run into the draft format, and the CLI checks it without private data.
4. The package is published to Mooncakes after the API and examples work.

## Current status

The MoonBit module and Git repository are initialized. The JSONL contract above is a proposal; validation is not implemented yet.

## Development

```sh
moon check
moon test
moon run cmd/main
```

## License

Apache-2.0.
