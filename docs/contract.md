# TraceCite JSONL v1

One UTF-8 file contains one Agent run. Each nonempty line is a JSON object with
`type` and `run_id`. Events are ordered by observation time. Unknown fields are
allowed so an adapter can retain its own metadata.

## Events

```jsonl
{"type":"tool_call","run_id":"r1","call_id":"c1","tool":"search"}
{"type":"tool_result","run_id":"r1","call_id":"c1","ok":true,"sources":[{"id":"s1","uri":"https://example.org/report","title":"Report"}]}
{"type":"answer","run_id":"r1","claims":[{"text":"The report is available.","source_ids":["s1"]}]}
```

- `tool_call`: `call_id` and `tool` are nonempty strings. A call ID is unique
  within the run.
- `tool_result`: `call_id` identifies an earlier call. `ok` is a Boolean.
  `sources` is an optional array of objects with nonempty `id` and `uri`.
  `title` is optional. Sources from failed results are invalid.
- `answer`: exactly one per run, after all tool events. `claims` is an array of
  objects containing nonempty `text` and a `source_ids` array. An empty array
  is allowed for a claim that does not need a citation; TraceCite does not
  decide which claims require citations.

The validator rejects malformed JSON, missing or mistyped required fields,
mixed run IDs, duplicate calls or sources, orphan or duplicate results,
unanswered calls, references to unknown sources, and tool events after the
final answer. Diagnostics carry a stable code and one-based input line number.

## Three use cases

1. **RAG answer review:** an Agent cites `s1`, but retrieval returned only
   `s2`. The validator points to the answer line and reports `UNKNOWN_SOURCE`.
2. **Tool failure review:** a search call failed but its adapter still emitted
   `s1`. The validator reports `SOURCE_ON_FAILED_RESULT`; it cannot be used to
   justify a later answer.
3. **Trace export review:** an exporter reuses `call_id` or `source.id` when
   merging records. The validator reports the duplicate and keeps the first
   valid record's provenance, so a later citation cannot silently change
   meaning.

## Evidence boundary

This is a structural provenance check. It does not fetch URLs, inspect private
systems, or determine whether a source's content supports a claim. It also
does not claim to prevent an Agent from fabricating the source record itself.
