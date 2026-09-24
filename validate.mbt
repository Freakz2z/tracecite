///|
/// Validate one JSONL Agent run. Each diagnostic identifies an input line and
/// a stable machine-readable code. This checks trace structure, not truth.
pub fn validate_jsonl(input : String) -> Report {
  validate_jsonl_internal(input, false)
}

///|
/// Require each citation to quote bytes present in the captured tool output.
pub fn validate_evidence_jsonl(input : String) -> Report {
  validate_jsonl_internal(input, true)
}

///|
fn validate_jsonl_internal(input : String, require_evidence : Bool) -> Report {
  let diagnostics : Array[Diagnostic] = []
  let events = parse_jsonl(input, diagnostics)
  let calls : Map[String, Int] = Map([])
  let results : Map[String, Int] = Map([])
  let source_lines : Map[String, Int] = Map([])
  let source_calls : Map[String, String] = Map([])
  let source_contents : Map[String, String] = Map([])
  let source_uris : Map[String, Int] = Map([])
  let source_records : Array[SourceRecord] = []
  let citations : Array[CitationEdge] = []
  let call_ids : Array[String] = []
  let mut run_id : String? = None
  let mut answer_seen = false
  let mut claim_count = 0
  let mut verified_citation_count = 0
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
              if require_evidence && source.content is None {
                add_diagnostic(
                  diagnostics,
                  line,
                  "MISSING_SOURCE_CONTENT",
                  "source has no captured content: " + source.id,
                )
              }
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
                if require_evidence &&
                  source_uris.get(source.uri) is Some(first_line) {
                  add_diagnostic(
                    diagnostics,
                    line,
                    "DUPLICATE_URI",
                    "source URI first appeared on line " +
                    first_line.to_string(),
                  )
                }
                source_uris.set(source.uri, line)
                source_lines.set(source.id, line)
                source_calls.set(source.id, call_id)
                if source.content is Some(content) {
                  source_contents.set(source.id, content)
                }
                source_records.push({
                  id: source.id,
                  uri: source.uri,
                  title: source.title,
                  call_id,
                  line,
                  content_present: source.content is Some(_),
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
          if require_evidence && claims.is_empty() {
            add_diagnostic(
              diagnostics, line, "EMPTY_ANSWER", "evidence mode requires at least one claim",
            )
          }
          for claim_index = 0
              claim_index < claims.length()
              claim_index = claim_index + 1 {
            let claim = claims[claim_index]
            if require_evidence && claim.citations.is_empty() {
              add_diagnostic(
                diagnostics,
                line,
                "UNCITED_CLAIM",
                "claim " + (claim_index + 1).to_string() + " has no citation",
              )
            }
            for citation in claim.citations {
              let id = citation.source_id
              let call_id = source_calls.get(id)
              let mut evidence_status = "unverified"
              if call_id is Some(_) {
                match citation.quote {
                  None =>
                    if require_evidence {
                      add_diagnostic(
                        diagnostics,
                        line,
                        "MISSING_QUOTE",
                        "citation lacks an exact quote for source: " + id,
                      )
                    }
                  Some(quote) =>
                    match source_contents.get(id) {
                      None =>
                        add_diagnostic(
                          diagnostics,
                          line,
                          "MISSING_SOURCE_CONTENT",
                          "source has no captured content: " + id,
                        )
                      Some(content) =>
                        if content.contains(quote) {
                          evidence_status = "matched"
                          verified_citation_count = verified_citation_count + 1
                        } else {
                          evidence_status = "mismatch"
                          add_diagnostic(
                            diagnostics,
                            line,
                            "QUOTE_NOT_IN_SOURCE",
                            "quote not found in captured content for source: " +
                            id,
                          )
                        }
                    }
                }
              }
              citations.push({
                claim_index: claim_index + 1,
                source_id: id,
                call_id,
                line,
                evidence_status,
              })
              if call_id is None {
                add_diagnostic(
                  diagnostics,
                  line,
                  "UNKNOWN_SOURCE",
                  "claim " +
                  (claim_index + 1).to_string() +
                  " cites unknown source: " +
                  id,
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
    verified_citation_count,
    sources: source_records,
    citations,
    diagnostics,
  }
}
