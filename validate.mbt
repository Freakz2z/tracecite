///|
/// Validate one JSONL Agent run. Each diagnostic identifies an input line and
/// a stable machine-readable code. This checks trace structure, not truth.
pub fn validate_jsonl(input : String) -> Report {
  let diagnostics : Array[Diagnostic] = []
  let events = parse_jsonl(input, diagnostics)
  let calls : Map[String, Int] = Map([])
  let results : Map[String, Int] = Map([])
  let source_lines : Map[String, Int] = Map([])
  let source_records : Array[SourceRecord] = []
  let call_ids : Array[String] = []
  let mut run_id : String? = None
  let mut answer_seen = false
  let mut claim_count = 0
  let mut last_line = 1

  if events.is_empty() {
    add_diagnostic(diagnostics, 1, "EMPTY_TRACE", "no valid events")
  }

  for event in events {
    let (event_run, line) = match event {
      ToolCall(id, _, line) => (id, line)
      ToolResult(id, _, _, _, line) => (id, line)
      Answer(id, _, line) => (id, line)
    }
    last_line = line
    match run_id {
      None => run_id = Some(event_run)
      Some(expected) =>
        if event_run != expected {
          add_diagnostic(
            diagnostics,
            line,
            "RUN_MISMATCH",
            "event belongs to run " + event_run + "; expected " + expected,
          )
          continue
        }
    }

    match event {
      ToolCall(_, call_id, line) =>
        if answer_seen {
          add_diagnostic(
            diagnostics, line, "EVENT_AFTER_ANSWER", "tool call after final answer",
          )
        } else if calls.get(call_id) is Some(first_line) {
          add_diagnostic(
            diagnostics,
            line,
            "DUPLICATE_CALL",
            "call_id " +
            call_id +
            " first appeared on line " +
            first_line.to_string(),
          )
        } else {
          calls.set(call_id, line)
          call_ids.push(call_id)
        }
      ToolResult(_, call_id, ok, sources, line) =>
        if answer_seen {
          add_diagnostic(
            diagnostics, line, "EVENT_AFTER_ANSWER", "tool result after final answer",
          )
        } else if calls.get(call_id) is None {
          add_diagnostic(
            diagnostics,
            line,
            "ORPHAN_RESULT",
            "unknown call_id: " + call_id,
          )
        } else if results.get(call_id) is Some(first_line) {
          add_diagnostic(
            diagnostics,
            line,
            "DUPLICATE_RESULT",
            "call_id " +
            call_id +
            " already has a result on line " +
            first_line.to_string(),
          )
        } else {
          results.set(call_id, line)
          if !ok && !sources.is_empty() {
            add_diagnostic(
              diagnostics, line, "SOURCE_ON_FAILED_RESULT", "failed tool result cannot provide sources",
            )
          } else if ok {
            for source in sources {
              if source_lines.get(source.id) is Some(first_line) {
                add_diagnostic(
                  diagnostics,
                  line,
                  "DUPLICATE_SOURCE",
                  "source id " +
                  source.id +
                  " first appeared on line " +
                  first_line.to_string(),
                )
              } else {
                source_lines.set(source.id, line)
                source_records.push({
                  id: source.id,
                  uri: source.uri,
                  title: source.title,
                  call_id,
                  line,
                })
              }
            }
          }
        }
      Answer(_, claims, line) =>
        if answer_seen {
          add_diagnostic(
            diagnostics, line, "DUPLICATE_ANSWER", "run already has a final answer",
          )
        } else {
          answer_seen = true
          claim_count = claims.length()
          for claim in claims {
            for id in claim.source_ids {
              if source_lines.get(id) is None {
                add_diagnostic(
                  diagnostics,
                  line,
                  "UNKNOWN_SOURCE",
                  "claim \"" + claim.text + "\" cites unknown source: " + id,
                )
              }
            }
          }
        }
    }
  }

  for call_id in call_ids {
    if results.get(call_id) is None {
      let line = calls.get(call_id).unwrap_or(1)
      add_diagnostic(
        diagnostics,
        line,
        "MISSING_RESULT",
        "no result for call_id: " + call_id,
      )
    }
  }
  if !answer_seen && !events.is_empty() {
    add_diagnostic(
      diagnostics, last_line, "MISSING_ANSWER", "run has no final answer",
    )
  }

  {
    run_id,
    event_count: events.length(),
    call_count: call_ids.length(),
    source_count: source_records.length(),
    claim_count,
    sources: source_records,
    diagnostics,
  }
}
